import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'services/auth_service.dart';
import 'screens/login_dialog.dart';
import 'screens/register_dialog.dart';
import 'screens/main_screen.dart';
import 'api/auth_api.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'core/network/dio_client.dart';
import 'core/cache/cache_manager.dart';
import 'core/localization/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 네이버 지도 초기화 (모바일에서만)
  if (!kIsWeb) {
    try {
      // flutter_naver_map 패키지 초기화 (모바일 전용)
      // 공식 문서에 따라 FlutterNaverMap().init() 사용
      await FlutterNaverMap().init(
        clientId: 'i94jktzz8g',
        onAuthFailed: (ex) {
          if (kDebugMode) {
            switch (ex) {
              case NQuotaExceededException(:final message):
                print('🔴 사용량 초과 (message: $message)');
                break;
              case NUnauthorizedClientException() ||
                  NClientUnspecifiedException() ||
                  NAnotherAuthFailedException():
                print('🔴 네이버 지도 인증 실패: $ex');
                print('🔴 Client ID: i94jktzz8g');
                print('🔴 패키지 이름 확인 필요: com.sunmoon.shuttle');
                break;
            }
          }
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔴 main: FlutterNaverMap 초기화 에러: $e');
        print('🔴 스택 트레이스: $stackTrace');
      }
    }
  }
  
  try {
    await AuthService.I.loadToken(); // 저장된 토큰 복구
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('🔴 main: AuthService.loadToken 에러: $e');
      print('🔴 스택 트레이스: $stackTrace');
    }
  }
  
  try {
    await CacheManager.I.init(); // 캐시 매니저 초기화
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('🔴 main: CacheManager.init 에러: $e');
      print('🔴 스택 트레이스: $stackTrace');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 백그라운드로 가거나 포그라운드로 올 때 처리
    // 혼잡도 서비스는 백그라운드에서도 계속 작동하도록 설정됨
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = SettingsProvider();
            // 초기화 시 설정 로드
            provider.loadSettings();
            return provider;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isKorean = settingsProvider.isKorean;
          final locale = isKorean ? const Locale('ko', 'KR') : const Locale('en', 'US');
          
          return MaterialApp(
            title: 'Sunmoon Shuttle',
            locale: locale,
            debugShowCheckedModeBanner: false, // 디버그 배너 숨기기
            theme: ThemeData(
              useMaterial3: true,
              // 모든 환경에서 asset 폰트 사용 (한글/특수문자 지원)
              fontFamily: 'NotoSansKR',
            ),
            home: const HomePage(),
          );
        },
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
  bool _showLoginDialog = false;

  @override
  void initState() {
    super.initState();
    // DioClient에 루트 컨텍스트 설정 (에러 처리 및 로그인 리다이렉트용)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DioClient.instance.setRootContext(context);
      _tryAutoLogin();
    });
  }

  @override
  void dispose() {
    // 컨텍스트 해제
    DioClient.instance.setRootContext(null);
    super.dispose();
  }

  /// 자동 로그인 시도
  /// 1. secure_storage에서 refreshToken 조회
  /// 2. 있으면 POST /api/auth/token/refresh로 새 AccessToken 수신
  /// 3. 성공 시 홈으로 진입, 실패 시 로그인 화면
  Future<void> _tryAutoLogin() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.tryAutoLogin();

      if (!mounted) return;

      // 초기화 완료 표시
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      if (!success) {
        // 자동 로그인 실패 시 로그인 다이얼로그 표시
        // 짧은 딜레이 후 다이얼로그 표시 (빌드 사이클 완료 대기)
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          final loginResult = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => LoginDialog(rootContext: context),
          );
          if (mounted) {
            if (loginResult == true) {
              authProvider.setAuthenticated(true);
            }
          }
        }
      } else {
        // 자동 로그인 성공
        authProvider.setAuthenticated(true);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔴 _tryAutoLogin 에러: $e');
        print('🔴 스택 트레이스: $stackTrace');
      }
      // 에러 발생 시에도 초기화 완료 표시
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // 에러 발생 시에도 로그인 다이얼로그 표시
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => LoginDialog(rootContext: context),
          ).then((result) {
            if (mounted && result == true) {
              context.read<AuthProvider>().setAuthenticated(true);
            }
          });
        }
      }
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
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // 초기화가 완료되지 않았으면 로딩 화면
        if (!_isInitialized) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 로그인되지 않은 경우 로딩 화면 (로그인 다이얼로그가 표시됨)
        if (!authProvider.isAuthenticated) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 로그인 성공 시 메인 화면 표시
        return const MainScreen();
      },
    );
  }
}
