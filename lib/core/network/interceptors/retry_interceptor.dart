/// 재시도 인터셉터
/// 네트워크 오류 시 자동 재시도 (최대 2회, 3초 간격)
import 'dart:async';
import 'package:dio/dio.dart';
import '../../utils/app_logger.dart';

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    this.maxRetries = 2,
    this.retryDelay = const Duration(seconds: 3),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 재시도 가능한 에러 타입 확인
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    // 재시도 횟수 확인
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;
    if (retryCount >= maxRetries) {
      AppLogger.warning(
        'RetryInterceptor',
        '최대 재시도 횟수($maxRetries)에 도달했습니다.',
      );
      handler.next(err);
      return;
    }

    // 재시도 대기
    AppLogger.info(
      'RetryInterceptor',
      '재시도 중... (${retryCount + 1}/$maxRetries)',
    );
    await Future.delayed(retryDelay);

    // 재시도
    try {
      final opts = err.requestOptions;
      opts.extra['retryCount'] = retryCount + 1;

      // 새로운 Dio 인스턴스 생성 (인터셉터 없이)
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
        // 재시도 실패 시 재시도 횟수 확인 후 처리
        final newRetryCount = e.requestOptions.extra['retryCount'] as int? ?? 0;
        if (newRetryCount < maxRetries) {
          // 재시도 횟수가 남아있으면 다시 시도
          onError(e, handler);
        } else {
          // 최대 재시도 횟수 초과 시 에러 전달
          handler.next(e);
        }
      } else {
        handler.next(err);
      }
    }
  }

  /// 재시도 가능한 에러인지 확인
  bool _shouldRetry(DioException err) {
    // 네트워크 오류 또는 타임아웃만 재시도
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null &&
            err.response!.statusCode! >= 500 &&
            err.response!.statusCode! < 600);
  }
}

