/// 공지사항 API 클라이언트
/// 셔틀 관련 공지사항 조회 API 호출
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
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
      headers: {'Content-Type': 'application/json'},
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
}

