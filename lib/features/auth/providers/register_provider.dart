import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../services/profile_storage_service.dart';

class RegisterProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository.I;
  final ProfileStorageService _profileStorage = ProfileStorageService.I;

  bool _isLoading = false;
  String? _errorMessage;
  String? _errorCode;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;

  // 실시간 유효성 검사 상태
  String? _userIdError;
  String? _passwordError;
  String? _passwordConfirmError;

  String? get userIdError => _userIdError;
  String? get passwordError => _passwordError;
  String? get passwordConfirmError => _passwordConfirmError;

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

  /// 전체 폼 유효성 검사
  bool isFormValid(String userId, String password, String passwordConfirm) {
    if (userId.isEmpty || password.isEmpty || passwordConfirm.isEmpty) {
      return false;
    }
    if (_userIdError != null || _passwordError != null || _passwordConfirmError != null) {
      return false;
    }
    if (password != passwordConfirm) {
      return false;
    }
    return true;
  }

  /// 회원가입 실행
  Future<bool> register({
    required String userId,
    required String password,
    required String passwordConfirm,
  }) async {
    if (_isLoading) return false; // 중복 클릭 방지

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final result = await _authRepository.register(
        userId: userId.trim(),
        password: password,
        passwordConfirm: passwordConfirm,
      );

      final message = result['message']?.toString().toUpperCase() ?? '';
      final success = result['success'] == true || message.contains('REGISTER');

      if (success) {
        await _profileStorage.saveUserId(userId.trim());
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = result['message']?.toString() ?? '회원가입 실패';
      _errorCode = result['error']?.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    } on RegisterException catch (e) {
      _errorMessage = e.message;
      _errorCode = e.error;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // 예상치 못한 오류
      _errorMessage = '회원가입 중 오류가 발생했습니다: ${e.toString()}';
      _errorCode = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 에러 초기화
  void clearError() {
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
  }

  /// 모든 검증 에러 초기화
  void clearValidationErrors() {
    _userIdError = null;
    _passwordError = null;
    _passwordConfirmError = null;
    notifyListeners();
  }
}

