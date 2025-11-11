import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  AuthService._internal();
  static final AuthService I = AuthService._internal();

  final _storage = const FlutterSecureStorage();
  String? _accessToken;

  String? get token => _accessToken;

  Future<void> loadToken() async {
    _accessToken = await _storage.read(key: 'accessToken');
  }

  Future<void> setToken(String? t) async {
    _accessToken = t;
    if (t == null) {
      await _storage.delete(key: 'accessToken');
    } else {
      await _storage.write(key: 'accessToken', value: t);
    }
  }

  /// Dio 요청에 Authorization 주입
  void attachAuthHeader(Options options) {
    if (_accessToken != null) {
      options.headers ??= {};
      options.headers!['Authorization'] = 'Bearer $_accessToken';
    }
  }
}
