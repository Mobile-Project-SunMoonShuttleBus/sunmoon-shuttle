import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/utils/app_logger.dart'; // [수정됨] 경로 맞춤

/// 재시도 인터셉터
/// 네트워크 오류 시 자동 재시도 (최대 2회, 3초 간격)
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    this.maxRetries = 2,
    this.retryDelay = const Duration(seconds: 3),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;
    if (retryCount >= maxRetries) {
      AppLogger.warning('RetryInterceptor', '최대 재시도 횟수($maxRetries)에 도달했습니다.');
      handler.next(err);
      return;
    }

    AppLogger.info('RetryInterceptor', '재시도 중... (${retryCount + 1}/$maxRetries)');
    await Future.delayed(retryDelay);

    try {
      final opts = err.requestOptions;
      opts.extra['retryCount'] = retryCount + 1;

      final dio = Dio(BaseOptions(
        baseUrl: opts.baseUrl,
        connectTimeout: opts.connectTimeout,
        receiveTimeout: opts.receiveTimeout,
        headers: opts.headers,
      ));
      
      final response = await dio.fetch(opts);
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        final newRetryCount = e.requestOptions.extra['retryCount'] as int? ?? 0;
        if (newRetryCount < maxRetries) {
          onError(e, handler);
        } else {
          handler.next(e);
        }
      } else {
        handler.next(err);
      }
    }
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null &&
            err.response!.statusCode! >= 500 &&
            err.response!.statusCode! < 600);
  }
}