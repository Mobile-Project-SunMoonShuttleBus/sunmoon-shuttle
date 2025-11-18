import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show HtmlElementView;
import 'package:webview_flutter/webview_flutter.dart';
import '../features/portal/services/portal_cookie_service.dart';

// 웹 전용 import
import 'dart:html' as html;
import 'dart:ui' as ui;

/// 포털 로그인 화면
/// WebView로 선문대학교 포털 로그인 페이지를 표시
class PortalLoginScreen extends StatefulWidget {
  const PortalLoginScreen({super.key});

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

class _PortalLoginScreenState extends State<PortalLoginScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _iframeViewId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeIframe();
    } else {
      _initializeWebView();
    }
  }

  void _initializeIframe() {
    // 웹에서는 iframe 사용
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
          ..src = 'https://lily.sunmoon.ac.kr/Page2/Etc/Login.aspx'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
    );
    setState(() {
      _isLoading = false;
    });
  }

  void _initializeWebView() {
    // 모바일/데스크톱에서는 WebView 사용
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
            
            // 로그인 성공 패턴 감지 (시간표 URL 또는 메인 페이지)
            final successPatterns = ['/UA/Course', '/CourseRegisterCal', '/timetable', '/TimeTable', '/Main.aspx', 'sws.sunmoon.ac.kr'];
            final isSuccess = successPatterns.any((pattern) => url.contains(pattern));
            
            if (isSuccess) {
              // 로그인 성공 시 쿠키 저장 상태 기록
              await PortalCookieService.I.markCookieSaved();
              
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
            final successPatterns = ['/UA/Course', '/CourseRegisterCal', '/timetable', '/TimeTable', '/Main.aspx', 'sws.sunmoon.ac.kr'];
            final isSuccess = successPatterns.any((pattern) => request.url.contains(pattern));
            if (isSuccess) {
              // 로그인 성공 시 쿠키 저장 상태 기록
              PortalCookieService.I.markCookieSaved();
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
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
      ..loadRequest(Uri.parse('https://lily.sunmoon.ac.kr/Page2/Etc/Login.aspx'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('선문대학교 포털 로그인'),
        backgroundColor: const Color(0xFF1890FF),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // 웹에서는 iframe, 모바일/데스크톱에서는 WebView
          if (kIsWeb && _iframeViewId != null)
            // ignore: undefined_prefixed_name
            HtmlElementView(viewType: _iframeViewId!)
          else if (!kIsWeb && _controller != null)
            WebViewWidget(controller: _controller!),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
