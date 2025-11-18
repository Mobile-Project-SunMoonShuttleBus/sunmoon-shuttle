/// 캐시 인터셉터
/// 요청 전 캐시 확인, 응답 후 캐시 저장
import 'package:dio/dio.dart';
import '../../cache/cache_manager.dart';
import '../../cache/cache_item.dart';
import '../../utils/app_logger.dart';

class CacheInterceptor extends Interceptor {
  final CacheManager _cacheManager = CacheManager.I;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // GET 요청만 캐시 처리
    if (options.method != 'GET') {
      handler.next(options);
      return;
    }

    // 캐시 키 생성 (URL 기반)
    final cacheKey = _getCacheKey(options);
    if (cacheKey == null) {
      handler.next(options);
      return;
    }

    // 캐시 확인 (동기적으로 처리)
    try {
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        // 캐시가 있으면 캐시 데이터로 응답
        AppLogger.debug('CacheInterceptor', '캐시 히트: ${options.path}');
        final response = Response(
          requestOptions: options,
          data: cachedData,
          statusCode: 200,
          headers: Headers.fromMap({
            'cache': ['hit'],
          }),
        );
        handler.resolve(response);
        return;
      }
    } catch (error) {
      // 캐시 조회 실패 시 원래 요청 진행
      AppLogger.warning('CacheInterceptor', '캐시 조회 실패: $cacheKey');
    }

    // 캐시가 없으면 원래 요청 진행
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // GET 요청만 캐시 저장
    if (response.requestOptions.method != 'GET') {
      handler.next(response);
      return;
    }

    // 캐시 키 생성
    final cacheKey = _getCacheKey(response.requestOptions);
    if (cacheKey == null) {
      handler.next(response);
      return;
    }

    // TTL 결정
    final ttl = _getTTL(cacheKey);
    if (ttl == null) {
      handler.next(response);
      return;
    }

    // 캐시 저장 (비동기, 응답은 즉시 반환)
    _cacheManager.setCache(cacheKey, response.data, ttl).catchError((error) {
      AppLogger.error('CacheInterceptor', '캐시 저장 실패: $cacheKey', error is Error ? error.stackTrace : null);
    });

    handler.next(response);
  }

  /// 캐시 키 생성
  /// query parameter도 포함하여 고유한 캐시 키 생성
  String? _getCacheKey(RequestOptions options) {
    final path = options.path;
    final queryParams = options.queryParameters;
    
    // 경로에 따라 캐시 키 결정
    String? baseCacheKey;
    if (path.contains('/api/shuttle/favorites') || path.contains('/api/shuttle/next')) {
      baseCacheKey = CacheKeys.favorites;
    } else if (path.contains('/api/shuttle/crowd') || path.contains('/api/shuttle/snapshot')) {
      baseCacheKey = CacheKeys.crowdSnapshots;
    } else if (path.contains('/api/shuttle/timetable') || path.contains('/api/shuttle/schedule')) {
      baseCacheKey = CacheKeys.timetable;
    } else if (path.contains('/api/notices') || path.contains('/api/announcements')) {
      baseCacheKey = CacheKeys.notices;
    }
    
    if (baseCacheKey == null) {
      return null;
    }
    
    // query parameter가 있으면 캐시 키에 포함
    if (queryParams.isNotEmpty) {
      final sortedParams = Map.fromEntries(
        queryParams.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      final queryString = sortedParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      return '${baseCacheKey}?$queryString';
    }
    
    return baseCacheKey;
  }

  /// 캐시 TTL 결정
  Duration? _getTTL(String cacheKey) {
    // query parameter가 포함된 경우 baseCacheKey만 추출
    final baseKey = cacheKey.split('?').first;
    
    switch (baseKey) {
      case CacheKeys.favorites:
        return CacheTTL.favorites;
      case CacheKeys.crowdSnapshots:
        return CacheTTL.crowdSnapshots;
      case CacheKeys.timetable:
        return CacheTTL.timetable;
      case CacheKeys.notices:
        return CacheTTL.notices;
      default:
        return null;
    }
  }

  /// 캐시 데이터 조회
  Future<dynamic> _getCachedData(String cacheKey) async {
    try {
      return await _cacheManager.getCache(cacheKey);
    } catch (e) {
      AppLogger.error('CacheInterceptor', '캐시 조회 오류: $cacheKey', e is Error ? e.stackTrace : null);
      return null;
    }
  }
}

