import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:creania/core/theme.dart';
import '../auth/login_screen.dart';
import '../vip/vip_purchase_screen.dart';
import '../novel/novel_purchase_screen.dart';
import '../store/store_home_screen.dart';
import '../wallet/creania_balance_wallet_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../services/storage/theme_controller.dart';
import '../../services/community/community_controller.dart';
import '../../services/auth/auth_memory_service.dart';
import './notification_settings_screen.dart';
import './blocked_users_screen.dart';
import './devices_screen.dart';
import './login_activity_screen.dart';
import './help_support_screen.dart';
import './legal_terms_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _privateProfile = false;
  bool _twoFactorEnabled = false;
  String _currentLanguage = 'English (US)';
  final _pinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserSettingStates();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _loadUserSettingStates() async {
    final user = UserProfileCacheManager.currentUser;
    if (user != null) {
      setState(() {
        _privateProfile = user.isPrivate;
        _twoFactorEnabled = user.twoFactorEnabled;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final savedLangCode = prefs.getString('app_language_code') ?? 'en';
    setState(() {
      _currentLanguage = _getLanguageLabel(savedLangCode);
    });
  }

  String _getLanguageLabel(String code) {
    if (code == 'en_GB') return 'English (UK)';
    if (code == 'hi') return 'Hindi (India)';
    return 'English (US)';
  }

  Future<void> _togglePrivateProfile(bool val) async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    setState(() => _privateProfile = val);

    try {
      await _supabase.from('profiles').update({'is_private': val}).eq('id', userId);
      final currentUser = UserProfileCacheManager.currentUser;
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(isPrivate: val);
        UserProfileCacheManager.setCurrentUser(updatedUser);
        UserProfileCacheManager.rxCache[userId] = updatedUser;
        UserProfileCacheManager.rxCache['me'] = updatedUser;
      }
      Get.snackbar(
        val ? 'Private Profile Enabled 🔒' : 'Public Profile Enabled 🌐',
        val
            ? 'Only followers can now view your posts and activities.'
            : 'Your profile and posts are visible to the Creania community.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      setState(() => _privateProfile = !val);
      Get.snackbar('Error', 'Failed to update privacy settings: $e');
    }
  }

  void _handle2FAChange(bool enable) {
    _pinCtrl.clear();
    if (enable) {
      // Prompt setup Security PIN
      Get.defaultDialog(
        title: 'Enable Two-Factor Auth 🛡️',
        backgroundColor: context.secondaryBackgroundColor,
        titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        middleTextStyle: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Set a 4 to 6 digit Security PIN to secure your account during logins.',
                style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Security PIN',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        confirm: ElevatedButton(
          onPressed: () async {
            final pin = _pinCtrl.text.trim();
            if (pin.length < 4 || pin.length > 6) {
              Get.snackbar('Error', 'PIN must be 4 to 6 digits');
              return;
            }
            Get.back();
            try {
              final res = await _supabase.rpc('enable_2fa', params: {'p_pin': pin});
              if (res != null && res['success'] == true) {
                setState(() => _twoFactorEnabled = true);
                final user = UserProfileCacheManager.currentUser;
                if (user != null) {
                  final updated = user.copyWith(twoFactorEnabled: true);
                  UserProfileCacheManager.setCurrentUser(updated);
                }
                Get.snackbar(
                  '2FA Enabled 🛡️',
                  'Your Security PIN has been set.',
                  backgroundColor: const Color(0xFF10B981),
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              } else {
                Get.snackbar('Error', res?['error'] ?? 'Failed to enable 2FA');
              }
            } catch (e) {
              Get.snackbar('Error', 'Failed to enable 2FA: $e');
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: context.primaryColor),
          child: const Text('Enable 2FA'),
        ),
        cancel: OutlinedButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
      );
    } else {
      // Prompt verification to disable
      Get.defaultDialog(
        title: 'Disable 2FA?',
        backgroundColor: context.secondaryBackgroundColor,
        titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.errorColor),
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Enter your Security PIN to turn off Two-Factor Authentication.',
                style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Current Security PIN',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        confirm: ElevatedButton(
          onPressed: () async {
            final pin = _pinCtrl.text.trim();
            if (pin.isEmpty) return;
            Get.back();
            try {
              final res = await _supabase.rpc('disable_2fa', params: {'p_pin': pin});
              if (res != null && res['success'] == true) {
                setState(() => _twoFactorEnabled = false);
                final user = UserProfileCacheManager.currentUser;
                if (user != null) {
                  final updated = user.copyWith(twoFactorEnabled: false);
                  UserProfileCacheManager.setCurrentUser(updated);
                }
                Get.snackbar(
                  '2FA Disabled',
                  'Two-Factor Authentication has been turned off.',
                  backgroundColor: Colors.orangeAccent,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              } else {
                Get.snackbar('Error', res?['error'] ?? 'Incorrect Security PIN');
              }
            } catch (e) {
              Get.snackbar('Error', 'Failed to disable 2FA: $e');
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
          child: const Text('Disable'),
        ),
        cancel: OutlinedButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
      );
    }
  }

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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
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
              onTap: () => Get.to(() => const EditProfileScreen()),
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
              'Creania Store',
              'Purchase frames, entry effects, and gifts',
              icon: Icons.storefront_rounded,
              onTap: () => Get.to(() => const StoreHomeScreen()),
            ),
            _buildSettingsTile(
              context,
              'Income Center & Wallet',
              'Manage Creania Balance (CB), gift earnings, exchanges & withdrawals',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => Get.to(() => const CreaniaBalanceWalletScreen()),
            ),

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            // Privacy & Security
            _buildSectionHeader('Privacy & Security'),
            _buildToggleSetting(
              'Private Profile',
              'Only followers can see your posts and rooms',
              Icons.privacy_tip_outlined,
              _privateProfile,
              (val) => _togglePrivateProfile(val),
            ),
            _buildSettingsTile(
              context,
              'Blocked Users',
              'Manage accounts you have blocked',
              icon: Icons.block_flipped,
              onTap: () => Get.to(() => const BlockedUsersScreen()),
            ),
            _buildSettingsTile(
              context,
              'Devices',
              'View and manage authorized devices and active sessions',
              icon: Icons.devices_rounded,
              onTap: () => Get.to(() => const DevicesScreen()),
            ),
            _buildSettingsTile(
              context,
              'Login Activity',
              'Check recent login locations and active sessions',
              icon: Icons.history_toggle_off_rounded,
              onTap: () => Get.to(() => const LoginActivityScreen()),
            ),
            _buildToggleSetting(
              'Two-Factor Authentication',
              'Secure your account with 2FA verification codes',
              Icons.security_rounded,
              _twoFactorEnabled,
              (val) => _handle2FAChange(val),
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
              'Language ($_currentLanguage)',
              'Select display language',
              icon: Icons.language_rounded,
              onTap: () => _showLanguageSelectionBottomSheet(context),
            ),

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            // Community Settings
            _buildSectionHeader('Community Settings'),
            _buildSettingsTile(
              context,
              'Leave Official Community',
              'Leave your currently joined Creania Official Community',
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
              onTap: () => Get.to(() => const HelpSupportScreen()),
            ),
            _buildSettingsTile(
              context,
              'About Creania',
              'View terms of service, privacy policy and app version',
              icon: Icons.info_outline_rounded,
              onTap: () => _showAboutDialog(context),
            ),

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _showForgetDeviceConfirm,
                      icon: Icon(Icons.phonelink_erase_rounded, color: context.errorColor, size: 18),
                      label: Text(
                        'Logout & Forget Device',
                        style: GoogleFonts.poppins(
                          color: context.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.errorColor.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor, width: 0.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: context.textSecondary, size: 20),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: context.primaryColor, size: 20),
            ),
            const SizedBox(width: 14),
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
                  const SizedBox(height: 4),
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

  void _showLogoutConfirm() {
    Get.defaultDialog(
      title: 'Sign Out?',
      middleText: 'You will be signed out. Your email and last login info will be remembered on this device.',
      backgroundColor: context.secondaryBackgroundColor,
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      middleTextStyle: GoogleFonts.poppins(color: context.textSecondary),
      confirm: ElevatedButton(
        onPressed: () async {
          await UserProfileCacheManager.forceLogout(message: "You have signed out.");
        },
        style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
        child: const Text('Logout'),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }

  void _showForgetDeviceConfirm() {
    Get.defaultDialog(
      title: 'Forget This Device?',
      middleText: 'This will sign you out AND delete all saved login info from this device — your email, last login, and Remember Me settings.\n\nYou will need to log in from scratch.',
      backgroundColor: context.secondaryBackgroundColor,
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.errorColor),
      middleTextStyle: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
      confirm: ElevatedButton(
        onPressed: () async {
          // Revoke device session in backend
          final userId = UserProfileCacheManager.currentUserId;
          if (userId.isNotEmpty) {
            final String platform = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Web/Desktop');
            final String deviceId = '${userId}_${platform.toLowerCase()}';
            try {
              await _supabase.rpc('revoke_user_device', params: {'p_device_id': deviceId});
            } catch (_) {}
          }
          // Memory wipe & force logout
          await AuthMemoryService.forgetDevice();
          await UserProfileCacheManager.forceLogout(message: "Device forgotten. Please log in again.");
        },
        style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
        child: const Text('Forget Device'),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    Get.defaultDialog(
      title: 'About Creania',
      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
      backgroundColor: context.secondaryBackgroundColor,
      content: Column(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 80,
            width: 80,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, size: 64, color: context.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Creania v1.0.0 (Build 1)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Learn, Discuss & Connect',
            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Get.back();
              Get.to(() => const LegalTermsScreen(initialTabIndex: 0));
            },
            child: Text(
              'Terms of Service',
              style: GoogleFonts.poppins(color: context.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.to(() => const LegalTermsScreen(initialTabIndex: 1));
            },
            child: Text(
              'Privacy Policy',
              style: GoogleFonts.poppins(color: context.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => Get.back(),
        child: const Text('Close', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showThemeSelectionBottomSheet(BuildContext context) {
    final themeCtrl = ThemeController.to;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.secondaryBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Obx(() {
          final currentPref = themeCtrl.currentThemePreference.value;
          return Container(
            padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 8),
                Text(
                  'Choose your preferred theme for the app.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                _buildThemeOption(
                  context,
                  title: 'System (Recommended)',
                  subtitle: 'Match device settings automatically',
                  icon: Icons.settings_brightness_rounded,
                  value: 'system',
                  isSelected: currentPref == 'system',
                  onTap: () {
                    themeCtrl.updateThemePreference('system');
                    Get.back();
                  },
                ),
                const SizedBox(height: 12),
                _buildThemeOption(
                  context,
                  title: 'Light Theme',
                  subtitle: 'Always use a light interface',
                  icon: Icons.light_mode_rounded,
                  value: 'light',
                  isSelected: currentPref == 'light',
                  onTap: () {
                    themeCtrl.updateThemePreference('light');
                    Get.back();
                  },
                ),
                const SizedBox(height: 12),
                _buildThemeOption(
                  context,
                  title: 'Dark Theme',
                  subtitle: 'Always use a dark interface',
                  icon: Icons.dark_mode_rounded,
                  value: 'dark',
                  isSelected: currentPref == 'dark',
                  onTap: () {
                    themeCtrl.updateThemePreference('dark');
                    Get.back();
                  },
                ),
                const SizedBox(height: 24),
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
        padding: const EdgeInsets.all(16),
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
            const SizedBox(width: 16),
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
                  const SizedBox(height: 2),
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

  void _showLanguageSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.secondaryBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Language Settings',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your preferred display language.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _buildLangOption('English (US)', 'en'),
              const SizedBox(height: 10),
              _buildLangOption('English (UK)', 'en_GB'),
              const SizedBox(height: 10),
              _buildLangOption('Hindi (India - Beta)', 'hi'),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLangOption(String name, String code) {
    final isSelected = _currentLanguage == name;
    return GestureDetector(
      onTap: () async {
        setState(() => _currentLanguage = name);
        Get.back();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_language_code', code);

        final userId = UserProfileCacheManager.currentUserId;
        if (userId.isNotEmpty) {
          try {
            await _supabase.from('profiles').update({'language': code}).eq('id', userId);
          } catch (_) {}
        }

        Get.snackbar(
          'Language Updated',
          'Display language set to $name.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? context.primaryColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.primaryColor.withOpacity(0.4) : context.borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.language_rounded,
              color: isSelected ? context.primaryColor : context.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? context.primaryColor : context.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: context.primaryColor, size: 20),
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
