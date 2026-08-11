// lib/screens/settings/two_factor_settings_screen.dart
// Premium, compact Two-Factor Authentication card component for Creania Settings.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/auth/two_factor_models.dart';
import '../../services/auth/two_factor_service.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../auth/two_factor_setup_screen.dart';
import './manage_two_factor_sheet.dart';

class TwoFactorSettingsWidget extends StatefulWidget {
  const TwoFactorSettingsWidget({Key? key}) : super(key: key);

  @override
  State<TwoFactorSettingsWidget> createState() => _TwoFactorSettingsWidgetState();
}

class _TwoFactorSettingsWidgetState extends State<TwoFactorSettingsWidget> {
  bool _isLoading = true;
  bool _isEnabled = false;
  int _remainingCodes = 0;
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load2FAStatus();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load2FAStatus() async {
    final status = await TwoFactorService.fetchStatus();
    if (mounted) {
      setState(() {
        _isEnabled = status.isEnabled;
        _remainingCodes = status.remainingRecoveryCodes;
        _isLoading = false;
      });
    }
  }

  void _onToggleChanged(bool enable) {
    if (enable) {
      _promptPasswordForSetup();
    } else {
      _showManageSheet();
    }
  }

  bool _isOAuthUser() {
    final supaUser = Supabase.instance.client.auth.currentUser;
    if (supaUser == null) return false;
    final provider = supaUser.appMetadata['provider']?.toString().toLowerCase() ?? '';
    if (provider.isNotEmpty && provider != 'email' && provider != 'password') {
      return true;
    }
    final identities = supaUser.identities ?? [];
    for (final id in identities) {
      final p = id.provider.toLowerCase();
      if (p == 'google' || p == 'facebook' || p == 'apple' || p == 'phone') {
        return true;
      }
    }
    return false;
  }

  void _promptPasswordForSetup() {
    _passwordCtrl.clear();
    final isOAuth = _isOAuthUser();
    final user = UserProfileCacheManager.currentUser;
    final email = user?.email ?? Supabase.instance.client.auth.currentUser?.email ?? '';

    Get.defaultDialog(
      title: 'Security Verification 🛡️',
      backgroundColor: context.secondaryBackgroundColor,
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      content: Column(
        children: [
          Text(
            isOAuth
                ? 'Your account is verified via Social Sign-In ($email).\nTap Continue to proceed with 2FA setup.'
                : 'Please confirm your account password before setting up Two-Factor Authentication.',
            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (!isOAuth) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              style: GoogleFonts.poppins(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'Account Password',
                labelStyle: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.lock_outline_rounded, color: context.primaryColor, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.primaryColor, width: 1.5),
                ),
              ),
            ),
          ],
        ],
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        onPressed: () async {
          final password = _passwordCtrl.text.trim();
          if (!isOAuth && password.isEmpty) {
            Get.snackbar('Error', 'Please enter your password');
            return;
          }
          Get.back();

          Get.to(() => TwoFactorSetupScreen(
                userEmail: email,
                password: password,
              ))?.then((_) => _load2FAStatus());
        },
        child: Text('Continue', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      cancel: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => Get.back(),
        child: Text('Cancel', style: GoogleFonts.poppins(color: context.textSecondary)),
      ),
    );
  }

  void _showManageSheet() {
    Get.bottomSheet(
      ManageTwoFactorSheet(
        remainingRecoveryCodes: _remainingCodes,
        onStatusUpdated: () => _load2FAStatus(),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text('Loading 2FA status...', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isEnabled ? const Color(0xFF10B981).withOpacity(0.4) : context.borderColor,
            width: _isEnabled ? 1.0 : 0.5,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _isEnabled
                        ? const Color(0xFF10B981).withOpacity(0.12)
                        : context.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: _isEnabled ? const Color(0xFF10B981) : context.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Two-Factor Authentication',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                          ),
                          if (_isEnabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Enabled',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isEnabled
                            ? 'Your account is protected with authenticator 2FA.'
                            : 'Secure your account with 2FA verification codes',
                        style: GoogleFonts.poppins(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) => _onToggleChanged(val),
                ),
              ],
            ),
            if (_isEnabled) ...[
              const SizedBox(height: 10),
              Divider(color: context.borderColor.withOpacity(0.5), height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.vpn_key_rounded, size: 14, color: context.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '$_remainingCodes recovery codes remaining',
                        style: GoogleFonts.poppins(fontSize: 11, color: context.textSecondary),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _showManageSheet,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'Manage 2FA',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 16, color: context.primaryColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
