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
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json', // JSON만 받도록 명시
      },
      responseType: ResponseType.json, // JSON 응답만 받도록 명시
    ));
    // 401 처리 및 토큰 갱신 인터셉터 추가
    _dio.interceptors.add(AuthInterceptor());
  }

  Future<Map<String, dynamic>> register({
    required String userId,
    required String password,
    required String passwordConfirm, // 프론트에서만 검증용으로 사용
  }) async {
    // null 값이 포함되지 않도록 검증
    if (userId.isEmpty || password.isEmpty) {
      throw ArgumentError('userId와 password는 필수입니다.');
    }
    
    // 서버가 요구하는 Body 구조에 맞춰 전송
    // passwordConfirm은 프론트엔드에서만 검증용으로 사용, 서버에는 전송하지 않음
    final body = <String, dynamic>{
      'userId': userId.trim(),
      'password': password,
    };
    
    // 디버그: 실제 전송되는 Body 확인
    if (kDebugMode) {
      print('회원가입 요청 Body: $body');
    }
    
    try {
      final resp = await _dio.post('/api/auth/register', data: body);
      
      // 디버그: 서버 응답 확인
      if (kDebugMode) {
        print('회원가입 응답: ${resp.data}');
      }
      
      return Map<String, dynamic>.from(resp.data);
    } on DioException catch (e) {
      // 디버그: 에러 응답 상세 확인
      if (kDebugMode) {
        print('=== 회원가입 에러 상세 ===');
        print('에러 타입: ${e.type}');
        print('에러 메시지: ${e.message}');
        print('요청 URL: ${e.requestOptions.uri}');
        print('요청 Body: ${e.requestOptions.data}');
        print('응답 상태 코드: ${e.response?.statusCode}');
        print('응답 데이터: ${e.response?.data}');
        print('======================');
      }
      
      // CORS 또는 네트워크 연결 오류인 경우
      if (e.type == DioExceptionType.connectionError || 
          e.type == DioExceptionType.connectionTimeout) {
        final serverUrl = e.requestOptions.uri.toString().replaceAll(e.requestOptions.path, '');
        
        // CORS 에러인지 확인 (웹 환경에서만)
        final isCorsError = e.message?.contains('CORS') == true || 
                           e.message?.contains('XMLHttpRequest') == true ||
                           e.response == null;
        
        if (isCorsError && kDebugMode) {
          print('⚠️ CORS 에러가 발생했습니다.');
          print('서버($serverUrl)에서 CORS 헤더를 설정해야 합니다.');
          print('서버 측에서 다음 헤더를 추가해야 합니다:');
          print('  - Access-Control-Allow-Origin: * (또는 http://localhost:57493)');
          print('  - Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
          print('  - Access-Control-Allow-Headers: Content-Type, Authorization');
        }
        
        throw DioException(
          requestOptions: e.requestOptions,
          type: e.type,
          error: isCorsError 
            ? 'CORS 정책으로 인해 요청이 차단되었습니다. 서버에서 CORS 설정이 필요합니다.'
            : '서버에 연결할 수 없습니다. 서버 주소($serverUrl)와 네트워크 연결을 확인해주세요.',
        );
      }
      
      rethrow;
    } catch (e) {
      // 예상치 못한 에러
      if (kDebugMode) {
        print('예상치 못한 에러: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
  }) async {
    // 서버가 요구하는 Body 구조: userId와 password (소문자)
    final body = <String, dynamic>{
      'userId': userId,
      'password': password,
    };
    
    // 디버그: 실제 전송되는 Body 확인
    if (kDebugMode) {
      print('로그인 요청 Body: $body');
    }
    
    final resp = await _dio.post('/api/auth/login', data: body);
    
    // 디버그: 서버 응답 확인
    if (kDebugMode) {
      print('로그인 응답: ${resp.data}');
    }
    
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

  /// 로그아웃 API 호출
  /// POST /api/auth/logout
  /// 응답: { "message":"ok" }
  /// 주의: clearTokens()는 호출하지 않음 (Provider에서 처리)
  Future<Map<String, dynamic>> logout() async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);
    final resp = await _dio.post('/api/auth/logout', options: opts);
    return Map<String, dynamic>.from(resp.data);
  }

  /// 보호된 API 호출 예시
  Future<Map<String, dynamic>> getMe() async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);
    
    try {
      final resp = await _dio.get('/api/users/me', options: opts);
      
      if (kDebugMode) {
        print('🔵 getMe 응답 상태 코드: ${resp.statusCode}');
        print('🔵 getMe 응답 Content-Type: ${resp.headers.value('content-type')}');
        print('🔵 getMe 응답 데이터 타입: ${resp.data.runtimeType}');
      }
      
      // 응답이 JSON인지 확인
      if (resp.data is String) {
        // HTML이나 다른 텍스트 응답인 경우
        if (kDebugMode) {
          print('⚠️ getMe 응답이 JSON이 아닙니다. 응답 타입: ${resp.data.runtimeType}');
          final preview = resp.data.toString().substring(0, resp.data.toString().length > 200 ? 200 : resp.data.toString().length);
          print('⚠️ 응답 미리보기: $preview...');
          print('⚠️ 서버가 HTML을 반환했습니다. 백엔드 라우팅 설정을 확인하세요.');
        }
        throw DioException(
          requestOptions: resp.requestOptions,
          response: resp,
          type: DioExceptionType.badResponse,
          message: '서버가 JSON 대신 HTML을 반환했습니다. 백엔드 API 엔드포인트 설정을 확인하세요.',
        );
      }
      
      // JSON 응답인 경우
      if (resp.data is Map) {
        if (kDebugMode) {
          print('✅ getMe 응답 파싱 성공');
        }
        return Map<String, dynamic>.from(resp.data);
      }
      
      // 예상치 못한 응답 형식
      if (kDebugMode) {
        print('❌ getMe 예상치 못한 응답 형식: ${resp.data.runtimeType}');
      }
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        type: DioExceptionType.badResponse,
        message: '예상치 못한 응답 형식입니다.',
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ getMe API 호출 실패: ${e.message}');
        if (e.response != null) {
          print('❌ 응답 상태 코드: ${e.response?.statusCode}');
          print('❌ 응답 데이터 타입: ${e.response?.data.runtimeType}');
          print('❌ 응답 Content-Type: ${e.response?.headers.value('content-type')}');
        }
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ getMe 예외: $e');
      }
      rethrow;
    }
  }

  /// 사용자 설정 업데이트 (PATCH /api/me)
  /// pref.crowdAnimation 등의 설정을 업데이트
  Future<Map<String, dynamic>> updateMe({
    Map<String, dynamic>? pref,
  }) async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);
    
    final body = <String, dynamic>{};
    if (pref != null) {
      body['pref'] = pref;
    }
    
    final resp = await _dio.patch('/api/users/me', data: body, options: opts);
    return Map<String, dynamic>.from(resp.data);
  }

  /// 학교 포털 계정 저장
  /// POST /api/auth/school/save
  /// { "schoolId":"2025xxxx","schoolPassword":"secret" }
  /// 응답: { "message":"SAVED" }
  /// 서버 DB에 영구 저장되며, 저장 후 자동으로 시간표 크롤링이 백그라운드에서 실행됩니다.
  Future<Map<String, dynamic>> saveSchoolAccount({
    required String schoolId,
    required String schoolPassword,
  }) async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);
    
    final body = <String, dynamic>{
      'schoolId': schoolId.trim(),
      'schoolPassword': schoolPassword, // 서버에서 암호화 처리
    };
    
    if (kDebugMode) {
      print('포털 계정 저장 요청: schoolId=${body['schoolId']}');
      print('서버 DB에 영구 저장됩니다. 저장 후 자동 크롤링이 실행됩니다.');
    }
    
    try {
      final resp = await _dio.post('/api/auth/school/save', data: body, options: opts);
      
      if (kDebugMode) {
        print('포털 계정 저장 응답: ${resp.data}');
        if (resp.data is Map && resp.data['message'] == 'SAVED') {
          print('✅ 포털 계정 정보가 서버 DB에 영구 저장되었습니다.');
          print('📋 자동 크롤링이 백그라운드에서 실행됩니다. (약 10~30초 소요)');
        }
      }
      
      return Map<String, dynamic>.from(resp.data);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 포털 계정 저장 실패: ${e.message}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      rethrow;
    }
  }
}
