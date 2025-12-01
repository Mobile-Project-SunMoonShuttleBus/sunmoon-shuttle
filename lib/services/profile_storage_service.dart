import 'package:shared_preferences/shared_preferences.dart';

class ProfileStorageService {
  ProfileStorageService._internal();
  static final ProfileStorageService I = ProfileStorageService._internal();

  static const String _keyUserId = 'profile.userId';

  /// userId 저장 (자동채움용 프로필)
  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }

  /// 저장된 userId 조회
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// userId 삭제
  Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
  }
}