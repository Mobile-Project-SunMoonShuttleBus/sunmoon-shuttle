import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

// Core & API
import 'api/dio_client.dart';
import 'core/cache/cache_manager.dart';
import 'core/utils/global_keys.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/login_provider.dart'; // 필요시 유지
import 'providers/settings_provider.dart';

// Screens
import 'screens/main_screen.dart';
import 'screens/auth/login_screen.dart'; // 경로 수정됨

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await CacheManager.I.init();
  DioClient.instance; 

  await FlutterNaverMap().init(
    clientId: 'i94jktzz8g', 
    onAuthFailed: (ex) {
      print("********* 네이버맵 인증 오류 발생: $ex *********");
    }
  );
  
  runApp(
    MultiProvider(
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
      child: const MyApp(),
    )
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // GlobalKey를 사용하여 Context 접근
      DioClient.instance.setRootContext(navigatorKey.currentContext);
      if (navigatorKey.currentContext != null) {
        navigatorKey.currentContext!.read<AuthProvider>().tryAutoLogin();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // global_keys.dart에 정의된 키 사용
      debugShowCheckedModeBanner: false,
      title: '선문대 셔틀버스',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (authProvider.isAuthenticated) {
            return const MainScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
