import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/login_dialog.dart';
import 'screens/register_dialog.dart';
import 'api/auth_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.I.loadToken(); // 저장된 토큰 복구
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunmoon Shuttle',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _openLogin(BuildContext ctx) async {
    await showDialog(context: ctx, builder: (_) => const LoginDialog());
  }

  Future<void> _openRegister(BuildContext ctx) async {
    await showDialog(context: ctx, builder: (_) => const RegisterDialog());
  }

  Future<void> _callProtected(BuildContext ctx) async {
    try {
      final me = await AuthApi.I.getMe();
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('ME: $me')));
    } catch (_) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('인증 필요 또는 실패')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(onPressed: () => _openLogin(context), child: const Text('로그인')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => _openRegister(context), child: const Text('회원가입')),
              const SizedBox(height: 12),
              TextButton(onPressed: () => _callProtected(context), child: const Text('보호 API 호출 /api/users/me')),
            ],
          ),
        ),
      ),
    );
  }
}
