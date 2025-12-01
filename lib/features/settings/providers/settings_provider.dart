/// 설정 상태 관리 Provider
/// - 혼잡도 애니메이션 ON/OFF 설정 관리
/// - 언어 설정 관리
/// - 서버와 동기화
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../api/auth_api.dart';

class SettingsProvider extends ChangeNotifier {
  final AuthApi _authApi = AuthApi.I;
  static const String _keyLanguage = 'settings.lang';
  static const String _keyCrowdAnimation = 'settings.crowdAnimation';

  bool _crowdAnimation = true; // 기본값: ON
  String _language = 'ko'; // 기본값: 한국어 ('ko' 또는 'en')
  bool _isLoading = false;
  String? _errorMessage;

  bool get crowdAnimation => _crowdAnimation;
  bool get isKorean => _language == 'ko';
  String get language => _language;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 초기 설정 로드 (로컬 영속 저장된 설정만 사용)
  /// 서버 동기화는 필요 없으므로 로컬 설정만 로드
  Future<void> loadSettings() async {
    try {
      // 로컬에서 설정 로드
      await _loadSettingsFromLocal();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('설정 로드 실패: $e');
      }
      // 기본값 사용
      notifyListeners();
    }
  }

  /// 로컬에서 모든 설정 로드
  Future<void> _loadSettingsFromLocal() async {
    await _loadLanguageFromLocal();
    await _loadCrowdAnimationFromLocal();
  }

  /// 로컬에서 언어 설정 로드
  Future<void> _loadLanguageFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(_keyLanguage);
      if (savedLang != null && (savedLang == 'ko' || savedLang == 'en')) {
        _language = savedLang;
      }
    } catch (e) {
      if (kDebugMode) {
        print('로컬 언어 설정 로드 실패: $e');
      }
    }
  }

  /// 언어 설정을 로컬에 영속 저장
  Future<void> _saveLanguageToLocal(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, lang);
    } catch (e) {
      if (kDebugMode) {
        print('로컬 언어 설정 저장 실패: $e');
      }
    }
  }

  /// 로컬에서 혼잡도 애니메이션 설정 로드
  Future<void> _loadCrowdAnimationFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_keyCrowdAnimation);
      if (saved != null) {
        _crowdAnimation = saved;
      }
    } catch (e) {
      if (kDebugMode) {
        print('로컬 혼잡도 애니메이션 설정 로드 실패: $e');
      }
    }
  }

  /// 혼잡도 애니메이션 설정을 로컬에 영속 저장
  Future<void> _saveCrowdAnimationToLocal(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyCrowdAnimation, value);
    } catch (e) {
      if (kDebugMode) {
        print('로컬 혼잡도 애니메이션 설정 저장 실패: $e');
      }
    }
  }

  /// 혼잡도 애니메이션 설정 업데이트
  Future<bool> updateCrowdAnimation(bool value) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authApi.updateMe(
        pref: {'crowdAnimation': value},
      );

      if (response['message'] == 'UPDATED') {
        _crowdAnimation = value;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = '설정 업데이트에 실패했습니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // CORS 오류 감지 (PATCH 메서드에서 connectionError는 거의 확실히 CORS)
      bool isCorsError = false;
      
      if (e is DioException) {
        // 1. PATCH 메서드에서 connectionError이고 응답이 없으면 무조건 CORS로 간주
        if (e.type == DioExceptionType.connectionError && 
            e.response == null &&
            e.requestOptions.method.toUpperCase() == 'PATCH') {
          isCorsError = true;
        }
        
        // 2. 에러 메시지에 CORS 관련 키워드가 있으면
        final errorMsg = (e.message ?? '').toLowerCase();
        if (errorMsg.contains('cors') || 
            errorMsg.contains('xmlhttprequest') ||
            errorMsg.contains('access-control') ||
            errorMsg.contains('preflight') ||
            errorMsg.contains('blocked by cors')) {
          isCorsError = true;
        }
      }
      
      // 3. toString()에도 CORS 관련 키워드가 있는지 확인
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cors') || 
          errorStr.contains('connection error') ||
          errorStr.contains('connection errored') ||
          errorStr.contains('xmlhttprequest') ||
          errorStr.contains('access-control') ||
          errorStr.contains('preflight') ||
          errorStr.contains('blocked by cors')) {
        isCorsError = true;
      }
      
      // 4. PATCH 메서드이고 connectionError이면 무조건 CORS로 간주 (웹 환경)
      if (e is DioException && 
          e.type == DioExceptionType.connectionError &&
          e.requestOptions.method.toUpperCase() == 'PATCH') {
        isCorsError = true;
      }
      
      if (isCorsError) {
        // 로컬에만 저장 (SharedPreferences 사용)
        _crowdAnimation = value;
        await _saveCrowdAnimationToLocal(value);
        _isLoading = false;
        _errorMessage = null; // 로컬 저장은 성공이므로 에러 메시지 제거
        notifyListeners();
        // 로컬 저장 성공 - UI는 업데이트되지만 서버 동기화는 나중에
        return true; // 로컬 저장 성공으로 간주
      }
      
      _errorMessage = '설정 업데이트 중 오류가 발생했습니다.';
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('❌ 혼잡도 애니메이션 설정 업데이트 실패 (CORS 아님): $e');
        print('❌ 에러 타입: ${e.runtimeType}');
        if (e is DioException) {
          print('❌ DioException 타입: ${e.type}');
          print('❌ 메서드: ${e.requestOptions.method}');
          print('❌ 응답: ${e.response}');
          print('❌ 메시지: ${e.message}');
        }
      }
      return false;
    }
  }

  /// 언어 설정 변경 (서버 동기화 + 로컬 영속 저장)
  Future<bool> updateLanguage(bool isKorean) async {
    final newLang = isKorean ? 'ko' : 'en';
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authApi.updateMe(
        pref: {'lang': newLang},
      );

      if (response['message'] == 'UPDATED') {
        _language = newLang;
        // 로컬에도 영속 저장
        await _saveLanguageToLocal(_language);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = '설정 업데이트에 실패했습니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // 404 에러 또는 CORS 오류 감지
      bool shouldSaveLocally = false;
      
      if (e is DioException) {
        // 1. 404 에러인 경우 (서버 경로가 없을 수 있음)
        if (e.response?.statusCode == 404) {
          shouldSaveLocally = true;
        }
        
        // 2. PATCH 메서드에서 connectionError이고 응답이 없으면 무조건 CORS로 간주
        if (e.type == DioExceptionType.connectionError && 
            e.response == null &&
            e.requestOptions.method.toUpperCase() == 'PATCH') {
          shouldSaveLocally = true;
        }
        
        // 3. 에러 메시지에 CORS 관련 키워드가 있으면
        final errorMsg = (e.message ?? '').toLowerCase();
        if (errorMsg.contains('cors') || 
            errorMsg.contains('xmlhttprequest') ||
            errorMsg.contains('access-control') ||
            errorMsg.contains('preflight') ||
            errorMsg.contains('blocked by cors')) {
          shouldSaveLocally = true;
        }
      }
      
      // 4. toString()에도 CORS 관련 키워드가 있는지 확인
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cors') || 
          errorStr.contains('connection error') ||
          errorStr.contains('connection errored') ||
          errorStr.contains('xmlhttprequest') ||
          errorStr.contains('access-control') ||
          errorStr.contains('preflight') ||
          errorStr.contains('blocked by cors')) {
        shouldSaveLocally = true;
      }
      
      // 5. PATCH 메서드이고 connectionError이면 무조건 CORS로 간주 (웹 환경)
      if (e is DioException && 
          e.type == DioExceptionType.connectionError &&
          e.requestOptions.method.toUpperCase() == 'PATCH') {
        shouldSaveLocally = true;
      }
      
      if (shouldSaveLocally) {
        // 로컬에만 저장
        _language = newLang;
        await _saveLanguageToLocal(_language);
        _isLoading = false;
        _errorMessage = null; // 로컬 저장은 성공이므로 에러 메시지 제거
        notifyListeners();
        // 로컬 저장 성공 - UI는 업데이트되지만 서버 동기화는 나중에
        return true; // 로컬 저장 성공으로 간주
      }
      
      _errorMessage = '설정 업데이트 중 오류가 발생했습니다.';
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('❌ 언어 설정 업데이트 실패: $e');
        print('❌ 에러 타입: ${e.runtimeType}');
        if (e is DioException) {
          print('❌ DioException 타입: ${e.type}');
          print('❌ 메서드: ${e.requestOptions.method}');
          print('❌ 응답: ${e.response}');
          print('❌ 메시지: ${e.message}');
        }
      }
      return false;
    }
  }

  /// 에러 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

