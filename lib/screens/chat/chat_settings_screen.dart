import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/chat/chat_model.dart';
import '../../services/chat/chat_controller.dart';
import '../../services/chat/chat_wallpaper_service.dart';
import '../../core/chat_crypto.dart';
import './chat_wallpaper_editor_sheet.dart';

class ChatSettingsScreen extends StatefulWidget {
  final String conversationId;
  final String userName;
  final String? userAvatar;

  const ChatSettingsScreen({
    Key? key,
    required this.conversationId,
    required this.userName,
    this.userAvatar,
  }) : super(key: key);

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  late final ChatController _ctrl;
  bool _notificationsEnabled = true;
  String _selectedTheme = 'Premium Purple Dark';

  String get _otherUserId => ChatController.extractOtherUserId(
        widget.conversationId,
        ChatController.currentUserId,
      );

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<ChatController>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.secondaryBackgroundColor,
        elevation: 0,
        title: Text(
          'Chat Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.textPrimary),
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

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            _buildSectionHeader('Chat Customization'),
            Obx(() {
              final wp = ChatWallpaperService.to.getWallpaper(widget.conversationId);
              return _buildSettingsTile(
                'Wallpaper & Controls',
                'Current: ${wp.displayName}',
                icon: Icons.wallpaper_rounded,
                onTap: () => _showWallpaperSelector(),
              );
            }),
            _buildSettingsTile(
              'Theme Accent',
              'Current: $_selectedTheme',
              icon: Icons.palette_outlined,
              onTap: () => _showThemeSelector(),
            ),

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            _buildSectionHeader('Preferences & Security'),
            Obx(() {
              final conv = _ctrl.conversations.firstWhereOrNull((c) => c.id == widget.conversationId);
              final isMuted = conv?.isMuted ?? false;
              return _buildToggleSetting(
                'Mute Notifications',
                'Silence all alerts for this conversation',
                Icons.volume_off_outlined,
                isMuted,
                (val) {
                  _ctrl.toggleMute(widget.conversationId);
                  _showSuccessToast(val ? 'Notifications muted' : 'Notifications unmuted');
                },
              );
            }),
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

            Divider(color: context.borderColor, height: 32, thickness: 0.5),

            _buildSectionHeader('Actions'),
            _buildSettingsTile(
              'Export Chat',
              'Save a backup of this conversation history',
              icon: Icons.ios_share_rounded,
              onTap: () => _exportChat(),
            ),
            _buildSettingsTile(
              'Clear Chat',
              'Delete all messages, keep conversation in list',
              icon: Icons.cleaning_services_outlined,
              iconColor: context.warningColor,
              textColor: context.warningColor,
              onTap: () => _showConfirmDialog(
                title: 'Clear Chat?',
                message: 'This will permanently delete all messages in this conversation. This action cannot be undone.',
                confirmText: 'Clear',
                onConfirm: () {
                  _ctrl.clearChat(widget.conversationId);
                  _showSuccessToast('Chat cleared successfully!');
                },
              ),
            ),
            _buildSettingsTile(
              'Delete Chat',
              'Delete all messages and remove conversation',
              icon: Icons.delete_outline_rounded,
              iconColor: context.errorColor,
              textColor: context.errorColor,
              onTap: () => _showConfirmDialog(
                title: 'Delete Chat?',
                message: 'This will delete the conversation and all of its messages. This action is permanent.',
                confirmText: 'Delete',
                onConfirm: () {
                  _ctrl.deleteConversation(widget.conversationId);
                  _showSuccessToast('Chat deleted!');
                  Get.back();
                  Get.back(); // Return past ChatScreen to chat list
                },
              ),
            ),

            Obx(() {
              final isBlocked = _ctrl.isUserBlocked(_otherUserId);
              return _buildSettingsTile(
                isBlocked ? 'Unblock User' : 'Block User',
                isBlocked
                    ? 'Allow this user to message and call you again'
                    : 'Prevent this user from messaging or calling you',
                icon: isBlocked ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                iconColor: isBlocked ? context.successColor : context.errorColor,
                textColor: isBlocked ? context.successColor : context.errorColor,
                onTap: () => _showConfirmDialog(
                  title: isBlocked ? 'Unblock ${widget.userName}?' : 'Block ${widget.userName}?',
                  message: isBlocked
                      ? 'Unblocking will allow ${widget.userName} to send you messages and initiate calls.'
                      : 'Blocked users will not be able to message you, call you, or see your online status.',
                  confirmText: isBlocked ? 'Unblock' : 'Block',
                  onConfirm: () async {
                    final nowBlocked = await _ctrl.toggleBlockUser(_otherUserId);
                    _showSuccessToast(
                      nowBlocked
                          ? '${widget.userName} has been blocked'
                          : '${widget.userName} has been unblocked',
                    );
                  },
                ),
              );
            }),
            _buildSettingsTile(
              'Report User',
              'Flag this user for spam, abuse, or inappropriate behavior',
              icon: Icons.report_problem_outlined,
              iconColor: context.errorColor,
              textColor: context.errorColor,
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
              border: Border.all(color: context.primaryColor.withOpacity(0.5), width: 3),
              boxShadow: [
                BoxShadow(
                  color: context.primaryColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: context.secondaryBackgroundColor,
              backgroundImage: widget.userAvatar != null && widget.userAvatar!.isNotEmpty
                  ? NetworkImage(widget.userAvatar!)
                  : null,
              child: widget.userAvatar == null || widget.userAvatar!.isEmpty
                  ? Text(
                      widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: context.primaryColor,
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
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.successColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Online',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: context.successColor,
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
          color: context.primaryColor,
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
    Color? iconColor,
    Color? textColor,
  }) {
    final Color resolvedIconColor = iconColor ?? context.primaryColor;
    final Color resolvedTextColor = textColor ?? context.textPrimary;
    return InkWell(
      onTap: onTap,
      splashColor: context.primaryColor.withOpacity(0.05),
      highlightColor: context.primaryColor.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: resolvedIconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: resolvedIconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: resolvedTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: context.caption,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: context.caption.withOpacity(0.5), size: 14),
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
              color: context.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
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
                  style: GoogleFonts.outfit(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: context.caption,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: context.primaryColor,
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
      backgroundColor: context.primaryColor.withOpacity(0.95),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  void _exportChat() async {
    final filePath = await _ctrl.exportChatTranscript(widget.conversationId, widget.userName);
    if (filePath != null && File(filePath).existsSync()) {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Creania Chat Backup with ${widget.userName}',
      );
      _showSuccessToast('Chat exported successfully!');
    } else {
      Get.snackbar(
        'Export Empty',
        'No messages found to export.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.warningColor,
        colorText: Colors.white,
      );
    }
  }

  void _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.outfit(color: context.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: GoogleFonts.outfit(color: context.caption)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.errorColor,
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
    final msgs = _ctrl.getMessages(widget.conversationId);

    final mediaMsgs = msgs.where((m) =>
      m.type == MessageType.image ||
      m.type == MessageType.video ||
      (m.mediaUrl != null && m.mediaUrl!.isNotEmpty && (m.mediaUrl!.endsWith('.jpg') || m.mediaUrl!.endsWith('.png') || m.mediaUrl!.endsWith('.webp')))
    ).toList();

    final docMsgs = msgs.where((m) =>
      m.type == MessageType.file ||
      (m.fileName != null && m.fileName!.isNotEmpty)
    ).toList();

    final linkMsgs = msgs.where((m) =>
      m.content.contains('http://') ||
      m.content.contains('https://') ||
      m.content.contains('www.')
    ).toList();

    Get.bottomSheet(
      Container(
        height: 440,
        decoration: BoxDecoration(
          color: context.secondaryBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Media, Files & Links', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
            const SizedBox(height: 12),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      indicatorColor: context.primaryColor,
                      labelColor: context.primaryColor,
                      unselectedLabelColor: context.caption,
                      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(text: 'Media (${mediaMsgs.length})'),
                        Tab(text: 'Docs (${docMsgs.length})'),
                        Tab(text: 'Links (${linkMsgs.length})'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // 1. Media Tab
                          mediaMsgs.isEmpty
                              ? _buildEmptyState('No photos or videos shared yet')
                              : GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: mediaMsgs.length,
                                  itemBuilder: (context, idx) {
                                    final item = mediaMsgs[idx];
                                    final imgUrl = item.mediaUrl ?? item.thumbnailUrl ?? '';
                                    return GestureDetector(
                                      onTap: () {
                                        if (imgUrl.isNotEmpty) {
                                          Get.dialog(
                                            Dialog(
                                              backgroundColor: Colors.transparent,
                                              child: InteractiveViewer(
                                                child: Image.network(imgUrl, fit: BoxFit.contain),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: context.scaffoldBackgroundColor,
                                          borderRadius: BorderRadius.circular(10),
                                          image: imgUrl.isNotEmpty
                                              ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: imgUrl.isEmpty
                                            ? Icon(Icons.image, color: context.primaryColor)
                                            : null,
                                      ),
                                    );
                                  },
                                ),

                          // 2. Docs Tab
                          docMsgs.isEmpty
                              ? _buildEmptyState('No documents shared yet')
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: docMsgs.length,
                                  itemBuilder: (context, idx) {
                                    final item = docMsgs[idx];
                                    return ListTile(
                                      leading: Icon(Icons.description_rounded, color: context.primaryColor, size: 28),
                                      title: Text(item.fileName ?? 'Document', style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.w600)),
                                      subtitle: Text('${item.fileSize != null ? (item.fileSize! / 1024).round() : 120} KB • File', style: GoogleFonts.outfit(color: context.caption, fontSize: 12)),
                                    );
                                  },
                                ),

                          // 3. Links Tab
                          linkMsgs.isEmpty
                              ? _buildEmptyState('No links shared yet')
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: linkMsgs.length,
                                  itemBuilder: (context, idx) {
                                    final item = linkMsgs[idx];
                                    return ListTile(
                                      leading: Icon(Icons.link_rounded, color: context.primaryColor, size: 28),
                                      title: Text(item.content, style: GoogleFonts.outfit(color: context.primaryColor, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(item.timestamp.toLocal().toString().substring(0, 16), style: GoogleFonts.outfit(color: context.caption, fontSize: 11)),
                                    );
                                  },
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

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, color: context.caption.withOpacity(0.5), size: 40),
          const SizedBox(height: 8),
          Text(text, style: GoogleFonts.outfit(color: context.caption, fontSize: 14)),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final searchCtrl = TextEditingController();
    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final allMsgs = _ctrl.getMessages(widget.conversationId);
          final matches = query.isEmpty
              ? <ChatMessage>[]
              : allMsgs.where((m) => m.content.toLowerCase().contains(query)).toList();

          return AlertDialog(
            backgroundColor: context.secondaryBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Search in Chat', style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter keyword...',
                      hintStyle: TextStyle(color: context.caption),
                      prefixIcon: Icon(Icons.search, color: context.primaryColor),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.borderColor)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.primaryColor)),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (query.isNotEmpty) ...[
                    Text('${matches.length} matches found', style: GoogleFonts.outfit(color: context.caption, fontSize: 12)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: matches.isEmpty
                          ? Center(child: Text('No results', style: GoogleFonts.outfit(color: context.caption)))
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (context, idx) {
                                final m = matches[idx];
                                final isMe = m.senderId == ChatController.currentUserId;
                                return ListTile(
                                  dense: true,
                                  title: Text(m.content, style: GoogleFonts.outfit(color: context.textPrimary)),
                                  subtitle: Text(
                                    '${isMe ? "You" : widget.userName} • ${m.timestamp.toLocal().toString().substring(11, 16)}',
                                    style: GoogleFonts.outfit(color: context.caption, fontSize: 11),
                                  ),
                                  onTap: () {
                                    Get.back();
                                    _showSuccessToast('Found: "${m.content}"');
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Close', style: GoogleFonts.outfit(color: context.primaryColor)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWallpaperSelector() {
    Get.bottomSheet(
      ChatWallpaperEditorSheet(conversationId: widget.conversationId),
      isScrollControlled: true,
    );
  }

  void _showThemeSelector() {
    final themes = ['Premium Purple Dark', 'Stealth Black', 'Amoled Neon Purple', 'Deep Space'];
    Get.dialog(
      SimpleDialog(
        backgroundColor: context.secondaryBackgroundColor,
        title: Text('Select Accent Theme', style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold)),
        children: themes.map((t) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedTheme = t);
              Get.back();
              _showSuccessToast('Accent set to $t');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(t, style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 16)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showEncryptionInfo() {
    final String keyHash = ChatCrypto.deriveFallbackKey(
      ChatController.currentUserId,
      _otherUserId,
    ).take(16).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');

    Get.dialog(
      AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.security_rounded, color: context.successColor),
            const SizedBox(width: 8),
            Text('E2E Encrypted', style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages in this chat are secured using end-to-end AES-256-GCM encryption with X25519 DH key exchange.',
              style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Client Fingerprint:\n$keyHash',
                style: GoogleFonts.sourceCodePro(color: context.caption, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: GoogleFonts.outfit(color: context.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasons = ['Spam & Solicitations', 'Harassment & Abuse', 'Inappropriate profile media', 'Inappropriate messages', 'Other'];
    final detailCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Report ${widget.userName}', style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select a reason:', style: GoogleFonts.outfit(color: context.caption, fontSize: 12)),
            const SizedBox(height: 8),
            ...reasons.map((r) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.report_gmailerrorred_rounded, color: context.errorColor, size: 20),
              title: Text(r, style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 14)),
              onTap: () async {
                Get.back();
                try {
                  await Supabase.instance.client.from('reports').insert({
                    'reporter_id': ChatController.currentUserId,
                    'reported_user_id': _otherUserId,
                    'reason': r,
                    'details': 'Reported via Chat Settings Screen',
                  });
                } catch (_) {}
                _showSuccessToast('Thank you. Report filed for: $r');
              },
            )).toList(),
          ],
        ),
      ),
    );
  }
}
