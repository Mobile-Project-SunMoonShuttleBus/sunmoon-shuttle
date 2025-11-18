import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show HtmlElementView;
import 'package:webview_flutter/webview_flutter.dart';
import '../services/portal_cookie_service.dart';

// 웹 전용 import - 조건부 import 사용
import 'dart:html' as html;
import 'dart:ui' as ui;

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
  static const String _portalLoginUrl = 'https://lily.sunmoon.ac.kr/Page2/Etc/Login.aspx';
  // 로그인 성공 패턴 (URL에 /UA/Course, /timetable, /TimeTable 등이 포함되면 로그인 성공)
  static const List<String> _successPatterns = ['/UA/Course', '/CourseRegisterCal', '/timetable', '/TimeTable', '/Main.aspx', '/Page2', 'sws.sunmoon.ac.kr'];
  // 시간표 페이지 패턴 (이 패턴이 감지되면 시간표 페이지로 이동 완료)
  static const List<String> _timetablePatterns = ['/CourseRegisterCal', '/UA/Course', '/TimeTable', '/timetable'];
  
  bool _isLoggedIn = false; // 로그인 성공 여부

  @override
  void initState() {
    super.initState();
    _checkCookieAndNavigate();
  }

  /// 쿠키 확인 후 분기
  Future<void> _checkCookieAndNavigate() async {
    setState(() {
      _isCheckingCookie = true;
      _isLoading = true;
    });

    try {
      final hasCookie = await PortalCookieService.I.hasValidCookie();
      
      if (hasCookie) {
        // 쿠키가 있으면 시간표 페이지로 직접 이동 (자동 로그인됨)
        if (kIsWeb) {
          _initializeIframe(_portalTimetableUrl);
        } else {
          _initializeWebView(_portalTimetableUrl);
        }
      } else {
        // 쿠키가 없으면 로그인 페이지로 이동
        if (kIsWeb) {
          _initializeIframe(_portalLoginUrl);
        } else {
          _initializeWebView(_portalLoginUrl);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '쿠키 확인 중 오류가 발생했습니다: $e';
        _isCheckingCookie = false;
        _isLoading = false;
      });
    }
  }

  void _initializeIframe(String url) {
    if (!kIsWeb) return;
    
    _iframeViewId = 'portal-iframe-${DateTime.now().millisecondsSinceEpoch}';
    // ignore: avoid_web_libraries_in_flutter, undefined_prefixed_name
    final window = ui.window as dynamic;
    final platformViewRegistry = window.platformViewRegistry;
    platformViewRegistry.registerViewFactory(
      _iframeViewId!,
      (int viewId) {
        // ignore: avoid_web_libraries_in_flutter
        final iframe = html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
    );
    setState(() {
      _isCheckingCookie = false;
      _isLoading = false;
    });
  }

  void _initializeWebView(String initialUrl) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });
            
            // 로그인 성공 패턴 감지
            final isSuccess = _successPatterns.any((pattern) => url.contains(pattern));
            final isTimetablePage = _timetablePatterns.any((pattern) => url.contains(pattern));
            
            if (isSuccess && !_isLoggedIn) {
              // 로그인 성공 시 쿠키 저장 상태 기록
              await PortalCookieService.I.markCookieSaved();
              _isLoggedIn = true;
              
              // 시간표 페이지가 아니면 시간표 페이지로 이동
              if (!isTimetablePage && _controller != null) {
                // 로그인 성공 후 시간표 페이지로 자동 이동
                await Future.delayed(const Duration(milliseconds: 500));
                if (mounted && _controller != null) {
                  await _controller!.loadRequest(Uri.parse(_portalTimetableUrl));
                }
              }
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('포털 로그인 성공'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // 로그인 성공 패턴 감지 (리다이렉트 시)
            final isSuccess = _successPatterns.any((pattern) => request.url.contains(pattern));
            final isTimetablePage = _timetablePatterns.any((pattern) => request.url.contains(pattern));
            
            if (isSuccess && !_isLoggedIn) {
              // 로그인 성공 시 쿠키 저장 상태 기록
              PortalCookieService.I.markCookieSaved();
              _isLoggedIn = true;
              
              // 시간표 페이지가 아니면 시간표 페이지로 이동
              if (!isTimetablePage) {
                // 로그인 성공 후 시간표 페이지로 자동 이동
                Future.microtask(() async {
                  if (mounted && _controller != null) {
                    await _controller!.loadRequest(Uri.parse(_portalTimetableUrl));
                  }
                });
                return NavigationDecision.prevent; // 원래 네비게이션 차단하고 시간표로 이동
              }
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _errorMessage = '페이지 로드 오류: ${error.description}';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('페이지 로드 오류: ${error.description}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));
    
    setState(() {
      _isCheckingCookie = false;
    });
  }

  /// 포털 세션 새로고침 (재로그인)
  Future<void> _refreshSession() async {
    setState(() {
      _isLoggedIn = false;
    });
    await PortalCookieService.I.clearCookieStatus();
    await _checkCookieAndNavigate();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포털 세션을 새로고침합니다. 다시 로그인해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('선문대학교 포털'),
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
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('학기 시간표'),
        backgroundColor: const Color(0xFF1890FF),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // 포털 세션 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSession,
            tooltip: '포털 세션 새로고침',
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
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('로딩 중...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

