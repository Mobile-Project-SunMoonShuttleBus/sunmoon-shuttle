import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
=======
import 'main_map_page.dart';     
import 'bus_stops_screen.dart';  
import 'timetable_screen.dart'; 
// [추가] 새로 만든 화면들 임포트
import 'portal_login_screen.dart'; 
>>>>>>> f110e58bb7fd74024b6752e3978237cce5b26de7
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // [위젯 페이지 목록 - 통합 완료]
  final List<Widget> _widgetPages = [
    MainMapPage(),          // 0: 메인화면
    BusStopsScreen(),       // 1: 위치
    TimetableScreen(),      // 2: 셔틀시간표 (기존 timetable_screen)
    const PortalLoginScreen(), // 3: 학기시간표 (새로 추가됨)
    const SettingsScreen(),    // 4: 설정 (새로 추가됨)
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
<<<<<<< HEAD
  void dispose() {
    // 화면 종료 시에도 추적은 계속 (백그라운드 지원)
    // 앱이 완전히 종료될 때만 중지
    super.dispose();
  }

  /// 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    try {
      // 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition();
      
      setState(() {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
        _isLoadingLocation = false;
      });

      // 지도 컨트롤러가 이미 생성되었다면 카메라 이동
      if (_mapController != null) {
        await _mapController!.updateCamera(
          NCameraUpdate.withParams(
            target: NLatLng(_currentLatitude, _currentLongitude),
            zoom: 15,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔴 현재 위치 가져오기 실패: $e');
      }
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  /// 혼잡도 자동 추적 시작 (백그라운드에서도 작동)
  Future<void> _startCongestionTracking() async {
    // 버스 운영 시간 확인
    if (!CongestionService.I.isBusOperatingTime(DateTime.now())) {
      return;
    }

    // 이미 추적 중이면 중복 시작하지 않음
    if (CongestionService.I.isTracking) {
      return;
    }

    try {
      // 백그라운드에서도 작동하도록 자동 추적 시작
      await CongestionService.I.startAutoTracking(
        onError: (error) {
          // 사용자에게는 조용히 실패 (필요시 스낵바로 알림 가능)
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 혼잡도 추적 시작 실패: $e');
      }
    }
  }

  /// 앱 시작 시 공지 동기화 (백그라운드에서 조용히 실행)
  /// - 로그인 성공 후 자동으로 크롤링 및 동기화 수행
  /// - 에러 발생해도 앱은 정상 동작하도록 조용히 처리
  Future<void> _syncNoticesOnStartup() async {
    try {
      // 백그라운드에서 조용히 동기화 실행 (사용자 알림 없음)
      await NoticeApi.I.syncShuttleNotices();
    } catch (e) {
      // 동기화 실패해도 앱은 정상 동작하도록 에러만 로깅
      // 사용자에게는 알림하지 않음 (백그라운드 작업이므로)
      if (kDebugMode) {
        print('⚠️ 앱 시작 시 공지 동기화 실패: $e');
      }
    }
  }

  /// 학기 시간표 버튼 클릭 시 WebView로 포털 로그인 페이지 표시
  Future<void> _navigateToTimetable(BuildContext context) async {
    // 바로 WebView로 포털 로그인 페이지 표시
    if (mounted) {
      final loginResult = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const PortalLoginScreen(),
        ),
      );
      
      // 로그인 성공 시 시간표 화면으로 이동 (로그인 성공 메시지 표시)
      if (loginResult == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const TimetableScreen(showLoginSuccess: true),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            children: [
              // 헤더 영역
              _buildHeader(),
              // 공지사항 바
              _buildAnnouncementBar(),
              // 메인 콘텐츠 영역 (지도)
              Expanded(
                child: kIsWeb
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.map,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '지도는 모바일 앱에서만 사용할 수 있습니다.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : _isLoadingLocation
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : Stack(
                            children: [
                              // 네이버 지도
                              NaverMap(
                                options: NaverMapViewOptions(
                                  initialCameraPosition: NCameraPosition(
                                    target: NLatLng(_currentLatitude, _currentLongitude),
                                    zoom: 15,
                                  ),
                                  mapType: NMapType.basic,
                                ),
                                onMapReady: (controller) async {
                                  _mapController = controller;
                                  setState(() {
                                    _isMapReady = true;
                                  });
                                  
                                  // 현재 위치로 카메라 이동
                                  await controller.updateCamera(
                                    NCameraUpdate.withParams(
                                      target: NLatLng(_currentLatitude, _currentLongitude),
                                      zoom: 15,
                                    ),
                                  );
                                  
                                  // 현재 위치 마커 추가
                                  controller.addOverlay(NMarker(
                                    id: 'current_location',
                                    position: NLatLng(_currentLatitude, _currentLongitude),
                                  ));
                                },
                                onMapTapped: (point, latLng) {
                                  // 지도 탭 처리 (필요시 구현)
                                },
                              ),
                    // 탑승위치/탑승시간 정보 박스
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '탑승위치 / 탑승시간',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '아산역 / 09:00',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1890FF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
=======
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      
      // IndexedStack 대신 현재 페이지만 렌더링 (지도 최적화)
      body: _widgetPages[_selectedIndex],
      
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          _buildNavItem(
            'assets/icons/main.png', 
            'assets/icons/main_active.png', 
            '메인화면'
>>>>>>> f110e58bb7fd74024b6752e3978237cce5b26de7
          ),
          _buildNavItem(
            'assets/icons/nav_location.png', 
            'assets/icons/nav_location_active.png', 
            '위치'
          ),
          _buildNavItem(
            'assets/icons/nav_calendar_bus1.png', 
            'assets/icons/nav_calendar_bus1_active.png', 
            '셔틀시간표' // [수정] 텍스트 변경 완료
          ),
          _buildNavItem(
            'assets/icons/nav_calendar_bus2.png', 
            'assets/icons/nav_calendar_bus2_active.png', 
            '학기시간표' // [수정] 텍스트 변경 완료
          ),
          _buildNavItem(
            'assets/icons/nav_settings.png', 
            'assets/icons/nav_settings_active.png', 
            '설정'
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey[400],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, 
        showSelectedLabels: true, 
        showUnselectedLabels: true,
        backgroundColor: Colors.white,
        elevation: 10,
        // 라벨 텍스트 크기 조정 (글자가 길어져서 조금 줄임)
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  // [헬퍼 함수]
  BottomNavigationBarItem _buildNavItem(String iconPath, String activeIconPath, String label) {
    return BottomNavigationBarItem(
      icon: Image.asset(
        iconPath, 
        width: 24, // 아이콘 크기 약간 조정 (텍스트 공간 확보)
        height: 24,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline),
      ),
      activeIcon: Image.asset(
        activeIconPath, 
        width: 24, 
        height: 24,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
      ),
      label: label,
    );
  }
}