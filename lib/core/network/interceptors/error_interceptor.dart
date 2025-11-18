/// 에러 처리 인터셉터
/// 403, 500 등 공통 에러 처리 및 UX 제공
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../utils/app_logger.dart';
import '../../widgets/error_view.dart';

class ErrorInterceptor extends Interceptor {
  final BuildContext? context;

  ErrorInterceptor({this.context});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;

    // CORS 오류 감지 - 에러를 전파하지 않고 여기서 처리 완료
    if (_isCorsError(err)) {
      AppLogger.error('ErrorInterceptor', 'CORS 오류 감지: ${err.requestOptions.method} ${err.requestOptions.path}');
      AppLogger.error('ErrorInterceptor', 'CORS 오류 상세: type=${err.type}, response=${err.response}, message=${err.message}');
      // CORS 오류는 여기서 처리 완료하고 에러를 전파하지 않음
      // SettingsProvider에서 로컬 저장을 위해 에러를 전파해야 하므로 handler.next(err) 호출
      handler.next(err);
      return;
    }

    // 403 Forbidden 처리
    if (statusCode == 403) {
      AppLogger.error('ErrorInterceptor', '403 Forbidden: ${err.requestOptions.path}');
      _showSnackBar('권한이 없습니다.');
      handler.next(err);
      return;
    }

    // 500 Server Error 처리
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      AppLogger.error(
        'ErrorInterceptor',
        'Server Error ($statusCode): ${err.requestOptions.path}',
        err.stackTrace,
      );
      _showErrorDialog(
        title: '서버 오류',
        message: '서버에서 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
      handler.next(err);
      return;
    }

    // 기타 에러는 다음 인터셉터로 전달
    handler.next(err);
  }

  /// CORS 오류인지 확인
  bool _isCorsError(DioException err) {
    // PATCH 메서드에서 connectionError가 발생하면 CORS 가능성이 매우 높음
    if (err.requestOptions.method.toUpperCase() == 'PATCH' && 
        err.type == DioExceptionType.connectionError &&
        err.response == null) {
      AppLogger.debug('ErrorInterceptor', 'CORS 감지: PATCH + connectionError + no response');
      return true;
    }
    
    // connectionError 타입이고 메시지에 CORS 관련 키워드가 포함된 경우
    if (err.type == DioExceptionType.connectionError) {
      final message = (err.message ?? '').toLowerCase();
      if (message.contains('cors') ||
          message.contains('xmlhttprequest') ||
          message.contains('access-control') ||
          message.contains('preflight') ||
          message.contains('blocked by cors policy')) {
        AppLogger.debug('ErrorInterceptor', 'CORS 감지: 메시지에 CORS 키워드 포함');
        return true;
      }
    }
    
    // toString()에도 CORS 관련 키워드가 있는지 확인
    final errorStr = err.toString().toLowerCase();
    if (errorStr.contains('cors') ||
        errorStr.contains('access-control') ||
        errorStr.contains('preflight')) {
      AppLogger.debug('ErrorInterceptor', 'CORS 감지: toString에 CORS 키워드 포함');
      return true;
    }
    
    // 응답이 없고 connectionError인 경우 (특히 웹 환경에서)
    if (err.response == null && 
        err.type == DioExceptionType.connectionError &&
        err.requestOptions.method.toUpperCase() != 'GET') {
      // GET이 아닌 메서드에서 응답 없이 connectionError면 CORS 가능성 높음
      AppLogger.debug('ErrorInterceptor', 'CORS 감지: non-GET + connectionError + no response');
      return true;
    }
    
    return false;
  }

  /// 스낵바 표시
  void _showSnackBar(String message) {
    if (context == null) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context!);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 에러 다이얼로그 표시
  void _showErrorDialog({
    String? title,
    String? message,
    VoidCallback? onRetry,
  }) {
    if (context == null) return;
    
    ErrorView.show(
      context!,
      title: title,
      message: message,
      onRetry: onRetry,
    );
  }
}

