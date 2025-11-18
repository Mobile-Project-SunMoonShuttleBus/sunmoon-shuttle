/// 로그인 다이얼로그 화면
/// - 앱 시작 시 자동 표시
/// - 저장된 userId 자동 채움 기능
/// - 로그인 성공 시 JWT 토큰 저장
/// - 회원가입 화면으로 이동 가능
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/validators.dart';
import '../screens/register_dialog.dart';
import '../features/auth/providers/login_provider.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/services/profile_storage_service.dart';

class LoginDialog extends StatefulWidget {
  final BuildContext? rootContext;
  
  const LoginDialog({super.key, this.rootContext});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  // 입력 필드 컨트롤러 - 아이디와 비밀번호 입력값을 관리
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 저장된 userId를 자동으로 채움 (자동채움 기능)
    _loadSavedUserId();
  }

  /// 저장된 userId를 불러와서 입력 필드에 자동 채움
  Future<void> _loadSavedUserId() async {
    final savedUserId = await ProfileStorageService.I.getUserId();
    if (savedUserId != null && mounted) {
      _idCtrl.text = savedUserId;
    }
  }

  // 로그인 버튼 비활성화 여부를 판단하는 getter
  // 아이디/비밀번호가 유효하지 않거나 로그인 처리 중일 때 버튼을 비활성화
  bool _isFormValid() {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (!Validators.isValidUserId(id)) return false; // 아이디 형식 검증 실패
    if (!Validators.isValidPassword(pw)) return false; // 비밀번호 형식 검증 실패
    return true;
  }

  // 로그인 요청 처리 메서드
  // LoginProvider와 BuildContext를 파라미터로 받아서 사용
  Future<void> _submit(BuildContext context, LoginProvider loginProvider) async {
    if (!_isFormValid()) return;

    if (loginProvider.isLoading) return; // 중복 클릭 방지

    final success = await loginProvider.login(
      userId: _idCtrl.text.trim(),
      password: _pwCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      // 로그인 성공 - AuthProvider 인증 상태 업데이트
      // 원래 위젯 트리의 context를 사용하여 AuthProvider에 접근
      final rootCtx = widget.rootContext ?? context;
      if (rootCtx.mounted) {
        try {
          final authProvider = rootCtx.read<AuthProvider>();
          authProvider.setAuthenticated(true);
        } catch (e) {
          // AuthProvider를 찾을 수 없는 경우, context를 통해 접근 시도
          if (context.mounted) {
            final authProvider = context.read<AuthProvider>();
            authProvider.setAuthenticated(true);
          }
        }
      }
      // 다이얼로그를 닫고 true 반환
      Navigator.of(context).pop(true);
    } else {
      // 로그인 실패 - 에러 메시지는 provider에서 관리하므로 여기서는 스낵바로 표시
      final errorMsg = loginProvider.errorMessage ?? '로그인 실패';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 회원가입 다이얼로그를 여는 메서드
  Future<void> _openRegister() async {
    final result = await showDialog(
      context: context,
      builder: (_) => const RegisterDialog(),
    );
    // 회원가입이 성공적으로 완료되면(result == true) 로그인 다이얼로그도 닫음
    // 회원가입 후 자동으로 로그인된 상태로 전환하기 위함
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dialog는 새로운 위젯 트리를 만들기 때문에, LoginProvider를 내부에서 제공해야 함
    return ChangeNotifierProvider(
      create: (_) => LoginProvider(),
      builder: (context, child) {
        // builder를 사용하여 Provider의 context를 명확히 전달
        return Dialog(
          backgroundColor: Colors.transparent, // 배경을 투명하게 설정하여 Container의 회색 배경이 보이도록 함
          insetPadding: const EdgeInsets.symmetric(horizontal: 24), // 좌우 여백 설정
          child: Container(
        // 회색 배경의 둥근 모서리 컨테이너로 모달 디자인 구현
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 내용에 맞게 최소 크기로 설정
          children: [
            // 우측 상단 X 버튼 - 다이얼로그 닫기
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF1890FF)),
                  onPressed: () => Navigator.of(context).pop(false), // false 반환하여 로그인 취소를 알림
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 아이디 입력 필드 - 왼쪽에 라벨, 오른쪽에 입력 필드
            _labeledInput(
              _idCtrl,
              '아이디',
              obscure: false,
              onChanged: (_) => setState(() {}), // 입력값 변경 시 UI 업데이트
            ),
            const SizedBox(height: 16),
            // 비밀번호 입력 필드 - 입력값이 보이지 않도록 obscure: true 설정
            _labeledInput(
              _pwCtrl,
              '비밀번호',
              obscure: true,
              onChanged: (_) => setState(() {}), // 입력값 변경 시 UI 업데이트
            ),
            // 에러 메시지가 있을 때만 표시 (provider에서 관리)
            Consumer<LoginProvider>(
              builder: (context, provider, _) {
                if (provider.errorMessage != null) {
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 20),
            // 로그인 버튼 (파란색) - 메인 액션 버튼
            Consumer<LoginProvider>(
              builder: (context, provider, _) {
                return _primaryButton(
                  text: provider.isLoading ? '처리 중...' : '로그인',
                  disabled: !_isFormValid() || provider.isLoading, // 입력값이 유효하지 않거나 로딩 중일 때 비활성화
                  onPressed: () => _submit(context, provider), // Consumer의 context와 provider를 전달
                );
              },
            ),
            const SizedBox(height: 12),
            // 회원가입 버튼 (흰색 배경, 파란색 테두리) - OutlinedButton 스타일
            _outlinedButton(
              text: '회원가입',
              onPressed: _openRegister,
            ),
            const SizedBox(height: 12),
            // 취소 버튼 (회색 배경) - 보조 액션 버튼
            _grayButton(
              text: '취소',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
        );
      },
    );
  }

  // 라벨이 있는 입력 필드 위젯 - 왼쪽에 라벨, 오른쪽에 입력 필드
  Widget _labeledInput(
    TextEditingController c,
    String label, {
    bool obscure = false,
    ValueChanged<String>? onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 왼쪽 라벨 영역 - 고정 너비 80으로 설정하여 정렬 유지
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        // 오른쪽 입력 필드 영역 - 남은 공간을 모두 차지하도록 Expanded 사용
        Expanded(
          child: TextField(
            controller: c,
            obscureText: obscure, // 비밀번호 필드의 경우 true로 설정하여 입력값 숨김
            onChanged: onChanged, // 입력값 변경 시 콜백 호출
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white, // 흰색 배경
              // 기본 테두리 스타일
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              // 비활성 상태 테두리
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              // 포커스 상태 테두리 - 파란색으로 강조
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1890FF), width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // 메인 액션 버튼 (로그인 버튼) - 파란색 배경, 흰색 텍스트
  Widget _primaryButton({required String text, required VoidCallback onPressed, bool disabled = false}) {
    return SizedBox(
      width: double.infinity, // 전체 너비 사용
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed, // disabled가 true이면 버튼 비활성화
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? Colors.grey[300] : const Color(0xFF1890FF), // 비활성화 시 회색, 활성화 시 파란색
          foregroundColor: disabled ? Colors.black54 : Colors.white, // 비활성화 시 어두운 회색, 활성화 시 흰색
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }

  // 아웃라인 버튼 (회원가입 버튼) - 흰색 배경, 파란색 테두리와 텍스트
  Widget _outlinedButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white, // 흰색 배경
          foregroundColor: const Color(0xFF1890FF), // 파란색 텍스트
          side: const BorderSide(color: Color(0xFF1890FF), width: 1), // 파란색 테두리
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }

  // 보조 액션 버튼 (취소 버튼) - 회색 배경, 파란색 텍스트
  Widget _grayButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300], // 회색 배경
          foregroundColor: const Color(0xFF1890FF), // 파란색 텍스트
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }
}
