/// 포털 계정 연동 화면
/// 학교 포털 ID/PW를 입력하여 서버에 저장
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../features/settings/providers/settings_provider.dart';

class PortalLinkScreen extends StatefulWidget {
  const PortalLinkScreen({super.key});

  @override
  State<PortalLinkScreen> createState() => _PortalLinkScreenState();
}

class _PortalLinkScreenState extends State<PortalLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolIdController = TextEditingController();
  final _schoolPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _schoolIdController.dispose();
    _schoolPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveSchoolAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = AuthRepository.I;
      final response = await repository.saveSchoolAccount(
        schoolId: _schoolIdController.text.trim(),
        schoolPassword: _schoolPasswordController.text,
      );

      if (response['message'] == 'SAVED' && mounted) {
        final settingsProvider = context.read<SettingsProvider>();
        final l10n = AppLocalizations(settingsProvider.isKorean);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.portalAccountSaved),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // 성공 시 화면 닫기
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final l10n = AppLocalizations(settingsProvider.isKorean);
        
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.portalLinkTitle),
            backgroundColor: const Color(0xFF1890FF),
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 안내 메시지
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.portalLinkDescription,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 포털 ID 입력
                    Text(
                      l10n.portalId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _schoolIdController,
                      decoration: InputDecoration(
                        hintText: l10n.portalIdHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.portalIdRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // 포털 비밀번호 입력
                    Text(
                      l10n.portalPassword,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _schoolPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: l10n.portalPasswordHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.portalPasswordRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // 에러 메시지
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[900],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_errorMessage != null) const SizedBox(height: 16),
                    
                    // 저장 버튼
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveSchoolAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1890FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              l10n.save,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

