/// 공지사항 API 클라이언트
/// 셔틀 관련 공지사항 조회 API 호출
library;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/shuttle_notice_models.dart';
import 'dio_interceptor.dart';

class NoticeApi {
  static final NoticeApi I = NoticeApi._internal();

  late final Dio _dio;

  NoticeApi._internal() {
    // 서버 주소 설정
    final envBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const defaultBaseUrl = 'http://124.61.202.9:8080';
    final baseUrl = envBaseUrl.isEmpty ? defaultBaseUrl : envBaseUrl;

    if (kDebugMode) {
      print('NoticeApi Base URL: $baseUrl');
    }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json', // JSON만 받도록 명시 (Swagger HTML 방지)
      },
      responseType: ResponseType.json, // JSON 응답만 받도록 명시
      validateStatus: (status) {
        // 200-299 범위의 상태 코드만 성공으로 처리
        return status != null && status >= 200 && status < 300;
      },
    ));
    // 401 처리 및 토큰 갱신 인터셉터 추가
    _dio.interceptors.add(AuthInterceptor());
  }

  /// 공지사항 목록 조회
  /// GET /api/notices?scope=ROUTE&routeId=R001
  /// 응답: { "data": [...], "meta": { "etag": "..." } }
  Future<Map<String, dynamic>> getNotices({
    String? routeId,
  }) async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);

    final queryParams = <String, dynamic>{
      'scope': 'ROUTE',
    };
    
    if (routeId != null) {
      queryParams['routeId'] = routeId;
    }

    if (kDebugMode) {
      print('공지사항 조회 요청: $queryParams');
    }

    final resp = await _dio.get(
      '/api/notices',
      queryParameters: queryParams,
      options: opts,
    );
    
    return Map<String, dynamic>.from(resp.data);
  }

  /// 공지사항 상세 조회
  /// GET /api/notices/{noticeId}
  /// 응답: { "data": { "_id": "...", "title": "...", "body": "...", ... } }
  Future<Map<String, dynamic>> getNoticeDetail({
    required String noticeId,
  }) async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);

    if (kDebugMode) {
      print('공지사항 상세 조회 요청: noticeId=$noticeId');
    }

    final resp = await _dio.get(
      '/api/notices/$noticeId',
      options: opts,
    );
    
    return Map<String, dynamic>.from(resp.data);
  }

  /// 셔틀 공지 리스트 조회: GET /api/notices/shuttle
  /// 셔틀 관련 공지 목록을 최신순으로 조회
  /// 응답 200: [{ "_id": "string", "title": "string", "postedAt": "2025-11-26T02:25:46.576Z" }]
  Future<List<ShuttleNoticeSummary>> fetchShuttleNotices() async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);

    if (kDebugMode) {
      print('셔틀 공지 리스트 조회 요청: GET /api/notices/shuttle');
    }

    try {
      final resp = await _dio.get(
        '/api/notices/shuttle',
        options: opts,
      );

      // 200 응답 처리
      if (resp.statusCode != 200) {
        throw Exception('셔틀 공지 리스트 조회 실패: ${resp.statusCode}');
      }

      if (kDebugMode) {
        print('✅ 셔틀 공지 리스트 응답 데이터 타입: ${resp.data.runtimeType}');
        print('셔틀 공지 리스트 응답 데이터: ${resp.data}');
      }

      // API 스펙에 따르면 응답은 바로 배열 형태: [{ "_id": "...", "title": "...", "postedAt": "..." }]
      if (resp.data is! List) {
        if (kDebugMode) {
          print('⚠️ 응답이 리스트가 아닙니다. 응답 타입: ${resp.data.runtimeType}');
        }
        throw Exception('셔틀 공지 리스트 조회 실패: 응답 형식이 올바르지 않습니다. 배열이 아닙니다.');
      }

      final List<dynamic> jsonList = resp.data as List<dynamic>;
      
      if (kDebugMode) {
        print('셔틀 공지 리스트 파싱: ${jsonList.length}개 항목');
      }

      // 각 항목을 ShuttleNoticeSummary로 변환
      final notices = jsonList
          .map((item) {
            try {
              // 각 항목은 { "_id": "...", "title": "...", "postedAt": "..." } 형태
              if (item is! Map<String, dynamic>) {
                throw FormatException('공지 항목이 Map 형식이 아닙니다: $item');
              }
              return ShuttleNoticeSummary.fromJson(item);
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ 공지 항목 파싱 실패: $item, 에러: $e');
              }
              rethrow;
            }
          })
          .toList();

      if (kDebugMode) {
        print('✅ 셔틀 공지 리스트 파싱 완료: ${notices.length}개');
      }

      return notices;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 셔틀 공지 리스트 조회 DioException: ${e.message}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      throw Exception('셔틀 공지 리스트 조회 실패: ${e.message}');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 셔틀 공지 리스트 조회 예외: $e');
        print('스택 트레이스: $stackTrace');
      }
      rethrow;
    }
  }

  /// 셔틀 공지 상세 조회: GET /api/notices/shuttle/:id
  /// 응답: { "_id": "string", "portalNoticeId": "string", "title": "string", 
  ///        "content": "string", "summary": "string", "url": "string", 
  ///        "postedAt": "2025-11-26T02:25:46.581Z", "createdAt": "2025-11-26T02:25:46.581Z", 
  ///        "updatedAt": "2025-11-26T02:25:46.581Z" }
  /// 주의: summary가 없으면 서버에서 자동 생성될 수 있음
  Future<ShuttleNoticeDetail> fetchShuttleNoticeDetail(String id) async {
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);

    if (kDebugMode) {
      print('셔틀 공지 상세 조회 요청: GET /api/notices/shuttle/$id');
    }

    try {
      final resp = await _dio.get(
        '/api/notices/shuttle/$id',
        options: opts,
      );

      // 404 에러 처리
      if (resp.statusCode == 404) {
        throw Exception('공지 없음');
      }

      // 200 응답 처리
      if (resp.statusCode != 200) {
        throw Exception('셔틀 공지 상세 조회 실패: ${resp.statusCode} / ${resp.data}');
      }

      if (kDebugMode) {
        print('✅ 셔틀 공지 상세 응답 데이터 타입: ${resp.data.runtimeType}');
      }

      // 응답이 JSON인지 확인
      if (resp.data is String) {
        if (kDebugMode) {
          print('⚠️ 응답이 JSON이 아닙니다. 응답 타입: ${resp.data.runtimeType}');
          final preview = resp.data.toString().substring(0, resp.data.toString().length > 200 ? 200 : resp.data.toString().length);
          print('⚠️ 응답 미리보기: $preview...');
        }
        throw Exception('서버가 JSON 대신 다른 형식을 반환했습니다.');
      }

      // API 스펙에 따르면 응답은 바로 객체 형태: { "_id": "...", "title": "...", ... }
      Map<String, dynamic> jsonMap;
      if (resp.data is Map<String, dynamic>) {
        jsonMap = resp.data as Map<String, dynamic>;
      } else {
        throw Exception('예상치 못한 응답 형식입니다. Map이 아닙니다.');
      }

      if (kDebugMode) {
        print('셔틀 공지 상세 파싱 시작');
        print('  - ID: ${jsonMap['_id']}');
        print('  - 포털 공지 ID: ${jsonMap['portalNoticeId']}');
        print('  - 제목: ${jsonMap['title']}');
        print('  - 요약 존재 여부: ${jsonMap.containsKey('summary') && jsonMap['summary'] != null && (jsonMap['summary'] as String).isNotEmpty}');
        if (jsonMap.containsKey('summary')) {
          final summary = jsonMap['summary'];
          if (summary != null && summary.toString().trim().isNotEmpty) {
            print('  - 요약 길이: ${summary.toString().length}자');
            print('  - 요약 미리보기: ${summary.toString().substring(0, summary.toString().length > 100 ? 100 : summary.toString().length)}...');
          } else {
            print('  - 요약: 없음 (빈 문자열 또는 null)');
          }
        }
      }

      try {
        final notice = ShuttleNoticeDetail.fromJson(jsonMap);
        if (kDebugMode) {
          print('✅ 셔틀 공지 상세 파싱 완료');
          print('  - 요약 표시 여부: ${notice.hasSummary}');
        }
        return notice;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 공지 상세 파싱 실패: $e');
          print('⚠️ JSON 데이터: $jsonMap');
        }
        rethrow;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('공지 없음');
      }
      if (kDebugMode) {
        print('❌ 셔틀 공지 상세 조회 DioException: ${e.message}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      throw Exception('셔틀 공지 상세 조회 실패: ${e.message}');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 셔틀 공지 상세 조회 예외: $e');
        print('스택 트레이스: $stackTrace');
      }
      rethrow;
    }
  }

  /// 셔틀 공지 동기화: POST /api/notices/shuttle/sync
  /// 포털에서 공지를 수집하고 LLM으로 분류하여 셔틀 관련 공지만 DB에 저장
  /// 응답: 200 - { "message": "셔틀 공지 동기화 완료" }
  ///       500 - 동기화 실패
  /// 주의: 동기화는 시간이 오래 걸릴 수 있으므로 타임아웃을 길게 설정
  Future<Map<String, dynamic>> syncShuttleNotices() async {
    // 동기화는 시간이 오래 걸릴 수 있으므로 별도의 Dio 인스턴스 사용
    final envBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const defaultBaseUrl = 'http://124.61.202.9:8080';
    final baseUrl = envBaseUrl.isEmpty ? defaultBaseUrl : envBaseUrl;

    // 크롤링 및 LLM 처리는 시간이 오래 걸릴 수 있으므로 타임아웃을 매우 길게 설정
    // (타임아웃 없이 작동하도록 충분히 긴 시간 설정)
    final syncDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(hours: 1), // 연결 타임아웃 (1시간)
      sendTimeout: const Duration(hours: 1), // 요청 전송 타임아웃 (1시간)
      receiveTimeout: const Duration(hours: 1), // 응답 대기 타임아웃 (1시간 - LLM 처리 시간 고려)
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      responseType: ResponseType.json,
      validateStatus: (status) {
        // 200과 500 모두 처리 (500도 JSON 메시지를 포함할 수 있음)
        return status != null && (status == 200 || status == 500);
      },
    ));
    syncDio.interceptors.add(AuthInterceptor());

    // Options는 타임아웃을 받지 않음 (BaseOptions에서 이미 설정됨)
    final opts = Options();
    AuthService.I.attachAuthHeader(opts);

    if (kDebugMode) {
      print('셔틀 공지 동기화 요청: POST /api/notices/shuttle/sync');
      print('동기화 타임아웃: 연결 1시간, 전송 1시간, 응답 대기 1시간 (LLM 처리 시간 고려)');
    }

    try {
      final resp = await syncDio.post(
        '/api/notices/shuttle/sync',
        options: opts,
      );

      // 200 응답 처리: { "message": "셔틀 공지 동기화 완료" }
      if (resp.statusCode == 200) {
        if (kDebugMode) {
          print('✅ 셔틀 공지 동기화 성공: ${resp.data}');
        }

        // 응답이 Map인 경우
        if (resp.data is Map<String, dynamic>) {
          final responseMap = resp.data as Map<String, dynamic>;
          // message 필드가 있는지 확인
          if (responseMap.containsKey('message')) {
            return responseMap;
          }
          // message 필드가 없으면 기본 메시지 추가
          return {'message': '셔틀 공지 동기화 완료'};
        }

        // 응답이 문자열인 경우
        if (resp.data is String) {
          return {'message': resp.data as String};
        }

        // 예상치 못한 형식이지만 200이면 성공으로 처리
        return {'message': '셔틀 공지 동기화 완료'};
      }

      // 500 응답 처리: 서버가 에러 메시지를 JSON으로 반환할 수 있음
      if (resp.statusCode == 500) {
        if (kDebugMode) {
          print('❌ 셔틀 공지 동기화 실패 (500): ${resp.data}');
        }

        // 서버가 보낸 메시지 추출
        String errorMessage = '서버에서 동기화를 처리하는 중 오류가 발생했습니다.';
        if (resp.data is Map<String, dynamic>) {
          final errorData = resp.data as Map<String, dynamic>;
          if (errorData.containsKey('message')) {
            errorMessage = errorData['message'] as String;
          } else if (errorData.containsKey('error')) {
            errorMessage = errorData['error'] as String;
          }
        } else if (resp.data is String) {
          errorMessage = resp.data as String;
        }

        throw Exception('동기화 실패: $errorMessage');
      }

      // 기타 상태 코드
      throw Exception('셔틀 공지 동기화 실패: ${resp.statusCode}');
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 셔틀 공지 동기화 DioException: ${e.message}');
        print('에러 타입: ${e.type}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      
      // 500 에러 처리: 서버가 에러 메시지를 JSON으로 반환할 수 있음
      if (e.response?.statusCode == 500) {
        String errorMessage = '서버에서 동기화를 처리하는 중 오류가 발생했습니다.';
        if (e.response?.data is Map<String, dynamic>) {
          final errorData = e.response!.data as Map<String, dynamic>;
          if (errorData.containsKey('message')) {
            errorMessage = errorData['message'] as String;
          } else if (errorData.containsKey('error')) {
            errorMessage = errorData['error'] as String;
          }
        } else if (e.response?.data is String) {
          errorMessage = e.response!.data as String;
        }
        throw Exception('동기화 실패: $errorMessage');
      }
      
      // 타임아웃 에러 처리
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('동기화 타임아웃: 서버 응답 시간이 초과되었습니다. 백엔드 서버(Ollama 등) 상태를 확인하세요.');
      }
      
      // 기타 네트워크 에러
      throw Exception('셔틀 공지 동기화 실패: ${e.message}');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 셔틀 공지 동기화 예외: $e');
        print('스택 트레이스: $stackTrace');
      }
      rethrow;
    }
  }
}

