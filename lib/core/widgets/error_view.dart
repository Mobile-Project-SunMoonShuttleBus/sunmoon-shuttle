import 'package:flutter/material.dart';

/// 공통 에러 화면 (Dialog 형태)
/// 500 에러 등 서버 오류 시 표시
class ErrorView extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorView({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.onDismiss,
  });

  /// 에러 다이얼로그 표시
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
    VoidCallback? onRetry,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorView(
        title: title,
        message: message,
        onRetry: onRetry,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title ?? '오류가 발생했습니다',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message ?? '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: const Text('닫기'),
          ),
        if (onRetry != null)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1890FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('다시 시도'),
          ),
      ],
    );
  }
}

