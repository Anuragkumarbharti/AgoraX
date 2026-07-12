import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../widgets/send_gift_dialog.dart';
import '../../core/theme.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_controller.dart';
import '../profile/user_profile_screen.dart';
import '../../services/vip_controller.dart';
import '../../widgets/vip_badge_widget.dart';
import '../../widgets/vip_avatar_decorator.dart';
import '../../services/novel_controller.dart';
import '../../widgets/novel_badge_widget.dart';
import '../../widgets/novel_avatar_decorator.dart';
import '../../widgets/custom_avatar_frame.dart';
import '../../services/customization_controller.dart';
import '../../services/premium_identity_controller.dart';
import '../../widgets/index.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({Key? key, required this.conversation}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  late final ChatController _ctrl;
  final CustomizationController _custCtrl = Get.find<CustomizationController>();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final RxBool _showEmoji = false.obs;
  final RxBool _showAttachOptions = false.obs;
  final RxString _replyToId = ''.obs;
  final RxString _replyToContent = ''.obs;
  final RxBool _hasText = false.obs;
  Timer? _typingTimer;

  late final AnimationController _sendBtnCtrl;

  static const List<String> _quickEmojis = [
    '❤️', '😂', '😍', '🔥', '👏', '😮', '😢', '🙏'
  ];

  static const List<Map<String, dynamic>> _reactionEmojis = [
    {'emoji': '❤️', 'label': 'Love'},
    {'emoji': '😂', 'label': 'Haha'},
    {'emoji': '😮', 'label': 'Wow'},
    {'emoji': '😢', 'label': 'Sad'},
    {'emoji': '🔥', 'label': 'Fire'},
    {'emoji': '👏', 'label': 'Clap'},
    {'emoji': '🙏', 'label': 'Thanks'},
    {'emoji': '💯', 'label': '100'},
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<ChatController>();
    _sendBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _msgCtrl.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _sendBtnCtrl.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _msgCtrl.text.trim().isNotEmpty;
    _hasText.value = hasText;
    if (hasText) {
      _sendBtnCtrl.forward();
    } else {
      _sendBtnCtrl.reverse();
    }
    _ctrl.setTyping(widget.conversation.id, hasText);
    _typingTimer?.cancel();
    if (hasText) {
      _typingTimer =
          Timer(const Duration(seconds: 3), () => _ctrl.setTyping(widget.conversation.id, false));
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollCtrl.hasClients) return;
    if (animated) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.sendMessage(widget.conversation.id, text);
    _msgCtrl.clear();
    _hasText.value = false;
    _replyToId.value = '';
    _replyToContent.value = '';
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _setReply(ChatMessage msg) {
    _replyToId.value = msg.id;
    _replyToContent.value = msg.content;
    _focusNode.requestFocus();
  }

  void _clearReply() {
    _replyToId.value = '';
    _replyToContent.value = '';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'Today';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(dt);
  }

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildMessageList()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final conv = widget.conversation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 20),
            onPressed: () => Get.back(),
          ),
          GestureDetector(
            onTap: _navigateToUserProfile,
            child: Stack(
              children: [
                _buildAvatar(conv.otherUserAvatar, conv.otherUserName,
                    size: 42),
                if (conv.otherUserOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppTheme.bgLight, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _navigateToUserProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumNameWidget(
                    name: conv.otherUserName,
                    userId: '',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Obx(() {
                    final isTyping =
                        _ctrl.typingState[widget.conversation.id] ?? false;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isTyping
                          ? const Text(
                              'typing...',
                              key: ValueKey('typing'),
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Text(
                              conv.otherUserOnline ? '🟢 Online' : 'Offline',
                              key: const ValueKey('status'),
                              style: const TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                    );
                  }),
                ],
              ),
            ),
          ),
          _appBarBtn(Icons.more_vert_rounded, _showChatOptions),
        ],
      ),
    );
  }

  Widget _appBarBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppTheme.textSecondary, size: 22),
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildMessageList() {
    return Obx(() {
      final messages = _ctrl.getMessages(widget.conversation.id);
      return GestureDetector(
        onTap: () {
          _focusNode.unfocus();
          _showEmoji.value = false;
          _showAttachOptions.value = false;
        },
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final prevMsg = index > 0 ? messages[index - 1] : null;
            final isMe = msg.senderId == ChatController.currentUserId;

            // Date separator
            final showDateSep = prevMsg == null ||
                !_isSameDay(msg.timestamp, prevMsg.timestamp);

            return Column(
              children: [
                if (showDateSep) _buildDateSeparator(msg.timestamp),
                _buildMessageBubble(msg, isMe),
              ],
            );
          },
        ),
      );
    });
  }

  Widget _buildDateSeparator(DateTime dt) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: AppTheme.borderColor, height: 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              _formatDate(dt),
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(
              child: Divider(color: AppTheme.borderColor, height: 1)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showMessageOptions(msg, isMe);
      },
      onDoubleTap: () {
        _ctrl.addReaction(widget.conversation.id, msg.id, '❤️');
        HapticFeedback.lightImpact();
      },
      child: Padding(
        padding: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              _buildSmallAvatar(),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Reply preview
                  if (msg.replyToContent != null && !msg.isDeleted)
                    _buildReplyPreview(msg.replyToContent!, isMe),

                  // Bubble
                  Obx(() {
                    final activeBubbleVal = _custCtrl.activeBubble.value;
                    String theme = 'Default';
                    if (isMe) {
                      final activeBubble = activeBubbleVal;
                      if (activeBubble.contains('VIP') || activeBubble.contains('Gold')) {
                        theme = 'VIP';
                      } else if (activeBubble.contains('Galaxy')) {
                        theme = 'Novel';
                      } else if (activeBubble.contains('Luxury') || activeBubble.contains('Cosmic')) {
                        theme = 'Luxury';
                      } else if (activeBubble.contains('Love') || activeBubble.contains('Event')) {
                        theme = 'Event';
                      } else if (activeBubble.contains('Official')) {
                        theme = 'Official';
                      }
                    } else {
                      final otherNovel = PremiumEffectsResolver.getNovelLevel('', widget.conversation.otherUserName);
                      final otherVip = PremiumEffectsResolver.getVipLevel('', widget.conversation.otherUserName);
                      if (otherNovel > 0) {
                        theme = 'Novel';
                      } else if (otherVip > 0) {
                        theme = 'VIP';
                      }
                    }

                    return PremiumChatBubble(
                      isMe: isMe,
                      theme: theme,
                      isDeleted: msg.isDeleted,
                      isSending: msg.status == MessageStatus.sending,
                      child: msg.isDeleted
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.block_rounded,
                                    size: 14,
                                    color: AppTheme.textTertiary),
                                SizedBox(width: 6),
                                Text(
                                  'This message was deleted',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.content,
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                if (msg.isEdited) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'edited',
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white.withOpacity(0.6)
                                          : AppTheme.textTertiary,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    );
                  }),

                  // Timestamp + status
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(msg.timestamp),
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                        if (isMe && !msg.isDeleted) ...[
                          const SizedBox(width: 4),
                          _buildStatusIcon(msg.status),
                        ],
                      ],
                    ),
                  ),

                  // Reactions
                  if (msg.reactions != null && msg.reactions!.isNotEmpty)
                    _buildReactions(msg, isMe),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Decoration _getBubbleDecoration(bool isMe, bool isDeleted) {
    if (isDeleted) {
      return BoxDecoration(
        color: AppTheme.bgLight.withOpacity(0.5),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
      );
    }

    final _custCtrl = Get.find<CustomizationController>();

    if (isMe) {
      final activeBubble = _custCtrl.activeBubble.value;
      
      List<Color> colors = [AppTheme.primaryColor, AppTheme.secondaryColor];
      BoxBorder? border;
      List<BoxShadow>? shadows = [
        BoxShadow(
          color: AppTheme.primaryColor.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        )
      ];

      if (activeBubble == 'Classic Bubble' || activeBubble == 'Standard Bubble' || activeBubble == 'Normal' || activeBubble == 'None') {
        // Standard gradient
        colors = [AppTheme.primaryColor, AppTheme.secondaryColor];
        border = null;
      } else if (activeBubble.contains('Blue Shield')) {
        colors = [const Color(0xFF2563EB), const Color(0xFF1D4ED8)];
        border = Border.all(color: Colors.blueAccent.withOpacity(0.6), width: 1.2);
        shadows = [BoxShadow(color: Colors.blue.withOpacity(0.25), blurRadius: 6)];
      } else if (activeBubble.contains('VIP') || activeBubble.contains('Golden Shimmer') || activeBubble.contains('Gold')) {
        colors = [const Color(0xFFFFD700).withOpacity(0.85), const Color(0xFFD97706).withOpacity(0.85)];
        border = Border.all(color: const Color(0xFFFFD700), width: 1.2);
        shadows = [const BoxShadow(color: Color(0xFFD4AF37), blurRadius: 8)];
      } else if (activeBubble.contains('Neon') || activeBubble.contains('Crystal Cyan')) {
        colors = [const Color(0xFF06B6D4), const Color(0xFF0891B2)];
        border = Border.all(color: const Color(0xFF22D3EE), width: 1.2);
        shadows = [BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.45), blurRadius: 8)];
      } else if (activeBubble.contains('Love')) {
        colors = [const Color(0xFFEC4899), const Color(0xFFF43F5E)];
        border = Border.all(color: Colors.pinkAccent.withOpacity(0.6), width: 1.2);
        shadows = [BoxShadow(color: Colors.pink.withOpacity(0.3), blurRadius: 6)];
      } else if (activeBubble.contains('Galaxy')) {
        colors = [const Color(0xFF7C3AED), const Color(0xFF4C1D95)];
        border = Border.all(color: Colors.purpleAccent.withOpacity(0.6), width: 1.2);
        shadows = [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 6)];
      } else if (activeBubble.contains('Cosmic')) {
        colors = [const Color(0xFF1C1917), const Color(0xFF09090B)];
        border = Border.all(color: const Color(0xFFFFD700), width: 1.5);
        shadows = [const BoxShadow(color: Color(0xFFFFD700), blurRadius: 10, spreadRadius: 0.5)];
      }

      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        border: border,
        boxShadow: shadows,
      );
    } else {
      // Logic for messages from other users based on reputation/tiers
      int novelLevel = 0;
      int activeNovel = 0;
      if (widget.conversation.otherUserName.hashCode % 5 == 0) {
        novelLevel = (widget.conversation.otherUserName.hashCode % 7) + 1;
        activeNovel = novelLevel;
      }

      if (novelLevel > 0 && activeNovel > 0) {
        List<Color> colors;
        BoxBorder? border;
        List<BoxShadow>? shadows;
        switch (activeNovel) {
          case 1:
            colors = [const Color(0xFF1E40AF), const Color(0xFF1D4ED8)];
            border = Border.all(color: Colors.blueAccent.withOpacity(0.6), width: 1.2);
            break;
          case 2:
            colors = [const Color(0xFF7C3AED), const Color(0xFF4C1D95)];
            border = Border.all(color: Colors.purpleAccent.withOpacity(0.6), width: 1.2);
            shadows = [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 6)];
            break;
          case 3:
            colors = [const Color(0xFFFFD700).withOpacity(0.85), const Color(0xFFD97706).withOpacity(0.85)];
            border = Border.all(color: const Color(0xFFFFD700), width: 1.2);
            shadows = [const BoxShadow(color: Color(0xFFD4AF37), blurRadius: 8)];
            break;
          case 4:
            colors = [const Color(0xFFDC2626), const Color(0xFF7F1D1D)];
            border = Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.2);
            shadows = [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 8)];
            break;
          case 5:
            colors = [const Color(0xFFF97316), const Color(0xFFEA580C)];
            border = Border.all(color: const Color(0xFFFDBA74), width: 1.2);
            shadows = [BoxShadow(color: const Color(0xFFF97316).withOpacity(0.45), blurRadius: 8)];
            break;
          case 6:
            colors = [const Color(0xFF06B6D4), const Color(0xFF0891B2)];
            border = Border.all(color: const Color(0xFF22D3EE), width: 1.2);
            shadows = [BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.5), blurRadius: 8)];
            break;
          case 7:
          default:
            colors = [const Color(0xFF1C1917), const Color(0xFF09090B)];
            border = Border.all(color: const Color(0xFFFFD700), width: 1.5);
            shadows = [const BoxShadow(color: Color(0xFFFFD700), blurRadius: 10, spreadRadius: 0.5)];
            break;
        }

        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: border,
          boxShadow: shadows,
        );
      }

      int vipLevel = 0;
      if (widget.conversation.otherUserName.hashCode % 4 == 0) {
        vipLevel = (widget.conversation.otherUserName.hashCode % 6) + 1;
      }

      if (vipLevel <= 0) {
        return BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
      }

      List<Color> colors;
      BoxBorder? border;
      List<BoxShadow>? shadows;

      switch (vipLevel) {
        case 1:
          colors = [const Color(0xFF2563EB), const Color(0xFF1D4ED8)];
          border = Border.all(color: Colors.blueAccent.withOpacity(0.6), width: 1.2);
          shadows = [BoxShadow(color: Colors.blue.withOpacity(0.25), blurRadius: 6)];
          break;
        case 2:
          colors = [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)];
          border = Border.all(color: Colors.purpleAccent.withOpacity(0.6), width: 1.2);
          shadows = [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 6)];
          break;
        case 3:
          colors = [const Color(0xFFFFD700).withOpacity(0.85), const Color(0xFFD97706).withOpacity(0.85)];
          border = Border.all(color: const Color(0xFFFFD700), width: 1.2);
          shadows = [const BoxShadow(color: Color(0xFFD4AF37), blurRadius: 8)];
          break;
        case 4:
          colors = [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)];
          border = Border.all(color: Colors.white, width: 1.2);
          shadows = [BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 8)];
          break;
        case 5:
          colors = [const Color(0xFF06B6D4), const Color(0xFF0891B2)];
          border = Border.all(color: const Color(0xFF22D3EE), width: 1.2);
          shadows = [BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.45), blurRadius: 8)];
          break;
        case 6:
          colors = [const Color(0xFFEC4899), const Color(0xFF3B82F6)];
          border = Border.all(color: Colors.white.withOpacity(0.5), width: 1.2);
          shadows = [BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.4), blurRadius: 8)];
          break;
        case 7:
        default:
          colors = [const Color(0xFF1C1917), const Color(0xFF09090B)];
          border = Border.all(color: const Color(0xFFD4AF37), width: 1.5);
          shadows = [const BoxShadow(color: Color(0xFFD4AF37), blurRadius: 10, spreadRadius: 0.5)];
          break;
      }

      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        border: border,
        boxShadow: shadows,
      );
    }
  }

  Widget _buildSmallAvatar() {
    final _custCtrl = Get.find<CustomizationController>();
    return GestureDetector(
      onTap: _navigateToUserProfile,
      child: _buildAvatar(
        widget.conversation.otherUserAvatar,
        widget.conversation.otherUserName,
        size: 28,
      ),
    );
  }

  Widget _buildReplyPreview(String content, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.1)
            : AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white.withOpacity(0.5) : AppTheme.primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Text(
        content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMe
              ? Colors.white.withOpacity(0.8)
              : AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppTheme.textTertiary,
          ),
        );
      case MessageStatus.sent:
        return const Icon(Icons.done_rounded,
            size: 14, color: AppTheme.textTertiary);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: AppTheme.textTertiary);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Color(0xFF60A5FA));
    }
  }

  Widget _buildReactions(ChatMessage msg, bool isMe) {
    final reactions = msg.reactions!;
    // Group reactions
    final Map<String, int> grouped = {};
    for (final r in reactions) {
      grouped[r] = (grouped[r] ?? 0) + 1;
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: grouped.entries.map((e) {
          return GestureDetector(
            onTap: () => _ctrl.addReaction(
                widget.conversation.id, msg.id, e.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                e.value > 1 ? '${e.key} ${e.value}' : e.key,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply banner
        Obx(() {
          if (_replyToId.value.isEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              border: Border(
                top: BorderSide(color: AppTheme.borderColor.withOpacity(0.5)),
                left: const BorderSide(
                    color: AppTheme.primaryColor, width: 3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.reply_rounded,
                    color: AppTheme.primaryColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Replying to',
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _replyToContent.value,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _clearReply,
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.textTertiary, size: 18),
                ),
              ],
            ),
          );
        }),

        // Emoji quick panel
        Obx(() {
          if (!_showEmoji.value) return const SizedBox.shrink();
          return _buildEmojiPanel();
        }),

        // Attachment options
        Obx(() {
          if (!_showAttachOptions.value) return const SizedBox.shrink();
          return _buildAttachOptions();
        }),

        // Main input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: AppTheme.bgLight,
            border: Border(
              top:
                  BorderSide(color: AppTheme.borderColor.withOpacity(0.5)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach
              GestureDetector(
                onTap: () {
                  _showAttachOptions.value = !_showAttachOptions.value;
                  _showEmoji.value = false;
                  if (_showAttachOptions.value) _focusNode.unfocus();
                },
                child: Obx(() => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: _showAttachOptions.value
                            ? AppTheme.primaryColor.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _showAttachOptions.value
                            ? Icons.close_rounded
                            : Icons.add_rounded,
                        color: _showAttachOptions.value
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                        size: 22,
                      ),
                    )),
              ),
              const SizedBox(width: 6),
              // Text field with photo icon inside
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Photo icon (inside field, left)
                      GestureDetector(
                        onTap: () {
                          _showAttachOptions.value = false;
                          _showEmoji.value = false;
                          Get.snackbar(
                            '📷 Photo',
                            'Photo sharing coming soon!',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor:
                                const Color(0xFF6366F1).withOpacity(0.9),
                            colorText: Colors.white,
                            duration: const Duration(seconds: 2),
                          );
                        },
                        child: const Padding(
                          padding:
                              EdgeInsets.only(left: 10, bottom: 10),
                          child: Icon(
                            Icons.photo_rounded,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          focusNode: _focusNode,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                          onTap: () {
                            _showEmoji.value = false;
                            _showAttachOptions.value = false;
                          },
                        ),
                      ),
                      // Emoji btn
                      GestureDetector(
                        onTap: () {
                          _showEmoji.value = !_showEmoji.value;
                          _showAttachOptions.value = false;
                          if (_showEmoji.value) _focusNode.unfocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10, bottom: 10),
                          child: Obx(() => Icon(
                                _showEmoji.value
                                    ? Icons.keyboard_rounded
                                    : Icons.emoji_emotions_rounded,
                                color: _showEmoji.value
                                    ? AppTheme.primaryColor
                                    : AppTheme.textTertiary,
                                size: 20,
                              )),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send / Mic button
              Obx(() {
                final hasText = _hasText.value;
                return GestureDetector(
                  onTap: hasText ? _sendMessage : null,
                  onLongPress: !hasText
                      ? () => Get.snackbar(
                            '🎤 Voice Message',
                            'Voice recording coming soon!',
                            snackPosition: SnackPosition.BOTTOM,
                          )
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: hasText
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor,
                              ],
                            )
                          : null,
                      color: hasText ? null : AppTheme.bgDark,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: hasText
                              ? Colors.transparent
                              : AppTheme.borderColor),
                      boxShadow: hasText
                          ? [
                              BoxShadow(
                                color:
                                    AppTheme.primaryColor.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      hasText
                          ? Icons.send_rounded
                          : Icons.mic_rounded,
                      color: hasText
                          ? Colors.white
                          : AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.bgLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Reactions',
              style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _quickEmojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  _msgCtrl.text += emoji;
                  _msgCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _msgCtrl.text.length),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachOptions() {
    final options = [
      {
        'icon': Icons.image_rounded,
        'label': 'Photo',
        'color': const Color(0xFF6366F1),
        'sub': 'Gallery',
      },
      {
        'icon': Icons.camera_alt_rounded,
        'label': 'Camera',
        'color': const Color(0xFF10B981),
        'sub': 'Take photo',
      },
      {
        'icon': Icons.card_giftcard_rounded,
        'label': 'Gift',
        'color': const Color(0xFFEF4444),
        'sub': 'Send gift',
      },
      {
        'icon': Icons.link_rounded,
        'label': 'Link',
        'color': const Color(0xFFF59E0B),
        'sub': 'Share URL',
      },
      {
        'icon': Icons.insert_drive_file_rounded,
        'label': 'Document',
        'color': const Color(0xFFEC4899),
        'sub': 'File',
      },
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        border: Border(
          top: BorderSide(
              color: AppTheme.borderColor.withOpacity(0.4)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: options.map((opt) {
          final color = (opt['color'] as Color?) ?? AppTheme.primaryColor;
          final icon = (opt['icon'] as IconData?) ?? Icons.attach_file;
          final label = (opt['label'] as String?) ?? '';
          final sub = (opt['sub'] as String?) ?? '';
          return GestureDetector(
            onTap: () {
              _showAttachOptions.value = false;
              if (label == 'Link') {
                _showLinkDialog();
              } else if (label == 'Gift') {
                _showGiftDialog();
              } else {
                Get.snackbar(
                  '📎 $label',
                  '$sub coming soon!',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: color.withValues(alpha: 0.9),
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: color.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showGiftDialog() {
    Get.dialog(
      SendGiftDialog(
        roomId: '', // Direct chat
        targetUserId: widget.conversation.otherUserId,
        targetUserName: widget.conversation.otherUserName,
        onGiftSent: (giftName, giftIcon, giftCost, currency) {
          final msgText = 'Sent a $giftName $giftIcon ($giftCost ${currency.toUpperCase()})';
          _ctrl.sendMessage(widget.conversation.id, msgText);
        },
      ),
    );
  }

  void _showLinkDialog() {
    final linkCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.bgLight,
        title: const Text('Share Link',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: linkCtrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Paste a URL...',
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.bgDark,
            prefixIcon: const Icon(Icons.link_rounded,
                color: Color(0xFFF59E0B)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final link = linkCtrl.text.trim();
              if (link.isNotEmpty) {
                Get.back();
                _ctrl.sendMessage(
                    widget.conversation.id, '🔗 $link');
                Future.delayed(
                    const Duration(milliseconds: 100), _scrollToBottom);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url, String name, {double size = 42}) {
    final isMe = name == 'Anurag Kumar' || name == 'Anurag Kumar Bharti';

    int novelLevel = 0;
    int activeNovel = 0;
    int vipLevel = 0;

    if (!isMe) {
      if (name.hashCode % 5 == 0) {
        novelLevel = (name.hashCode % 7) + 1;
        activeNovel = novelLevel;
      }
      if (name.hashCode % 4 == 0) {
        vipLevel = (name.hashCode % 6) + 1;
      }
    }

    return Obx(() {
      final activeAvatarVal = _custCtrl.activeAvatar.value;
      final avatarUrl = isMe 
          ? _custCtrl.getAvatarUrl(activeAvatarVal, url ?? '')
          : (url ?? '');

      return CustomAvatarFrame(
        userId: isMe ? 'me' : 'other',
        username: name,
        size: size,
        defaultNovelLevel: activeNovel,
        defaultVipLevel: vipLevel,
        child: Container(
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
            child: avatarUrl.isNotEmpty
                ? (avatarUrl.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _initialsWidget(name, size),
                        errorWidget: (_, __, ___) => _initialsWidget(name, size),
                      )
                    : Image.file(
                        File(avatarUrl),
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                      ))
                : _initialsWidget(name, size),
          ),
        ),
      );
    });
  }

  Widget _initialsWidget(String name, double size) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.2),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.32,
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage msg, bool isMe) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Quick reaction row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _reactionEmojis.map((r) {
                  return GestureDetector(
                    onTap: () {
                      _ctrl.addReaction(
                          widget.conversation.id, msg.id, r['emoji'] as String);
                      Get.back();
                    },
                    child: Text(r['emoji'] as String,
                        style: const TextStyle(fontSize: 26)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _msgOptionTile(
              Icons.reply_rounded,
              AppTheme.primaryColor,
              'Reply',
              () {
                Get.back();
                _setReply(msg);
              },
            ),
            _msgOptionTile(
              Icons.content_copy_rounded,
              AppTheme.textSecondary,
              'Copy Text',
              () {
                Clipboard.setData(ClipboardData(text: msg.content));
                Get.back();
                Get.snackbar('Copied', 'Message copied to clipboard',
                    snackPosition: SnackPosition.BOTTOM);
              },
            ),
            _msgOptionTile(
              Icons.forward_rounded,
              AppTheme.accentColor,
              'Forward',
              () => Get.back(),
            ),
            if (isMe)
              _msgOptionTile(
                Icons.delete_outline_rounded,
                AppTheme.errorColor,
                'Delete Message',
                () {
                  _ctrl.deleteMessage(widget.conversation.id, msg.id);
                  Get.back();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _msgOptionTile(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
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

  void _showChatOptions() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _msgOptionTile(Icons.search_rounded, AppTheme.primaryColor, 'Search in Chat', () => Get.back()),
            _msgOptionTile(Icons.wallpaper_rounded, AppTheme.secondaryColor, 'Change Wallpaper', () => Get.back()),
            _msgOptionTile(Icons.volume_off_rounded, AppTheme.textSecondary, 'Mute Notifications', () {
              _ctrl.toggleMute(widget.conversation.id);
              Get.back();
            }),
            _msgOptionTile(Icons.block_rounded, AppTheme.errorColor, 'Block User', () => Get.back()),
          ],
        ),
      ),
    );
  }

  void _navigateToUserProfile() {
    final conv = widget.conversation;
    // Construct a User model to pass to UserProfileScreen
    final targetUser = User(
      id: conv.otherUserId,
      username: conv.otherUserName.toLowerCase().replaceAll(' ', '_'),
      email: '${conv.otherUserId}@creania.app',
      displayName: conv.otherUserName,
      avatar: conv.otherUserAvatar,
      interests: ['Flutter', 'Live Chat', 'Collaborations'],
      communities: ['Creania Lounge'],
      followers: 1420,
      following: 480,
      isVerified: conv.isVerified,
      isPremium: conv.isVerified,
      reputation: 2150,
      sid: (conv.otherUserId.hashCode.abs() % 900000 + 100000).toString(),
      level: conv.level,
      xp: 450,
      totalXp: 1000,
    );
    Get.to(() => UserProfileScreen(user: targetUser));
  }
}
