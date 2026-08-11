// lib/screens/auth/two_factor_login_screen.dart
// Mandatory 2FA Verification Checkpoint screen displayed when signing in from untrusted devices.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../services/auth/two_factor_service.dart';
import '../../services/user/user_profile_cache_manager.dart';

class TwoFactorLoginScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onVerificationSuccess;
  final VoidCallback onCancel;

  const TwoFactorLoginScreen({
    Key? key,
    required this.userId,
    required this.onVerificationSuccess,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<TwoFactorLoginScreen> createState() => _TwoFactorLoginScreenState();
}

class _TwoFactorLoginScreenState extends State<TwoFactorLoginScreen> {
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _serverKeyCtrl = TextEditingController();
  final TextEditingController _recoveryCodeCtrl = TextEditingController();
  
  bool _trustDevice = true;
  bool _isLoading = false;
  int _verificationMode = 0; // 0: 6-Digit TOTP, 1: 64-Bit Server Key, 2: Recovery Code
  String? _errorMessage;
  int _attemptCount = 0;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _serverKeyCtrl.dispose();
    _recoveryCodeCtrl.dispose();
    super.dispose();
  }

  String get _deviceName {
    if (Platform.isAndroid) return 'Android Phone';
    if (Platform.isIOS) return 'iPhone';
    return 'Web/Desktop Client';
  }

  String get _deviceId => '${widget.userId}_${Platform.operatingSystem}';

  void _handleVerifyTotp() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _attemptCount++;
    if (_attemptCount >= 5) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Too many attempts. Please wait before trying again.';
      });
      return;
    }

    try {
      // 1. Get user secret key
      final res = await Supabase.instance.client
          .from('user_security_settings')
          .select('totp_secret_encrypted')
          .eq('user_id', widget.userId)
          .maybeSingle();

      final secret = res?['totp_secret_encrypted'] as String?;
      if (secret == null || secret.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '2FA configuration error. Please contact support.';
        });
        return;
      }

      final result = await TwoFactorService.verify2FALogin(
        userId: widget.userId,
        secret: secret,
        code: code,
        trustDevice: _trustDevice,
        deviceId: _deviceId,
        deviceName: _deviceName,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        widget.onVerificationSuccess();
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Invalid verification code. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Verification failed. Please try again.';
        });
      }
    }
  }

  void _handleVerifyRecoveryCode() async {
    final code = _recoveryCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a recovery code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await TwoFactorService.verifyRecoveryCodeLogin(
      userId: widget.userId,
      recoveryCode: code,
      trustDevice: _trustDevice,
      deviceId: _deviceId,
    try {
      final result = await TwoFactorService.verifyRecoveryCodeLogin(
        userId: widget.userId,
        recoveryCode: code,
        trustDevice: _trustDevice,
        deviceId: _deviceId,
        deviceName: _deviceName,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final remaining = result['remaining_codes'] ?? 0;
        Get.snackbar(
          'Recovery Code Used 🔓',
          'Login successful. You have $remaining recovery codes remaining.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        widget.onVerificationSuccess();
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Invalid recovery code. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Verification error: $e';
        });
      }
    }
  }

  void _handleVerifyServerSecurityKey() async {
    final key = _serverKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Please enter a server security key.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await TwoFactorService.verifyServerSecurityKeyLogin(
        userId: widget.userId,
        key: key,
        trustDevice: _trustDevice,
        deviceId: _deviceId,
        deviceName: _deviceName,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final remaining = result['remaining_keys'] ?? 0;
        Get.snackbar(
          'Server Key Used 🔓',
          'Login successful. You have $remaining server security keys remaining.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        widget.onVerificationSuccess();
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Invalid server security key. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Verification failed. Please try again.';
        });
      }
    }
  }

  Widget _buildModeTab(int modeIndex, String label) {
    final isSelected = _verificationMode == modeIndex;
    return InkWell(
      onTap: () {
        setState(() {
          _verificationMode = modeIndex;
          _errorMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.primaryColor : context.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? context.primaryColor : context.borderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : context.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Two-Step Verification', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: widget.onCancel,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _verificationMode == 1
                      ? Icons.key_rounded
                      : (_verificationMode == 2 ? Icons.vpn_key_rounded : Icons.shield_rounded),
                  size: 48,
                  color: context.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _verificationMode == 1
                    ? '64-Bit Server Security Key'
                    : (_verificationMode == 2 ? 'Use Backup Recovery Code' : 'Two-Step Verification Required'),
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _verificationMode == 1
                    ? 'Enter one of the 64-bit high-security keys generated for you by the server.'
                    : (_verificationMode == 2
                        ? 'Enter one of your 8-digit backup recovery codes (format: XXXX-XXXX).'
                        : 'Enter the 6-digit verification code generated by your authenticator app.'),
                style: GoogleFonts.poppins(fontSize: 13, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Verification Mode Selector Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildModeTab(0, '6-Digit TOTP'),
                  const SizedBox(width: 8),
                  _buildModeTab(1, 'Server Key'),
                  const SizedBox(width: 8),
                  _buildModeTab(2, 'Recovery Code'),
                ],
              ),
              const SizedBox(height: 24),

              if (_verificationMode == 0) ...[
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • • • •',
                    hintStyle: GoogleFonts.outfit(fontSize: 32, letterSpacing: 12, color: context.textSecondary.withOpacity(0.3)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.primaryColor, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.length == 6) {
                      _handleVerifyTotp();
                    }
                  },
                ),
              ] else if (_verificationMode == 1) ...[
                TextField(
                  controller: _serverKeyCtrl,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: context.primaryColor,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Server Key (e.g. A7F9-3B2E-8C4D-1E9F)',
                    labelStyle: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.primaryColor, width: 2),
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _recoveryCodeCtrl,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Recovery Code (e.g. XXXX-XXXX)',
                    labelStyle: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.primaryColor, width: 2),
                    ),
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.errorColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.errorColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 20, color: context.errorColor),
                      const SizedBox(width: 10),
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

              const SizedBox(height: 20),

              // Trust Device Checkbox
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor, width: 0.5),
                ),
                child: CheckboxListTile(
                  title: Text(
                    "Don't ask for 2FA on this device again",
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                  ),
                  subtitle: Text(
                    'Trust this device for 30 days',
                    style: GoogleFonts.poppins(fontSize: 11, color: context.textSecondary),
                  ),
                  value: _trustDevice,
                  activeColor: context.primaryColor,
                  onChanged: (val) => setState(() => _trustDevice = val ?? true),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_verificationMode == 0) _handleVerifyTotp();
                          if (_verificationMode == 1) _handleVerifyServerSecurityKey();
                          if (_verificationMode == 2) _handleVerifyRecoveryCode();
                        },
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Verify & Continue',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
