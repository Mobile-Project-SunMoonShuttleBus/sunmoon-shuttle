import 'package:dio/dio.dart';

// [경로 확인] lib/api 폴더의 AuthApi를 참조합니다.
import '../api/auth_api.dart'; 
// [경로 확인] lib/models 폴더의 LoginResponseModel을 참조합니다.
import '../models/login_response_model.dart'; 

class AuthRepository {
  AuthRepository._internal();
  static final AuthRepository I = AuthRepository._internal();

  /// 회원가입 처리
  Future<Map<String, dynamic>> register({
    required String userId,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final res = await AuthApi.I.register(
        userId: userId,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      return res;
    } on DioException catch (e) {
      if (e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map) {
          final message = errorData['message']?.toString() ?? '회원가입 실패';
          throw RegisterException(message: message);
        }
      }
      throw RegisterException(message: '회원가입 중 네트워크 오류가 발생했습니다.');
    } catch (e) {
      if (e is RegisterException) rethrow;
      throw RegisterException(message: '회원가입 중 알 수 없는 오류가 발생했습니다.');
    }
  }

  /// 로그인 처리
  Future<LoginResponseModel> login({
    required String userId,
    required String password,
  }) async {
    try {
      final res = await AuthApi.I.login(
        userId: userId,
        password: password,
      );
      return LoginResponseModel.fromMap(res);
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData is Map) {
        final message = errorData['message']?.toString() ?? '로그인 실패';
        throw LoginException(message: message);
      }
      throw LoginException(message: '로그인 중 오류가 발생했습니다.');
    } catch (e) {
      if (e is LoginException) rethrow;
      throw LoginException(message: '로그인 중 오류가 발생했습니다.');
    }
  }

  /// RefreshToken으로 새 AccessToken 발급
  Future<LoginResponseModel> refreshToken(String refreshToken) async {
    try {
      final res = await AuthApi.I.refreshToken(refreshToken);
      return LoginResponseModel.fromMap(res);
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData is Map) {
        final message = errorData['message']?.toString() ?? '토큰 갱신 실패';
        throw RefreshTokenException(message: message);
      }
      throw RefreshTokenException(message: '토큰 갱신 중 오류가 발생했습니다.');
    } catch (e) {
      if (e is RefreshTokenException) rethrow;
      throw RefreshTokenException(message: '토큰 갱신 중 오류가 발생했습니다.');
    }
  }
  
  /// 학교 포털 계정 저장
  Future<Map<String, dynamic>> saveSchoolAccount({
    required String schoolId,
    required String schoolPassword,
  }) async {
    return AuthApi.I.saveSchoolAccount(
      schoolId: schoolId,
      schoolPassword: schoolPassword,
    );
  }
}

// 커스텀 예외 클래스
class RegisterException implements Exception {
  final String message;
  RegisterException({required this.message});
  @override
  String toString() => message;
}

class LoginException implements Exception {
  final String message;
  LoginException({required this.message});
  @override
  String toString() => message;
}

class RefreshTokenException implements Exception {
  final String message;
  RefreshTokenException({required this.message});
  @override
  String toString() => message;
}