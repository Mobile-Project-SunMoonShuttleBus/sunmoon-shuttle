import 'package:dio/dio.dart';
import '../../../api/auth_api.dart';

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
}

class RegisterException implements Exception {
  final String message;
  final String? error;

  RegisterException({required this.message, this.error});

  @override
  String toString() => message;
}

