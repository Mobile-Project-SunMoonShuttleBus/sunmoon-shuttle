/// 혼잡도 판정 및 위치 추적 서비스
/// - GPS 위치 추적 (포그라운드/백그라운드 모두 지원)
/// - 속도 측정
/// - 혼잡도 판정 (사용자 속도 < 버스 속도)
/// - 정류장 출발 시간 기반 자동 혼잡도 판단
/// - 백엔드로 리포트 전송
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/congestion_models.dart';
import '../api/congestion_api.dart';
import '../widgets/manual_congestion_dialog.dart';

/// 정류장 정보
class StopInfo {
  final String name;
  final double latitude;
  final double longitude;
  final List<String> departureTimes; // HH:MM 형식

  StopInfo({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.departureTimes,
  });
}

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
  
  // 이동 중 판정 속도 (km/h) - 이 속도 이상이면 이동 중으로 판단 (사람의 걷는 속도)
  static const double _busBoardingSpeed = 2.5; // 2.5km/h 이상이면 이동 중으로 판단 (걷는 속도)
  
  // 이동 중 확인을 위한 연속 속도 체크 (최소 1회 연속)
  int _consecutiveBusSpeedCount = 0;
  static const int _minConsecutiveBusSpeed = 1; // 최소 1회 연속 이동 속도여야 이동 중으로 판단
  
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

  // 속도 감지 시 모달 표시 중복 방지
  DateTime? _lastSpeedModalTime;
  static const Duration _speedModalInterval = Duration(seconds: 90); // 1분 30초마다 최대 1회 모달 표시

  // 정류장 출발 시간 기반 자동 판단
  DateTime? _lastStopCheckTime; // 마지막 정류장 체크 시간
  LocationData? _stopLocation; // 정류장에 있을 때의 위치
  static const double _stopRadiusM = 100.0; // 정류장 인식 반경 (미터)
  static const Duration _departureCheckWindow = Duration(minutes: 1); // 출발 시간 이후 1분 윈도우
  
  // 정류장 정보 (외부 셔틀 승차장) - 웹사이트에 표시된 시간대 사용
  static final List<StopInfo> _stops = [
    StopInfo(
      name: '아산(KTX)역',
      latitude: 36.794978,
      longitude: 127.103806,
      departureTimes: [
        '07:40', '08:45', '11:30', '15:20'  // 웹사이트에 표시된 시간대
      ],
    ),
    StopInfo(
      name: '천안역',
      latitude: 36.809727,
      longitude: 127.145230,
      departureTimes: [
        '08:10', '08:55', '12:00', '15:40'  // 웹사이트에 표시된 시간대
      ],
    ),
    StopInfo(
      name: '천안터미널',
      latitude: 36.8220,
      longitude: 127.1810,
      departureTimes: [
        '07:30', '09:05', '11:45', '15:10'  // 웹사이트에 표시된 시간대
      ],
    ),
    StopInfo(
      name: '온양터미널/역',
      latitude: 36.7860,
      longitude: 127.0020,
      departureTimes: [
        '07:50', '08:35', '12:30', '15:50'  // 웹사이트에 표시된 시간대
      ],
    ),
  ];

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

    // 정류장 출발 시간 기반 자동 혼잡도 판단 (버스 탑승 전에도 작동)
    _checkStopDepartureAutoDetection(currentLocation, position);

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

    // 이동 중 자동 감지: 연속적으로 일정 속도 이상이면 이동 중으로 판단 (걷는 속도 기준)
    if (finalSpeedKmh >= _busBoardingSpeed) {
      _consecutiveBusSpeedCount++;
    } else {
      _consecutiveBusSpeedCount = 0; // 속도가 떨어지면 리셋
    }
    
    final isMoving = _consecutiveBusSpeedCount >= _minConsecutiveBusSpeed;
    
    if (!isMoving) {
      // 이동 중이 아니면 속도 기반 혼잡도 측정 안 함
      _lastLocation = currentLocation;
      return;
    }

    // 이동 중이고, 사용자 속도 < 버스 속도 → 혼잡 (셔틀장 밖에서도 작동)
    if (finalSpeedKmh < _busAverageSpeed) {
      final congestionIndex = _calculateCongestionIndex(finalSpeedKmh);
      
      if (kDebugMode) {
        print('🚌 혼잡도 판정: $congestionIndex (속도: ${finalSpeedKmh.toStringAsFixed(1)} km/h < 버스: $_busAverageSpeed km/h)');
      }

      // 속도 감지 시 모달 표시 (어떤 화면에 있든 표시)
      _showSpeedBasedModal(finalSpeedKmh);

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

  /// 정류장 출발 시간 기반 자동 혼잡도 판단
  void _checkStopDepartureAutoDetection(LocationData currentLocation, Position position) {
    if (_currentBusType == null || _currentStartId == null || _currentStopId == null) {
      return;
    }

    final now = DateTime.now();
    
    // 정류장 찾기
    StopInfo? nearbyStop;
    double? distanceToStop;
    
    for (final stop in _stops) {
      final distance = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        stop.latitude,
        stop.longitude,
      );
      
      if (distance <= _stopRadiusM) {
        nearbyStop = stop;
        distanceToStop = distance;
        break;
      }
    }
    
    if (nearbyStop == null) {
      // 정류장 근처가 아니면 리셋
      _stopLocation = null;
      _lastStopCheckTime = null;
      return;
    }
    
    // 정류장 근처에 있음
    if (_stopLocation == null) {
      // 처음 정류장에 도착한 경우
      _stopLocation = currentLocation;
      _lastStopCheckTime = now;
      if (kDebugMode) {
        print('📍 정류장 도착: ${nearbyStop.name} (거리: ${distanceToStop!.toStringAsFixed(1)}m)');
      }
      return;
    }
    
    // 정류장에 계속 있는 상태
    // 출발 시간 확인
    bool isDepartureTime = false;
    String? departureTimeStr;
    
    for (final depTimeStr in nearbyStop.departureTimes) {
      final parts = depTimeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      // 출발 시간 생성
      final depDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      // 출발 시간이 지났고, 1분 이내인지 확인
      if (now.isAfter(depDateTime) && now.difference(depDateTime) <= _departureCheckWindow) {
        isDepartureTime = true;
        departureTimeStr = depTimeStr;
        break;
      }
    }
    
    if (!isDepartureTime) {
      return; // 출발 시간이 아님
    }
    
    // 출발 시간이 되었고, 정류장에 계속 있는지 확인
    final distanceFromStop = Geolocator.distanceBetween(
      _stopLocation!.latitude,
      _stopLocation!.longitude,
      currentLocation.latitude,
      currentLocation.longitude,
    );
    
    // 마지막 체크로부터 1분 이상 지났는지 확인 (중복 리포트 방지)
    if (_lastStopCheckTime != null) {
      final timeSinceLastCheck = now.difference(_lastStopCheckTime!);
      if (timeSinceLastCheck < const Duration(minutes: 1)) {
        return; // 너무 자주 체크하지 않음
      }
    }
    
    _lastStopCheckTime = now;
    
    // 정류장에서 30m 이상 이동했으면 출발한 것으로 판단
    if (distanceFromStop > 30.0) {
      // 출발 성공 → 혼잡도 낮음
      final index = 20; // 여유
      if (kDebugMode) {
        print('✅ 정류장 출발 감지: ${nearbyStop.name} (${departureTimeStr}) → 혼잡도 낮음');
      }
      
      _sendCongestionReportWithThrottle(
        busType: _currentBusType!,
        startId: nearbyStop.name,
        stopId: _currentStopId!,
        index: index,
        currentPosition: position,
      );
      
      // 리셋
      _stopLocation = null;
    } else {
      // 정류장에 계속 머물러 있음 → 혼잡도 높음
      final index = 85; // 혼잡
      if (kDebugMode) {
        print('⚠️ 정류장 출발 실패: ${nearbyStop.name} (${departureTimeStr}) → 혼잡도 높음');
      }
      
      _sendCongestionReportWithThrottle(
        busType: _currentBusType!,
        startId: nearbyStop.name,
        stopId: _currentStopId!,
        index: index,
        currentPosition: position,
      );
    }
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
    int? timeSlot, // 테스트용: 직접 지정 가능 (null이면 현재 시간으로 계산)
  }) async {
    try {
      final now = DateTime.now();
      // 서버의 weekday: 0=일요일, 1=월요일, ..., 6=토요일 (서버 응답 확인)
      // Dart의 weekday: 1=월요일, 7=일요일
      final weekday = now.weekday == 7 ? 0 : now.weekday; // 일요일=0, 월요일=1, ..., 토요일=6
      final calculatedTimeSlot = timeSlot ?? _calculateTimeSlot(now);

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
        timeSlot: calculatedTimeSlot,
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
        // 서버의 weekday: 0=일요일, 1=월요일, ..., 6=토요일
        // Dart의 weekday: 1=월요일, 7=일요일
        final weekday = now.weekday == 7 ? 0 : now.weekday; // 일요일=0, 월요일=1, ..., 토요일=6
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

  /// 테스트: 모킹된 위치/속도로 자동 혼잡도 리포트 전송
  /// 실제 GPS 없이 테스트 가능
  /// 서버 DB에 있는 시간대(12:40, timeSlot: 76)를 사용하여 테스트
  Future<void> testAutoReport({
    required double latitude,
    required double longitude,
    required double speedKmh, // km/h
    String? busType,
    String? startId,
    String? stopId,
    String? testTime, // HH:MM 형식 (예: "12:40"), null이면 현재 시간 사용
  }) async {
    if (kDebugMode) {
      print('🧪 테스트: 모킹된 위치/속도로 자동 혼잡도 리포트 전송');
      print('   위치: $latitude, $longitude');
      print('   속도: $speedKmh km/h');
    }
    
    // 테스트 시간대 계산 (서버 DB에 있는 시간대 사용)
    int? testTimeSlot;
    if (testTime != null) {
      final parts = testTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      testTimeSlot = hour * 6 + (minute / 10).floor();
      if (kDebugMode) {
        print('   테스트 시간대: $testTime (timeSlot: $testTimeSlot)');
      }
    } else {
      // 기본값: 서버 DB에 있는 12:40 (timeSlot: 76) 사용
      testTimeSlot = 76; // 12:40
      if (kDebugMode) {
        print('   테스트 시간대: 12:40 (timeSlot: 76) - 서버 DB에 있는 시간대');
      }
    }

    // 모킹된 Position 객체 생성
    final mockPosition = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: speedKmh / 3.6, // km/h → m/s
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );

    // 모킹된 LocationData 생성
    final mockLocation = LocationData(
      latitude: latitude,
      longitude: longitude,
      speed: speedKmh / 3.6, // km/h → m/s
      timestamp: DateTime.now(),
    );

    // busType, startId, stopId 설정 (서버 DB에 있는 노선 사용)
    _currentBusType = busType ?? 'shuttle';
    _currentStartId = startId ?? '아산캠퍼스';
    _currentStopId = stopId ?? '천안 아산역'; // 서버 DB에 있는 정류장명

    // 속도 기반 혼잡도 판정 테스트
    if (speedKmh >= _busBoardingSpeed && speedKmh < _busAverageSpeed) {
      final congestionIndex = _calculateCongestionIndex(speedKmh);
      if (kDebugMode) {
        print('🚌 테스트 혼잡도 판정: $congestionIndex (속도: $speedKmh km/h)');
      }
      
      await _sendCongestionReport(
        busType: _currentBusType!,
        startId: _currentStartId!,
        stopId: _currentStopId!,
        index: congestionIndex,
        currentPosition: mockPosition,
        timeSlot: testTimeSlot, // 서버 DB에 있는 시간대 사용
      );
    } else if (speedKmh >= _busAverageSpeed) {
      if (kDebugMode) {
        print('✅ 테스트: 속도가 정상 범위 ($speedKmh km/h >= $_busAverageSpeed km/h) - 리포트 전송 안 함');
      }
    } else {
      if (kDebugMode) {
        print('⚠️ 테스트: 버스 탑승 속도 미달 ($speedKmh km/h < $_busBoardingSpeed km/h) - 리포트 전송 안 함');
      }
    }

    // 정류장 출발 시간 기반 자동 판단 테스트
    _checkStopDepartureAutoDetection(mockLocation, mockPosition);
  }

  /// 테스트: 정류장 출발 시간 기반 리포트 (모킹 위치)
  /// departureTime을 timeSlot으로 변환하여 서버 DB에 있는 시간대 사용
  Future<void> testStopDepartureReport({
    required String stopName,
    required String departureTime, // HH:MM 형식
    required double latitude,
    required double longitude,
    required bool hasDeparted, // true: 출발함 (30m 이상 이동), false: 머물러 있음
    String? busType,
    String? stopId,
  }) async {
    if (kDebugMode) {
      print('🧪 테스트: 정류장 출발 시간 기반 리포트');
      print('   정류장: $stopName');
      print('   출발 시간: $departureTime');
      print('   출발 여부: $hasDeparted');
    }
    
    // departureTime을 timeSlot으로 변환
    final parts = departureTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final testTimeSlot = hour * 6 + (minute / 10).floor();
    if (kDebugMode) {
      print('   timeSlot: $testTimeSlot (출발 시간: $departureTime)');
    }

    // 정류장 찾기
    StopInfo? targetStop;
    for (final stop in _stops) {
      if (stop.name == stopName) {
        targetStop = stop;
        break;
      }
    }

    if (targetStop == null) {
      if (kDebugMode) {
        print('❌ 테스트 실패: 정류장을 찾을 수 없습니다: $stopName');
      }
      return;
    }

    // 모킹된 Position 객체 생성
    final mockPosition = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );

    // 출발 여부에 따라 위치 조정
    double testLatitude = latitude;
    double testLongitude = longitude;
    
    if (hasDeparted) {
      // 정류장에서 30m 이상 떨어진 위치로 설정
      // 간단하게 위도에 0.0003 추가 (약 33m)
      testLatitude = latitude + 0.0003;
    }

    final mockLocation = LocationData(
      latitude: testLatitude,
      longitude: testLongitude,
      speed: 0.0,
      timestamp: DateTime.now(),
    );

    // busType, startId, stopId 설정 (서버 DB에 있는 노선 사용)
    _currentBusType = busType ?? 'shuttle';
    _currentStartId = '아산캠퍼스'; // 서버 DB에 있는 출발지
    _currentStopId = stopId ?? '천안 아산역'; // 서버 DB에 있는 도착지

    // 정류장 위치 저장 (시뮬레이션)
    _stopLocation = LocationData(
      latitude: targetStop.latitude,
      longitude: targetStop.longitude,
      speed: 0.0,
      timestamp: DateTime.now(),
    );

    // 출발 여부에 따라 리포트 전송
    final index = hasDeparted ? 20 : 85; // 출발함: 낮음, 머물러 있음: 높음
    
    if (kDebugMode) {
      print('📤 테스트 리포트 전송: index=$index (${hasDeparted ? "출발함" : "머물러 있음"})');
      print('   노선: $_currentStartId → $_currentStopId');
    }

    await _sendCongestionReport(
      busType: _currentBusType!,
      startId: _currentStartId!,
      stopId: _currentStopId!,
      index: index,
      currentPosition: mockPosition,
      timeSlot: testTimeSlot, // 출발 시간을 timeSlot으로 변환하여 사용
    );

    // 리셋
    _stopLocation = null;
  }

  /// 속도 감지 시 모달 표시 (어떤 화면에 있든 표시)
  void _showSpeedBasedModal(double speedKmh) {
    final now = DateTime.now();
    
    // 중복 방지: 1분 30초마다 최대 1회 모달 표시
    if (_lastSpeedModalTime != null) {
      final timeSinceLastModal = now.difference(_lastSpeedModalTime!);
      if (timeSinceLastModal < _speedModalInterval) {
        if (kDebugMode) {
          print('⏱️ 속도 기반 모달 빈도 제한: ${timeSinceLastModal.inSeconds}초 전에 표시됨 (${_speedModalInterval.inSeconds}초 필요)');
        }
        return;
      }
    }

    // busType, startId, stopId가 설정되지 않았으면 기본값 사용
    final busType = _currentBusType ?? 'shuttle';
    final startId = _currentStartId ?? '아산캠퍼스';
    final stopId = _currentStopId ?? '천안 아산역';
    
    // 현재 시간을 출발 시간으로 사용 (HH:MM 형식)
    final departureTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    if (kDebugMode) {
      final timeSinceLast = _lastSpeedModalTime != null 
          ? now.difference(_lastSpeedModalTime!).inSeconds 
          : null;
      print('📱 속도 기반 혼잡도 모달 표시 시도: 속도 ${speedKmh.toStringAsFixed(1)} km/h (마지막 모달: ${timeSinceLast != null ? "${timeSinceLast}초 전" : "없음"})');
    }

    // 전역 모달 표시 (어떤 화면에 있든 표시)
    // 모달이 실제로 표시되고 닫혔을 때만 시간을 업데이트
    ManualCongestionDialog.showGlobal(
      busType: busType,
      startId: startId,
      stopId: stopId,
      departureTime: 'SPEED_$departureTime', // 속도 기반임을 표시
    ).then((wasShown) {
      // 모달이 실제로 표시되고 닫혔을 때만 시간 업데이트
      // 입력했든 안 했든, 자동으로 닫혔든 상관없이 모달이 닫혔으면 시간 업데이트
      if (wasShown) {
        _lastSpeedModalTime = DateTime.now();
        if (kDebugMode) {
          print('✅ 속도 기반 모달 닫힘: 시간 업데이트됨 (다음 모달은 1분 30초 후 표시 가능)');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ 속도 기반 모달 표시 실패: 시간 업데이트 안 함');
        }
      }
    }).catchError((error) {
      // 에러 발생 시에도 시간 업데이트하지 않음
      if (kDebugMode) {
        print('❌ 속도 기반 모달 표시 중 에러: $error');
      }
    });
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

