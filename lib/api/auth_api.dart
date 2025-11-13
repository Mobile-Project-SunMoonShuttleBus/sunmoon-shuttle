/// 인증 API 클라이언트
/// - 회원가입, 로그인, 로그아웃 API 호출
/// - Dio 인터셉터를 통한 자동 토큰 관리 및 401 처리
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import 'dio_interceptor.dart';

class AuthApi {
  static final AuthApi I = AuthApi._internal();

  late final Dio _dio;

  AuthApi._internal() {
    // 서버 주소 설정
    // 환경 변수가 설정되어 있으면 사용, 없으면 기본값 사용
    final envBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    
    // 기본값: 실제 서버 주소
    const defaultBaseUrl = 'http://124.61.202.9:8080';
    
    final baseUrl = envBaseUrl.isEmpty ? defaultBaseUrl : envBaseUrl;
    
    // 디버그: 실제 사용 중인 baseUrl 출력
    if (kDebugMode) {
      print('API Base URL: $baseUrl');
    }
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'Content-Type': 'application/json'},
    ));
    // 401 처리 및 토큰 갱신 인터셉터 추가
    _dio.interceptors.add(AuthInterceptor());
  }

  Future<Map<String, dynamic>> register({
    required String userId,
    required String password,
    required String passwordConfirm, // 프론트에서만 검증용으로 사용
  }) async {
    // 백엔드는 userId와 Password(대문자)만 받음
    // null 값이 포함되지 않도록 검증
    if (userId.isEmpty || password.isEmpty) {
      throw ArgumentError('userId와 password는 필수입니다.');
    }
    
    final body = <String, dynamic>{
      'userId': userId.trim(),
      'Password': password, // 백엔드가 대문자 P를 기대함
    };
    
    final resp = await _dio.post('/api/auth/register', data: body);
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
  }) async {
    // 백엔드는 userId와 Password(대문자)를 기대함
    final resp = await _dio.post('/api/auth/login', data: {
      'userId': userId,
      'Password': password, // 백엔드가 대문자 P를 기대함
    });
    // 토큰 저장은 provider에서 처리하므로 여기서는 응답만 반환
    return Map<String, dynamic>.from(resp.data);
  }

  /// RefreshToken으로 새 AccessToken 발급
  /// 요구사항: POST /api/auth/token/refresh
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final resp = await _dio.post(
      '/api/auth/token/refresh',
      data: {'refreshToken': refreshToken},
    );
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> logout() async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);
    final resp = await _dio.post('/api/auth/logout', options: opts);
    await AuthService.I.clearTokens();
    return Map<String, dynamic>.from(resp.data);
  }

  /// 보호된 API 호출 예시
  Future<Map<String, dynamic>> getMe() async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);
    final resp = await _dio.get('/api/users/me', options: opts);
    return Map<String, dynamic>.from(resp.data);
  }
}
