/// 혼잡도 판정 및 위치 추적 서비스
/// - GPS 위치 추적 (포그라운드/백그라운드 모두 지원)
/// - 속도 측정
/// - 혼잡도 판정 (사용자 속도 < 버스 속도)
/// - 백엔드로 리포트 전송
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/congestion_models.dart';
import '../api/congestion_api.dart';

class CongestionService {
  static final CongestionService I = CongestionService._internal();
  CongestionService._internal();

  StreamSubscription<Position>? _positionStream;
  LocationData? _lastLocation;
  bool _isTracking = false;
  String? _currentRouteId;
  String? _currentStopId;

  // 버스 평균 속도 (km/h)
  static const double _busAverageSpeed = 50.0; // 도심/고속도로 평균
  
  // 버스 탑승 판정 속도 (km/h) - 이 속도 이상이면 버스 탑승으로 판단
  static const double _busBoardingSpeed = 20.0; // 20km/h 이상이면 버스 탑승으로 판단

  // 위치 업데이트 설정 (백그라운드 지원)
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // 10m 이상 이동 시 업데이트
  );
  
  // 백그라운드 위치 추적 설정
  static const LocationSettings _backgroundLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  /// 위치 추적 시작 (자동 감지 모드)
  /// 지도 화면에 있을 때 자동으로 호출
  /// routeId와 stopId는 나중에 자동 감지하거나 기본값 사용
  Future<void> startAutoTracking({
    String? routeId,
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
      _currentRouteId = routeId ?? 'R001'; // 기본값 또는 자동 감지
      _currentStopId = stopId ?? 'S001'; // 기본값 또는 자동 감지

      if (kDebugMode) {
        print('🔵 혼잡도 자동 위치 추적 시작');
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

    if (kDebugMode) {
      print('🔵 혼잡도 위치 추적 중지');
    }
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

    // 속도 계산
    final speedMeasurement = _calculateSpeed(_lastLocation!, currentLocation);

    if (kDebugMode) {
      print('📍 위치 업데이트: 속도 ${speedMeasurement.speedKmh.toStringAsFixed(1)} km/h');
    }

    // 버스 탑승 자동 감지: 속도가 일정 이상이면 버스 탑승으로 판단
    final isOnBus = speedMeasurement.speedKmh >= _busBoardingSpeed;
    
    if (!isOnBus) {
      // 버스에 탑승하지 않았으면 혼잡도 측정 안 함
      _lastLocation = currentLocation;
      return;
    }

    // 버스 탑승 중이고, 사용자 속도 < 버스 속도 → 혼잡
    if (speedMeasurement.speedKmh < _busAverageSpeed) {
      final congestionIndex = _calculateCongestionIndex(speedMeasurement.speedKmh);
      
      if (kDebugMode) {
        print('🚌 혼잡도 판정: $congestionIndex (속도: ${speedMeasurement.speedKmh.toStringAsFixed(1)} km/h < 버스: $_busAverageSpeed km/h)');
      }

      // 백엔드로 리포트 전송
      _sendCongestionReport(
        routeId: _currentRouteId!,
        stopId: _currentStopId!,
        index: congestionIndex,
      );
    }

    _lastLocation = currentLocation;
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

  /// 백엔드로 혼잡도 리포트 전송
  Future<void> _sendCongestionReport({
    required String routeId,
    required String stopId,
    required int index,
  }) async {
    try {
      final now = DateTime.now();
      final weekday = now.weekday - 1; // 0=월요일, 6=일요일
      final timeSlot = _calculateTimeSlot(now);

      final request = CongestionReportRequest(
        routeId: routeId,
        stopId: stopId,
        weekday: weekday,
        timeSlot: timeSlot,
        index: index,
      );

      await CongestionApi.I.reportCongestion(request);

      if (kDebugMode) {
        print('✅ 혼잡도 리포트 전송 완료: $index');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 혼잡도 리포트 전송 실패: $e');
      }
      // 전송 실패해도 위치 추적은 계속
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
  
  /// 현재 노선/정류장 업데이트 (자동 감지 또는 사용자 선택 시)
  void updateRouteAndStop({String? routeId, String? stopId}) {
    if (routeId != null) _currentRouteId = routeId;
    if (stopId != null) _currentStopId = stopId;
    
    if (kDebugMode) {
      print('📍 노선/정류장 업데이트: routeId=$_currentRouteId, stopId=$_currentStopId');
    }
  }
}

