// lib/providers/register_provider.dart (최종 완성 버전)

import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';

class RegisterProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository.I;

  bool _isLoading = false;
  String? _errorMessage;
  
  // --- 실시간 유효성 검사 상태 (Getter와 내부 변수) ---
  String? _userIdError;
  String? _passwordError;
  String? _passwordConfirmError;

  // ✅ [필수] Screen에서 참조하는 모든 Getter
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  String? get userIdError => _userIdError;
  String? get passwordError => _passwordError;
  String? get passwordConfirmError => _passwordConfirmError;
  // --------------------------------------------------

  /// userId 실시간 검증
  void validateUserId(String userId) {
    if (userId.isEmpty) {
      _userIdError = null;
    } else if (userId.length < 4 || userId.length > 20) {
      _userIdError = '아이디는 4자 이상 20자 이하여야 합니다.';
    } else if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(userId)) {
      _userIdError = '아이디는 영문/숫자만 사용할 수 있습니다.';
    } else {
      _userIdError = null;
    }
    notifyListeners();
  }

  /// password 실시간 검증
  void validatePassword(String password) {
    if (password.isEmpty) {
      _passwordError = null;
    } else if (password.length < 6) {
      _passwordError = '비밀번호는 6자 이상이어야 합니다.';
    } else {
      _passwordError = null;
    }
    notifyListeners();
  }

  /// passwordConfirm 실시간 검증
  void validatePasswordConfirm(String password, String passwordConfirm) {
    if (passwordConfirm.isEmpty) {
      _passwordConfirmError = null;
    } else if (password != passwordConfirm) {
      _passwordConfirmError = '비밀번호가 일치하지 않습니다.';
    } else {
      _passwordConfirmError = null;
    }
    notifyListeners();
  }

  /// ✅ [필수] 회원가입 실행 (register 메서드)
  Future<bool> register({
    required String userId,
    required String password,
    required String passwordConfirm,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authRepository.register(
        userId: userId.trim(),
        password: password,
        passwordConfirm: passwordConfirm,
      );

      if (result['message'] == 'REGISTER_SUCCESS' || result['success'] == true) { 
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = result['message']?.toString() ?? '회원가입 실패';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // Custom Exception 처리
      _errorMessage = e.toString().contains('RegisterException') 
          ? e.toString().replaceFirst('Exception: ', '')
          : '회원가입 중 오류가 발생했습니다.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}