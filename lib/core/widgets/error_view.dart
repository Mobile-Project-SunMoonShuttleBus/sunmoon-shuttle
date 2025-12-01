import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onDismiss;

  const ErrorView({super.key, this.title, this.message, this.onDismiss});

  // 외부에서 호출하기 편하게 만든 static 함수
  static void show(BuildContext context, {String? title, String? message, VoidCallback? onRetry}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title ?? '알림', style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(message ?? '오류가 발생했습니다.'),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('재시도'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // 이 클래스는 주로 static show() 메서드로 사용됨
  }
}