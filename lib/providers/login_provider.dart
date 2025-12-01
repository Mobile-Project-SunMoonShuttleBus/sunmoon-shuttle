// lib/providers/login_provider.dart
import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';

class LoginProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository.I;
  final AuthService _authService = AuthService.I;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login({required String userId, required String password,}) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authRepository.login(userId: userId.trim(), password: password);

      if (response.isSuccess) {
        await _authService.saveTokens(
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken,
          userId: response.profile?.userId,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = '로그인 중 오류가 발생했습니다.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}