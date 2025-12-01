/// 시간표 API 클라이언트
/// JWT 토큰으로 인증된 사용자의 시간표 조회
library;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/timetable_models.dart';
import 'dio_interceptor.dart';

class TimetableApi {
  static final TimetableApi I = TimetableApi._internal();

  late final Dio _dio;

  TimetableApi._internal() {
    // 서버 주소 설정
    final envBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const defaultBaseUrl = 'http://124.61.202.9:8080';
    final baseUrl = envBaseUrl.isEmpty ? defaultBaseUrl : envBaseUrl;

    if (kDebugMode) {
      print('TimetableApi Base URL: $baseUrl');
    }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json', // JSON만 받도록 명시 (Swagger HTML 방지)
      },
      responseType: ResponseType.json,
      validateStatus: (status) {
        // 200-299 범위의 상태 코드만 성공으로 처리
        return status != null && status >= 200 && status < 300;
      },
    ));
    // 401 처리 및 토큰 갱신 인터셉터 추가
    _dio.interceptors.add(AuthInterceptor());
  }

  /// 시간표 조회
  /// GET /api/timetable
  /// JWT 토큰으로 인증된 사용자의 시간표를 조회합니다.
  /// 시간표는 요일별로 그룹화되어 반환됩니다.
  Future<TimetableResponse> getTimetable() async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);

    if (kDebugMode) {
      print('시간표 조회 요청: GET /api/timetable');
    }

    try {
      final resp = await _dio.get('/api/timetable', options: opts);
      
      if (kDebugMode) {
        print('시간표 조회 응답: ${resp.data}');
      }

      return TimetableResponse.fromMap(Map<String, dynamic>.from(resp.data));
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 시간표 조회 실패: ${e.message}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      rethrow;
    }
  }
}

