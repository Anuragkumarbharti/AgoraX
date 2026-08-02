import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../services/user_profile_cache_manager.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Settings states
  bool _muteAll = false;
  bool _messages = true;
  bool _followers = true;
  bool _community = true;
  bool _voiceRooms = true;
  bool _quiz = true;
  bool _wallet = true;
  bool _security = true;
  bool _marketing = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    try {
      final response = await _supabase
          .from('notification_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _muteAll = response['mute_all'] ?? false;
          _messages = response['messages'] ?? true;
          _followers = response['followers'] ?? true;
          _community = response['community'] ?? true;
          _voiceRooms = response['voice_rooms'] ?? true;
          _quiz = response['quiz'] ?? true;
          _wallet = response['wallet'] ?? true;
          _security = response['security'] ?? true;
          _marketing = response['marketing'] ?? true;
          _isLoading = false;
        });
      } else {
        // If row doesn't exist yet, insert default settings row
        await _supabase.from('notification_settings').insert({
          'user_id': userId,
        });
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading notification settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    setState(() {
      if (key == 'mute_all') _muteAll = value;
      if (key == 'messages') _messages = value;
      if (key == 'followers') _followers = value;
      if (key == 'community') _community = value;
      if (key == 'voice_rooms') _voiceRooms = value;
      if (key == 'quiz') _quiz = value;
      if (key == 'wallet') _wallet = value;
      if (key == 'security') _security = value;
      if (key == 'marketing') _marketing = value;
    });

    try {
      await _supabase.from('notification_settings').upsert({
        'user_id': userId,
        key: value,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Error updating notification setting: $e');
      Get.snackbar('Error', 'Failed to save settings: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white);
      // Rollback on failure
      _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A10) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildSectionHeader('General Preferences'),
                _buildSwitchTile(
                  title: 'Mute All Notifications',
                  subtitle: 'Silence all incoming push notification banners',
                  icon: Icons.do_not_disturb_on_outlined,
                  value: _muteAll,
                  onChanged: (val) => _updateSetting('mute_all', val),
                  isCritical: true,
                ),
                const SizedBox(height: 16),
                
                // Content settings are disabled if mute_all is on
                AnimatedOpacity(
                  opacity: _muteAll ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: _muteAll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Channels'),
                        _buildSwitchTile(
                          title: 'Direct Messages & Chats',
                          subtitle: 'Alerts for private chat and group messages',
                          icon: Icons.chat_bubble_outline_rounded,
                          value: _messages,
                          onChanged: (val) => _updateSetting('messages', val),
                        ),
                        _buildSwitchTile(
                          title: 'Followers & Friends',
                          subtitle: 'New follow and friend request approvals',
                          icon: Icons.person_add_alt_1_outlined,
                          value: _followers,
                          onChanged: (val) => _updateSetting('followers', val),
                        ),
                        _buildSwitchTile(
                          title: 'Community Notifications',
                          subtitle: 'Post announcements, invites, and community polls',
                          icon: Icons.people_outline_rounded,
                          value: _community,
                          onChanged: (val) => _updateSetting('community', val),
                        ),
                        _buildSwitchTile(
                          title: 'Voice Rooms',
                          subtitle: 'Invites to speak and room start alerts',
                          icon: Icons.spatial_audio_off_rounded,
                          value: _voiceRooms,
                          onChanged: (val) => _updateSetting('voice_rooms', val),
                        ),
                        _buildSwitchTile(
                          title: 'Educational Quizzes',
                          subtitle: 'Daily quizzes, test reminders, and rewards',
                          icon: Icons.quiz_outlined,
                          value: _quiz,
                          onChanged: (val) => _updateSetting('quiz', val),
                        ),
                        _buildSwitchTile(
                          title: 'Wallet & Coins Transactions',
                          subtitle: 'Credits, withdrawals, refunds, and recharges',
                          icon: Icons.account_balance_wallet_outlined,
                          value: _wallet,
                          onChanged: (val) => _updateSetting('wallet', val),
                        ),
                        _buildSwitchTile(
                          title: 'Promotional & Marketing',
                          subtitle: 'Custom discount vouchers, events, and contests',
                          icon: Icons.local_offer_outlined,
                          value: _marketing,
                          onChanged: (val) => _updateSetting('marketing', val),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                _buildSectionHeader('Security Alert System (Non-mutable)'),
                _buildSwitchTile(
                  title: 'Security & Auth Alerts',
                  subtitle: 'Login status detection, OTP, and account alerts',
                  icon: Icons.security_rounded,
                  value: _security,
                  onChanged: null, // Always active
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor.withOpacity(0.8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool isCritical = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12121E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(
          icon,
          color: isCritical 
              ? Colors.amberAccent 
              : (value ? AppTheme.primaryColor : Colors.grey[500]),
          size: 24,
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white54 : Colors.black45,
            fontSize: 12,
          ),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
