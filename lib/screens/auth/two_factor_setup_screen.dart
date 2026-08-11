// lib/screens/auth/two_factor_setup_screen.dart
// Production-grade 2FA Setup Flow: TOTP Key -> 6-Digit Code Verification -> Recovery Codes Screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/auth/two_factor_models.dart';
import '../../services/auth/two_factor_service.dart';
import '../../services/auth/totp_helper.dart';

class TwoFactorSetupScreen extends StatefulWidget {
  final String userEmail;
  final String password;

  const TwoFactorSetupScreen({
    Key? key,
    required this.userEmail,
    required this.password,
  }) : super(key: key);

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  int _currentStep = 1; // 1: QR & Secret Setup, 2: Verification, 3: Recovery Codes
  bool _isLoading = true;
  TwoFactorSetupData? _setupData;

  final TextEditingController _codeCtrl = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;
  int _attemptsCount = 0;

  @override
  void initState() {
    super.initState();
    _initSetup();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSetup() async {
    setState(() => _isLoading = true);
    final data = await TwoFactorService.initiateSetup(email: widget.userEmail);
    if (mounted) {
      setState(() {
        _setupData = data;
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      '$label Copied 📋',
      'Text copied to clipboard.',
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  void _verifyAndCompleteSetup() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit verification code.');
      return;
    }

    if (_setupData == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    // Check rate limit locally
    _attemptsCount++;
    if (_attemptsCount >= 5) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Too many failed attempts. Please wait 15 minutes before trying again.';
      });
      return;
    }

    final res = await TwoFactorService.verifyAndEnable2FA(
      secret: _setupData!.secret,
      code: code,
      recoveryCodes: _setupData!.recoveryCodes,
      serverSecurityKeys: _setupData!.serverSecurityKeys,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (res['success'] == true) {
      setState(() => _currentStep = 3); // Move to Recovery Codes screen
    } else {
      setState(() {
        _errorMessage = res['error'] ?? 'Invalid verification code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _currentStep == 3 ? 'Two-Step Verification Enabled' : 'Setup 2FA',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_currentStep == 3) {
              Get.back();
            } else if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Get.back();
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _setupData == null
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildStepProgressHeader(),
                      const SizedBox(height: 24),
                      if (_currentStep == 1) _buildStep1QrSetup(),
                      if (_currentStep == 2) _buildStep2CodeVerification(),
                      if (_currentStep == 3) _buildStep3RecoveryCodes(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStepProgressHeader() {
    return Row(
      children: [
        _buildProgressDot(1, 'Setup App'),
        _buildProgressLine(_currentStep >= 2),
        _buildProgressDot(2, 'Verify Code'),
        _buildProgressLine(_currentStep >= 3),
        _buildProgressDot(3, 'Backup Codes'),
      ],
    );
  }

  Widget _buildProgressDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? context.primaryColor : context.surfaceColor,
            border: Border.all(
              color: isCurrent ? context.primaryColor : context.borderColor,
              width: 2,
            ),
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : Text(
                    '$step',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : context.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? context.primaryColor : context.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: active ? context.primaryColor : context.borderColor,
      ),
    );
  }

  Widget _buildStep1QrSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor, width: 0.5),
          ),
          child: Column(
            children: [
              Icon(Icons.qr_code_scanner_rounded, size: 48, color: context.primaryColor),
              const SizedBox(height: 12),
              Text(
                'Scan QR Code with Authenticator',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Scan this QR code using:\nGoogle Authenticator, Microsoft Authenticator, Authy, or another TOTP compatible app.',
                style: GoogleFonts.poppins(fontSize: 12, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Visual QR Code Card Box
              Container(
                width: 200,
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 130, color: Colors.black),
                    Text(
                      'CREANIA AUTH',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Divider(color: context.borderColor, height: 24),

              Text(
                "Can't scan? Enter setup key manually",
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _setupData!.setupKey,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: context.primaryColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () => _copyToClipboard(_setupData!.setupKey, 'Setup Key'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => setState(() => _currentStep = 2),
            child: Text(
              'Next: Verify Code',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2CodeVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor, width: 0.5),
          ),
          child: Column(
            children: [
              Icon(Icons.dialpad_rounded, size: 44, color: context.primaryColor),
              const SizedBox(height: 12),
              Text(
                'Enter 6-Digit Verification Code',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Open your authenticator app and enter the code generated for Creania.',
                style: GoogleFonts.poppins(fontSize: 12, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                  color: context.textPrimary,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '• • • • • •',
                  hintStyle: GoogleFonts.outfit(fontSize: 28, letterSpacing: 10, color: context.textSecondary.withOpacity(0.4)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.primaryColor, width: 2),
                  ),
                ),
                onChanged: (val) {
                  if (val.length == 6) {
                    _verifyAndCompleteSetup();
                  }
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 18, color: context.errorColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(fontSize: 12, color: context.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isVerifying ? null : _verifyAndCompleteSetup,
            child: _isVerifying
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    'Verify & Enable',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3RecoveryCodes() {
    final codes = _setupData?.recoveryCodes ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, size: 40, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 12),
              Text(
                'Two-Step Verification Enabled',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your account is now protected with an additional verification step when signing in from a new or untrusted device.',
                style: GoogleFonts.poppins(fontSize: 12, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // High-Security 64-Bit Server Security Keys Section
              Text(
                'High-Security 64-Bit Server Keys',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: context.primaryColor),
              ),
              const SizedBox(height: 4),
              Text(
                'The server generated these cryptographically secure emergency keys for login:',
                style: GoogleFonts.poppins(fontSize: 11, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.primaryColor.withOpacity(0.3)),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: (_setupData?.serverSecurityKeys ?? []).map((k) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.primaryColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        k,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: context.primaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              Divider(color: context.borderColor),
              const SizedBox(height: 12),

              // Recovery codes list grid
              Text(
                'Save Your Backup Recovery Codes',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'If you lose access to your phone or authenticator app, you can use these codes to sign in. Each code can be used ONLY ONCE.',
                style: GoogleFonts.poppins(fontSize: 11, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: codes.map((c) {
                    return Container(
                      width: 130,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.borderColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        c,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: context.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text('Copy Codes', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _copyToClipboard(codes.join('\n'), 'Recovery Codes'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.accentOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.accentOrange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: context.accentOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Keep these codes somewhere safe. Anyone with a recovery code may be able to access your account.',
                        style: GoogleFonts.poppins(fontSize: 11, color: context.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Get.back(),
            child: Text(
              "I've Saved My Codes",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: context.errorColor),
          const SizedBox(height: 12),
          Text('Failed to initialize 2FA setup.', style: GoogleFonts.poppins(color: context.textPrimary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initSetup,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
