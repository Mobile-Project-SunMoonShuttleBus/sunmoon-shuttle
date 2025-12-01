/// 회원가입 다이얼로그 화면
/// - 실시간 입력값 유효성 검사
/// - 회원가입 성공 시 userId 자동 저장 (자동채움용)
/// - 중복 클릭 방지 및 에러 처리
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/providers/register_provider.dart';

class RegisterDialog extends StatefulWidget {
  const RegisterDialog({super.key});

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RegisterProvider>();
    if (provider.isLoading) return; // 중복 클릭 방지

    final success = await provider.register(
      userId: _idCtrl.text.trim(),
      password: _pwCtrl.text,
      passwordConfirm: _pw2Ctrl.text,
    );

    if (!mounted) return;

    if (success) {
      // 성공 시 아이디와 비밀번호를 반환하여 자동 로그인 처리
      // 스낵바는 자동 로그인 성공 후 표시하도록 login_dialog에서 처리
      if (mounted) {
        Navigator.of(context).pop({
          'success': true,
          'userId': _idCtrl.text.trim(),
          'password': _pwCtrl.text,
        });
      }
    } else {
      // 실패 시 에러 메시지 표시
      final errorMsg = provider.errorMessage ?? '회원가입 실패';
      final errorCode = provider.errorCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorCode != null ? '$errorMsg ($errorCode)' : errorMsg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterProvider(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 우측 상단 X 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF1890FF)),
                        onPressed: () => Navigator.of(context).pop(false),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 아이디 입력 필드 - 실시간 검증
                  Consumer<RegisterProvider>(
                    builder: (context, provider, _) {
                      return _labeledInput(
                        _idCtrl,
                        '아이디',
                        obscure: false,
                        errorText: provider.userIdError,
                        onChanged: (value) => provider.validateUserId(value),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // 비밀번호 입력 필드 - 실시간 검증
                  Consumer<RegisterProvider>(
                    builder: (context, provider, _) {
                      return _labeledInput(
                        _pwCtrl,
                        '비밀번호',
                        obscure: true,
                        errorText: provider.passwordError,
                        onChanged: (value) {
                          provider.validatePassword(value);
                          // 비밀번호 확인도 다시 검증
                          provider.validatePasswordConfirm(value, _pw2Ctrl.text);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // 비밀번호 확인 입력 필드 - 실시간 검증
                  Consumer<RegisterProvider>(
                    builder: (context, provider, _) {
                      return _labeledInput(
                        _pw2Ctrl,
                        '비밀번호 확인',
                        obscure: true,
                        errorText: provider.passwordConfirmError,
                        onChanged: (value) => provider.validatePasswordConfirm(_pwCtrl.text, value),
                      );
                    },
                  ),
                  // 에러 메시지 표시
                  Consumer<RegisterProvider>(
                    builder: (context, provider, _) {
                      if (provider.errorMessage != null) {
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              provider.errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 20),
                  // 회원가입 버튼
                  Consumer<RegisterProvider>(
                    builder: (context, provider, _) {
                      return _primaryButton(
                        text: provider.isLoading ? '처리 중...' : '회원가입',
                        disabled: !provider.isFormValid(
                          _idCtrl.text.trim(),
                          _pwCtrl.text,
                          _pw2Ctrl.text,
                        ) || provider.isLoading,
                        onPressed: () => _handleSubmit(context),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // 취소 버튼
                  _grayButton(
                    text: '취소',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _labeledInput(
    TextEditingController c,
    String label, {
    bool obscure = false,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: c,
                obscureText: obscure,
                onChanged: onChanged,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1890FF), width: 1),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  errorText: errorText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _primaryButton({required String text, required VoidCallback onPressed, bool disabled = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? Colors.grey[300] : const Color(0xFF1890FF),
          foregroundColor: disabled ? Colors.black54 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _grayButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          foregroundColor: const Color(0xFF1890FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }
}
