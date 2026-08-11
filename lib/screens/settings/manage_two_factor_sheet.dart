// lib/screens/settings/manage_two_factor_sheet.dart
// Manage 2FA Modal Bottom Sheet providing options to view trusted devices, regenerate recovery codes, or turn off 2FA.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/auth/two_factor_service.dart';
import './devices_screen.dart';

class ManageTwoFactorSheet extends StatefulWidget {
  final int remainingRecoveryCodes;
  final VoidCallback onStatusUpdated;

  const ManageTwoFactorSheet({
    Key? key,
    required this.remainingRecoveryCodes,
    required this.onStatusUpdated,
  }) : super(key: key);

  @override
  State<ManageTwoFactorSheet> createState() => _ManageTwoFactorSheetState();
}

class _ManageTwoFactorSheetState extends State<ManageTwoFactorSheet> {
  bool _isLoading = false;

  void _promptRegenerateRecoveryCodes() {
    Get.defaultDialog(
      title: 'Regenerate Recovery Codes? 🔐',
      backgroundColor: context.secondaryBackgroundColor,
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18),
      contentPadding: const EdgeInsets.all(20),
      content: Text(
        'This will invalidate ALL your existing recovery codes and generate a new set of 10 codes. Make sure to save the new codes.',
        style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
        textAlign: TextAlign.center,
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () async {
          Get.back();
          setState(() => _isLoading = true);

          final res = await TwoFactorService.regenerateRecoveryCodes();
          setState(() => _isLoading = false);

          if (res['success'] == true) {
            final List<String> codes = res['codes'] ?? [];
            widget.onStatusUpdated();
            _showNewCodesDialog(codes);
          } else {
            Get.snackbar('Error', res['error'] ?? 'Failed to regenerate recovery codes');
          }
        },
        child: Text('Regenerate Codes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
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

  void _showNewCodesDialog(List<String> codes) {
    Get.defaultDialog(
      title: 'New Recovery Codes 🔑',
      backgroundColor: context.secondaryBackgroundColor,
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18),
      contentPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              'Your old recovery codes are now INVALID. Keep these new codes somewhere safe:',
              style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
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
                spacing: 8,
                runSpacing: 8,
                children: codes.map((c) {
                  return Container(
                    width: 120,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c,
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
        onPressed: () => Get.back(),
        child: Text("I've Saved New Codes", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  void _promptDisable2FA() {
    Get.defaultDialog(
      title: 'Disable Two-Step Verification? ⚠️',
      backgroundColor: context.secondaryBackgroundColor,
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.errorColor, fontSize: 18),
      contentPadding: const EdgeInsets.all(20),
      content: Text(
        'Turning off 2FA will remove the extra layer of security from your account. All trusted devices and recovery codes will be revoked.',
        style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
        textAlign: TextAlign.center,
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
        onPressed: () async {
          Get.back();
          setState(() => _isLoading = true);

          final res = await TwoFactorService.disable2FA();
          setState(() => _isLoading = false);

          if (res['success'] == true) {
            widget.onStatusUpdated();
            Get.back(); // Close manage sheet
            Get.snackbar(
              '2FA Disabled 🔓',
              'Two-Factor Authentication has been turned off.',
              backgroundColor: context.accentOrange,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
            );
          } else {
            Get.snackbar('Error', res['error'] ?? 'Failed to disable 2FA');
          }
        },
        child: Text('Turn Off 2FA', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(),
        child: Text('Cancel', style: GoogleFonts.poppins(color: context.textSecondary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.security_rounded, color: const Color(0xFF10B981), size: 24),
              const SizedBox(width: 10),
              Text(
                'Manage Two-Factor Authentication',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Control your security verification settings, trusted devices, and backup recovery codes.',
            style: GoogleFonts.poppins(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else ...[
            _buildManageTile(
              icon: Icons.devices_rounded,
              title: 'Trusted & Authorized Devices',
              subtitle: 'View and revoke devices trusted for 30 days',
              onTap: () {
                Get.back();
                Get.to(() => const DevicesScreen());
              },
            ),
            const SizedBox(height: 10),
            _buildManageTile(
              icon: Icons.key_rounded,
              title: 'Generate New Recovery Codes',
              subtitle: '${widget.remainingRecoveryCodes} unused recovery codes remaining',
              onTap: _promptRegenerateRecoveryCodes,
            ),
            const SizedBox(height: 10),
            _buildManageTile(
              icon: Icons.no_encryption_rounded,
              title: 'Turn Off 2FA',
              subtitle: 'Remove 2FA protection from your account',
              iconColor: context.errorColor,
              onTap: _promptDisable2FA,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildManageTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? context.primaryColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor ?? context.primaryColor, size: 20),
        ),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: context.textSecondary)),
        trailing: Icon(Icons.chevron_right_rounded, color: context.textSecondary, size: 20),
        onTap: onTap,
      ),
    );
  }
}
