import 'package:shared_preferences/shared_preferences.dart';

/// 포털 쿠키 관리 서비스
/// WebView 쿠키 확인 및 저장 관리
class PortalCookieService {
  PortalCookieService._internal();
  static final PortalCookieService I = PortalCookieService._internal();

  static const String _keyPortalUserId = 'portal.userId';
  static const String _keyPortalCookieSaved = 'portal.cookieSaved';
  static const String _keyPortalLastLogin = 'portal.lastLogin';

  final _prefs = SharedPreferences.getInstance();

  /// 포털 쿠키가 유효한지 확인
  /// SharedPreferences로 쿠키 저장 여부 확인
  /// (WebView 쿠키는 직접 접근할 수 없으므로 로그인 성공 시 저장한 플래그 사용)
  Future<bool> hasValidCookie() async {
    // 모든 플랫폼에서 SharedPreferences 사용
    final prefs = await _prefs;
    final cookieSaved = prefs.getBool(_keyPortalCookieSaved) ?? false;
    
    if (!cookieSaved) return false;
    
    // 마지막 로그인 시간 확인 (30일 이내면 유효)
    final lastLogin = await getLastLoginTime();
    if (lastLogin == null) return false;
    
    final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
    return daysSinceLogin < 30; // 30일 이내면 유효
  }

  /// 포털 로그인 성공 시 쿠키 저장 상태 기록
  Future<void> markCookieSaved() async {
    final prefs = await _prefs;
    await prefs.setBool(_keyPortalCookieSaved, true);
    await prefs.setString(_keyPortalLastLogin, DateTime.now().toIso8601String());
  }

  /// 포털 쿠키 저장 상태 초기화
  Future<void> clearCookieStatus() async {
    final prefs = await _prefs;
    await prefs.remove(_keyPortalCookieSaved);
    await prefs.remove(_keyPortalLastLogin);
    await prefs.remove(_keyPortalUserId);
  }

  /// 포털 사용자 ID 저장
  Future<void> savePortalUserId(String userId) async {
    final prefs = await _prefs;
    await prefs.setString(_keyPortalUserId, userId);
  }

  /// 포털 사용자 ID 가져오기
  Future<String?> getPortalUserId() async {
    final prefs = await _prefs;
    return prefs.getString(_keyPortalUserId);
  }

  /// 마지막 로그인 시간 가져오기
  Future<DateTime?> getLastLoginTime() async {
    final prefs = await _prefs;
    final lastLoginStr = prefs.getString(_keyPortalLastLogin);
    if (lastLoginStr == null) return null;
    return DateTime.tryParse(lastLoginStr);
  }
}

