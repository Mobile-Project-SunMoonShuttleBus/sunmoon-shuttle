/// 인증 레포지토리 - 회원가입 및 로그인 API 호출 처리
/// AuthApi를 래핑하여 비즈니스 로직과 예외 처리 담당
import 'package:dio/dio.dart';
import '../../../api/auth_api.dart';
import '../models/login_response_model.dart';

class AuthRepository {
  AuthRepository._internal();
  static final AuthRepository I = AuthRepository._internal();

  /// 회원가입
  /// 성공 시 userId 반환, 실패 시 예외 발생
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
      final errorData = e.response?.data;
      if (errorData is Map) {
        final error = errorData['error']?.toString() ?? '';
        final message = errorData['message']?.toString() ?? '회원가입 실패';
        throw RegisterException(message: message, error: error);
      }
      throw RegisterException(message: '회원가입 중 오류가 발생했습니다.');
    } catch (e) {
      if (e is RegisterException) rethrow;
      throw RegisterException(message: '회원가입 중 오류가 발생했습니다.');
    }
  }

  /// 로그인
  /// 성공 시 LoginResponseModel 반환, 실패 시 예외 발생
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
  /// 성공 시 LoginResponseModel 반환, 실패 시 예외 발생
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
}

class RegisterException implements Exception {
  final String message;
  final String? error;

  RegisterException({required this.message, this.error});

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

