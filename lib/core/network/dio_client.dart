/// 통합 Dio 클라이언트
/// 모든 네트워크 요청에 공통 인터셉터 적용
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../cache/cache_manager.dart';
import 'interceptors/cache_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import '../../api/dio_interceptor.dart';

class DioClient {
  static DioClient? _instance;
  late final Dio _dio;
  final CacheInterceptor _cacheInterceptor = CacheInterceptor();
  final AuthInterceptor _authInterceptor = AuthInterceptor();
  ErrorInterceptor? _errorInterceptor;
  final RetryInterceptor _retryInterceptor = RetryInterceptor();

  DioClient._internal() {
    // 서버 주소 설정
    final envBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const defaultBaseUrl = 'http://124.61.202.9:8080';
    final baseUrl = envBaseUrl.isEmpty ? defaultBaseUrl : envBaseUrl;

    AppLogger.info('DioClient', 'API Base URL: $baseUrl');

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'Content-Type': 'application/json'},
    ));

    // 인터셉터 추가 순서 중요!
    // 1. CacheInterceptor (캐시 확인/저장) - 가장 먼저
    _dio.interceptors.add(_cacheInterceptor);
    
    // 2. AuthInterceptor (토큰 추가, 401 처리)
    _dio.interceptors.add(_authInterceptor);
    
    // 3. RetryInterceptor (네트워크 오류 재시도)
    _dio.interceptors.add(_retryInterceptor);
    
    // 4. ErrorInterceptor (403, 500 처리) - context가 필요하므로 나중에 설정
    
    // CacheManager 초기화
    CacheManager.I.init().catchError((error) {
      AppLogger.error('DioClient', 'CacheManager 초기화 실패', error is Error ? error.stackTrace : null);
    });
  }

  /// 싱글톤 인스턴스
  static DioClient get instance {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  /// Dio 인스턴스 반환
  Dio get dio => _dio;

  /// 루트 컨텍스트 설정 (로그인 화면 리다이렉트 및 에러 다이얼로그용)
  void setRootContext(BuildContext? context) {
    _authInterceptor.setRootContext(context);
    
    // ErrorInterceptor도 context 설정
    if (context != null) {
      _errorInterceptor = ErrorInterceptor(context: context);
      // 기존 ErrorInterceptor 제거 후 새로 추가
      _dio.interceptors.removeWhere((interceptor) => interceptor is ErrorInterceptor);
      _dio.interceptors.add(_errorInterceptor!);
    } else {
      _errorInterceptor = null;
      _dio.interceptors.removeWhere((interceptor) => interceptor is ErrorInterceptor);
    }
  }

  /// GET 요청
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// POST 요청
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// PUT 요청
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// PATCH 요청
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// DELETE 요청
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}

