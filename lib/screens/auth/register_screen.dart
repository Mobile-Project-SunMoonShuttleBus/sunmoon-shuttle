// lib/storage/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/../providers/register_provider.dart'; 
import '/../core/utils/validators.dart';       

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _idCtrl.addListener(_onTextChanged);
    _pwCtrl.addListener(_onTextChanged);
    _pw2Ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // 이제 부모에서 Provider를 주입받았으므로 오류 없이 찾을 수 있습니다.
    final provider = context.read<RegisterProvider>();
    provider.validateUserId(_idCtrl.text.trim());
    provider.validatePassword(_pwCtrl.text);
    provider.validatePasswordConfirm(_pwCtrl.text, _pw2Ctrl.text);
    setState(() {}); 
  }

  bool _isFormValid() {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pw2 = _pw2Ctrl.text;
    
    // 1. 빈값 체크
    if (id.isEmpty || pw.isEmpty || pw2.isEmpty) return false;
    // 2. ID/PW 규칙 체크
    if (!Validators.isValidUserId(id)) return false;
    if (!Validators.isValidPassword(pw)) return false;
    // 3. 비밀번호 일치 체크
    if (pw != pw2) return false;
    
    return true;
  }
  
  Future<void> _handleSubmit(BuildContext context, RegisterProvider provider) async {
    if (!_isFormValid()) return;

    final success = await provider.register(
      userId: _idCtrl.text.trim(),
      password: _pwCtrl.text,
      passwordConfirm: _pw2Ctrl.text,
    );

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원가입 성공! 로그인해주세요.'), backgroundColor: Colors.green));
      Navigator.of(context).pop(); 
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? '회원가입 실패'), backgroundColor: Colors.red));
    }
  }
  
  // UI 헬퍼
  Widget _labeledInput(TextEditingController c, String label, {bool obscure = false, String? errorText}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87))),
        Expanded(child: TextFormField(
            controller: c, obscureText: obscure,
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white, 
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFF1890FF), width: 1)),
              errorBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.red, width: 1)),
              focusedErrorBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.red, width: 1)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              errorText: errorText, 
            ),
            validator: (value) => (value == null || value.isEmpty) ? '필수 입력 항목입니다.' : null,
          )),
      ]);
  }

  Widget _primaryButton({required String text, required VoidCallback onPressed, bool disabled = false}) {
    return SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: disabled ? Colors.grey[300] : const Color(0xFF1890FF), foregroundColor: disabled ? Colors.black54 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text(text),
      ));
  }

  Widget _grayButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: const Color(0xFF1890FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text(text),
      ));
  }
  
  @override
  Widget build(BuildContext context) {
    // ⭐️ [수정] ChangeNotifierProvider 제거 (부모에서 받음)
    // Consumer만 사용하여 부모가 준 Provider를 씁니다.
    return Scaffold(
      backgroundColor: const Color(0xFF1890FF), 
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Consumer<RegisterProvider>( // 여기서 부모 Provider 사용
              builder: (context, provider, _) {
                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('회원가입', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1890FF))),
                      const SizedBox(height: 32),
                      _labeledInput(_idCtrl, '아이디', errorText: provider.userIdError), 
                      const SizedBox(height: 16),
                      _labeledInput(_pwCtrl, '비밀번호', obscure: true, errorText: provider.passwordError),
                      const SizedBox(height: 16),
                      _labeledInput(_pw2Ctrl, '비밀번호 확인', obscure: true, errorText: provider.passwordConfirmError),
                      const SizedBox(height: 24),
                      if (provider.errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                      _primaryButton(
                        text: provider.isLoading ? '처리 중...' : '회원가입',
                        disabled: !_isFormValid() || provider.isLoading, 
                        onPressed: () => _handleSubmit(context, provider),
                      ),
                      const SizedBox(height: 12),
                      _grayButton(text: '취소', onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}