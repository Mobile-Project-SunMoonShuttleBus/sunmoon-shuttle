import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

// [경로 수정] Core 유틸리티 참조
import '../core/utils/app_logger.dart';
import '../core/cache/cache_manager.dart';

// [경로 수정] 인터셉터 참조
import 'interceptors/cache_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'dio_interceptor.dart'; // (AuthInterceptor가 여기 정의되어 있음)

class DioClient {
  static DioClient? _instance;
  late final Dio _dio;
  
  final CacheInterceptor _cacheInterceptor = CacheInterceptor();
  final AuthInterceptor _authInterceptor = AuthInterceptor();
  final RetryInterceptor _retryInterceptor = RetryInterceptor();
  ErrorInterceptor? _errorInterceptor;

  DioClient._internal() {
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

    _dio.interceptors.add(_cacheInterceptor);
    _dio.interceptors.add(_authInterceptor);
    _dio.interceptors.add(_retryInterceptor);
    
    CacheManager.I.init().catchError((error) {
      AppLogger.error('DioClient', 'CacheManager 초기화 실패', error is Error ? error.stackTrace : null);
    });
  }

  static DioClient get instance {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  Dio get dio => _dio;

  void setRootContext(BuildContext? context) {
    _authInterceptor.setRootContext(context);
    
    _dio.interceptors.removeWhere((i) => i is ErrorInterceptor);
    if (context != null) {
      _errorInterceptor = ErrorInterceptor(context: context);
      _dio.interceptors.add(_errorInterceptor!);
    }
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) {
    return _dio.get<T>(path, queryParameters: queryParameters, options: options, cancelToken: cancelToken, onReceiveProgress: onReceiveProgress);
  }

  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress);
  }
  
  // put, patch, delete 등 나머지 메서드도 동일하게 유지
  Future<Response<T>> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) {
    return _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress);
  }

  Future<Response<T>> patch<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) {
    return _dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress);
  }

  Future<Response<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) {
    return _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }
}