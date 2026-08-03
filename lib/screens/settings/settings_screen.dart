import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:creania/core/theme.dart';
import '../auth/login_screen.dart';
import '../vip/vip_purchase_screen.dart';
import '../novel/novel_purchase_screen.dart';
import '../store/store_home_screen.dart';
import '../../services/user_profile_cache_manager.dart';
import '../../services/theme_controller.dart';
import '../../services/community_controller.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = true;
  bool _privateProfile = false;
  bool _twoFactorEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account & Memberships
            _buildSectionHeader('Account & Membership'),
            _buildSettingsTile(
              context,
              'Account Details',
              'Manage username, display name, and basic info',
              icon: Icons.person_outline_rounded,
              onTap: () {},
            ),
            _buildSettingsTile(
              context,
              'VIP Membership',
              'Manage your VIP status & cosmetic tiers',
              icon: Icons.diamond_outlined,
              onTap: () => Get.to(() => const VipPurchaseScreen()),
            ),
            _buildSettingsTile(
              context,
              'Novel Membership',
              'Manage prestigious luxury collectibles',
              icon: Icons.menu_book_outlined,
              onTap: () => Get.to(() => const NovelPurchaseScreen()),
            ),
            _buildSettingsTile(
              context,
              'Creaniaa Store',
              'Purchase frames, entry effects, and gifts',
              icon: Icons.storefront_rounded,
              onTap: () => Get.to(() => const StoreHomeScreen()),
            ),

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            // Privacy & Security
            _buildSectionHeader('Privacy & Security'),
            _buildToggleSetting(
              'Private Profile',
              'Only followers can see your posts and rooms',
              Icons.privacy_tip_outlined,
              _privateProfile,
              (val) => setState(() => _privateProfile = val),
            ),
            _buildSettingsTile(
              context,
              'Blocked Users',
              'Manage accounts you have blocked',
              icon: Icons.block_flipped,
              onTap: () => _showComingSoon('Blocked Users'),
            ),
            _buildSettingsTile(
              context,
              'Devices',
              'View and manage authorized devices for offline reading',
              icon: Icons.devices_rounded,
              onTap: () => _showComingSoon('Authorized Devices'),
            ),
            _buildSettingsTile(
              context,
              'Login Activity',
              'Check recent login locations and active sessions',
              icon: Icons.history_toggle_off_rounded,
              onTap: () => _showComingSoon('Login Activity'),
            ),
            _buildToggleSetting(
              'Two-Factor Authentication',
              'Secure your account with 2FA verification codes',
              Icons.security_rounded,
              _twoFactorEnabled,
              (val) => setState(() => _twoFactorEnabled = val),
            ),

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            // Preferences
            _buildSectionHeader('Preferences'),
            _buildSettingsTile(
              context,
              'Push Notifications',
              'Manage alert channels, messages, voice room settings and mute preferences',
              icon: Icons.notifications_none_rounded,
              onTap: () => Get.to(() => const NotificationSettingsScreen()),
            ),
            Obx(() {
              final pref = ThemeController.to.currentThemePreference.value;
              String displayVal = 'System (Auto)';
              if (pref == 'light') displayVal = 'Light';
              if (pref == 'dark') displayVal = 'Dark';
              
              return _buildSettingsTile(
                context,
                'Appearance ($displayVal)',
                'Toggle between dark, light, and system auto themes',
                icon: Icons.palette_outlined,
                onTap: () => _showThemeSelectionBottomSheet(context),
              );
            }),
            _buildSettingsTile(
              context,
              'Language',
              'Select display language (English)',
              icon: Icons.language_rounded,
              onTap: () => _showComingSoon('Language Settings'),
            ),

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            // Community Settings
            _buildSectionHeader('Community Settings'),
            _buildSettingsTile(
              context,
              'Leave Official Community',
              'Leave your currently joined Creaniaa Official Community',
              icon: Icons.group_remove_outlined,
              onTap: () => _showLeaveCommunityConfirm(),
            ),

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            // Support & Info
            _buildSectionHeader('Help & Support'),
            _buildSettingsTile(
              context,
              'Help & Support Center',
              'Submit reports, requests, and account recovery help',
              icon: Icons.help_outline_rounded,
              onTap: () => _showComingSoon('Help Center'),
            ),
            _buildSettingsTile(
              context,
              'About Creaniaa',
              'View terms of service, privacy policy and app version',
              icon: Icons.info_outline_rounded,
              onTap: () {
                Get.defaultDialog(
                  title: 'About Creaniaa',
                  titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                  content: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        width: 80,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Creaniaa v1.0.0',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create. Connect. Grow.',
                        style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  backgroundColor: context.secondaryBackgroundColor,
                  confirm: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Get.back(),
                    child: Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            // Danger Zone Actions
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _showLogoutConfirm,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.errorColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Logout',
                        style: GoogleFonts.poppins(
                          color: context.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _showDeleteConfirm,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.errorColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Delete Account',
                        style: GoogleFonts.poppins(
                          color: context.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: context.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context,
    String title,
    String subtitle, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor, width: 0.5),
          ),
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: context.textSecondary, size: 20),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: context.textSecondary, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSetting(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: context.primaryColor, size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: context.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: context.primaryColor,
              activeTrackColor: context.primaryColor.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    Get.snackbar(
      'Coming Soon 🚀',
      '$feature will be editable in the next update.',
      backgroundColor: context.primaryColor.withOpacity(0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _showLogoutConfirm() {
    Get.defaultDialog(
      title: 'Sign Out?',
      middleText: 'Are you sure you want to log out of your Creaniaa account?',
      backgroundColor: context.secondaryBackgroundColor,
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      middleTextStyle: GoogleFonts.poppins(color: context.textSecondary),
      confirm: ElevatedButton(
        onPressed: () async {
          await UserProfileCacheManager.forceLogout(message: "You have signed out.");
        },
        style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
        child: Text('Logout'),
      ),

      cancel: OutlinedButton(
        onPressed: () => Get.back(),
        child: Text('Cancel'),
      ),
    );
  }

  void _showDeleteConfirm() {
    Get.defaultDialog(
      title: 'Delete Account?',
      middleText: 'Deleting your account is permanent. All your coins, diamond balances, and library assets will be deleted.',
      backgroundColor: context.secondaryBackgroundColor,
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.errorColor),
      middleTextStyle: GoogleFonts.poppins(color: context.textSecondary),
      confirm: ElevatedButton(
        onPressed: () async {
          try {
            final canonicalId = UserProfileCacheManager.currentUserId;
            if (canonicalId.isNotEmpty && canonicalId != 'me') {
              // Delete profile row (foreign key will cascade delete other entries)
              await Supabase.instance.client.from('profiles').delete().eq('id', canonicalId);
              UserProfileCacheManager.clear();
              await Supabase.instance.client.auth.signOut();
            }
          } catch (_) {}
          Get.offAll(() => const LoginScreen());
        },
        style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
        child: Text('Delete Permanently'),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(),
        child: Text('Cancel'),
      ),
    );
  }

  void _showThemeSelectionBottomSheet(BuildContext context) {
    final themeCtrl = ThemeController.to;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.secondaryBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Obx(() {
          final currentPref = themeCtrl.currentThemePreference.value;
          return Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Choose your preferred theme for the app.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
                SizedBox(height: 24),
                _buildThemeOption(
                  context,
                  title: 'System (Recommended)',
                  subtitle: 'Match device settings automatically',
                  icon: Icons.settings_brightness_rounded,
                  value: 'system',
                  isSelected: currentPref == 'system',
                  onTap: () => themeCtrl.updateThemePreference('system'),
                ),
                SizedBox(height: 12),
                _buildThemeOption(
                  context,
                  title: 'Light Theme',
                  subtitle: 'Always use a light interface',
                  icon: Icons.light_mode_rounded,
                  value: 'light',
                  isSelected: currentPref == 'light',
                  onTap: () => themeCtrl.updateThemePreference('light'),
                ),
                SizedBox(height: 12),
                _buildThemeOption(
                  context,
                  title: 'Dark Theme (Coming Soon)',
                  subtitle: 'Always use a dark interface',
                  icon: Icons.dark_mode_rounded,
                  value: 'dark',
                  isSelected: currentPref == 'dark',
                  onTap: () => _showComingSoon('Dark Theme'),
                ),
                SizedBox(height: 24),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? context.primaryColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? context.primaryColor.withOpacity(0.3)
                : context.borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? context.primaryColor : context.textSecondary,
              size: 24,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? context.primaryColor : context.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: context.primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showLeaveCommunityConfirm() async {
    final commCtrl = Get.find<CommunityController>();
    final myId = UserProfileCacheManager.currentUserId;
    if (myId.isEmpty) return;

    final joined = commCtrl.communities.firstWhereOrNull((c) =>
        c.type == 'Official' && c.members.contains(myId));

    if (joined == null) {
      Get.snackbar(
        'Not In Any Official Community',
        'You are not currently a member of any Official Community.',
        backgroundColor: context.primaryColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.defaultDialog(
      title: 'Leave Official Community?',
      backgroundColor: context.secondaryBackgroundColor,
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.errorColor),
      middleTextStyle: GoogleFonts.poppins(color: context.textSecondary),
      middleText: 'Are you sure you want to leave this Official Community?\n\nAfter leaving, you must wait 24 hours before joining another Official Community.\n\nYour Community TagLight will be removed immediately.',
      confirm: ElevatedButton(
        onPressed: () async {
          Get.back();
          try {
            await commCtrl.leaveCommunity(joined.id);

            final cooldownUntil = DateTime.now().add(const Duration(hours: 24)).toUtc().toIso8601String();
            await Supabase.instance.client
                .from('profiles')
                .update({'official_community_cooldown_until': cooldownUntil})
                .eq('id', myId);

            Get.snackbar(
              'Left Community',
              'You have left ${joined.name}. Cooldown activated.',
              backgroundColor: const Color(0xFF10B981),
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
            );
          } catch (e) {
            Get.snackbar('Error', 'Failed to leave community: $e');
          }
        },
        style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
        child: const Text('Leave Community'),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }
}
