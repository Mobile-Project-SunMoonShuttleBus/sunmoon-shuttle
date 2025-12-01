import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../core/utils/app_logger.dart';

// [수정] 2번 코드의 로그인 화면 경로로 변경
import '../screens/auth/login_screen.dart';

class AuthInterceptor extends Interceptor {
  final AuthService _authService = AuthService.I;
  BuildContext? _rootContext;
  
  // 메인에서 context를 주입받기 위한 메서드
  void setRootContext(BuildContext? context) {
    _rootContext = context;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 요청 전 로그 출력
    AppLogger.debug('AuthInterceptor', '${options.method} ${options.path}');
    
    // 토큰이 있으면 헤더에 자동 추가
    final token = _authService.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 401 에러(인증 토큰 만료)가 발생했을 때
    if (err.response?.statusCode == 401) {
      AppLogger.warning('AuthInterceptor', '401 인증 만료됨 -> 로그인 화면으로 이동');
      
      // 토큰 삭제 후 로그인 화면으로 튕겨내기
      await _authService.clearTokens();
      _redirectToLogin();
      
      handler.reject(err);
      return;
    } 
    
    handler.next(err);
  }
  
  // [수정] 다이얼로그(팝업) 대신 로그인 스크린(페이지)으로 이동하도록 변경
  void _redirectToLogin() {
    if (_rootContext != null && _rootContext!.mounted) {
      // 로그인 화면으로 이동하고, 뒤로가기 못하게 스택 비우기
      Navigator.of(_rootContext!).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
      
      // 안내 메시지 표시
      ScaffoldMessenger.of(_rootContext!).showSnackBar(
        const SnackBar(content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.')),
      );
    }
  }
}

