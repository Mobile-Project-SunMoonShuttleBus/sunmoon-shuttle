import 'package:dio/dio.dart';
import '../services/auth_service.dart';

class AuthApi {
  AuthApi._internal();
  static final AuthApi I = AuthApi._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_BASE_URL',
        defaultValue: 'http://localhost:3000'),
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<Map<String, dynamic>> register({
    required String userId,
    required String password,
    required String passwordConfirm, // 프론트에서만 검증용으로 사용
  }) async {
    // 백엔드는 userId와 Password(대문자)만 받음
    final body = {
      'userId': userId,
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
    final data = Map<String, dynamic>.from(resp.data);
    final token = data['accessToken'] as String?;
    if (token != null) {
      await AuthService.I.setToken(token);
    }
    return data;
  }

  Future<Map<String, dynamic>> logout() async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);
    final resp = await _dio.post('/api/auth/logout', options: opts);
    await AuthService.I.setToken(null);
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
