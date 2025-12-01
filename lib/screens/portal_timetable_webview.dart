import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PortalTimetableWebViewScreen extends StatefulWidget {
  const PortalTimetableWebViewScreen({super.key});

  @override
  State<PortalTimetableWebViewScreen> createState() => _PortalTimetableWebViewScreenState();
}

class _PortalTimetableWebViewScreenState extends State<PortalTimetableWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            // [핵심] 로그인 후 메인 페이지(MainQ)로 넘어가면 '성공'으로 간주
            if (url.contains('MainQ.aspx')) {
              if (mounted) Navigator.of(context).pop(true); // 성공 신호(true) 반환
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://sws.sunmoon.ac.kr/Login.aspx'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('포털 로그인')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}