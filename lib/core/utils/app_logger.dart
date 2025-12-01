// lib/core/utils/app_logger.dart
import 'package:flutter/foundation.dart';

class AppLogger {
  static void error(String tag, dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('❌ [ERROR] [$tag] $error');
      if (stackTrace != null) print('Stack: $stackTrace');
    }
  }

  static void info(String tag, String message) {
    if (kDebugMode) print('ℹ️ [INFO] [$tag] $message');
  }

  static void warning(String tag, String message) {
    if (kDebugMode) print('⚠️ [WARNING] [$tag] $message');
  }

  static void debug(String tag, String message) {
    if (kDebugMode) print('🐛 [DEBUG] [$tag] $message');
  }
}