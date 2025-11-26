import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'settings_screen.dart';
import '../features/portal/screens/portal_timetable_webview.dart';
import '../features/portal/screens/timetable_screen.dart';
import '../features/notice/screens/notice_list_screen.dart';
import '../features/settings/providers/settings_provider.dart';
import '../core/localization/app_localizations.dart';
import 'notice/shuttle_notice_list_screen.dart';
import '../api/notice_api.dart';
import 'portal_login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isFavorite = false;
  int _selectedIndex = 0; // 현재 선택된 탭 인덱스
  NaverMapController? _mapController;
  
  // 현재 위치 좌표 (기본값: 아산역)
  double _currentLatitude = 36.7946;
  double _currentLongitude = 127.1047;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    // 현재 위치 가져오기
    _getCurrentLocation();
    // 앱 시작 시 설정 로드 (토큰 기반 me 조회 시 pref 반영)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
      // 앱 시작 시 공지 동기화 (백그라운드에서 실행)
      _syncNoticesOnStartup();
    });
  }

  /// 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    try {
      if (kDebugMode) {
        print('🔵 현재 위치 가져오기 시작');
      }
      
      // 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('⚠️ 위치 서비스가 비활성화되어 있습니다.');
        }
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
          if (kDebugMode) {
            print('⚠️ 위치 권한이 거부되었습니다.');
          }
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('⚠️ 위치 권한이 영구적으로 거부되었습니다.');
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition();
      if (kDebugMode) {
        print('✅ 현재 위치: ${position.latitude}, ${position.longitude}');
      }
      
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

  /// 앱 시작 시 공지 동기화 (에러 발생해도 앱은 정상 동작)
  Future<void> _syncNoticesOnStartup() async {
    try {
      if (kDebugMode) {
        print('🔵 앱 시작 시 공지 동기화 시작');
      }
      await NoticeApi.I.syncShuttleNotices();
      if (kDebugMode) {
        print('✅ 앱 시작 시 공지 동기화 완료');
      }
    } catch (e) {
      // 동기화 실패해도 앱은 정상 동작하도록 에러만 로깅
      if (kDebugMode) {
        print('⚠️ 앱 시작 시 공지 동기화 실패: $e');
      }
      // 사용자에게는 조용히 실패 (필요시 스낵바로 알림 가능)
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
                                  minZoom: 10.0,
                                  maxZoom: 20.0,
                                  scrollGesturesEnabled: true,
                                  zoomGesturesEnabled: true,
                                  tiltGesturesEnabled: true,
                                  rotateGesturesEnabled: true,
                                  locationButtonEnable: false,
                                  consumeSymbolTapEvents: false,
                                ),
                                onMapReady: (controller) async {
                                  _mapController = controller;
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
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // 헤더: 버스 이모지 + 제목 + 별 버튼
  Widget _buildHeader() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final l10n = AppLocalizations(settingsProvider.isKorean);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 버스 이모지
              const Text(
                '🚌',
                style: TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 8),
              // 제목
              Expanded(
                child: Text(
                  l10n.appTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
          // 별 버튼 (즐겨찾기)
          GestureDetector(
            onTap: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isFavorite ? Icons.star : Icons.star_border,
                color: const Color(0xFF1890FF),
                size: 24,
              ),
            ),
            ),
          ],
        ),
      );
      },
    );
  }

  // 공지사항 바
  Widget _buildAnnouncementBar() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final l10n = AppLocalizations(settingsProvider.isKorean);
        return GestureDetector(
          onTap: () {
            // 공지사항 클릭 시 모달창으로 셔틀 공지 표시
            showDialog(
              context: context,
              builder: (context) => Dialog(
                insetPadding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 600,
                    maxHeight: double.infinity,
                  ),
                  child: const ShuttleNoticeListScreen(),
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[200],
            child: Row(
              children: [
                const Icon(Icons.announcement_outlined, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '셔틀 공지',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  // 하단 네비게이션 바
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 위치 아이콘 (현재 선택됨)
              _buildNavItem(
                icon: Icons.location_on,
                isSelected: _selectedIndex == 0,
                onTap: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
              // 일정 + 버스 아이콘
              _buildNavItem(
                icon: Icons.calendar_today,
                overlayIcon: Icons.directions_bus,
                isSelected: _selectedIndex == 1,
                onTap: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                  // 일정 화면으로 이동 (추후 구현)
                },
              ),
              // 일정 + 졸업모 아이콘 (학기 시간표 - API 기반)
              _buildNavItem(
                icon: Icons.calendar_today,
                overlayIcon: Icons.school,
                isSelected: _selectedIndex == 2,
                onTap: () async {
                  setState(() {
                    _selectedIndex = 2;
                  });
                  // 포털 계정 정보 확인 후 분기
                  await _navigateToTimetable(context);
                },
              ),
              // 설정 아이콘
              _buildNavItem(
                icon: Icons.settings,
                isSelected: _selectedIndex == 3,
                onTap: () {
                  // 설정 화면 열기
                  showDialog(
                    context: context,
                    builder: (context) => const SettingsScreen(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 네비게이션 아이템 위젯
  Widget _buildNavItem({
    required IconData icon,
    IconData? overlayIcon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 메인 아이콘
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1890FF) : Colors.grey[600],
              size: isSelected ? 28 : 24,
            ),
            // 오버레이 아이콘 (일정 + 버스, 일정 + 졸업모)
            if (overlayIcon != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    overlayIcon,
                    color: isSelected ? const Color(0xFF1890FF) : Colors.grey[600],
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


