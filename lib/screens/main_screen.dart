import 'package:flutter/material.dart';
import 'main_map_page.dart';     
import 'bus_stops_screen.dart';  
import 'timetable_screen.dart'; 
// [추가] 새로 만든 화면들 임포트
import 'portal_login_screen.dart'; 
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