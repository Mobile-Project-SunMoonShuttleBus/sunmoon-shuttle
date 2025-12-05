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
  /// 
  /// 응답 형식:
  /// {
  ///   "success": true,
  ///   "count": 17,
  ///   "crawlingStatus": "completed",
  ///   "statusMessage": "시간표를 불러오는 중입니다. 잠시만 기다려주세요.",
  ///   "lastCrawledAt": "2025-11-23T09:30:00.000Z",
  ///   "timetable": {
  ///     "월": [...],
  ///     "화": [...]
  ///   }
  /// }
  Future<TimetableResponse> getTimetable() async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);

    if (kDebugMode) {
      print('📋 시간표 조회 요청: GET /api/timetable');
    }

    try {
      final resp = await _dio.get('/api/timetable', options: opts);
      
      if (kDebugMode) {
        print('📋 시간표 조회 응답 받음');
        print('  - 상태 코드: ${resp.statusCode}');
        print('  - 응답 타입: ${resp.data.runtimeType}');
        if (resp.data is Map) {
          final data = resp.data as Map<String, dynamic>;
          print('  - success: ${data['success']}');
          print('  - count: ${data['count']}');
          print('  - crawlingStatus: ${data['crawlingStatus']}');
          print('  - timetable keys: ${data['timetable'] is Map ? (data['timetable'] as Map).keys.toList() : 'N/A'}');
        }
      }

      // 응답 데이터 검증
      if (resp.data is! Map) {
        throw DioException(
          requestOptions: resp.requestOptions,
          response: resp,
          type: DioExceptionType.badResponse,
          message: '시간표 응답이 올바른 형식이 아닙니다. Map이 아닙니다.',
        );
      }

      final responseData = Map<String, dynamic>.from(resp.data);
      
      // 필수 필드 확인
      if (!responseData.containsKey('success') || !responseData.containsKey('timetable')) {
        if (kDebugMode) {
          print('⚠️ 시간표 응답에 필수 필드가 없습니다.');
          print('  - 응답 키: ${responseData.keys.toList()}');
        }
      }

      final timetableResponse = TimetableResponse.fromMap(responseData);
      
      if (kDebugMode) {
        // 월~금만 필터링 (토, 일 제외)
        const weekdays = ['월', '화', '수', '목', '금'];
        final weekdayTimetable = timetableResponse.timetable.entries
            .where((entry) => weekdays.contains(entry.key))
            .toList();
        final weekdayCount = weekdayTimetable.fold<int>(
            0, (sum, entry) => sum + entry.value.length);
        
        print('✅ 시간표 파싱 완료:');
        print('  - success: ${timetableResponse.success}');
        print('  - count: ${timetableResponse.count} (전체) / $weekdayCount (월~금)');
        print('  - crawlingStatus: ${timetableResponse.crawlingStatus}');
        print('  - timetable 요일 수: ${weekdayTimetable.length} (월~금만)');
        weekdayTimetable.forEach((entry) {
          print('  - ${entry.key}: ${entry.value.length}개 과목');
        });
      }

      return timetableResponse;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 시간표 조회 실패: ${e.message}');
        print('  - 에러 타입: ${e.type}');
        if (e.response != null) {
          print('  - 응답 상태 코드: ${e.response?.statusCode}');
          print('  - 응답 데이터: ${e.response?.data}');
        }
      }
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 시간표 조회 예외: $e');
        print('스택 트레이스: $stackTrace');
      }
      rethrow;
    }
  }
}

