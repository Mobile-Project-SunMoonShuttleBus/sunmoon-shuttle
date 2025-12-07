/// 혼잡도 API 클라이언트
/// 백엔드로 혼잡도 리포트 전송
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
  /// AuthInterceptor가 자동으로 토큰을 추가하므로 별도 헤더 설정 불필요
  Future<CongestionReportResponse> reportCongestion(CongestionReportRequest request) async {
    if (kDebugMode) {
      print('혼잡도 리포트 전송: ${request.toJson()}');
    }

    try {
      final resp = await _dio.post(
        '/api/congestion/report',
        data: request.toJson(),
      );

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

  /// 혼잡도 Overview 조회
  /// GET /api/congestion/{busType}/overview?dayKey=YYYY-MM-DD
  /// busType: 'campus' 또는 'shuttle'
  /// 주의: 현재 백엔드는 'campus'만 지원하므로 'shuttle' 요청은 빈 응답 반환
  Future<CongestionOverviewResponse> getOverview({
    required String busType,
    String? dayKey,
  }) async {
    if (kDebugMode) {
      print('혼잡도 Overview 조회: busType=$busType, dayKey=$dayKey');
    }

    // 셔틀버스는 아직 백엔드 지원 안 함 - 빈 응답 반환
    if (busType == 'shuttle') {
      if (kDebugMode) {
        print('⚠️ 셔틀버스 API는 아직 구현되지 않았습니다. 빈 데이터 반환.');
      }
      return CongestionOverviewResponse(
        success: true,
        busType: 'shuttle',
        dayKey: dayKey ?? DateTime.now().toString().split(' ')[0],
        lastUpdated: null,
        routes: [],
      );
    }

    try {
      final queryParams = <String, dynamic>{};
      if (dayKey != null) {
        queryParams['dayKey'] = dayKey;
      }

      final resp = await _dio.get(
        '/api/congestion/$busType/overview',
        queryParameters: queryParams,
      );

      return CongestionOverviewResponse.fromJson(resp.data);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 혼잡도 Overview 조회 실패: ${e.message}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      throw Exception('혼잡도 Overview 조회 실패: ${e.message}');
    } catch (e) {
      if (kDebugMode) {
        print('❌ 혼잡도 Overview 조회 예외: $e');
      }
      rethrow;
    }
  }
}

