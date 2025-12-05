/// 혼잡도 판정 및 위치 추적 서비스
/// - GPS 위치 추적 (포그라운드/백그라운드 모두 지원)
/// - 속도 측정
/// - 혼잡도 판정 (사용자 속도 < 버스 속도)
/// - 백엔드로 리포트 전송
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/congestion_models.dart';
import '../api/congestion_api.dart';

class CongestionService {
  static final CongestionService I = CongestionService._internal();
  CongestionService._internal();

  StreamSubscription<Position>? _positionStream;
  LocationData? _lastLocation;
  bool _isTracking = false;
  String? _currentBusType; // shuttle 또는 campus
  String? _currentStartId; // 출발지 이름 (예: "아산캠퍼스")
  String? _currentStopId; // 도착지 이름 (예: "아산(KTX)역")

  // 버스 평균 속도 (km/h)
  static const double _busAverageSpeed = 50.0; // 도심/고속도로 평균
  
  // 버스 탑승 판정 속도 (km/h) - 이 속도 이상이면 버스 탑승으로 판단
  static const double _busBoardingSpeed = 20.0; // 20km/h 이상이면 버스 탑승으로 판단
  
  // 버스 탑승 확인을 위한 연속 속도 체크 (최소 2회 연속)
  int _consecutiveBusSpeedCount = 0;
  static const int _minConsecutiveBusSpeed = 2; // 최소 2회 연속 버스 속도여야 탑승으로 판단
  
  // 혼잡도 리포트 전송 빈도 제한 (30초마다 최대 1회)
  DateTime? _lastReportTime;
  static const Duration _minReportInterval = Duration(seconds: 30);
  
  // 정지 상태 감지 (배터리 최적화)
  int _stationaryCount = 0;
  static const int _maxStationaryCount = 5; // 5회 연속 정지면 업데이트 빈도 감소
  static const double _stationarySpeedThreshold = 2.0; // 2km/h 이하면 정지로 판단
  
  // 실패한 리포트 재시도 큐
  final List<_PendingReport> _pendingReports = [];
  static const int _maxRetries = 3;

  // 위치 업데이트 설정 (백그라운드 지원)
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // 10m 이상 이동 시 업데이트
  );

  /// 위치 추적 시작 (자동 감지 모드)
  /// 지도 화면에 있을 때 자동으로 호출
  /// busType, startId, stopId는 나중에 자동 감지하거나 기본값 사용
  Future<void> startAutoTracking({
    String? busType,
    String? startId,
    String? stopId,
    Function(String)? onError,
  }) async {
    if (_isTracking) {
      if (kDebugMode) {
        print('⚠️ 위치 추적이 이미 시작되어 있습니다.');
      }
      return;
    }

    try {
      // 위치 권한 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('위치 서비스가 비활성화되어 있습니다.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onError?.call('위치 권한이 거부되었습니다.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onError?.call('위치 권한이 영구적으로 거부되었습니다.');
        return;
      }

      _isTracking = true;
      _lastLocation = null;
      _currentBusType = busType ?? 'shuttle'; // 기본값: 셔틀버스
      _currentStartId = startId ?? '아산캠퍼스'; // 기본값: 아산캠퍼스
      _currentStopId = stopId ?? '아산(KTX)역'; // 기본값: 아산(KTX)역
      _consecutiveBusSpeedCount = 0;
      _stationaryCount = 0;
      _lastReportTime = null;
      _pendingReports.clear();

      if (kDebugMode) {
      }

      // 위치 스트림 구독
      _positionStream = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        (Position position) {
          _handlePositionUpdate(position);
        },
        onError: (error) {
          if (kDebugMode) {
            print('❌ 위치 추적 오류: $error');
          }
          onError?.call('위치 추적 중 오류가 발생했습니다: $error');
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 위치 추적 시작 실패: $e');
      }
      onError?.call('위치 추적 시작 실패: $e');
      _isTracking = false;
    }
  }

  /// 위치 추적 중지
  void stopTracking() {
    if (!_isTracking) {
      return;
    }

    _positionStream?.cancel();
    _positionStream = null;
    _lastLocation = null;
    _isTracking = false;
    _consecutiveBusSpeedCount = 0;
    _stationaryCount = 0;
    _lastReportTime = null;
    _pendingReports.clear();
  }

  /// 위치 업데이트 처리 (자동 감지)
  void _handlePositionUpdate(Position position) {
    final now = DateTime.now();
    final currentLocation = LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed, // m/s
      timestamp: now,
    );

    if (_lastLocation == null) {
      // 첫 위치는 저장만
      _lastLocation = currentLocation;
      if (kDebugMode) {
        print('📍 첫 위치 저장: ${currentLocation.latitude}, ${currentLocation.longitude}');
      }
      return;
    }

    // 속도 계산 (GPS 속도와 계산 속도 모두 활용)
    final speedMeasurement = _calculateSpeed(_lastLocation!, currentLocation);
    
    // GPS 속도도 활용 (더 정확할 수 있음)
    final gpsSpeedKmh = (position.speed * 3.6); // m/s → km/h
    final finalSpeedKmh = gpsSpeedKmh > 0 && gpsSpeedKmh < 120 
        ? (speedMeasurement.speedKmh * 0.7 + gpsSpeedKmh * 0.3) // 계산 속도 70% + GPS 속도 30%
        : speedMeasurement.speedKmh; // GPS 속도가 비정상이면 계산 속도만 사용

    if (kDebugMode) {
      print('📍 위치 업데이트: 계산속도 ${speedMeasurement.speedKmh.toStringAsFixed(1)} km/h, GPS속도 ${gpsSpeedKmh.toStringAsFixed(1)} km/h, 최종 ${finalSpeedKmh.toStringAsFixed(1)} km/h');
    }

    // 정지 상태 감지 (배터리 최적화: 정지 상태에서는 혼잡도 측정 안 함)
    if (finalSpeedKmh <= _stationarySpeedThreshold) {
      _stationaryCount++;
      // 정지 상태가 지속되면 혼잡도 측정 안 함
      if (_stationaryCount >= _maxStationaryCount) {
        _lastLocation = currentLocation;
        return;
      }
    } else {
      _stationaryCount = 0; // 이동 중이면 카운터 리셋
    }

    // 버스 탑승 자동 감지: 연속적으로 일정 속도 이상이면 버스 탑승으로 판단
    if (finalSpeedKmh >= _busBoardingSpeed) {
      _consecutiveBusSpeedCount++;
    } else {
      _consecutiveBusSpeedCount = 0; // 속도가 떨어지면 리셋
    }
    
    final isOnBus = _consecutiveBusSpeedCount >= _minConsecutiveBusSpeed;
    
    if (!isOnBus) {
      // 버스에 탑승하지 않았으면 혼잡도 측정 안 함
      _lastLocation = currentLocation;
      return;
    }

    // 버스 탑승 중이고, 사용자 속도 < 버스 속도 → 혼잡
    if (finalSpeedKmh < _busAverageSpeed) {
      final congestionIndex = _calculateCongestionIndex(finalSpeedKmh);
      
      if (kDebugMode) {
        print('🚌 혼잡도 판정: $congestionIndex (속도: ${finalSpeedKmh.toStringAsFixed(1)} km/h < 버스: $_busAverageSpeed km/h)');
      }

      // 백엔드로 리포트 전송 (빈도 제한 + null 체크)
      if (_currentBusType != null && _currentStartId != null && _currentStopId != null) {
        _sendCongestionReportWithThrottle(
          busType: _currentBusType!,
          startId: _currentStartId!,
          stopId: _currentStopId!,
          index: congestionIndex,
          currentPosition: position,
        );
      } else {
        if (kDebugMode) {
          print('⚠️ busType, startId 또는 stopId가 설정되지 않아 리포트를 전송하지 않습니다.');
        }
      }
    }

    _lastLocation = currentLocation;
    
    // 실패한 리포트 재시도
    _retryPendingReports();
  }

  /// 두 위치 간 속도 계산
  SpeedMeasurement _calculateSpeed(LocationData start, LocationData end) {
    final distance = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    ); // m

    final duration = end.timestamp.difference(start.timestamp);
    final durationSeconds = duration.inSeconds;

    if (durationSeconds == 0) {
      return SpeedMeasurement(
        speedKmh: 0,
        distance: distance,
        duration: duration,
      );
    }

    // m/s → km/h 변환
    final speedMs = distance / durationSeconds;
    final speedKmh = speedMs * 3.6;

    return SpeedMeasurement(
      speedKmh: speedKmh,
      distance: distance,
      duration: duration,
    );
  }

  /// 혼잡도 지수 계산 (0~100)
  /// 속도가 낮을수록 혼잡도 높음
  int _calculateCongestionIndex(double userSpeedKmh) {
    if (userSpeedKmh <= 0) {
      return 100; // 정지 상태 = 매우 혼잡
    }

    if (userSpeedKmh >= _busAverageSpeed) {
      return 0; // 버스 속도 이상 = 여유
    }

    // 속도 비율 기반 계산
    final speedRatio = userSpeedKmh / _busAverageSpeed;
    final congestionIndex = ((1 - speedRatio) * 100).round();

    // 0~100 범위로 제한
    return congestionIndex.clamp(0, 100);
  }

  /// 백엔드로 혼잡도 리포트 전송 (빈도 제한)
  void _sendCongestionReportWithThrottle({
    required String busType,
    required String startId,
    required String stopId,
    required int index,
    Position? currentPosition,
  }) {
    final now = DateTime.now();
    
    // 빈도 제한 체크
    if (_lastReportTime != null) {
      final timeSinceLastReport = now.difference(_lastReportTime!);
      if (timeSinceLastReport < _minReportInterval) {
        if (kDebugMode) {
          print('⏱️ 리포트 전송 빈도 제한: ${timeSinceLastReport.inSeconds}초 전에 전송됨');
        }
        return;
      }
    }

    _lastReportTime = now;
    _sendCongestionReport(
      busType: busType,
      startId: startId,
      stopId: stopId,
      index: index,
      currentPosition: currentPosition,
    );
  }

  /// 백엔드로 혼잡도 리포트 전송
  Future<void> _sendCongestionReport({
    required String busType,
    required String startId,
    required String stopId,
    required int index,
    Position? currentPosition,
  }) async {
    try {
      final now = DateTime.now();
      final weekday = now.weekday - 1; // 0=월요일, 6=일요일 (Dart의 weekday는 1=월요일, 7=일요일)
      final timeSlot = _calculateTimeSlot(now);

      // meta 정보 수집
      CongestionMeta? meta;
      if (currentPosition != null) {
        // GPS 정확도는 Position 객체에서 가져올 수 있음 (미터 단위)
        final gpsAccuracy = currentPosition.accuracy;
        
        // OS 정보는 간단하게 생략 (나중에 package_info_plus 추가 가능)
        meta = CongestionMeta(
          appVer: '1.0.0', // pubspec.yaml의 version 사용
          os: null, // TODO: package_info_plus 또는 dart:io Platform 사용
          gpsAcc: gpsAccuracy > 0 ? gpsAccuracy : null,
        );
      }

      final request = CongestionReportRequest(
        busType: busType,
        startId: startId,
        stopId: stopId,
        weekday: weekday,
        timeSlot: timeSlot,
        index: index,
        clientTs: now, // 단말에서 리포트 전송 시각
        meta: meta,
      );

      await CongestionApi.I.reportCongestion(request);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 혼잡도 리포트 전송 실패: $e');
      }
      
      // 실패한 리포트를 재시도 큐에 추가
      _pendingReports.add(_PendingReport(
        busType: busType,
        startId: startId,
        stopId: stopId,
        index: index,
        retryCount: 0,
      ));
    }
  }

  /// 실패한 리포트 재시도
  Future<void> _retryPendingReports() async {
    if (_pendingReports.isEmpty) return;

    final now = DateTime.now();
    final reportsToRetry = _pendingReports.where((report) {
      // 마지막 시도로부터 10초 이상 지났으면 재시도
      final timeSinceLastRetry = now.difference(report.lastRetryTime);
      return timeSinceLastRetry.inSeconds >= 10;
    }).toList();

    for (final report in reportsToRetry) {
      if (report.retryCount >= _maxRetries) {
        // 최대 재시도 횟수 초과 시 제거
        _pendingReports.remove(report);
        if (kDebugMode) {
          print('❌ 리포트 재시도 포기: ${report.retryCount}회 실패');
        }
        continue;
      }

      try {
        final weekday = now.weekday - 1;
        final timeSlot = _calculateTimeSlot(now);
        
        final request = CongestionReportRequest(
          busType: report.busType,
          startId: report.startId,
          stopId: report.stopId,
          weekday: weekday,
          timeSlot: timeSlot,
          index: report.index,
          clientTs: now,
          meta: null, // 재시도 시에는 meta 정보 없이 전송
        );

        await CongestionApi.I.reportCongestion(request);
        
        // 성공 시 큐에서 제거
        _pendingReports.remove(report);
      } catch (e) {
        // 실패 시 재시도 카운트 증가
        report.retryCount++;
        report.lastRetryTime = now;
        
        if (kDebugMode) {
          print('⚠️ 리포트 재시도 실패 (${report.retryCount}/$_maxRetries): $e');
        }
      }
    }
  }

  /// 시간 슬롯 계산 (10분 단위)
  /// 예: 08:00 = 8*6+0 = 48, 08:10 = 8*6+1 = 49
  int _calculateTimeSlot(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final slot = (minute / 10).floor(); // 10분 단위
    return hour * 6 + slot;
  }

  /// 버스 운영 시간 확인
  /// TODO: 실제 노선 시간표 API와 연동 필요
  bool isBusOperatingTime(DateTime now) {
    final hour = now.hour;
    // 예시: 06:00 ~ 22:00 사이면 운영 시간
    return hour >= 6 && hour < 22;
  }

  /// 추적 중인지 확인
  bool get isTracking => _isTracking;
  
  /// 현재 버스 타입/출발지/도착지 업데이트 (자동 감지 또는 사용자 선택 시)
  void updateRouteAndStop({
    String? busType,
    String? startId,
    String? stopId,
  }) {
    if (busType != null) _currentBusType = busType;
    if (startId != null) _currentStartId = startId;
    if (stopId != null) _currentStopId = stopId;
    
    if (kDebugMode) {
      print('📍 버스 정보 업데이트: busType=$_currentBusType, startId=$_currentStartId, stopId=$_currentStopId');
    }
  }
}

/// 재시도 대기 중인 리포트
class _PendingReport {
  final String busType;
  final String startId;
  final String stopId;
  final int index;
  int retryCount;
  DateTime lastRetryTime;

  _PendingReport({
    required this.busType,
    required this.startId,
    required this.stopId,
    required this.index,
    required this.retryCount,
  }) : lastRetryTime = DateTime.now();
}

