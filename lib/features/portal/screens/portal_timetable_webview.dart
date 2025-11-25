import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 포털 로그인 + 시간표 크롤링을 위한 WebView 화면
/// - Login.aspx 로 시작
/// - MainQ.aspx 로 넘어가면 "로그인 성공"으로 판단하고 Navigator.pop(true)
class PortalTimetableWebViewScreen extends StatefulWidget {
  const PortalTimetableWebViewScreen({super.key});

  @override
  State<PortalTimetableWebViewScreen> createState() =>
      _PortalTimetableWebViewScreenState();
}

class _PortalTimetableWebViewScreenState
    extends State<PortalTimetableWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });

            // 🔥 이 URL로 넘어가면 로그인 성공으로 간주
            if (url.contains('MainQ.aspx')) {
              // 이 화면을 닫고, true 를 반환 (로그인 성공 신호)
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://sws.sunmoon.ac.kr/Login.aspx'),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포털 로그인'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
