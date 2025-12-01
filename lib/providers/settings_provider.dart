// lib/providers/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _keyLanguage = 'settings.lang';
  
  // 기본값: 한국어
  String _language = 'ko'; 

  bool get isKorean => _language == 'ko';
  String get language => _language;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString(_keyLanguage) ?? 'ko';
    notifyListeners();
  }

  Future<void> setLanguage(bool isKorean) async {
    final newLang = isKorean ? 'ko' : 'en';
    if (_language == newLang) return;

    _language = newLang;
    notifyListeners(); // 앱 전체에 변경 알림

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, _language);
  }
}