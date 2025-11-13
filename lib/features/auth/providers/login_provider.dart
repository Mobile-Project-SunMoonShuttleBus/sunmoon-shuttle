/// 로그인 상태 관리 Provider
/// - 로그인 요청 처리 및 상태 관리
/// - 로그인 성공 시 토큰 및 프로필 저장
/// - 에러 메시지 관리
import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../models/login_response_model.dart';
import '../../../services/auth_service.dart';

class LoginProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository.I;
  final AuthService _authService = AuthService.I;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 로그인 실행
  /// 성공 시 true 반환, 실패 시 false 반환
  Future<bool> login({
    required String userId,
    required String password,
  }) async {
    if (_isLoading) return false; // 중복 클릭 방지

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authRepository.login(
        userId: userId.trim(),
        password: password,
      );

      if (response.isSuccess) {
        // 로그인 성공 시 토큰 및 프로필 저장
        await _authService.saveTokens(
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken,
          expiresIn: response.expiresIn,
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
    } on LoginException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '로그인 중 오류가 발생했습니다.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 에러 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

