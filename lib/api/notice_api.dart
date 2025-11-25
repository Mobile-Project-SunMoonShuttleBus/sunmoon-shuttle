/// 공지사항 API 클라이언트
/// 셔틀 관련 공지사항 조회 API 호출
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
        'Accept': 'application/json', // JSON만 받도록 명시
      },
      responseType: ResponseType.json, // JSON 응답만 받도록 명시
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
  /// 응답: [{ "_id": "...", "title": "...", "postedAt": "..." }, ...]
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

      if (resp.statusCode != 200) {
        throw Exception('셔틀 공지 리스트 조회 실패: ${resp.statusCode}');
      }

      if (kDebugMode) {
        print('셔틀 공지 리스트 응답 데이터 타입: ${resp.data.runtimeType}');
        print('셔틀 공지 리스트 응답 데이터: ${resp.data}');
      }

      // 응답이 리스트인지 확인
      if (resp.data is! List) {
        if (kDebugMode) {
          print('⚠️ 응답이 리스트가 아닙니다. 응답 타입: ${resp.data.runtimeType}');
        }
        // 응답이 객체로 감싸져 있을 수 있음 (예: { "data": [...] })
        if (resp.data is Map<String, dynamic>) {
          final Map<String, dynamic> responseMap = resp.data as Map<String, dynamic>;
          if (responseMap.containsKey('data') && responseMap['data'] is List) {
            final List<dynamic> jsonList = responseMap['data'] as List<dynamic>;
            if (kDebugMode) {
              print('응답에서 data 필드 추출: ${jsonList.length}개 항목');
            }
            return jsonList
                .map((item) => ShuttleNoticeSummary.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }
        throw Exception('셔틀 공지 리스트 조회 실패: 응답 형식이 올바르지 않습니다. 리스트가 아닙니다.');
      }

      final List<dynamic> jsonList = resp.data as List<dynamic>;
      
      if (kDebugMode) {
        print('셔틀 공지 리스트 파싱: ${jsonList.length}개 항목');
      }

      final notices = jsonList
          .map((item) {
            try {
              return ShuttleNoticeSummary.fromJson(item as Map<String, dynamic>);
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ 공지 항목 파싱 실패: $item, 에러: $e');
              }
              rethrow;
            }
          })
          .toList();

      if (kDebugMode) {
        print('셔틀 공지 리스트 파싱 완료: ${notices.length}개');
      }

      return notices;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('셔틀 공지 리스트 조회 DioException: ${e.message}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      throw Exception('셔틀 공지 리스트 조회 실패: ${e.message}');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('셔틀 공지 리스트 조회 예외: $e');
        print('스택 트레이스: $stackTrace');
      }
      rethrow;
    }
  }

  /// 셔틀 공지 상세 조회: GET /api/notices/shuttle/:id
  /// 응답: { "_id": "...", "title": "...", "content": "...", "summary": "...", ... }
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

      if (resp.statusCode == 404) {
        throw Exception('공지 없음');
      }

      if (resp.statusCode != 200) {
        throw Exception('셔틀 공지 상세 조회 실패: ${resp.statusCode} / ${resp.data}');
      }

      if (kDebugMode) {
        print('셔틀 공지 상세 응답 데이터 타입: ${resp.data.runtimeType}');
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

      // 응답이 객체로 감싸져 있을 수 있음 (예: { "data": {...} })
      Map<String, dynamic> jsonMap;
      if (resp.data is Map<String, dynamic>) {
        final responseMap = resp.data as Map<String, dynamic>;
        if (responseMap.containsKey('data') && responseMap['data'] is Map) {
          if (kDebugMode) {
            print('응답에서 data 필드 추출');
          }
          jsonMap = responseMap['data'] as Map<String, dynamic>;
        } else {
          jsonMap = responseMap;
        }
      } else {
        throw Exception('예상치 못한 응답 형식입니다. Map이 아닙니다.');
      }

      if (kDebugMode) {
        print('셔틀 공지 상세 파싱 시작');
        print('  - ID: ${jsonMap['_id']}');
        print('  - 제목: ${jsonMap['title']}');
        print('  - 요약 존재 여부: ${jsonMap.containsKey('summary') && jsonMap['summary'] != null}');
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
          print('셔틀 공지 상세 파싱 완료');
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
        print('셔틀 공지 상세 조회 DioException: ${e.message}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      throw Exception('셔틀 공지 상세 조회 실패: ${e.message}');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('셔틀 공지 상세 조회 예외: $e');
        print('스택 트레이스: $stackTrace');
      }
      rethrow;
    }
  }

  /// 셔틀 공지 동기화: POST /api/notices/shuttle/sync
  /// 포털에서 공지를 수집하고 LLM으로 분류하여 셔틀 관련 공지만 DB에 저장
  /// 응답: { "message": "셔틀 공지 동기화 완료" }
  /// 주의: 동기화는 시간이 오래 걸릴 수 있으므로 타임아웃을 길게 설정
  Future<Map<String, dynamic>> syncShuttleNotices() async {
    // 동기화는 시간이 오래 걸릴 수 있으므로 별도의 Dio 인스턴스 사용
    final envBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const defaultBaseUrl = 'http://124.61.202.9:8080';
    final baseUrl = envBaseUrl.isEmpty ? defaultBaseUrl : envBaseUrl;

    final syncDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30), // 연결 타임아웃
      sendTimeout: const Duration(seconds: 30), // 요청 전송 타임아웃
      receiveTimeout: const Duration(seconds: 180), // 응답 대기 타임아웃 (LLM 처리 시간 고려)
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      responseType: ResponseType.json,
    ));
    syncDio.interceptors.add(AuthInterceptor());

    final opts = Options();
    AuthService.I.attachAuthHeader(opts);

    if (kDebugMode) {
      print('셔틀 공지 동기화 요청: POST /api/notices/shuttle/sync');
      print('동기화 타임아웃: 연결 30초, 전송 30초, 응답 대기 180초');
    }

    try {
      final resp = await syncDio.post(
        '/api/notices/shuttle/sync',
        options: opts,
      );

      if (resp.statusCode != 200) {
        throw Exception('셔틀 공지 동기화 실패: ${resp.statusCode}');
      }

      if (kDebugMode) {
        print('셔틀 공지 동기화 응답: ${resp.data}');
      }

      if (resp.data is Map<String, dynamic>) {
        return resp.data as Map<String, dynamic>;
      }

      // 응답이 문자열인 경우 (예: { "message": "..." })
      if (resp.data is String) {
        return {'message': resp.data as String};
      }

      throw Exception('셔틀 공지 동기화 실패: 예상치 못한 응답 형식');
    } on DioException catch (e) {
      if (kDebugMode) {
        print('셔틀 공지 동기화 DioException: ${e.message}');
        print('에러 타입: ${e.type}');
        if (e.response != null) {
          print('응답 상태 코드: ${e.response?.statusCode}');
          print('응답 데이터: ${e.response?.data}');
        }
      }
      
      // 타임아웃 에러 처리
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('동기화 타임아웃: 서버 응답 시간이 초과되었습니다. 백엔드 서버(Ollama 등) 상태를 확인하세요.');
      }
      
      if (e.response?.statusCode == 500) {
        throw Exception('동기화 실패: 서버 오류가 발생했습니다. 백엔드 서버 상태를 확인하세요.');
      }
      
      throw Exception('셔틀 공지 동기화 실패: ${e.message}');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('셔틀 공지 동기화 예외: $e');
        print('스택 트레이스: $stackTrace');
      }
      rethrow;
    }
  }
}

