// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart'; // AuthRepository는 lib/repositories에 있어야 합니다
import '../services/auth_service.dart';
import '../api/auth_api.dart'; 

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository.I;
  final AuthService _authService = AuthService.I;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();
    // [중요]: AuthRepository와 AuthService가 정상적으로 작동해야 합니다.
    try {
      final refreshToken = await _authService.getRefreshToken();
      if (refreshToken == null) return false;
      
      final response = await _authRepository.refreshToken(refreshToken);

      if (response.isSuccess) {
        await _authService.saveTokens(
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken,
        );
        _isAuthenticated = true;
        return true;
      }
    } catch (e) {
      await _authService.clearTokens();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    notifyListeners();
  }

  Future<void> logout() async {
    try { await AuthApi.I.logout(); } catch (e) {} 
    await _authService.clearTokens();
    _isAuthenticated = false;
    notifyListeners();
  }
}