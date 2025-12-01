class Validators {
  static bool isValidUserId(String s) {
    final reg = RegExp(r'^[A-Za-z0-9]{4,20}$');
    return reg.hasMatch(s);
  }

  static bool isValidPassword(String s) {
    // 백엔드는 6자 이상만 체크하므로 프론트도 동일하게 처리
    return s.length >= 6;
  }

  static bool isValidEmail(String s) {
    final reg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return reg.hasMatch(s);
  }
}
