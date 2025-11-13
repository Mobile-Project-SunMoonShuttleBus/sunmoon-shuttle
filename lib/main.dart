import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/login_dialog.dart';
import 'screens/register_dialog.dart';
import 'api/auth_api.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.I.loadToken(); // 저장된 토큰 복구
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Sunmoon Shuttle',
        theme: ThemeData(useMaterial3: true),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 자동 로그인 시도
    // 부트스트랩 흐름: secure_storage의 refreshToken으로 자동 재인증
    // context가 준비된 후에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoLogin();
    });
  }

  /// 자동 로그인 시도
  /// 1. secure_storage에서 refreshToken 조회
  /// 2. 있으면 POST /api/auth/token/refresh로 새 AccessToken 수신
  /// 3. 성공 시 홈으로 진입, 실패 시 로그인 화면
  Future<void> _tryAutoLogin() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.tryAutoLogin();

    if (!mounted) return;

    if (!success) {
      // 자동 로그인 실패 시 로그인 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false, // 배경 탭으로 닫기 방지 - 로그인은 필수이므로 닫을 수 없게 설정
        builder: (_) => const LoginDialog(),
      ).then((result) {
        // 로그인 성공 시 인증 상태 업데이트
        if (result == true && mounted) {
          authProvider.setAuthenticated(true);
        }
      });
    } else {
      // 자동 로그인 성공
      authProvider.setAuthenticated(true);
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
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
              TextButton(onPressed: () => _callProtected(context), child: const Text('보호 API 호출 /api/users/me')),
            ],
          ),
        ),
      ),
    );
  }
}
