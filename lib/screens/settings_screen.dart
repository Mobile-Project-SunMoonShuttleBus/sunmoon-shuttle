import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/settings/providers/settings_provider.dart';
import '../features/auth/providers/auth_provider.dart';
import '../core/localization/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 설정 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 320,
          maxHeight: 500,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              _buildHeader(context),
              // 설정 옵션들 (중앙 정렬, 위아래 비율에 맞게 배치)
              Expanded(
                child: _buildSettingsContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 헤더: 톱니바퀴 아이콘 + 제목 + 닫기 버튼
  Widget _buildHeader(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final l10n = AppLocalizations(settingsProvider.isKorean);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              // 톱니바퀴 아이콘
              const Icon(
                Icons.settings,
                color: Color(0xFF1890FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              // 제목
              Expanded(
                child: Text(
                  l10n.settingsTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
          // 닫기 버튼
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.close,
              color: Color(0xFF1890FF),
              size: 24,
            ),
            ),
          ],
        ),
      );
      },
    );
  }

  // 설정 콘텐츠 영역
  Widget _buildSettingsContent(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final l10n = AppLocalizations(settingsProvider.isKorean);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 언어 설정
              _buildSettingItem(
                context,
                label: l10n.language,
                value: settingsProvider.isKorean ? l10n.languageKo : l10n.languageEn,
                isEnabled: settingsProvider.isKorean, // 활성화(ON) = 한국어, 비활성화(OFF) = 영어
                onChanged: (value) async {
                  // value가 true면 한국어, false면 영어
                  final success = await settingsProvider.updateLanguage(value);
                  if (success && context.mounted) {
                    // 언어 변경 후 새로운 언어로 메시지 표시
                    final newL10n = AppLocalizations(value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value ? newL10n.languageChangedKo : newL10n.languageChangedEn,
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  } else if (!success && context.mounted && settingsProvider.errorMessage != null) {
                    // 에러 메시지가 있는 경우에만 표시
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(settingsProvider.errorMessage!),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              const Spacer(),
              // 로그아웃 버튼
              _buildLogoutButton(context),
            ],
          ),
        );
      },
    );
  }

  // 설정 항목 위젯
  Widget _buildSettingItem(
    BuildContext context, {
    required String label,
    required String value,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 라벨
          Text(
            '$label($value)',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          // 토글 스위치 (애니메이션 효과 포함)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Switch(
              key: ValueKey(isEnabled),
              value: isEnabled,
              onChanged: onChanged,
              // ON 상태: 초록색
              activeColor: Colors.green,
              activeTrackColor: Colors.green.shade300,
              // OFF 상태: 회색
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade300,
              // 부드러운 애니메이션
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // 로그아웃 버튼
  Widget _buildLogoutButton(BuildContext context) {
    return Consumer2<AuthProvider, SettingsProvider>(
      builder: (context, authProvider, settingsProvider, _) {
        final l10n = AppLocalizations(settingsProvider.isKorean);
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              // 로그아웃 확인 다이얼로그
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.logout),
                  content: Text(l10n.logoutConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(l10n.logout),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                // 로그아웃 실행
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pop(); // 설정 화면 닫기
                  // 로그인 화면으로 돌아가기 위해 HomePage가 자동으로 처리할 것
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1890FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              l10n.logout,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

