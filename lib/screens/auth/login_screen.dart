// lib/storage/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/login_provider.dart'; 
import '../../providers/register_provider.dart'; // ⭐️ [추가] RegisterProvider 임포트
import '../../core/utils/validators.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget { 
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> { 
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _idController.addListener(_onTextChanged);
    _passwordController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); 
  }
  
  Future<void> _login(BuildContext context, LoginProvider loginProvider) async {
    if (!_isFormValid()) return;
    
    final success = await loginProvider.login(
      userId: _idController.text.trim(),
      password: _passwordController.text,
    );

    if (success) { context.read<AuthProvider>().setAuthenticated(true); } 
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loginProvider.errorMessage ?? '로그인 실패'), backgroundColor: Colors.red),
      );
    }
  }

  // ⭐️ [핵심 수정] Provider를 여기서 생성해서 넘겨줍니다.
  void _goToRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => RegisterProvider(),
          child: const RegisterScreen(), // RegisterScreen은 이제 UI만 그립니다.
        ),
      ),
    );
  }

  bool _isFormValid() {
    final id = _idController.text.trim();
    final pw = _passwordController.text;
    if (!Validators.isValidUserId(id)) return false; 
    if (!Validators.isValidPassword(pw)) return false; 
    return true;
  }

  // ... (UI 헬퍼 함수들은 기존과 동일) ...
  Widget _labeledInput(TextEditingController c, String label, {bool obscure = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87))),
        Expanded(child: TextField(controller: c, obscureText: obscure, decoration: InputDecoration(
            filled: true, fillColor: Colors.white, 
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFF1890FF), width: 1)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        )),
      ],
    );
  }

  Widget _primaryButton({required String text, required VoidCallback onPressed, bool disabled = false}) {
    return SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: disabled ? Colors.grey[300] : const Color(0xFF1890FF), foregroundColor: disabled ? Colors.black54 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text(text),
      ));
  }

  Widget _grayButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: const Color(0xFF1890FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text(text),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginProvider(),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF1890FF),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Consumer<LoginProvider>(
                  builder: (context, provider, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('로그인', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1890FF))),
                        const SizedBox(height: 32),
                        _labeledInput(_idController, '아이디'),
                        const SizedBox(height: 16),
                        _labeledInput(_passwordController, '비밀번호', obscure: true),
                        if (provider.errorMessage != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                        const SizedBox(height: 20),
                        _primaryButton(
                          text: provider.isLoading ? '처리 중...' : '로그인',
                          disabled: !_isFormValid() || provider.isLoading,
                          onPressed: () => _login(context, provider),
                        ),
                        const SizedBox(height: 12),
                        _grayButton(text: '회원가입', onPressed: () => _goToRegister(context)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}