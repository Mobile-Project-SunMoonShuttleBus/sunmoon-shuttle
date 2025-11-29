import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:webview_flutter/webview_flutter.dart';

/// 포털 로그인 + 시간표 크롤링을 위한 WebView 화면
/// - Login.aspx 로 시작
/// - ID/PW를 받아서 자동 로그인
/// - MainQ.aspx 로 넘어가면 "로그인 성공"으로 판단하고 Navigator.pop(true)
class PortalTimetableWebViewScreen extends StatefulWidget {
  final String? schoolId;
  final String? schoolPassword;

  const PortalTimetableWebViewScreen({
    super.key,
    this.schoolId,
    this.schoolPassword,
  });

  @override
  State<PortalTimetableWebViewScreen> createState() =>
      _PortalTimetableWebViewScreenState();
}

class _PortalTimetableWebViewScreenState
    extends State<PortalTimetableWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasAutoLoggedIn = false;
  DateTime? _loginStartTime;
  static const _loginTimeout = Duration(seconds: 60); // 30초 → 60초로 증가

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (kDebugMode) {
              print('🌐 WebView 페이지 시작: $url');
            }
            
            // 🔥 MainQ.aspx로 이동하는 것을 감지하면 즉시 WebView를 닫음
            // 페이지가 로드되기 전에 닫아서 사용자가 메인 페이지를 보지 않도록 함
            if (url.contains('MainQ.aspx')) {
              if (kDebugMode) {
                print('✅ 로그인 성공: MainQ.aspx 감지 - 즉시 WebView 닫기');
              }
              // 페이지 로드 전에 바로 닫기
              Future.microtask(() {
                if (mounted) {
                  Navigator.of(context).pop({
                    'success': true,
                  });
                }
              });
              return;
            }
            
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) async {
            if (kDebugMode) {
              print('✅ WebView 페이지 로드 완료: $url');
            }
            
            // MainQ.aspx는 이미 onPageStarted에서 처리했으므로 여기서는 무시
            if (url.contains('MainQ.aspx')) {
              return;
            }
            
            setState(() {
              _isLoading = false;
            });

            // 로그인 페이지가 로드되었고, ID/PW가 제공되었으며, 아직 자동 로그인을 하지 않은 경우
            if (url.contains('Login.aspx') && 
                widget.schoolId != null && 
                widget.schoolPassword != null &&
                !_hasAutoLoggedIn) {
              _hasAutoLoggedIn = true;
              _loginStartTime = DateTime.now();
              await _autoLogin();
              // 타임아웃 체크 시작
              _startLoginTimeoutCheck();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print('❌ WebView 리소스 에러: ${error.description}');
              print('   URL: ${error.url}');
              print('   에러 코드: ${error.errorCode}');
            }
            
            // 심각한 에러인 경우 사용자에게 알림
            if (error.errorCode == WebResourceErrorType.hostLookup.index ||
                error.errorCode == WebResourceErrorType.timeout.index) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('네트워크 연결에 실패했습니다. 다시 시도해주세요.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            }
          },
          onHttpError: (HttpResponseError error) {
            if (kDebugMode) {
              print('❌ WebView HTTP 에러: ${error.response?.statusCode}');
              print('   URL: ${error.response?.uri}');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (kDebugMode) {
              print('🧭 WebView 네비게이션 요청: ${request.url}');
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://sws.sunmoon.ac.kr/Login.aspx'),
      );
  }

  /// 로그인 타임아웃 체크
  void _startLoginTimeoutCheck() {
    Future.delayed(_loginTimeout, () {
      if (mounted && _loginStartTime != null) {
        final elapsed = DateTime.now().difference(_loginStartTime!);
        if (elapsed >= _loginTimeout) {
          if (kDebugMode) {
            print('⏰ 로그인 타임아웃: ${_loginTimeout.inSeconds}초 경과');
          }
          // 타임아웃 시 사용자에게 알림
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인이 시간 초과되었습니다. 수동으로 로그인해주세요.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    });
  }

  /// WebView에서 자동 로그인 수행
  Future<void> _autoLogin() async {
    if (widget.schoolId == null || widget.schoolPassword == null) {
      if (kDebugMode) {
        print('⚠️ 자동 로그인 실패: ID 또는 비밀번호가 없습니다.');
      }
      return;
    }

    if (kDebugMode) {
      print('🔐 자동 로그인 시도 시작...');
    }

    // JavaScript 문자열 이스케이프 처리
    String escapeJs(String str) {
      return str
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
    }

    final escapedId = escapeJs(widget.schoolId!);
    final escapedPw = escapeJs(widget.schoolPassword!);

    // JavaScript로 폼 필드에 값 입력 및 제출
    // JavaScript 에러를 무시하도록 try-catch 추가
    final script = '''
      (function() {
        try {
          // ID 필드 찾기 (일반적으로 name이나 id가 'txtID', 'userId', 'id' 등)
          var idField = document.querySelector('input[name="txtID"]') || 
                        document.querySelector('input[id*="ID"]') || 
                        document.querySelector('input[id*="id"]') ||
                        document.querySelector('input[type="text"]');
          
          // 비밀번호 필드 찾기
          var pwField = document.querySelector('input[name="txtPW"]') || 
                        document.querySelector('input[name="txtPassword"]') ||
                        document.querySelector('input[type="password"]');
          
          // 로그인 버튼 찾기
          var loginButton = document.querySelector('input[type="submit"]') || 
                            document.querySelector('button[type="submit"]') ||
                            document.querySelector('button.btn-login') ||
                            document.querySelector('a.btn-login');
          
          if (!idField || !pwField) {
            console.error('로그인 폼 필드를 찾을 수 없습니다.');
            return;
          }
          
          idField.value = '$escapedId';
          pwField.value = '$escapedPw';
          
          // 입력 이벤트 발생 (일부 사이트에서 필요)
          idField.dispatchEvent(new Event('input', { bubbles: true }));
          idField.dispatchEvent(new Event('change', { bubbles: true }));
          pwField.dispatchEvent(new Event('input', { bubbles: true }));
          pwField.dispatchEvent(new Event('change', { bubbles: true }));
          
          // 약간의 지연 후 제출 (페이지가 완전히 로드되도록)
          setTimeout(function() {
            try {
              if (loginButton) {
                loginButton.click();
              } else if (idField.form) {
                idField.form.submit();
              } else {
                console.error('로그인 버튼을 찾을 수 없습니다.');
              }
            } catch (e) {
              console.error('로그인 제출 중 에러:', e);
            }
          }, 800);
        } catch (e) {
          console.error('자동 로그인 스크립트 에러:', e);
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
      if (kDebugMode) {
        print('✅ 자동 로그인 스크립트 실행 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 자동 로그인 스크립트 실행 실패: $e');
      }
      // JavaScript 실행 실패 시 사용자가 수동으로 로그인할 수 있도록 함
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('자동 로그인에 실패했습니다. 수동으로 로그인해주세요.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
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
