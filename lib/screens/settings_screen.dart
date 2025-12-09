// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart'; // [필수] 설정 로직
import '../core/localization/app_localizations.dart'; // [필수] 다국어 텍스트
import '../services/manual_congestion_monitor.dart';
import '../services/congestion_service.dart';
import '../api/congestion_api.dart';
import '../models/congestion_models.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'notice/shuttle_notice_list_screen.dart'; // 셔틀 공지 화면
import 'package:flutter/foundation.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 설정 Provider와 인증 Provider 가져오기
    final settings = context.watch<SettingsProvider>();
    final auth = context.read<AuthProvider>();
    
    // 2. 현재 언어 상태에 따른 텍스트 번역기 생성
    final l10n = AppLocalizations(settings.isKorean);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle), // "설정" or "Settings"
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          
          // --- 언어 설정 섹션 ---
          _buildSectionHeader(l10n.language), // "언어 설정"
          SwitchListTile(
            title: Text(l10n.languageOption), // "한국어" or "English"
            subtitle: Text(settings.isKorean ? '한국어로 사용 중' : 'Using English'),
            value: settings.isKorean,
            activeColor: Colors.blue[800],
            onChanged: (bool value) {
              // 스위치 토글 시 언어 변경 함수 호출
              settings.setLanguage(value);
            },
            secondary: const Icon(Icons.language),
          ),
          const Divider(),

          // --- 계정 섹션 ---
          _buildSectionHeader(l10n.account),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.logout),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.logout),
                  content: Text(l10n.logoutConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await auth.logout();
                if (context.mounted) {
                   Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
          
          const Divider(),
          
          // --- 공지사항 섹션 ---
          _buildSectionHeader('공지사항'),
          ListTile(
            leading: const Icon(Icons.announcement),
            title: const Text('셔틀 공지'),
            subtitle: const Text('셔틀버스 관련 공지사항'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ShuttleNoticeListScreen(),
                ),
              );
            },
          ),
          const Divider(),
          
          // --- 개발자 옵션 (디버그 모드에서만 표시) ---
          if (kDebugMode) ...[
            _buildSectionHeader('개발자 옵션'),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('수동 혼잡도 모달 테스트'),
              subtitle: const Text('위치/시간 체크 없이 모달 표시'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ManualCongestionMonitor.I.testShowModal();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('테스트 모달을 표시했습니다.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.api, color: Colors.green),
              title: const Text('API 직접 호출 테스트'),
              subtitle: const Text('서버 DB에 있는 시간대로 테스트'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _testApiDirectCall(context),
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.blue),
              title: const Text('자동 혼잡도 리포트 테스트'),
              subtitle: const Text('모킹된 위치/속도로 테스트'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAutoCongestionTestDialog(context),
            ),
            const Divider(),
          ],
          
          // --- 앱 정보 섹션 ---
          _buildSectionHeader(l10n.appInfo),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
            trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.blue[800],
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  /// API 직접 호출 테스트
  Future<void> _testApiDirectCall(BuildContext context) async {
    // 토큰 확인
    final token = AuthService.I.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ 로그인이 필요합니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 서버 DB에 있는 실제 시간대로 테스트
    // departure: "아산캠퍼스", arrival: "천안 아산역", departureTime: "08:10"
    final testTimes = ['08:10', '09:40', '09:55', '10:55', '11:40', '12:40', '13:40', '14:40', '15:40', '16:40'];
    
    // 현재 시간 이후 가장 가까운 시간 선택
    final now = DateTime.now();
    String? selectedTime;
    for (final timeStr in testTimes) {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final depDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (depDateTime.isAfter(now) || depDateTime.isAtSameMomentAs(now)) {
        selectedTime = timeStr;
        break;
      }
    }
    selectedTime ??= testTimes.first;

    // timeSlot 계산: hour * 6 + (minute ~/ 10)
    final timeParts = selectedTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final timeSlot = hour * 6 + (minute ~/ 10);

    // weekday: 1 (월요일, 평일)
    final weekday = 1;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final request = CongestionReportRequest(
        busType: 'shuttle',
        startId: '아산캠퍼스',
        stopId: '천안 아산역',
        weekday: weekday,
        timeSlot: timeSlot,
        index: 20, // 탑승했다 (낮은 혼잡도)
        clientTs: now,
      );

      final response = await CongestionApi.I.reportCongestion(request);

      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.success 
                ? '✅ API 호출 성공!\n시간: $selectedTime, timeSlot: $timeSlot'
                : '⚠️ 응답: ${response.message}',
            ),
            backgroundColor: response.success ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ API 호출 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 자동 혼잡도 리포트 테스트 다이얼로그
  void _showAutoCongestionTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('자동 혼잡도 리포트 테스트'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('테스트 방법을 선택하세요:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.speed),
                label: const Text('속도 기반 테스트'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _testSpeedBasedReport(context);
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('정류장 출발 시간 테스트'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _testStopDepartureReport(context);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  /// 속도 기반 혼잡도 리포트 테스트
  Future<void> _testSpeedBasedReport(BuildContext context) async {
    // 아산(KTX)역 좌표
    const testLatitude = 36.794978;
    const testLongitude = 127.103806;
    const testSpeed = 35.0; // km/h (버스 탑승 중, 혼잡 상태)

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await CongestionService.I.testAutoReport(
        latitude: testLatitude,
        longitude: testLongitude,
        speedKmh: testSpeed,
        busType: 'shuttle',
        startId: '아산캠퍼스',
        stopId: '천안 아산역', // 서버 DB에 있는 정류장명
        testTime: '12:40', // 서버 DB에 있는 시간대
      );

      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 속도 기반 혼잡도 리포트 테스트 완료!\n속도: 35 km/h (혼잡 상태)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 테스트 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 정류장 출발 시간 기반 리포트 테스트
  Future<void> _testStopDepartureReport(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정류장 출발 시간 테스트'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('출발 여부를 선택하세요:'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              label: const Text('출발함 (혼잡도 낮음)'),
              onPressed: () {
                Navigator.pop(ctx);
                _executeStopDepartureTest(context, true);
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('머물러 있음 (혼잡도 높음)'),
              onPressed: () {
                Navigator.pop(ctx);
                _executeStopDepartureTest(context, false);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeStopDepartureTest(BuildContext context, bool hasDeparted) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await CongestionService.I.testStopDepartureReport(
        stopName: '아산(KTX)역',
        departureTime: '12:40', // 서버 DB에 있는 시간대
        latitude: 36.794978,
        longitude: 127.103806,
        hasDeparted: hasDeparted,
        busType: 'shuttle',
        stopId: '천안 아산역', // 서버 DB에 있는 정류장명
      );

      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasDeparted 
                ? '✅ 정류장 출발 테스트 완료!\n출발함 → 혼잡도 낮음 (index: 20)'
                : '✅ 정류장 출발 테스트 완료!\n머물러 있음 → 혼잡도 높음 (index: 85)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 테스트 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}