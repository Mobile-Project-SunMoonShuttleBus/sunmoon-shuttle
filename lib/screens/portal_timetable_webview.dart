import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:webview_flutter/webview_flutter.dart';

/// 포털 로그인 + 시간표 크롤링을 위한 WebView 화면
/// - Login.aspx 로 시작
/// - ID/PW를 받아서 자동 로그인
/// - MainQ.aspx 로 넘어가면 "로그인 성공"으로 판단하고 아이디/패스워드와 함께 반환
class PortalTimetableWebViewScreen extends StatefulWidget {
  final String? schoolId;
  final String? schoolPassword;

  const PortalTimetableWebViewScreen({
    super.key,
    this.schoolId,
    this.schoolPassword,
  });

  @override
  State<PortalTimetableWebViewScreen> createState() => _PortalTimetableWebViewScreenState();
}

class _PortalTimetableWebViewScreenState extends State<PortalTimetableWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasAutoLoggedIn = false;
  DateTime? _loginStartTime;
  static const _loginTimeout = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            // MainQ.aspx로 이동하는 것을 감지하면 즉시 WebView를 닫음
            if (url.contains('MainQ.aspx')) {
              Future.microtask(() {
                if (mounted) {
                  Navigator.of(context).pop({
                    'success': true,
                    'schoolId': widget.schoolId,
                    'schoolPassword': widget.schoolPassword,
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
              _startLoginTimeoutCheck();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print('❌ WebView 리소스 에러: ${error.description}');
            }
            
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
    // 보안상의 이유로 일부 사이트는 JavaScript 직접 입력을 막을 수 있으므로
    // 더 많은 이벤트를 발생시키고 여러 번 시도합니다
    final script = '''
      (function() {
        try {
          // ID 필드 찾기
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
          
          // 1단계: 필드에 포커스 주기
          idField.focus();
          pwField.focus();
          
          // 2단계: 값 설정 (여러 방법 시도)
          function setValue(field, value) {
            // 방법 1: 직접 value 설정
            field.value = value;
            
            // 방법 2: Object.defineProperty로 설정 (일부 사이트에서 필요)
            try {
              Object.defineProperty(field, 'value', {
                value: value,
                writable: true,
                configurable: true
              });
            } catch(e) {}
            
            // 방법 3: setAttribute 시도
            try {
              field.setAttribute('value', value);
            } catch(e) {}
          }
          
          setValue(idField, '$escapedId');
          setValue(pwField, '$escapedPw');
          
          // 3단계: 다양한 이벤트 발생 (보안 검증을 통과하기 위해)
          function triggerEvents(field) {
            var events = ['focus', 'mousedown', 'mouseup', 'click', 'input', 'keydown', 'keyup', 'keypress', 'change', 'blur'];
            events.forEach(function(eventType) {
              try {
                var event = new Event(eventType, { bubbles: true, cancelable: true });
                field.dispatchEvent(event);
              } catch(e) {}
            });
            
            // InputEvent도 별도로 발생
            try {
              var inputEvent = new InputEvent('input', { bubbles: true, cancelable: true });
              field.dispatchEvent(inputEvent);
            } catch(e) {}
          }
          
          triggerEvents(idField);
          triggerEvents(pwField);
          
          // 4단계: 값이 유지되는지 확인하고, 없으면 다시 설정
          setTimeout(function() {
            if (idField.value !== '$escapedId') {
              setValue(idField, '$escapedId');
              triggerEvents(idField);
            }
            if (pwField.value !== '$escapedPw') {
              setValue(pwField, '$escapedPw');
              triggerEvents(pwField);
            }
            
            // 5단계: 최종 확인 후 제출
            setTimeout(function() {
              // 마지막으로 한 번 더 확인
              if (idField.value !== '$escapedId') {
                idField.value = '$escapedId';
                idField.dispatchEvent(new Event('input', { bubbles: true }));
                idField.dispatchEvent(new Event('change', { bubbles: true }));
              }
              if (pwField.value !== '$escapedPw') {
                pwField.value = '$escapedPw';
                pwField.dispatchEvent(new Event('input', { bubbles: true }));
                pwField.dispatchEvent(new Event('change', { bubbles: true }));
              }
              
              // 제출
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
              }, 300);
            }, 500);
          }, 500);
        } catch (e) {
          console.error('자동 로그인 스크립트 에러:', e);
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 자동 로그인 스크립트 실행 실패: $e');
      }
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