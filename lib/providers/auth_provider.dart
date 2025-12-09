// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart' show ChangeNotifier, kDebugMode;
import 'package:dio/dio.dart';
import '../repositories/auth_repository.dart'; // AuthRepository는 lib/repositories에 있어야 합니다
import '../services/auth_service.dart';
import '../services/manual_congestion_monitor.dart';
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
    
    try {
      final refreshToken = await _authService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        if (kDebugMode) {
          print('🔐 자동 로그인: refreshToken이 없습니다.');
        }
        return false;
      }
      
      if (kDebugMode) {
        print('🔐 자동 로그인 시도: refreshToken으로 새 accessToken 요청');
      }
      
      final response = await _authRepository.refreshToken(refreshToken);

      if (response.isSuccess && response.accessToken != null) {
        await _authService.saveTokens(
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken,
          expiresIn: response.expiresIn, // 만료 시간 전달
        );
        _isAuthenticated = true;
        
        // 로그인 성공 시 수동 혼잡도 모니터링 시작
        ManualCongestionMonitor.I.startMonitoring();
        
        if (kDebugMode) {
          print('✅ 자동 로그인 성공');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ 자동 로그인 실패: 응답이 성공이 아닙니다. ${response.message}');
        }
        // 응답이 실패인 경우에만 토큰 삭제 (refreshToken이 만료되었을 수 있음)
        await _authService.clearTokens();
      }
    } on DioException catch (e) {
      // 네트워크 오류나 서버 오류인 경우
      if (kDebugMode) {
        print('❌ 자동 로그인 DioException: ${e.message}');
        print('  - 상태 코드: ${e.response?.statusCode}');
      }
      
      // 401 (Unauthorized) 또는 403 (Forbidden)인 경우에만 토큰 삭제
      // 네트워크 오류 등은 토큰을 유지
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        if (kDebugMode) {
          print('🔐 refreshToken이 만료되었거나 유효하지 않습니다. 토큰 삭제');
        }
        await _authService.clearTokens();
      } else {
        if (kDebugMode) {
          print('⚠️ 네트워크 오류로 인한 자동 로그인 실패. 토큰은 유지합니다.');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 자동 로그인 예외: $e');
        print('스택 트레이스: $stackTrace');
      }
      // 예상치 못한 오류는 토큰을 유지 (네트워크 문제일 수 있음)
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    if (value) {
      // 로그인 성공 시 수동 혼잡도 모니터링 시작
      ManualCongestionMonitor.I.startMonitoring();
    } else {
      // 로그아웃 시 모니터링 중지
      ManualCongestionMonitor.I.stopMonitoring();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try { await AuthApi.I.logout(); } catch (e) {} 
    await _authService.clearTokens();
    _isAuthenticated = false;
    // 로그아웃 시 모니터링 중지
    ManualCongestionMonitor.I.stopMonitoring();
    notifyListeners();
  }
}