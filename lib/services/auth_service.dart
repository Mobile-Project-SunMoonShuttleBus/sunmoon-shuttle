import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// [수정] 같은 폴더 내에 있는 파일이므로 경로 단순화
import 'profile_storage_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService I = AuthService._internal();

  final _storage = const FlutterSecureStorage();
  
  // accessToken은 메모리에만 저장 (요구사항: 메모리 캐시)
  String? _accessToken;
  DateTime? _accessTokenExp; // accessToken 만료 시간
  
  // refreshToken은 secure_storage에 저장 (요구사항: flutter_secure_storage)
  static const String _keyRefreshToken = 'auth.refreshToken';

  String? get token => _accessToken;
  DateTime? get accessTokenExp => _accessTokenExp;
  
  /// accessToken이 유효한지 확인 (만료 시간 체크)
  bool get isTokenValid {
    if (_accessToken == null || _accessTokenExp == null) return false;
    return DateTime.now().isBefore(_accessTokenExp!);
  }

  /// 앱 시작 시 저장된 refreshToken 복구
  Future<void> loadToken() async {
    // refreshToken은 secure_storage에서 로드 (자동 로그인용)
    // accessToken은 서버에서 새로 발급받아야 하므로 로드하지 않음
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken != null) {
      // refreshToken이 있으면 자동 로그인 시도 가능
    }
  }

  /// 로그인 성공 시 토큰 저장
  /// accessToken: 메모리, refreshToken: secure_storage, profile.userId: SharedPreferences
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    int? expiresIn, // 초 단위
    String? userId, // 프로필 저장용
  }) async {
    // accessToken을 메모리에 저장
    _accessToken = accessToken;
    
    // 만료 시간 계산 (expiresIn이 있으면 현재 시간 + expiresIn)
    if (expiresIn != null) {
      _accessTokenExp = DateTime.now().add(Duration(seconds: expiresIn));
    }
    
    // refreshToken을 secure_storage에 저장
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
    
    // userId를 프로필 저장소에 저장 (자동채움용, 옵션)
    if (userId != null) {
      await ProfileStorageService.I.saveUserId(userId);
    }
  }

  /// refreshToken 조회
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  /// 로그아웃 시 모든 토큰 삭제
  Future<void> clearTokens() async {
    _accessToken = null;
    _accessTokenExp = null;
    await _storage.delete(key: _keyRefreshToken);
    // profile.userId는 유지 (자동채움용이므로)
  }

  /// accessToken만 삭제 (refreshToken은 유지)
  void clearAccessToken() {
    _accessToken = null;
    _accessTokenExp = null;
  }

  /// Dio 요청에 Authorization 주입
  void attachAuthHeader(Options options) {
    if (_accessToken != null) {
      options.headers ??= {};
      options.headers!['Authorization'] = 'Bearer $_accessToken';
    }
  }
}