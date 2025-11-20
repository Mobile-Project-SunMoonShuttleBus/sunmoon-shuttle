import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/widgets.dart' show HtmlElementView;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../services/portal_cookie_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../features/settings/providers/settings_provider.dart';

// 웹 전용 import - 조건부 import 사용
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

/// 포털 시간표 WebView 화면
/// 쿠키 확인 후 유효하면 시간표로, 없으면 로그인 페이지로 이동
class PortalTimetableWebView extends StatefulWidget {
  const PortalTimetableWebView({super.key});

  @override
  State<PortalTimetableWebView> createState() => _PortalTimetableWebViewState();
}

class _PortalTimetableWebViewState extends State<PortalTimetableWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isCheckingCookie = true;
  String? _iframeViewId;
  String? _errorMessage;

  // 포털 시간표 URL (쿠키가 있으면 이 URL로 직접 이동)
  static const String _portalTimetableUrl = 'https://sws.sunmoon.ac.kr/UA/Course/CourseRegisterCal.aspx';
  // 포털 로그인 URL
  static const String _portalLoginUrl = 'https://sws.sunmoon.ac.kr/Login.aspx';
  // 로그인 성공 패턴 (URL에 /UA/Course, /timetable, /TimeTable 등이 포함되면 로그인 성공)
  // 성공 패턴 기반 완료판정(HTML 의존 최소화)
  static const List<String> _successPatterns = [
    '/UA/Course',
    '/CourseRegisterCal',
    '/timetable',
    '/TimeTable',
    '/Main.aspx',
    'sws.sunmoon.ac.kr',
  ];
  // 시간표 페이지 패턴 (이 패턴이 감지되면 시간표 페이지로 이동 완료)
  // 성공 URL 패턴(/timetable) 감지 → 쿠키 스냅샷 저장
  static const List<String> _timetablePatterns = [
    '/CourseRegisterCal',
    '/UA/Course',
    '/TimeTable',
    '/timetable',
  ];
  
  /// 현재 날짜 기준으로 학기 계산
  /// 1~7월: 1학기, 8~12월: 2학기
  String get _currentSemester {
    final now = DateTime.now();
    final month = now.month;
    return month >= 1 && month <= 7 ? '1' : '2';
  }
  
  /// 현재 년도
  String get _currentYear {
    return DateTime.now().year.toString();
  }
  
  bool _isLoggedIn = false; // 로그인 성공 여부
  html.IFrameElement? _iframeElement; // 웹 환경에서 iframe 요소 참조
  bool _showExpiredBanner = false; // 쿠키 만료 배너 표시 여부
  Timer? _cookieCheckTimer; // 쿠키 만료 체크 타이머

  @override
  void initState() {
    super.initState();
    _checkCookieAndNavigate();
    _startCookieExpiryCheck();
  }

  @override
  void dispose() {
    _cookieCheckTimer?.cancel();
    super.dispose();
  }

  /// 쿠키 만료 주기적 체크
  void _startCookieExpiryCheck() {
    // 1분마다 쿠키 만료 여부 확인
    _cookieCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final isExpired = await PortalCookieService.I.isCookieExpired();
      if (isExpired && _isLoggedIn) {
        // 쿠키 만료 감지
        if (mounted) {
          setState(() {
            _showExpiredBanner = true;
            _isLoggedIn = false;
          });
          
          // 자동 재로그인 유도
          _handleCookieExpired();
        }
      }
    });
  }

  /// 쿠키 만료 시 처리
  Future<void> _handleCookieExpired() async {
    // 쿠키 상태 초기화
    await PortalCookieService.I.clearCookieStatus(
      webViewController: _controller,
    );
    
    // 로그인 페이지로 이동
    if (mounted) {
      if (kIsWeb && _iframeElement != null) {
        // ignore: avoid_web_libraries_in_flutter
        _iframeElement!.src = _portalLoginUrl;
      } else if (!kIsWeb && _controller != null) {
        await _controller!.loadRequest(Uri.parse(_portalLoginUrl));
      }
    }
  }

  /// 쿠키 확인 후 분기
  /// 핵심: 유효 쿠키가 있으면 시간표 URL로 직행, 없으면 로그인 페이지로 이동
  Future<void> _checkCookieAndNavigate() async {
    setState(() {
      _isCheckingCookie = true;
      _isLoading = true;
    });

    try {
      // 1단계: SharedPreferences 플래그만 먼저 확인 (빠른 체크)
      final prefs = await PortalCookieService.I.prefs;
      final cookieSaved = prefs.getBool('portal.cookieSaved') ?? false;
      final lastLoginStr = prefs.getString('portal.lastLogin');
      
      bool shouldTryTimetable = false;
      
      if (cookieSaved && lastLoginStr != null) {
        final lastLogin = DateTime.tryParse(lastLoginStr);
        if (lastLogin != null) {
          final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
          // 30일 이내면 시간표 페이지로 시도
          if (daysSinceLogin < 30) {
            shouldTryTimetable = true;
          }
        }
      }
      
      if (shouldTryTimetable) {
        // 플래그가 있으면 시간표 URL로 직행 시도 (WebView 쿠키는 로드 후 확인)
        if (kIsWeb) {
          _initializeIframe(_portalTimetableUrl);
        } else {
          _initializeWebView(_portalTimetableUrl);
        }
        // 실제 쿠키 확인은 페이지 로드 후 수행
      } else {
        // 플래그가 없거나 만료된 경우 로그인 페이지로 이동
        if (kIsWeb) {
          _initializeIframe(_portalLoginUrl);
        } else {
          _initializeWebView(_portalLoginUrl);
        }
        _isLoggedIn = false;
      }
    } catch (e) {
      if (mounted) {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final l10n = AppLocalizations(settingsProvider.isKorean);
        setState(() {
          _errorMessage = '${l10n.cookieCheckError}: $e';
          _isCheckingCookie = false;
          _isLoading = false;
        });
      }
    }
  }

  void _initializeIframe(String url) {
    if (!kIsWeb) return;
    
    // Flutter 웹에서 iframe 초기화를 지연시켜 엔진이 완전히 로드되도록 함
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      try {
        _iframeViewId = 'portal-iframe-${DateTime.now().millisecondsSinceEpoch}';
        
        // Flutter 웹에서 platformViewRegistry 접근 방법
        // ignore: avoid_web_libraries_in_flutter
        final window = html.window as dynamic;
        
        // platformViewRegistry 찾기 - 여러 방법 시도
        dynamic platformViewRegistry;
        
        // 방법 1: window.flutter_internal_platform_views
        try {
          platformViewRegistry = window.flutter_internal_platform_views;
        } catch (_) {}
        
        // 방법 2: window.platformViewRegistry
        if (platformViewRegistry == null) {
          try {
            platformViewRegistry = window.platformViewRegistry;
          } catch (_) {}
        }
        
        // 방법 3: ui.window.platformViewRegistry
        if (platformViewRegistry == null) {
          try {
            // ignore: avoid_web_libraries_in_flutter, undefined_prefixed_name
            final uiWindow = ui.window as dynamic;
            platformViewRegistry = uiWindow.platformViewRegistry;
          } catch (_) {}
        }
        
        if (platformViewRegistry == null) {
          // platformViewRegistry를 찾을 수 없으면 외부 브라우저로 열기
          _openInExternalBrowser(url);
          return;
        }
        
        // registerViewFactory 호출
        // ignore: avoid_web_libraries_in_flutter
        platformViewRegistry.registerViewFactory(
          _iframeViewId!,
          (int viewId) {
            // ignore: avoid_web_libraries_in_flutter
            final iframe = html.IFrameElement()
              ..src = url
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%'
              ..allowFullscreen = true
              ..allow = 'camera; microphone; geolocation';
            
            // iframe 요소 참조 저장 (나중에 src 변경용)
            _iframeElement = iframe;
            
            // iframe 로드 완료 이벤트
            iframe.onLoad.listen((event) async {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                
                // 시간표 페이지로 이동했는데 로그인 페이지로 리다이렉트된 경우 = 쿠키 만료
                if (url.contains('sws.sunmoon.ac.kr/Login.aspx')) {
                  // 시간표 페이지로 이동 시도했는데 로그인 페이지로 온 경우
                  if (_isCheckingCookie) {
                    // 쿠키가 없거나 만료된 경우 상태 초기화
                    await PortalCookieService.I.clearCookieStatus();
                    _isLoggedIn = false;
                    
                    if (mounted) {
                      setState(() {
                        _isCheckingCookie = false;
                        _showExpiredBanner = true;
                      });
                    }
                  } else if (!_isLoggedIn) {
                    // 로그인 페이지가 로드된 경우, 주기적으로 시간표 페이지로 이동 시도
                    _startLoginDetection(iframe);
                  }
                } else if (url.contains('sws.sunmoon.ac.kr') && (url.contains('/CourseRegisterCal') || url.contains('/UA/Course'))) {
                  // 시간표 페이지 패턴 감지 → 쿠키 스냅샷 저장
                  if (!_isLoggedIn) {
                    _isLoggedIn = true;
                    await PortalCookieService.I.markCookieSaved();
                    
                    if (mounted) {
                      setState(() {
                        _isCheckingCookie = false;
                        _showExpiredBanner = false; // 만료 배너 숨김
                      });
                    }
                  }
                  
                  // 시간표 페이지 폼 자동 채우기
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    _autoFillTimetableFormForIframe(iframe);
                  });
                }
              }
            });
            
            // iframe 로드 오류 이벤트
            iframe.onError.listen((event) {
              if (mounted) {
                final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                final l10n = AppLocalizations(settingsProvider.isKorean);
                setState(() {
                  _errorMessage = l10n.pageLoadError;
                  _isLoading = false;
                });
              }
            });
            
            return iframe;
          },
        );
        
        if (mounted) {
          setState(() {
            _isCheckingCookie = false;
            _isLoading = true; // iframe이 로드될 때까지 로딩 표시
          });
        }
      } catch (e) {
        // 오류 발생 시 외부 브라우저로 열기
        _openInExternalBrowser(url);
      }
    });
  }


  /// 로그인 성공 감지를 위한 주기적 체크
  /// 성공 패턴 기반 완료판정(HTML 의존 최소화)
  void _startLoginDetection(html.IFrameElement iframe) {
    Timer? detectionTimer;
    Timer? timeoutTimer;

    // 3초마다 iframe의 src를 확인하여 시간표 페이지로 이동했는지 체크
    detectionTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _isLoggedIn) {
        timer.cancel();
        timeoutTimer?.cancel();
        return;
      }
      
      try {
        // ignore: avoid_web_libraries_in_flutter
        final currentSrc = iframe.src;
        
        // 성공 URL 패턴(/timetable) 감지 → 쿠키 스냅샷 저장
        if (currentSrc != null) {
          final isSuccess = _successPatterns.any((pattern) => currentSrc.contains(pattern));
          final isTimetablePage = _timetablePatterns.any((pattern) => currentSrc.contains(pattern));
          
          if (isSuccess && !_isLoggedIn) {
            // 로그인 성공 및 시간표 페이지 도달 → 쿠키 스냅샷 저장
            _isLoggedIn = true;
            await PortalCookieService.I.markCookieSaved();
            timer.cancel();
            timeoutTimer?.cancel();
            
            if (mounted) {
              setState(() {
                _showExpiredBanner = false; // 만료 배너 숨김
              });
              
              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
              final l10n = AppLocalizations(settingsProvider.isKorean);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.portalLoginSuccess),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              
              // 시간표 페이지가 아니면 시간표 페이지로 이동
              if (!isTimetablePage && _iframeElement != null) {
                // ignore: avoid_web_libraries_in_flutter
                _iframeElement!.src = _portalTimetableUrl;
              }
            }
          }
        }
      } catch (e) {
        // CORS 제한으로 인한 오류는 무시
        if (kDebugMode) {
          print('iframe src 접근 오류 (정상일 수 있음): $e');
        }
      }
    });
    
    // 30초 후 타임아웃
    timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!_isLoggedIn && mounted) {
        if (kDebugMode) {
          print('로그인 감지 타임아웃. 시간표 페이지로 강제 이동.');
        }
        detectionTimer?.cancel();
        timeoutTimer?.cancel();
        
        // 타임아웃 후 시간표 페이지로 강제 이동
        if (_iframeElement != null) {
          // ignore: avoid_web_libraries_in_flutter
          _iframeElement!.src = _portalTimetableUrl;
        }
      }
    });
  }

  /// 시간표 페이지 폼 자동 채우기 (년도, 학기, 수강신청 선택)
  Future<void> _autoFillTimetableForm() async {
    if (_controller == null || !mounted) return;
    
    try {
      // JavaScript를 실행하여 폼 자동 채우기
      final year = _currentYear;
      final semester = _currentSemester;
      
      // JavaScript 코드: 년도, 학기, 수강신청 드롭다운 자동 선택
      // 실제 포털 페이지 구조에 맞춘 선택자 사용
      final jsCode = '''
        (function() {
          try {
            // 년도 선택 - 여러 패턴 시도
            var yearSelect = document.querySelector('select[name*="year"], select[id*="year"], select[name*="Year"], select[id*="Year"], select[name*="학년도"], select[id*="학년도"]');
            if (!yearSelect) {
              // 모든 select 요소를 확인하여 '년도' 라벨이 있는 것 찾기
              var selects = document.querySelectorAll('select');
              for (var i = 0; i < selects.length; i++) {
                var select = selects[i];
                var label = select.previousElementSibling;
                if (label && (label.textContent.includes('년도') || label.textContent.includes('Year'))) {
                  yearSelect = select;
                  break;
                }
              }
            }
            if (yearSelect) {
              yearSelect.value = '$year';
              yearSelect.dispatchEvent(new Event('change', { bubbles: true }));
            }
            
            // 학기 선택 (1학기 또는 2학기)
            var semesterSelect = document.querySelector('select[name*="semester"], select[id*="semester"], select[name*="Semester"], select[id*="Semester"], select[name*="학기"], select[id*="학기"]');
            if (!semesterSelect) {
              // 모든 select 요소를 확인하여 '학기' 라벨이 있는 것 찾기
              var selects = document.querySelectorAll('select');
              for (var i = 0; i < selects.length; i++) {
                var select = selects[i];
                var label = select.previousElementSibling;
                if (label && (label.textContent.includes('학기') || label.textContent.includes('Semester'))) {
                  semesterSelect = select;
                  break;
                }
              }
            }
            if (semesterSelect) {
              var targetValue = '$semester';
              var targetText = '$semester학기';
              var found = false;
              
              for (var i = 0; i < semesterSelect.options.length; i++) {
                var option = semesterSelect.options[i];
                if (option.value === targetValue || 
                    option.value === targetText ||
                    option.text.includes(targetText) ||
                    option.text.trim() === targetText ||
                    (option.text.includes('$semester') && option.text.includes('학기'))) {
                  semesterSelect.value = option.value;
                  found = true;
                  break;
                }
              }
              
              if (found) {
                semesterSelect.dispatchEvent(new Event('change', { bubbles: true }));
              }
            }
            
            // 수강신청 드롭다운 선택 - '장바구니/수강신청' 드롭다운
            var registrationSelect = document.querySelector('select[name*="registration"], select[id*="registration"], select[name*="Registration"], select[id*="Registration"], select[name*="수강신청"], select[id*="수강신청"], select[name*="장바구니"], select[id*="장바구니"]');
            if (!registrationSelect) {
              // 모든 select 요소를 확인하여 '장바구니' 또는 '수강신청' 라벨이 있는 것 찾기
              var selects = document.querySelectorAll('select');
              for (var i = 0; i < selects.length; i++) {
                var select = selects[i];
                var label = select.previousElementSibling;
                if (label && (label.textContent.includes('장바구니') || label.textContent.includes('수강신청'))) {
                  registrationSelect = select;
                  break;
                }
              }
            }
            if (registrationSelect) {
              // '수강신청' 텍스트를 포함하는 옵션 찾기 (장바구니 제외)
              for (var i = 0; i < registrationSelect.options.length; i++) {
                var option = registrationSelect.options[i];
                var optionText = option.text.trim();
                if ((optionText.includes('수강신청') || optionText === '수강신청') && 
                    !optionText.includes('장바구니') && 
                    optionText !== '장바구니/수강신청') {
                  registrationSelect.value = option.value;
                  registrationSelect.dispatchEvent(new Event('change', { bubbles: true }));
                  break;
                }
              }
            }
          } catch (e) {
            console.log('자동 채우기 오류: ' + e);
          }
        })();
      ''';
      
      // WebView에서 JavaScript 실행
      await _controller!.runJavaScript(jsCode);
      
      // iframe의 경우 (웹 환경)
      if (kIsWeb && _iframeElement != null) {
        // ignore: avoid_web_libraries_in_flutter
        final iframeWindow = _iframeElement!.contentWindow;
        if (iframeWindow != null) {
          try {
            // ignore: avoid_web_libraries_in_flutter
            (iframeWindow as dynamic).eval(jsCode);
          } catch (e) {
            // CORS 제한으로 인한 오류는 무시
            if (mounted) {
              print('iframe JavaScript 실행 오류 (정상일 수 있음): $e');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        print('폼 자동 채우기 오류: $e');
      }
    }
  }

  /// iframe에서 시간표 페이지 폼 자동 채우기
  void _autoFillTimetableFormForIframe(html.IFrameElement iframe) {
    try {
      // ignore: avoid_web_libraries_in_flutter
      final iframeWindow = iframe.contentWindow;
      if (iframeWindow == null) return;
      
      final year = _currentYear;
      final semester = _currentSemester;
      
      final jsCode = '''
        (function() {
          try {
            // 년도 선택 - 여러 패턴 시도
            var yearSelect = document.querySelector('select[name*="year"], select[id*="year"], select[name*="Year"], select[id*="Year"], select[name*="학년도"], select[id*="학년도"]');
            if (!yearSelect) {
              var selects = document.querySelectorAll('select');
              for (var i = 0; i < selects.length; i++) {
                var select = selects[i];
                var label = select.previousElementSibling;
                if (label && (label.textContent.includes('년도') || label.textContent.includes('Year'))) {
                  yearSelect = select;
                  break;
                }
              }
            }
            if (yearSelect) {
              yearSelect.value = '$year';
              yearSelect.dispatchEvent(new Event('change', { bubbles: true }));
            }
            
            // 학기 선택
            var semesterSelect = document.querySelector('select[name*="semester"], select[id*="semester"], select[name*="Semester"], select[id*="Semester"], select[name*="학기"], select[id*="학기"]');
            if (!semesterSelect) {
              var selects = document.querySelectorAll('select');
              for (var i = 0; i < selects.length; i++) {
                var select = selects[i];
                var label = select.previousElementSibling;
                if (label && (label.textContent.includes('학기') || label.textContent.includes('Semester'))) {
                  semesterSelect = select;
                  break;
                }
              }
            }
            if (semesterSelect) {
              var targetValue = '$semester';
              var targetText = '$semester학기';
              for (var i = 0; i < semesterSelect.options.length; i++) {
                var option = semesterSelect.options[i];
                if (option.value === targetValue || 
                    option.value === targetText ||
                    option.text.includes(targetText) ||
                    option.text.trim() === targetText ||
                    (option.text.includes('$semester') && option.text.includes('학기'))) {
                  semesterSelect.value = option.value;
                  semesterSelect.dispatchEvent(new Event('change', { bubbles: true }));
                  break;
                }
              }
            }
            
            // 수강신청 드롭다운 선택
            var registrationSelect = document.querySelector('select[name*="registration"], select[id*="registration"], select[name*="Registration"], select[id*="Registration"], select[name*="수강신청"], select[id*="수강신청"], select[name*="장바구니"], select[id*="장바구니"]');
            if (!registrationSelect) {
              var selects = document.querySelectorAll('select');
              for (var i = 0; i < selects.length; i++) {
                var select = selects[i];
                var label = select.previousElementSibling;
                if (label && (label.textContent.includes('장바구니') || label.textContent.includes('수강신청'))) {
                  registrationSelect = select;
                  break;
                }
              }
            }
            if (registrationSelect) {
              for (var i = 0; i < registrationSelect.options.length; i++) {
                var option = registrationSelect.options[i];
                var optionText = option.text.trim();
                if ((optionText.includes('수강신청') || optionText === '수강신청') && 
                    !optionText.includes('장바구니') && 
                    optionText !== '장바구니/수강신청') {
                  registrationSelect.value = option.value;
                  registrationSelect.dispatchEvent(new Event('change', { bubbles: true }));
                  break;
                }
              }
            }
          } catch (e) {
            console.log('자동 채우기 오류: ' + e);
          }
        })();
      ''';
      
      // ignore: avoid_web_libraries_in_flutter
      (iframeWindow as dynamic).eval(jsCode);
    } catch (e) {
      // CORS 제한으로 인한 오류는 무시
      if (mounted) {
        print('iframe 폼 자동 채우기 오류 (정상일 수 있음): $e');
      }
    }
  }

  /// 시간표 페이지로 이동
  /// 성공 URL 패턴(/timetable) 감지 → 쿠키 스냅샷 저장
  Future<void> _navigateToTimetable() async {
    if (!mounted) return;
    
    if (kIsWeb && _iframeElement != null) {
      // 웹 환경: iframe의 src 변경
      try {
        // ignore: avoid_web_libraries_in_flutter
        _iframeElement!.src = _portalTimetableUrl;
        _isLoggedIn = true;
        await PortalCookieService.I.markCookieSaved();
        
        if (mounted) {
          setState(() {
            _showExpiredBanner = false; // 만료 배너 숨김
          });
        }
        
        // 시간표 페이지 로드 후 폼 자동 채우기
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _iframeElement != null) {
            _autoFillTimetableFormForIframe(_iframeElement!);
          }
        });
        
        if (mounted) {
          final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
          final l10n = AppLocalizations(settingsProvider.isKorean);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.portalLoginSuccess),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          print('iframe src 변경 오류: $e');
        }
      }
    } else if (!kIsWeb && _controller != null) {
      // 모바일/데스크톱 환경: WebView 컨트롤러로 이동
      await _controller!.loadRequest(Uri.parse(_portalTimetableUrl));
      
      // 성공 패턴 감지 시 쿠키 저장은 onPageFinished에서 처리
      // 여기서는 로그인 상태만 업데이트
      _isLoggedIn = true;
      
      if (mounted) {
        setState(() {
          _showExpiredBanner = false; // 만료 배너 숨김
        });
      }
      
      // 시간표 페이지 로드 후 폼 자동 채우기
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _controller != null) {
          _autoFillTimetableForm();
        }
      });
    }
  }

  /// 외부 브라우저로 포털 열기
  Future<void> _openInExternalBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
          final l10n = AppLocalizations(settingsProvider.isKorean);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.portalOpenedInBrowser),
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final l10n = AppLocalizations(settingsProvider.isKorean);
        setState(() {
          _errorMessage = '${l10n.pageLoadError}: $e';
          _isCheckingCookie = false;
          _isLoading = false;
        });
      }
    }
  }

  void _initializeWebView(String initialUrl) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null; // 새 페이지 로드 시 에러 초기화
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isCheckingCookie = false; // 쿠키 확인 완료
              });
            }
            
            // 로그인 페이지로 리다이렉트되었는지 확인 (쿠키가 없어서 로그인 페이지로 돌아온 경우)
            final isLoginPage = url.contains('/Login.aspx') || url.contains('Login');
            
            // 시간표 페이지로 이동했는데 로그인 페이지로 리다이렉트된 경우 = 쿠키 만료
            if (isLoginPage && _isCheckingCookie) {
              // 쿠키가 없거나 만료된 경우 상태 초기화
              await PortalCookieService.I.clearCookieStatus();
              _isLoggedIn = false;
              
              if (mounted) {
                setState(() {
                  _showExpiredBanner = true;
                });
              }
              return; // 로그인 페이지에 머무름
            }
            
            // 로그인 성공 패턴 감지
            final isSuccess = _successPatterns.any((pattern) => url.contains(pattern));
            final isTimetablePage = _timetablePatterns.any((pattern) => url.contains(pattern));
            
            if (isSuccess && !_isLoggedIn) {
              // 성공 URL 패턴 감지 → 쿠키 스냅샷 저장
              await PortalCookieService.I.markCookieSaved(
                webViewController: _controller,
              );
              _isLoggedIn = true;
              
              if (mounted) {
                setState(() {
                  _showExpiredBanner = false; // 만료 배너 숨김
                });
              }
              
              // 시간표 페이지가 아니면 시간표 페이지로 자동 이동
              if (!isTimetablePage && _controller != null && mounted) {
                // 로그인 성공 후 시간표 페이지로 자동 이동
                await Future.delayed(const Duration(milliseconds: 800));
                if (mounted && _controller != null) {
                  try {
                    await _controller!.loadRequest(Uri.parse(_portalTimetableUrl));
                    
                    if (mounted) {
                      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                      final l10n = AppLocalizations(settingsProvider.isKorean);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.portalLoginSuccess),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                      final l10n = AppLocalizations(settingsProvider.isKorean);
                      setState(() {
                        _errorMessage = '${l10n.pageLoadError}: $e';
                      });
                    }
                  }
                }
              } else if (isTimetablePage) {
                // 시간표 페이지 로드 완료 시 자동으로 년도/학기/수강신청 선택
                await _autoFillTimetableForm();
                
                // 이미 시간표 페이지인 경우
                if (mounted) {
                  final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                  final l10n = AppLocalizations(settingsProvider.isKorean);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.portalLoginSuccess),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            } else if (isTimetablePage && _controller != null) {
              // 시간표 페이지가 직접 로드된 경우 = 쿠키가 유효함
              // 로그인 상태 업데이트 및 쿠키 저장 상태 갱신
              if (!_isLoggedIn) {
                await PortalCookieService.I.markCookieSaved(
                  webViewController: _controller,
                );
                _isLoggedIn = true;
                
                if (mounted) {
                  setState(() {
                    _showExpiredBanner = false;
                  });
                }
              }
              
              // 시간표 페이지가 직접 로드된 경우에도 자동 선택
              await _autoFillTimetableForm();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // CORS 및 보안을 위한 도메인 체크
            final allowedDomains = ['lily.sunmoon.ac.kr', 'sws.sunmoon.ac.kr', 'sunmoon.ac.kr'];
            final uri = Uri.tryParse(request.url);
            
            if (uri != null) {
              final host = uri.host;
              final isAllowed = allowedDomains.any((domain) => host.contains(domain));
              
              if (!isAllowed && !request.url.startsWith('data:') && !request.url.startsWith('javascript:')) {
                // 허용되지 않은 도메인으로의 네비게이션 차단
                return NavigationDecision.prevent;
              }
            }
            
            // 로그인 성공 패턴 감지 (리다이렉트 시)
            final isSuccess = _successPatterns.any((pattern) => request.url.contains(pattern));
            final isTimetablePage = _timetablePatterns.any((pattern) => request.url.contains(pattern));
            
            if (isSuccess && !_isLoggedIn) {
              // 성공 URL 패턴 감지 → 쿠키 스냅샷 저장
              PortalCookieService.I.markCookieSaved(
                webViewController: _controller,
              );
              _isLoggedIn = true;
              
              if (mounted) {
                setState(() {
                  _showExpiredBanner = false; // 만료 배너 숨김
                });
              }
              
              // 시간표 페이지가 아니면 시간표 페이지로 자동 이동
              if (!isTimetablePage && mounted) {
                // 로그인 성공 후 시간표 페이지로 자동 이동
                Future.microtask(() async {
                  if (mounted && _controller != null) {
                    try {
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (mounted && _controller != null) {
                        await _controller!.loadRequest(Uri.parse(_portalTimetableUrl));
                        
                        if (mounted) {
                          final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                          final l10n = AppLocalizations(settingsProvider.isKorean);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.portalLoginSuccess),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                        final l10n = AppLocalizations(settingsProvider.isKorean);
                        setState(() {
                          _errorMessage = '${l10n.pageLoadError}: $e';
                        });
                      }
                    }
                  }
                });
                return NavigationDecision.prevent; // 원래 네비게이션 차단하고 시간표로 이동
              } else if (isTimetablePage) {
                // 이미 시간표 페이지로 이동하는 경우
                if (mounted) {
                  final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                  final l10n = AppLocalizations(settingsProvider.isKorean);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.portalLoginSuccess),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
              final l10n = AppLocalizations(settingsProvider.isKorean);
              
              // 네트워크 오류는 무시 (일시적일 수 있음)
              if (error.errorCode == -2 || error.errorCode == -6) {
                // 네트워크 오류 코드: -2 (INTERNET_DISCONNECTED), -6 (HOST_LOOKUP)
                return;
              }
              
              setState(() {
                _errorMessage = '${l10n.pageLoadError}: ${error.description} (코드: ${error.errorCode})';
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${l10n.pageLoadError}: ${error.description}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          onHttpError: (HttpResponseError error) {
            // HTTP 오류는 로그만 남기고 계속 진행
            if (mounted) {
              print('HTTP 오류: ${error.response?.statusCode} - ${error.response?.uri}');
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse(initialUrl),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      );
    
    if (mounted) {
      setState(() {
        _isCheckingCookie = false;
      });
    }
  }

  /// 포털 세션 새로고침 (재로그인)
  /// 만료/삭제 시 자동 재로그인 유도
  Future<void> _refreshSession() async {
    setState(() {
      _isLoggedIn = false;
      _showExpiredBanner = false; // 배너 숨김
    });
    
    // 쿠키 상태 초기화
    await PortalCookieService.I.clearCookieStatus(
      webViewController: _controller,
    );
    
    // 로그인 페이지로 이동
    await _checkCookieAndNavigate();
    
    if (mounted) {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final l10n = AppLocalizations(settingsProvider.isKorean);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.portalSessionRefresh),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final l10n = AppLocalizations(settingsProvider.isKorean);
        
        if (_errorMessage != null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.portalTitle),
              backgroundColor: const Color(0xFF1890FF),
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                      _checkCookieAndNavigate();
                    },
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.timetableTitle),
            backgroundColor: const Color(0xFF1890FF),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              // 포털 세션 새로고침 버튼 (필요 시 "포털 세션 새로고침" 버튼 제공)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshSession,
                tooltip: l10n.refreshSession,
              ),
            ],
          ),
          body: Stack(
            children: [
              // 웹에서는 iframe, 모바일/데스크톱에서는 WebView
              if (kIsWeb && _iframeViewId != null)
                // ignore: undefined_prefixed_name
                HtmlElementView(viewType: _iframeViewId!)
              else if (!kIsWeb && _controller != null)
                WebViewWidget(controller: _controller!),
              if (_isLoading || _isCheckingCookie)
                Container(
                  color: Colors.white,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(l10n.loading),
                      ],
                    ),
                  ),
                ),
              // 쿠키 만료 배너 (UX 배너와 함께 즉시 재로그인 라우팅)
              if (_showExpiredBanner)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.orange.shade700,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.portalCookieExpired,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _refreshSession,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text(
                            l10n.refreshSession,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

