import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/chat_model.dart';
import '../../services/chat_controller.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({Key? key}) : super(key: key);

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen>
    with SingleTickerProviderStateMixin {
  late final ChatController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();
  late final AnimationController _fabAnimCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ChatController());
    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _searchCtrl.addListener(() {
      _ctrl.searchQuery.value = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fabAnimCtrl.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return DateFormat('h:mm a').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildOnlineRow(),
            const SizedBox(height: 8),
            Expanded(child: _buildConversationList()),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnimCtrl, curve: Curves.elasticOut),
        child: FloatingActionButton(
          onPressed: _showNewMessageSheet,
          backgroundColor: AppTheme.primaryColor,
          elevation: 4,
          child: const Icon(Icons.edit_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(() {
      final unread = _ctrl.totalUnread;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Messages',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  unread > 0
                      ? '$unread unread message${unread > 1 ? 's' : ''}'
                      : 'All caught up! ✅',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _headerBtn(Icons.filter_list_rounded, () {}),
            const SizedBox(width: 4),
            _headerBtn(Icons.more_vert_rounded, _showOptionsMenu),
          ],
        ),
      );
    });
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Obx(() => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _ctrl.isSearching.value
                  ? AppTheme.primaryColor.withOpacity(0.6)
                  : AppTheme.borderColor,
              width: _ctrl.isSearching.value ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                color: _ctrl.isSearching.value
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onTap: () => _ctrl.isSearching.value = true,
                  onSubmitted: (_) => _ctrl.isSearching.value = false,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: TextStyle(
                        color: AppTheme.textTertiary, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    _ctrl.isSearching.value = false;
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12,
                        color: AppTheme.textTertiary),
                  ),
                ),
            ],
          ),
        ));
  }

  Widget _buildOnlineRow() {
    return Obx(() {
      final onlineConvs =
          _ctrl.conversations.where((c) => c.otherUserOnline).toList();
      if (onlineConvs.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: onlineConvs.length,
          itemBuilder: (context, i) {
            final conv = onlineConvs[i];
            return GestureDetector(
              onTap: () => _openChat(conv),
              child: Container(
                width: 72,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        _buildAvatar(conv.otherUserAvatar, conv.otherUserName,
                            size: 52),
                        Positioned(
                          bottom: 1,
                          right: 1,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.bgDark, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      conv.otherUserName.split(' ').first,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildConversationList() {
    return Obx(() {
      final convs = _ctrl.filteredConversations;
      if (convs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    color: AppTheme.primaryColor, size: 48),
              ),
              const SizedBox(height: 16),
              const Text('No conversations yet',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Start a new chat with someone!',
                  style: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 14)),
            ],
          ),
        );
      }

      // Pinned first
      final pinned = convs.where((c) => c.isPinned).toList();
      final rest = convs.where((c) => !c.isPinned).toList();

      return ListView(
        children: [
          if (pinned.isNotEmpty) ...[
            _sectionLabel('📌 Pinned'),
            ...pinned.map((c) => _conversationTile(c)),
          ],
          if (rest.isNotEmpty) ...[
            if (pinned.isNotEmpty) _sectionLabel('Recent'),
            ...rest.map((c) => _conversationTile(c)),
          ],
          const SizedBox(height: 100),
        ],
      );
    });
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _conversationTile(Conversation conv) {
    final isMe = conv.lastMessageSenderId == ChatController.currentUserId;
    final lastMsgPrefix = isMe ? 'You: ' : '';

    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded,
                color: AppTheme.errorColor, size: 24),
            SizedBox(height: 4),
            Text('Delete',
                style:
                    TextStyle(color: AppTheme.errorColor, fontSize: 11)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await _showDeleteDialog(conv);
      },
      onDismissed: (_) => _ctrl.deleteConversation(conv.id),
      child: GestureDetector(
        onTap: () => _openChat(conv),
        onLongPress: () => _showConvOptions(conv),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: conv.unreadCount > 0
                ? AppTheme.primaryColor.withOpacity(0.05)
                : AppTheme.bgDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: conv.unreadCount > 0
                  ? AppTheme.primaryColor.withOpacity(0.15)
                  : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar + online indicator
                Stack(
                  children: [
                    _buildAvatar(
                        conv.otherUserAvatar, conv.otherUserName,
                        size: 54),
                    if (conv.otherUserOnline)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppTheme.bgDark, width: 2),
                          ),
                        ),
                      ),
                    if (conv.isPinned)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppTheme.bgDark, width: 1.5),
                          ),
                          child: const Icon(Icons.push_pin_rounded,
                              size: 8, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    conv.otherUserName,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: conv.unreadCount > 0
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (conv.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified_rounded,
                                      color: Color(0xFF60A5FA), size: 14),
                                ],
                                if (conv.isMuted) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.volume_off_rounded,
                                      color: AppTheme.textTertiary,
                                      size: 12),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(conv.lastMessageTime),
                            style: TextStyle(
                              color: conv.unreadCount > 0
                                  ? AppTheme.primaryColor
                                  : AppTheme.textTertiary,
                              fontSize: 12,
                              fontWeight: conv.unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isMe) ...[
                            const Icon(Icons.done_all_rounded,
                                size: 14,
                                color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              '$lastMsgPrefix${conv.lastMessage}',
                              style: TextStyle(
                                color: conv.unreadCount > 0
                                    ? AppTheme.textSecondary
                                    : AppTheme.textTertiary,
                                fontSize: 13,
                                fontWeight: conv.unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (conv.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.secondaryColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                conv.unreadCount > 99
                                    ? '99+'
                                    : '${conv.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, String name, {double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.7),
            AppTheme.secondaryColor.withOpacity(0.5),
          ],
        ),
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initialsWidget(name, size),
                errorWidget: (_, __, ___) => _initialsWidget(name, size),
              )
            : _initialsWidget(name, size),
      ),
    );
  }

  Widget _initialsWidget(String name, double size) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';
    return Container(
      width: size,
      height: size,
      color: AppTheme.primaryColor.withOpacity(0.2),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.3,
          ),
        ),
      ),
    );
  }

  void _openChat(Conversation conv) {
    _ctrl.markConversationRead(conv.id);
    Get.to(
      () => ChatScreen(conversation: conv),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _showNewMessageSheet() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Message',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const TextField(
                autofocus: true,
                style:
                    TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search for a user...',
                  hintStyle: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: AppTheme.textTertiary, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Suggestions',
                style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, i) {
                  final names = [
                    'Priya',
                    'Rahul',
                    'Ananya',
                    'Dev',
                    'Meera'
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppTheme.primaryColor.withOpacity(0.2),
                          child: Text(names[i][0],
                              style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 4),
                        Text(names[i],
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showConvOptions(Conversation conv) {
    HapticFeedback.mediumImpact();
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                _buildAvatar(conv.otherUserAvatar, conv.otherUserName, size: 44),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conv.otherUserName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text(
                        conv.otherUserOnline ? '🟢 Online' : '⚫ Offline',
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppTheme.borderColor, height: 1),
            const SizedBox(height: 12),
            _optionTile(
              icon: conv.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: AppTheme.warningColor,
              label: conv.isPinned ? 'Unpin Chat' : 'Pin Chat',
              onTap: () {
                _ctrl.togglePin(conv.id);
                Get.back();
              },
            ),
            _optionTile(
              icon: conv.isMuted
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: AppTheme.textSecondary,
              label: conv.isMuted ? 'Unmute' : 'Mute Notifications',
              onTap: () {
                _ctrl.toggleMute(conv.id);
                Get.back();
              },
            ),
            _optionTile(
              icon: Icons.mark_chat_read_rounded,
              color: AppTheme.accentColor,
              label: 'Mark as Read',
              onTap: () {
                _ctrl.markConversationRead(conv.id);
                Get.back();
              },
            ),
            _optionTile(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.errorColor,
              label: 'Delete Conversation',
              onTap: () async {
                Get.back();
                final confirm = await _showDeleteDialog(conv);
                if (confirm == true) _ctrl.deleteConversation(conv.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
    );
  }

  Future<bool?> _showDeleteDialog(Conversation conv) {
    return Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppTheme.bgLight,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Conversation',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
            'Delete your chat with ${conv.otherUserName}? This cannot be undone.',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _optionTile(
              icon: Icons.mark_chat_read_rounded,
              color: AppTheme.accentColor,
              label: 'Mark all as Read',
              onTap: () {
                for (final c in _ctrl.conversations) {
                  _ctrl.markConversationRead(c.id);
                }
                Get.back();
              },
            ),
            _optionTile(
              icon: Icons.archive_outlined,
              color: AppTheme.textSecondary,
              label: 'Archived Chats',
              onTap: () => Get.back(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
