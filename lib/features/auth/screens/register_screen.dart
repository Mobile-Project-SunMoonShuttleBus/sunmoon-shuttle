import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/register_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  Future<void> _handleSubmit() async {
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
      // 성공 시 스낵바 표시 및 화면 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원가입이 완료되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      // 실패 시 에러 메시지 표시
      final errorMsg = provider.errorMessage ?? '회원가입 실패';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterProvider(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('회원가입'),
        ),
        body: Consumer<RegisterProvider>(
          builder: (context, provider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 아이디 입력
                    TextFormField(
                      controller: _idCtrl,
                      decoration: InputDecoration(
                        labelText: '아이디',
                        hintText: '영문/숫자 4–20자',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: provider.userIdError,
                        errorMaxLines: 2,
                      ),
                      onChanged: (value) {
                        provider.validateUserId(value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '아이디를 입력해주세요.';
                        }
                        return provider.userIdError;
                      },
                      enabled: !provider.isLoading,
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 입력
                    TextFormField(
                      controller: _pwCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        hintText: '6자 이상',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: provider.passwordError,
                        errorMaxLines: 2,
                      ),
                      onChanged: (value) {
                        provider.validatePassword(value);
                        // passwordConfirm도 다시 검증
                        provider.validatePasswordConfirm(value, _pw2Ctrl.text);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해주세요.';
                        }
                        return provider.passwordError;
                      },
                      enabled: !provider.isLoading,
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 확인 입력
                    TextFormField(
                      controller: _pw2Ctrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: '비밀번호 확인',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: provider.passwordConfirmError,
                        errorMaxLines: 2,
                      ),
                      onChanged: (value) {
                        provider.validatePasswordConfirm(_pwCtrl.text, value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호 확인을 입력해주세요.';
                        }
                        if (_pwCtrl.text != value) {
                          return '비밀번호가 일치하지 않습니다.';
                        }
                        return provider.passwordConfirmError;
                      },
                      enabled: !provider.isLoading,
                    ),
                    const SizedBox(height: 24),

                    // 에러 메시지 표시 (인라인)
                    if (provider.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                provider.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 회원가입 버튼
                    ElevatedButton(
                      onPressed: provider.isLoading ||
                              !provider.isFormValid(
                                _idCtrl.text.trim(),
                                _pwCtrl.text,
                                _pw2Ctrl.text,
                              )
                          ? null
                          : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1890FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '회원가입',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

