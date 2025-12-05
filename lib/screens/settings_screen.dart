// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart'; // [필수] 설정 로직
import '../core/localization/app_localizations.dart'; // [필수] 다국어 텍스트
import 'auth/login_screen.dart';
import 'notice/shuttle_notice_list_screen.dart'; // 셔틀 공지 화면

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
}