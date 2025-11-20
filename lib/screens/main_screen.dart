import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings_screen.dart';
import '../features/portal/screens/portal_timetable_webview.dart';
import '../features/notice/screens/notice_list_screen.dart';
import '../features/settings/providers/settings_provider.dart';
import '../core/localization/app_localizations.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isFavorite = false;
  int _selectedIndex = 0; // 현재 선택된 탭 인덱스

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 설정 로드 (토큰 기반 me 조회 시 pref 반영)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
    });
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
              // 메인 콘텐츠 영역 (추후 버튼 등 추가 가능)
              Expanded(
                child: Container(
                  color: Colors.white,
                  // 여기에 버튼 등 추가할 수 있습니다
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
            // 공지사항 클릭 시 모달 창 열기
            showDialog(
              context: context,
              builder: (context) => const NoticeListScreen(),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[200],
            child: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  l10n.announcement,
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
              // 일정 + 졸업모 아이콘 (학기 시간표 - 포털 로그인)
              _buildNavItem(
                icon: Icons.calendar_today,
                overlayIcon: Icons.school,
                isSelected: _selectedIndex == 2,
                onTap: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                  // 포털 시간표 WebView로 이동 (쿠키 확인 후 분기)
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PortalTimetableWebView(),
                    ),
                  );
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

