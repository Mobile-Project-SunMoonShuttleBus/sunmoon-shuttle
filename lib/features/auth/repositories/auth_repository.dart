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
      // 네트워크 오류 또는 서버 응답 오류
      if (e.response != null) {
        // 서버에서 응답을 받았지만 오류 상태 코드
        final errorData = e.response?.data;
        if (errorData is Map) {
          final error = errorData['error']?.toString() ?? '';
          final message = errorData['message']?.toString() ?? '회원가입 실패';
          throw RegisterException(message: message, error: error);
        }
        throw RegisterException(
          message: '서버 오류가 발생했습니다. (${e.response?.statusCode})',
          error: 'SERVER_ERROR',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw RegisterException(
          message: '서버 연결 시간이 초과되었습니다.',
          error: 'TIMEOUT',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw RegisterException(
          message: '서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.',
          error: 'CONNECTION_ERROR',
        );
      } else {
        throw RegisterException(
          message: '네트워크 오류가 발생했습니다: ${e.message}',
          error: 'NETWORK_ERROR',
        );
      }
    } on ArgumentError catch (e) {
      throw RegisterException(message: e.message ?? '입력값이 유효하지 않습니다.', error: 'VALIDATION_ERROR');
    } catch (e) {
      if (e is RegisterException) rethrow;
      throw RegisterException(
        message: '회원가입 중 오류가 발생했습니다: ${e.toString()}',
        error: 'UNKNOWN_ERROR',
      );
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

  /// 학교 포털 계정 저장
  /// POST /api/auth/school-account
  /// 성공 시 { "message":"SAVED" } 반환, 실패 시 예외 발생
  Future<Map<String, dynamic>> saveSchoolAccount({
    required String schoolId,
    required String schoolPassword,
  }) async {
    try {
      final res = await AuthApi.I.saveSchoolAccount(
        schoolId: schoolId,
        schoolPassword: schoolPassword,
      );
      return res;
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData is Map) {
        final message = errorData['message']?.toString() ?? '포털 계정 저장 실패';
        throw SchoolAccountException(message: message);
      }
      throw SchoolAccountException(message: '포털 계정 저장 중 오류가 발생했습니다.');
    } catch (e) {
      if (e is SchoolAccountException) rethrow;
      throw SchoolAccountException(message: '포털 계정 저장 중 오류가 발생했습니다.');
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

class SchoolAccountException implements Exception {
  final String message;

  SchoolAccountException({required this.message});

  @override
  String toString() => message;
}

