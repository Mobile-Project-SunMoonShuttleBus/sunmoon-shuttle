import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../utils/validators.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _disabled {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (!Validators.isValidUserId(id)) return true;
    if (!Validators.isValidPassword(pw)) return true;
    return _loading;
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await AuthApi.I.login(
        userId: _idCtrl.text.trim(),
        password: _pwCtrl.text,
      );
      if ((res['accessToken'] ?? '').toString().isNotEmpty) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _error = res['message']?.toString() ?? '로그인 실패');
      }
    } catch (e) {
      setState(() => _error = '로그인 실패');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try { await AuthApi.I.logout(); } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _input(_idCtrl, '아이디'),
            const SizedBox(height: 8),
            _input(_pwCtrl, '비밀번호', obscure: true),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            _primaryButton(
              text: _loading ? '처리 중...' : '로그인',
              disabled: _disabled,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            _grayButton(text: '로그아웃', onPressed: _logout),
            const SizedBox(height: 8),
            _grayButton(text: '취소', onPressed: () => Navigator.of(context).pop(false)),
          ],
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
