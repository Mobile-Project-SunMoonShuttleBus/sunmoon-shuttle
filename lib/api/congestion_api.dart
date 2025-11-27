/// 혼잡도 API 클라이언트
/// 백엔드로 혼잡도 리포트 전송
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/congestion_models.dart';
import 'dio_interceptor.dart';

class CongestionApi {
  static final CongestionApi I = CongestionApi._internal();

  late final Dio _dio;

  CongestionApi._internal() {
    // 서버 주소 설정
    final envBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const defaultBaseUrl = 'http://124.61.202.9:8080';
    final baseUrl = envBaseUrl.isEmpty ? defaultBaseUrl : envBaseUrl;

    if (kDebugMode) {
      print('CongestionApi Base URL: $baseUrl');
    }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      responseType: ResponseType.json,
      validateStatus: (status) {
        return status != null && status >= 200 && status < 300;
      },
    ));
    _dio.interceptors.add(AuthInterceptor());
  }

  /// 혼잡도 리포트 전송
  /// POST /api/congestion/report
  Future<CongestionReportResponse> reportCongestion(CongestionReportRequest request) async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);

    if (kDebugMode) {
      print('혼잡도 리포트 전송: ${request.toJson()}');
    }

    try {
      final resp = await _dio.post(
        '/api/congestion/report',
        data: request.toJson(),
        options: opts,
      );

      if (kDebugMode) {
        print('✅ 혼잡도 리포트 전송 성공: ${resp.data}');
      }

      return CongestionReportResponse.fromJson(resp.data);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 혼잡도 리포트 전송 실패: ${e.message}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      throw Exception('혼잡도 리포트 전송 실패: ${e.message}');
    } catch (e) {
      if (kDebugMode) {
        print('❌ 혼잡도 리포트 전송 예외: $e');
      }
      rethrow;
    }
  }
}

