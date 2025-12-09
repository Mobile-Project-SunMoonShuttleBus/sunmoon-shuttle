/// 수동 혼잡도 입력 모니터링 서비스
/// 정류장 근처 + 출발 시간 조건 충족 시 전역 모달 표시
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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

class ManualCongestionMonitor {
  static final ManualCongestionMonitor I = ManualCongestionMonitor._internal();
  ManualCongestionMonitor._internal();

  StreamSubscription<Position>? _positionStream;
  bool _isMonitoring = false;
  Timer? _checkTimer;
  
  // 정류장 정보 (웹사이트에 표시된 시간대 사용)
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

  static const double _stopRadiusM = 100.0; // 정류장 인식 반경 (미터)
  static const Duration _departureCheckWindow = Duration(minutes: 1); // 출발 시간 이후 1분 윈도우
  
  // 중복 방지: 같은 출발 시간대에 한 번만 표시
  final Set<String> _shownDepartureTimes = {}; // "정류장명_출발시간" 형식
  Timer? _clearShownTimesTimer;
  
  // 테스트 모드: 위치 체크를 우회하고 강제로 모달 표시
  bool _testMode = false;

  /// 모니터링 시작
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      if (kDebugMode) {
        print('⚠️ 수동 혼잡도 모니터링이 이미 시작되어 있습니다.');
      }
      return;
    }

    try {
      // 위치 권한 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('⚠️ 위치 서비스가 비활성화되어 있습니다.');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('⚠️ 위치 권한이 거부되었습니다.');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('⚠️ 위치 권한이 영구적으로 거부되었습니다.');
        }
        return;
      }

      _isMonitoring = true;
      _shownDepartureTimes.clear();

      // 매 10초마다 위치 체크
      _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _checkLocationAndShowModal();
      });

      // 매 시간마다 표시된 시간대 리셋 (같은 시간대에 다음 날 다시 표시 가능)
      _clearShownTimesTimer = Timer.periodic(const Duration(hours: 1), (_) {
        _shownDepartureTimes.clear();
      });

      if (kDebugMode) {
        print('✅ 수동 혼잡도 모니터링 시작');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 수동 혼잡도 모니터링 시작 실패: $e');
      }
      _isMonitoring = false;
    }
  }

  /// 모니터링 중지
  void stopMonitoring() {
    if (!_isMonitoring) {
      return;
    }

    _checkTimer?.cancel();
    _checkTimer = null;
    _clearShownTimesTimer?.cancel();
    _clearShownTimesTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
    _isMonitoring = false;
    _shownDepartureTimes.clear();

    if (kDebugMode) {
      print('⏹️ 수동 혼잡도 모니터링 중지');
    }
  }

  /// 위치 체크 및 모달 표시
  Future<void> _checkLocationAndShowModal() async {
    if (!_isMonitoring) return;

    // 테스트 모드: 위치 체크 우회하고 강제로 모달 표시
    if (_testMode) {
      _showTestModal();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final now = DateTime.now();

      // 정류장 찾기
      StopInfo? nearbyStop;
      double? distanceToStop;

      for (final stop in _stops) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
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
        return; // 정류장 근처가 아님
      }

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

      if (!isDepartureTime || departureTimeStr == null) {
        return; // 출발 시간이 아님
      }

      // 중복 방지: 같은 출발 시간대에 한 번만 표시
      final key = '${nearbyStop.name}_$departureTimeStr';
      if (_shownDepartureTimes.contains(key)) {
        return; // 이미 표시됨
      }

      // 모달 표시
      _shownDepartureTimes.add(key);

      if (kDebugMode) {
        print('📱 수동 혼잡도 모달 표시: ${nearbyStop.name} → 아산캠퍼스 ($departureTimeStr)');
      }

      // 전역 모달 표시
      ManualCongestionDialog.showGlobal(
        busType: 'shuttle',
        startId: nearbyStop.name,
        stopId: '아산캠퍼스',
        departureTime: departureTimeStr,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 위치 체크 실패: $e');
      }
    }
  }

  /// 테스트 모드: 강제로 모달 표시
  void _showTestModal() {
    // 서버 DB에 있는 실제 시간대로 테스트
    // 서버 데이터: departure: "아산캠퍼스", arrival: "천안 아산역"
    // 서버에 있는 출발 시간: 08:10, 09:40, 09:55, 10:55, 11:40, 12:40, 13:40, 14:40, 15:40, 16:40 등
    final serverDepartureTimes = ['08:10', '09:40', '09:55', '10:55', '11:40', '12:40', '13:40', '14:40', '15:40', '16:40'];
    
    // 현재 시간 이후 가장 가까운 출발 시간 찾기
    final now = DateTime.now();
    String? testDepartureTime;
    
    for (final depTimeStr in serverDepartureTimes) {
      final parts = depTimeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final depDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      // 현재 시간 이후의 출발 시간 중 가장 가까운 것 선택
      if (depDateTime.isAfter(now) || depDateTime.isAtSameMomentAs(now)) {
        testDepartureTime = depTimeStr;
        break;
      }
    }
    
    // 현재 시간 이후 출발 시간이 없으면 첫 번째 시간 사용
    testDepartureTime ??= serverDepartureTimes.first;
    
    if (kDebugMode) {
      print('🧪 테스트 모드: 수동 혼잡도 모달 강제 표시');
      print('   출발 시간: $testDepartureTime (아산캠퍼스 → 천안 아산역)');
      print('   ⚠️ 테스트 모드에서는 평일(월요일) 스케줄을 사용합니다.');
    }

    // 전역 모달 표시 (테스트 모드 표시를 위해 departureTime에 TEST 추가)
    // 서버 DB 형식에 맞춰서: startId="아산캠퍼스", stopId="천안 아산역"
    ManualCongestionDialog.showGlobal(
      busType: 'shuttle',
      startId: '아산캠퍼스',  // 서버 DB의 departure 형식
      stopId: '천안 아산역',  // 서버 DB의 arrival 형식
      departureTime: 'TEST$testDepartureTime', // 테스트 모드 표시
    );
  }

  /// 테스트 모드 활성화/비활성화
  void setTestMode(bool enabled) {
    _testMode = enabled;
    if (kDebugMode) {
      print('🧪 테스트 모드: ${enabled ? "활성화" : "비활성화"}');
    }
  }

  /// 테스트 모드로 강제 모달 표시 (위치/시간 체크 없이)
  void testShowModal() {
    if (!_isMonitoring) {
      if (kDebugMode) {
        print('⚠️ 모니터링이 시작되지 않았습니다. 먼저 로그인해주세요.');
      }
      return;
    }
    _showTestModal();
  }
}

