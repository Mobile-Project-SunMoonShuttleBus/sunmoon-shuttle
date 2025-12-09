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
        // 404도 서버 응답이 있으면 처리 (스케줄 없음 등의 비즈니스 로직 에러)
        return status != null && (status >= 200 && status < 300 || status == 404);
      },
    ));
    _dio.interceptors.add(AuthInterceptor());
  }

  /// 혼잡도 리포트 전송
  /// POST /api/congestion/report
  /// AuthInterceptor가 자동으로 토큰을 추가하므로 별도 헤더 설정 불필요
  Future<CongestionReportResponse> reportCongestion(CongestionReportRequest request) async {
    final requestData = request.toJson();
    if (kDebugMode) {
      print('📤 혼잡도 리포트 전송 시작');
      print('요청 데이터: $requestData');
      print('Base URL: ${_dio.options.baseUrl}');
      print('전체 URL: ${_dio.options.baseUrl}/api/congestion/report');
    }

    try {
      // 서버가 /api/congestion/report를 사용하므로 직접 호출
      final resp = await _dio.post(
        '/api/congestion/report',
        data: requestData,
      );

      if (kDebugMode) {
        print('✅ 혼잡도 리포트 전송 성공 (/api/congestion/report)');
        print('응답 데이터: ${resp.data}');
      }

      // 404 응답도 처리 (서버가 스케줄 없음 등을 404로 반환할 수 있음)
      if (resp.statusCode == 404) {
        final responseData = resp.data;
        if (responseData is Map && responseData.containsKey('message')) {
          // 서버 응답이 있으면 메시지 반환
          final message = responseData['message'] as String? ?? '해당 시간대에 운행하는 스케줄이 없습니다.';
          if (kDebugMode) {
            print('⚠️ 서버 응답: $message');
          }
          throw Exception(message);
        }
      }

      return CongestionReportResponse.fromJson(resp.data);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 혼잡도 리포트 전송 실패: ${e.message}');
        print('요청 URL: ${e.requestOptions.baseUrl}${e.requestOptions.path}');
        print('요청 데이터: ${e.requestOptions.data}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        } else {
          print('응답 없음 (네트워크 오류 또는 서버 연결 실패)');
        }
        
        // 404 에러인 경우 서버 메시지 확인
        if (e.response?.statusCode == 404 && e.response?.data is Map) {
          final responseData = e.response!.data as Map;
          if (responseData.containsKey('message')) {
            // 서버가 메시지를 반환한 경우 (스케줄 없음 등)
            final message = responseData['message'] as String;
            if (kDebugMode) {
              print('⚠️ 서버 응답: $message');
            }
            throw Exception(message);
          } else {
            // 실제 404 에러 (엔드포인트 없음)
            print('');
            print('⚠️ 404 에러: API 엔드포인트를 찾을 수 없습니다.');
            print('요청한 URL: ${e.requestOptions.baseUrl}${e.requestOptions.path}');
          }
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
  Future<CongestionOverviewResponse> getOverview({
    required String busType,
    String? dayKey,
  }) async {
    if (kDebugMode) {
      print('혼잡도 Overview 조회: busType=$busType, dayKey=$dayKey');
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

