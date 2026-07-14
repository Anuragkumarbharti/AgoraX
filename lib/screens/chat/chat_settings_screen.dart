import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class ChatSettingsScreen extends StatefulWidget {
  final String userName;
  final String? userAvatar;

  const ChatSettingsScreen({
    Key? key,
    required this.userName,
    this.userAvatar,
  }) : super(key: key);

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isMuted = false;
  String _selectedWallpaper = 'Default Dark';
  String _selectedTheme = 'Premium Purple Dark';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgLight,
        elevation: 0,
        title: Text(
          'Chat Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildProfileHeader(),
            const SizedBox(height: 20),
            
            _buildSectionHeader('Shared Media & Search'),
            _buildSettingsTile(
              'Media, Files & Links',
              'View photos, documents, and links shared in this chat',
              icon: Icons.perm_media_outlined,
              onTap: () => _showMediaBottomSheet(),
            ),
            _buildSettingsTile(
              'Search in Conversation',
              'Find messages, links, or keywords',
              icon: Icons.search_rounded,
              onTap: () => _showSearchDialog(),
            ),

            const Divider(color: AppTheme.borderColor, height: 32, thickness: 0.5),

            _buildSectionHeader('Chat Customization'),
            _buildSettingsTile(
              'Wallpaper',
              'Current: $_selectedWallpaper',
              icon: Icons.wallpaper_rounded,
              onTap: () => _showWallpaperSelector(),
            ),
            _buildSettingsTile(
              'Theme Accent',
              'Current: $_selectedTheme',
              icon: Icons.palette_outlined,
              onTap: () => _showThemeSelector(),
            ),

            const Divider(color: AppTheme.borderColor, height: 32, thickness: 0.5),

            _buildSectionHeader('Preferences & Security'),
            _buildToggleSetting(
              'Mute Notifications',
              'Silence all alerts for this conversation',
              Icons.volume_off_outlined,
              _isMuted,
              (val) => setState(() => _isMuted = val),
            ),
            _buildToggleSetting(
              'High Priority Alerts',
              'Show notifications at the top of the screen',
              Icons.notifications_active_outlined,
              _notificationsEnabled,
              (val) => setState(() => _notificationsEnabled = val),
            ),
            _buildSettingsTile(
              'Encryption Information',
              'End-to-End Encrypted (AES-256-GCM). Tap to verify keys.',
              icon: Icons.lock_outline_rounded,
              onTap: () => _showEncryptionInfo(),
            ),

            const Divider(color: AppTheme.borderColor, height: 32, thickness: 0.5),

            _buildSectionHeader('Actions'),
            _buildSettingsTile(
              'Export Chat',
              'Save a backup of this conversation history',
              icon: Icons.ios_share_rounded,
              onTap: () => _showSuccessToast('Chat exported successfully!'),
            ),
            _buildSettingsTile(
              'Clear Chat',
              'Delete all messages, keep conversation in list',
              icon: Icons.cleaning_services_outlined,
              iconColor: AppTheme.warningColor,
              textColor: AppTheme.warningColor,
              onTap: () => _showConfirmDialog(
                title: 'Clear Chat?',
                message: 'This will permanently delete all messages in this conversation. This action cannot be undone.',
                confirmText: 'Clear',
                onConfirm: () => _showSuccessToast('Chat cleared'),
              ),
            ),
            _buildSettingsTile(
              'Delete Chat',
              'Delete all messages and remove conversation',
              icon: Icons.delete_outline_rounded,
              iconColor: AppTheme.errorColor,
              textColor: AppTheme.errorColor,
              onTap: () => _showConfirmDialog(
                title: 'Delete Chat?',
                message: 'This will delete the conversation and all of its messages. This action is permanent.',
                confirmText: 'Delete',
                onConfirm: () {
                  _showSuccessToast('Chat deleted');
                  Get.back(); // Go back to chats list
                },
              ),
            ),
            _buildSettingsTile(
              'Block User',
              'Prevent this user from messaging or calling you',
              icon: Icons.block_rounded,
              iconColor: AppTheme.errorColor,
              textColor: AppTheme.errorColor,
              onTap: () => _showConfirmDialog(
                title: 'Block ${widget.userName}?',
                message: 'Blocked users will not be able to message you, call you, or see your online status.',
                confirmText: 'Block',
                onConfirm: () => _showSuccessToast('${widget.userName} has been blocked'),
              ),
            ),
            _buildSettingsTile(
              'Report User',
              'Flag this user for spam, abuse, or inappropriate behavior',
              icon: Icons.report_problem_outlined,
              iconColor: AppTheme.errorColor,
              textColor: AppTheme.errorColor,
              onTap: () => _showReportDialog(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: AppTheme.bgLight,
              backgroundImage: widget.userAvatar != null && widget.userAvatar!.isNotEmpty
                  ? NetworkImage(widget.userAvatar!)
                  : null,
              child: widget.userAvatar == null || widget.userAvatar!.isEmpty
                  ? Text(
                      widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.userName,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Online',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    String title,
    String subtitle, {
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppTheme.primaryColor,
    Color textColor = AppTheme.textPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: AppTheme.primaryColor.withOpacity(0.05),
      highlightColor: AppTheme.primaryColor.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textTertiary.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSetting(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showSuccessToast(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  void _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Get.back();
              onConfirm();
            },
            child: Text(confirmText, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMediaBottomSheet() {
    Get.bottomSheet(
      Container(
        height: 400,
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Media, Files & Links', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      indicatorColor: AppTheme.primaryColor,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textTertiary,
                      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: 'Media (12)'),
                        Tab(text: 'Docs (4)'),
                        Tab(text: 'Links (2)'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Media Grid
                          GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: 9,
                            itemBuilder: (context, idx) => Container(
                              decoration: BoxDecoration(
                                color: AppTheme.bgDark,
                                borderRadius: BorderRadius.circular(8),
                                image: const DecorationImage(
                                  image: NetworkImage('https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=120'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          // Docs list
                          ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: 4,
                            itemBuilder: (context, idx) => ListTile(
                              leading: const Icon(Icons.description_outlined, color: AppTheme.primaryColor),
                              title: Text('study_material_unit_${idx+1}.pdf', style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
                              subtitle: Text('1.8 MB • PDF', style: GoogleFonts.outfit(color: AppTheme.textTertiary, fontSize: 12)),
                            ),
                          ),
                          // Links list
                          ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: 2,
                            itemBuilder: (context, idx) => ListTile(
                              leading: const Icon(Icons.link_rounded, color: AppTheme.primaryColor),
                              title: Text(idx == 0 ? 'github.com/creania/app' : 'meet.google.com/abc-xyz', style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
                              subtitle: Text('Added 2 days ago', style: GoogleFonts.outfit(color: AppTheme.textTertiary, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    final searchCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Search in Chat', style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: searchCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter keyword...',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              Get.back();
              _showSuccessToast('Found 3 matches for "${searchCtrl.text}"');
            },
            child: Text('Search', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showWallpaperSelector() {
    final wallpapers = ['Default Dark', 'Premium Purple', 'Space Blue', 'Solid Pitch Black', 'Light Lavender'];
    Get.dialog(
      SimpleDialog(
        backgroundColor: AppTheme.bgLight,
        title: Text('Select Wallpaper', style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        children: wallpapers.map((w) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedWallpaper = w);
              Get.back();
              _showSuccessToast('Wallpaper changed to $w');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(w, style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 16)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showThemeSelector() {
    final themes = ['Premium Purple Dark', 'Stealth Black', 'Amoled Neon Purple', 'Deep Space'];
    Get.dialog(
      SimpleDialog(
        backgroundColor: AppTheme.bgLight,
        title: Text('Select Accent Theme', style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        children: themes.map((t) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedTheme = t);
              Get.back();
              _showSuccessToast('Accent set to $t');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(t, style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 16)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showEncryptionInfo() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppTheme.successColor),
            const SizedBox(width: 8),
            Text('E2E Encrypted', style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages sent to this chat are protected with client-side end-to-end encryption.',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'SHA-256 Fingerprint:\n5F:8B:D2:C1:2E:7A:F4:3B:11:C2:5E:A9:77:BD:41:FF',
                style: GoogleFonts.sourceCodePro(color: AppTheme.textTertiary, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasons = ['Spam & Solicitations', 'Harassment & Abuse', 'Inappropriate profile media', 'Inappropriate messages', 'Other'];
    Get.dialog(
      SimpleDialog(
        backgroundColor: AppTheme.bgLight,
        title: Text('Report User', style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        children: reasons.map((r) {
          return SimpleDialogOption(
            onPressed: () {
              Get.back();
              _showSuccessToast('Thank you. Report filed for: $r');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(r, style: GoogleFonts.outfit(color: AppTheme.errorColor.withOpacity(0.8), fontSize: 15)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
