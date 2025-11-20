import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

/// 포털 쿠키 관리 서비스
/// WebView 쿠키 확인 및 저장 관리
/// 요구사항: FE_AUTH.PT-SS-01 - 포털(WebView) 로그인 유지
class PortalCookieService {
  PortalCookieService._internal();
  static final PortalCookieService I = PortalCookieService._internal();

  static const String _keyPortalUserId = 'portal.userId';
  static const String _keyPortalCookieSaved = 'portal.cookieSaved';
  static const String _keyPortalLastLogin = 'portal.lastLogin';
  static const String _keyPortalCookieSnapshot = 'portal.cookieSnapshot'; // 쿠키 스냅샷 (선택)

  final _prefs = SharedPreferences.getInstance();
  
  // SharedPreferences 인스턴스 접근 (외부에서도 사용 가능하도록)
  Future<SharedPreferences> get prefs => _prefs;
  
  // 포털 도메인
  static const String _portalDomain = 'sws.sunmoon.ac.kr';
  static const String _portalLoginDomain = 'sws.sunmoon.ac.kr';

  /// 포털 쿠키가 유효한지 확인
  /// 1. SharedPreferences 플래그 확인
  /// 2. 마지막 로그인 시간 확인 (30일 이내)
  /// 실제 쿠키 확인은 페이지 로드 후 URL 패턴으로 판단
  Future<bool> hasValidCookie({WebViewController? webViewController}) async {
    // 1. SharedPreferences 플래그 확인
    final prefs = await _prefs;
    final cookieSaved = prefs.getBool(_keyPortalCookieSaved) ?? false;
    
    if (!cookieSaved) return false;
    
    // 2. 마지막 로그인 시간 확인 (30일 이내면 유효)
    final lastLogin = await getLastLoginTime();
    if (lastLogin == null) return false;
    
    final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
    if (daysSinceLogin >= 30) {
      // 만료된 경우 상태 초기화
      await clearCookieStatus();
      return false;
    }
    
    // 3. WebView CookieManager로 실제 쿠키 확인 (모바일/데스크톱 환경)
    // 주의: webview_flutter 4.x에서는 CookieManager 접근이 제한적이므로
    // 실제 쿠키 확인은 페이지 로드 후 URL 패턴으로 판단
    // 여기서는 플래그 기반으로만 판단
    // 실제 쿠키 확인은 WebView의 onPageFinished에서 URL 패턴으로 수행
    
    return true;
  }

  /// 포털 로그인 성공 시 쿠키 저장 상태 기록
  /// 성공 URL 패턴 감지 시 호출
  Future<void> markCookieSaved({WebViewController? webViewController}) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyPortalCookieSaved, true);
    await prefs.setString(_keyPortalLastLogin, DateTime.now().toIso8601String());
    
    // WebView 쿠키는 자동으로 관리되므로 플래그만 저장
    // 실제 쿠키 확인은 페이지 로드 후 URL 패턴으로 판단
  }

  /// 포털 쿠키 저장 상태 초기화
  /// 만료/삭제 시 호출
  Future<void> clearCookieStatus({WebViewController? webViewController}) async {
    final prefs = await _prefs;
    await prefs.remove(_keyPortalCookieSaved);
    await prefs.remove(_keyPortalLastLogin);
    await prefs.remove(_keyPortalCookieSnapshot);
    // userId는 유지 (자동채움용)
    
    // WebView 쿠키는 자동으로 관리되므로 플래그만 삭제
    // 실제 쿠키는 WebView가 자동으로 관리
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
  
  /// 쿠키 만료 여부 확인
  Future<bool> isCookieExpired() async {
    final lastLogin = await getLastLoginTime();
    if (lastLogin == null) return true;
    
    final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
    return daysSinceLogin >= 30;
  }
}

