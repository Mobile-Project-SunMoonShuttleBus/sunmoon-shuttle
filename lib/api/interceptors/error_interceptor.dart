import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

// [경로 수정] Core 유틸리티 및 위젯 참조
import '../../core/utils/app_logger.dart';
import '../../core/widgets/error_view.dart'; // 위젯 폴더 위치에 맞게 수정

class ErrorInterceptor extends Interceptor {
  final BuildContext? context;

  ErrorInterceptor({this.context});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;

    if (_isCorsError(err)) {
      AppLogger.error('ErrorInterceptor', 'CORS 오류 감지: ${err.message}');
      handler.next(err);
      return;
    }

    if (statusCode == 403) {
      AppLogger.error('ErrorInterceptor', '403 Forbidden: ${err.requestOptions.path}');
      _showSnackBar('권한이 없습니다.');
      handler.next(err);
      return;
    }

    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      AppLogger.error('ErrorInterceptor', 'Server Error ($statusCode)');
      _showErrorDialog(
        title: '서버 오류',
        message: '서버에서 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
      handler.next(err);
      return;
    }

    handler.next(err);
  }

  bool _isCorsError(DioException err) {
    if (err.type == DioExceptionType.connectionError) {
      final message = (err.message ?? '').toLowerCase();
      return message.contains('cors') || 
             message.contains('xmlhttprequest') || 
             message.contains('preflight');
    }
    return false;
  }

  void _showSnackBar(String message) {
    if (context == null) return;
    ScaffoldMessenger.of(context!).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showErrorDialog({String? title, String? message}) {
    if (context == null) return;
    ErrorView.show(context!, title: title, message: message);
  }
}