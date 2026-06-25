import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../core/theme.dart';

class RoomUpgradeDialog extends StatelessWidget {
  final String roomId;

  const RoomUpgradeDialog({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  void _copyWebsiteUrl(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: 'https://www.agorax.com'));
    Get.snackbar(
      'Link Copied 📋',
      'Official portal link copied to clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.successColor.withOpacity(0.9),
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.purpleAccent,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Official Agency Upgrades 💎',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            const Text(
              'To purchase or request official room role slots (Co-owners, Admins, or Star Members), room hosts must register through our official agency web portal.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Info Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  const Text(
                    'Room ID to register:',
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roomId,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyWebsiteUrl(context),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Portal Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purpleAccent,
                      side: const BorderSide(color: Colors.purpleAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
