/// 공통 로깅 유틸리티
/// 모든 로깅은 이 클래스를 통해 통일
import 'package:flutter/foundation.dart';

class AppLogger {
  /// 에러 로깅
  static void error(String tag, dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('❌ [ERROR] [$tag] $error');
      if (stackTrace != null) {
        print('Stack Trace: $stackTrace');
      }
    }
    // 프로덕션에서는 Crashlytics나 Sentry 같은 서비스로 전송 가능
  }

  /// 정보 로깅
  static void info(String tag, String message) {
    if (kDebugMode) {
      print('ℹ️ [INFO] [$tag] $message');
    }
  }

  /// 경고 로깅
  static void warning(String tag, String message) {
    if (kDebugMode) {
      print('⚠️ [WARNING] [$tag] $message');
    }
  }

  /// 디버그 로깅
  static void debug(String tag, String message) {
    if (kDebugMode) {
      print('🐛 [DEBUG] [$tag] $message');
    }
  }
}

