import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = true;
  bool _privateProfile = false;
  bool _allowMessages = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            _buildSectionHeader(context, 'Account'),
            _buildSettingsTile(
              context,
              'Email Address',
              'user@example.com',
              onTap: () {},
            ),
            _buildSettingsTile(
              context,
              'Phone Number',
              '+91 98765 43210',
              onTap: () {},
            ),
            _buildSettingsTile(
              context,
              'Change Password',
              'Update your password',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // Notifications Section
            _buildSectionHeader(context, 'Notifications'),
            _buildToggleSetting(
              context,
              'Push Notifications',
              'Receive notifications from AgoraX',
              _notificationsEnabled,
              (value) {
                setState(() => _notificationsEnabled = value);
              },
            ),
            _buildSettingsTile(
              context,
              'Notification Preferences',
              'Customize your notifications',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // Privacy & Security Section
            _buildSectionHeader(context, 'Privacy & Security'),
            _buildToggleSetting(
              context,
              'Private Profile',
              'Only followers can see your profile',
              _privateProfile,
              (value) {
                setState(() => _privateProfile = value);
              },
            ),
            _buildToggleSetting(
              context,
              'Allow Messages',
              'Allow anyone to message you',
              _allowMessages,
              (value) {
                setState(() => _allowMessages = value);
              },
            ),
            _buildSettingsTile(
              context,
              'Blocked Users',
              'Manage blocked users',
              onTap: () {},
            ),
            _buildSettingsTile(
              context,
              'Two-Factor Authentication',
              'Add extra security to your account',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // Display Section
            _buildSectionHeader(context, 'Display'),
            _buildToggleSetting(
              context,
              'Dark Mode',
              'Currently enabled',
              _darkModeEnabled,
              (value) {
                setState(() => _darkModeEnabled = value);
              },
            ),
            _buildSettingsTile(
              context,
              'Language',
              'English (US)',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader(context, 'About'),
            _buildSettingsTile(
              context,
              'About AgoraX',
              'Learn more about us',
              onTap: () {},
            ),
            _buildSettingsTile(
              context,
              'Terms & Conditions',
              'Read our terms',
              onTap: () {},
            ),
            _buildSettingsTile(
              context,
              'Privacy Policy',
              'Read our privacy policy',
              onTap: () {},
            ),
            _buildSettingsTile(
              context,
              'Version',
              'v1.0.0',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // Danger Zone
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Get.defaultDialog(
                          title: 'Sign Out?',
                          middleText:
                              'Are you sure you want to sign out of your account?',
                          confirm: ElevatedButton(
                            onPressed: () => Get.back(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                            ),
                            child: const Text('Sign Out'),
                          ),
                          cancel: OutlinedButton(
                            onPressed: () => Get.back(),
                            child: const Text('Cancel'),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppTheme.errorColor,
                        ),
                      ),
                      child: Text(
                        'Sign Out',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Get.defaultDialog(
                          title: 'Delete Account?',
                          middleText:
                              'Deleting your account is permanent and cannot be undone.',
                          confirm: ElevatedButton(
                            onPressed: () => Get.back(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                            ),
                            child: const Text('Delete'),
                          ),
                          cancel: OutlinedButton(
                            onPressed: () => Get.back(),
                            child: const Text('Cancel'),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppTheme.errorColor,
                        ),
                      ),
                      child: Text(
                        'Delete Account',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.primaryColor,
            ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderColor,
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSetting(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
