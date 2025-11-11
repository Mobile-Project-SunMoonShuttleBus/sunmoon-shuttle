import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../api/auth_api.dart';
import '../utils/validators.dart';

class RegisterDialog extends StatefulWidget {
  const RegisterDialog({super.key});

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _disabled {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pw2 = _pw2Ctrl.text;
    if (!Validators.isValidUserId(id)) return true;
    if (!Validators.isValidPassword(pw)) return true;
    if (pw != pw2) return true;
    return _loading;
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AuthApi.I.register(
        userId: _idCtrl.text.trim(),
        password: _pwCtrl.text,
        passwordConfirm: _pw2Ctrl.text, // 프론트에서만 검증용
      );
      final msg = (res['message'] ?? '').toString();
      if (msg.contains('완료')) {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회원가입이 완료되었습니다.')),
          );
        }
      } else {
        // 백엔드 응답 형식에 맞게 에러 메시지 처리
        setState(() => _error = msg.isNotEmpty ? msg : '회원가입 실패');
      }
    } catch (e) {
      // Dio 에러 처리
      if (e is DioException) {
        final errorData = e.response?.data;
        if (errorData is Map) {
          final errorMsg = errorData['message']?.toString() ?? '회원가입 실패';
          setState(() => _error = errorMsg);
        } else {
          setState(() => _error = '회원가입 실패');
        }
      } else {
        setState(() => _error = '회원가입 실패');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input(_idCtrl, '아이디 (영문/숫자 4–20자)'),
              const SizedBox(height: 8),
              _input(_pwCtrl, '비밀번호 (6자 이상)', obscure: true),
              const SizedBox(height: 8),
              _input(_pw2Ctrl, '비밀번호 확인', obscure: true),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              _primaryButton(
                text: _loading ? '처리 중...' : '회원가입',
                disabled: _disabled,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              _grayButton(
                text: '취소',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String hint, {bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }
}
