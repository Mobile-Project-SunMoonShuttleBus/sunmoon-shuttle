/// 인증 상태 관리 Provider - 자동 로그인 처리
/// - 앱 시작 시 refreshToken으로 자동 재인증
/// - 인증 상태 관리 (로그인/로그아웃)
import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../models/login_response_model.dart';
import '../../../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository.I;
  final AuthService _authService = AuthService.I;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 앱 시작 시 자동 로그인 시도
  /// secure_storage의 refreshToken으로 새 accessToken 발급
  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // secure_storage에서 refreshToken 조회
      final refreshToken = await _authService.getRefreshToken();
      
      if (refreshToken == null) {
        // refreshToken이 없으면 자동 로그인 불가
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // refreshToken으로 새 accessToken 발급
      final response = await _authRepository.refreshToken(refreshToken);

      if (response.isSuccess && response.accessToken != null) {
        // 새 토큰 저장
        await _authService.saveTokens(
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken,
          expiresIn: response.expiresIn,
          userId: response.profile?.userId,
        );

        _isAuthenticated = true;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        // 토큰 갱신 실패
        await _authService.clearTokens();
        _isAuthenticated = false;
        _isLoading = false;
        _errorMessage = response.message;
        notifyListeners();
        return false;
      }
    } on RefreshTokenException catch (e) {
      // 토큰 갱신 실패 - 모든 토큰 삭제
      await _authService.clearTokens();
      _isAuthenticated = false;
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      // 예상치 못한 오류
      await _authService.clearTokens();
      _isAuthenticated = false;
      _isLoading = false;
      _errorMessage = '자동 로그인 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 로그인 성공 시 호출 (외부에서 호출)
  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    notifyListeners();
  }

  /// 로그아웃
  Future<void> logout() async {
    await _authService.clearTokens();
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// 에러 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

