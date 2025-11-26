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
      if (kDebugMode) {
        print('🔵 main: NaverMapSdk 초기화 시작');
      }
      // flutter_naver_map 패키지 초기화 (모바일 전용)
      await NaverMapSdk.instance.initialize(
        clientId: 'rnzdyb4a75',
      );
      if (kDebugMode) {
        print('🔵 main: NaverMapSdk 초기화 완료');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔴 main: NaverMapSdk 초기화 에러: $e');
        print('🔴 스택 트레이스: $stackTrace');
      }
    }
  } else {
    if (kDebugMode) {
      print('⚠️ 웹에서는 네이버 지도를 사용할 수 없습니다.');
    }
  }
  
  try {
    if (kDebugMode) {
      print('🔵 main: AuthService.loadToken 시작');
    }
    await AuthService.I.loadToken(); // 저장된 토큰 복구
    if (kDebugMode) {
      print('🔵 main: AuthService.loadToken 완료');
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('🔴 main: AuthService.loadToken 에러: $e');
      print('🔴 스택 트레이스: $stackTrace');
    }
  }
  
  try {
    if (kDebugMode) {
      print('🔵 main: CacheManager.init 시작');
    }
    await CacheManager.I.init(); // 캐시 매니저 초기화
    if (kDebugMode) {
      print('🔵 main: CacheManager.init 완료');
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('🔴 main: CacheManager.init 에러: $e');
      print('🔴 스택 트레이스: $stackTrace');
    }
  }
  
  if (kDebugMode) {
    print('🔵 main: runApp 시작');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
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
              // 한글 폰트 설정 (아이콘에는 영향 없음)
              fontFamily: 'Noto Sans KR',
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
    if (kDebugMode) {
      print('🔵 HomePage initState');
    }
    // DioClient에 루트 컨텍스트 설정 (에러 처리 및 로그인 리다이렉트용)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        print('🔵 HomePage addPostFrameCallback');
      }
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
    if (kDebugMode) {
      print('🔵 _tryAutoLogin 시작');
    }
    try {
      final authProvider = context.read<AuthProvider>();
      if (kDebugMode) {
        print('🔵 AuthProvider 읽기 완료');
      }
      final success = await authProvider.tryAutoLogin();
      if (kDebugMode) {
        print('🔵 tryAutoLogin 결과: $success');
      }

      if (!mounted) {
        if (kDebugMode) {
          print('🔴 mounted가 false입니다');
        }
        return;
      }

      // 초기화 완료 표시
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (kDebugMode) {
          print('🔵 _isInitialized = true 설정 완료');
        }
      }

      if (!success) {
        if (kDebugMode) {
          print('🔵 자동 로그인 실패, 로그인 다이얼로그 표시 예정');
        }
        // 자동 로그인 실패 시 로그인 다이얼로그 표시
        // 짧은 딜레이 후 다이얼로그 표시 (빌드 사이클 완료 대기)
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          if (kDebugMode) {
            print('🔵 로그인 다이얼로그 표시 중...');
          }
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              if (kDebugMode) {
                print('🔵 LoginDialog builder 호출');
              }
              return LoginDialog(rootContext: context);
            },
          ).then((result) {
            if (kDebugMode) {
              print('🔵 로그인 다이얼로그 결과: $result');
            }
            if (mounted) {
              if (result == true) {
                authProvider.setAuthenticated(true);
              }
            }
          });
        } else {
          if (kDebugMode) {
            print('🔴 mounted가 false여서 다이얼로그 표시 불가');
          }
        }
      } else {
        if (kDebugMode) {
          print('🔵 자동 로그인 성공');
        }
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
    if (kDebugMode) {
      print('🔵 HomePage build 호출, _isInitialized: $_isInitialized');
    }
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (kDebugMode) {
          print('🔵 Consumer builder 호출, isAuthenticated: ${authProvider.isAuthenticated}');
        }
        // 초기화가 완료되지 않았으면 로딩 화면
        if (!_isInitialized) {
          if (kDebugMode) {
            print('🔵 로딩 화면 표시 (초기화 중)');
          }
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 로그인되지 않은 경우 로딩 화면 (로그인 다이얼로그가 표시됨)
        if (!authProvider.isAuthenticated) {
          if (kDebugMode) {
            print('🔵 로딩 화면 표시 (로그인 대기 중)');
          }
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 로그인 성공 시 메인 화면 표시
        if (kDebugMode) {
          print('🔵 MainScreen 표시');
        }
        return const MainScreen();
      },
    );
  }
}
