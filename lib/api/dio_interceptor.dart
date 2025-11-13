/// Dio 인터셉터 - 401 에러 처리 및 토큰 자동 갱신
/// - 모든 요청에 accessToken 자동 추가
/// - 401 에러 발생 시 refreshToken으로 자동 갱신
/// - 갱신 중 동시 요청 대기 큐 처리
import 'dart:async';
import 'package:dio/dio.dart';
import '../services/auth_service.dart';

class AuthInterceptor extends Interceptor {
  final AuthService _authService = AuthService.I;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 모든 요청에 accessToken 자동 추가
    final token = _authService.token;
    if (token != null) {
      options.headers ??= {};
      options.headers!['Authorization'] = 'Bearer $token';
    }
    
    // 요청 데이터에서 null 값 제거 (Dio가 null을 직렬화하지 못함)
    if (options.data != null && options.data is Map) {
      final data = options.data as Map;
      final cleanedData = <String, dynamic>{};
      data.forEach((key, value) {
        if (value != null) {
          cleanedData[key.toString()] = value;
        }
      });
      options.data = cleanedData;
    }
    
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 401 Unauthorized 에러 처리
    if (err.response?.statusCode == 401) {
      // refreshToken으로 새 accessToken 발급 시도
      final refreshToken = await _authService.getRefreshToken();
      
      if (refreshToken == null) {
        // refreshToken이 없으면 로그인 화면으로 이동
        _authService.clearTokens();
        handler.reject(err);
        return;
      }

      // 이미 갱신 중이면 대기
      if (_isRefreshing) {
        // 대기 큐에 추가
        final completer = Completer<Response>();
        _pendingRequests.add(_PendingRequest(
          options: err.requestOptions,
          completer: completer,
        ));
        handler.resolve(await completer.future);
        return;
      }

      _isRefreshing = true;

      try {
        // refreshToken으로 새 accessToken 발급
        // 요구사항: POST /api/auth/token/refresh
        final dio = Dio(BaseOptions(
          baseUrl: err.requestOptions.baseUrl,
        ));
        final response = await dio.post(
          '/api/auth/token/refresh',
          data: {'refreshToken': refreshToken},
        );

        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['accessToken'] as String?;
        final newRefreshToken = data['refreshToken'] as String?; // 새 refreshToken도 받을 수 있음
        final expiresIn = data['expiresIn'] as int?;

        if (newAccessToken != null) {
          // 새 토큰 저장 (refreshToken도 갱신될 수 있음)
          await _authService.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? refreshToken, // 새 refreshToken이 없으면 기존 것 유지
            expiresIn: expiresIn,
          );

          // 원래 요청 재시도
          final opts = err.requestOptions;
          opts.headers ??= {};
          opts.headers!['Authorization'] = 'Bearer $newAccessToken';
          
          final retryResponse = await dio.fetch(opts);
          
          // 대기 중인 요청들도 처리
          for (var pending in _pendingRequests) {
            pending.options.headers ??= {};
            pending.options.headers!['Authorization'] = 'Bearer $newAccessToken';
            try {
              final pendingResponse = await dio.fetch(pending.options);
              pending.completer.complete(pendingResponse);
            } catch (e) {
              pending.completer.completeError(e);
            }
          }
          _pendingRequests.clear();
          
          handler.resolve(retryResponse);
        } else {
          // 토큰 갱신 실패 - 로그인 화면으로 이동
          await _authService.clearTokens();
          handler.reject(err);
        }
      } catch (e) {
        // 토큰 갱신 실패 - 로그인 화면으로 이동
        await _authService.clearTokens();
        handler.reject(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}

/// 대기 중인 요청 정보
class _PendingRequest {
  final RequestOptions options;
  final Completer<Response> completer;

  _PendingRequest({
    required this.options,
    required this.completer,
  });
}

