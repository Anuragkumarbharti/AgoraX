import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/chat/chat_model.dart';
import '../../services/chat/chat_controller.dart';
import '../../services/chat/chat_socket_service.dart';
import './chat_settings_screen.dart';
import '../../models/user/user_model.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../profile/profile_screen.dart';
import '../../widgets/chat/message_limit_dialog.dart';
import '../../widgets/chat/voice_message_player_widget.dart';
import '../../widgets/gifting/send_gift_dialog.dart';
import '../../widgets/chat/chat_media_attachment_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../models/room/room_model.dart';
import '../../services/room/room_controller.dart';
import '../rooms/voice_room_call_screen.dart';
import '../../services/room/room_entry_permission_engine.dart';
import 'dart:io';
import 'dart:ui';
import '../../services/chat/chat_wallpaper_service.dart';
import '../../services/room/room_pip_controller.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({Key? key, required this.conversation}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final ChatController _ctrl;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final RxList<ChatMessage> _messagesList = <ChatMessage>[].obs;
  final RxBool _hasText = false.obs;
  final RxBool _showEmojiPanel = false.obs;
  final RxBool _showAttachmentPanel = false.obs;
  final RxBool _isRecording = false.obs;
  final RxInt _recordingSeconds = 0.obs;

  Timer? _recordingTimer;
  late final AnimationController _waveAnimCtrl;

  final Rxn<ChatMessage> _replyToMessage = Rxn<ChatMessage>();
  
  Timer? _typingTimer;
  bool _isTyping = false;
  int _previousMessageCount = 0;

  final RxBool _showScrollToBottom = false.obs;

  String get _effectiveConvId => ChatController.getDeterministicConversationId(
        UserProfileCacheManager.currentUserId,
        widget.conversation.otherUserId,
      );

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<ChatController>();
    _waveAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _msgCtrl.addListener(() {
      _hasText.value = _msgCtrl.text.trim().isNotEmpty;
      if (!_isTyping && _msgCtrl.text.trim().isNotEmpty) {
        _isTyping = true;
        _ctrl.setTyping(_effectiveConvId, true, receiverId: widget.conversation.otherUserId);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (_isTyping) {
          _isTyping = false;
          _ctrl.setTyping(_effectiveConvId, false, receiverId: widget.conversation.otherUserId);
        }
      });
    });

    _loadConversationMessages();
    _ctrl.markConversationRead(_effectiveConvId);
    ChatSocketService.to.requestLastSeen(widget.conversation.otherUserId);

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels <= _scrollCtrl.position.minScrollExtent + 100) {
        _ctrl.loadMoreMessages(widget.conversation.id);
      }
      final double maxScroll = _scrollCtrl.position.maxScrollExtent;
      final double currentScroll = _scrollCtrl.position.pixels;
      _showScrollToBottom.value = (maxScroll - currentScroll) > 300;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _waveAnimCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      _waveAnimCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    if (_isTyping) {
      _ctrl.setTyping(widget.conversation.id, false, receiverId: widget.conversation.otherUserId);
    }
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _waveAnimCtrl.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _openGiftDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SendGiftDialog(
        roomId: '', // Direct Chat Gifting
        targetUserId: widget.conversation.otherUserId,
        targetUserName: widget.conversation.otherUserName,
        onGiftSent: (giftName, giftIcon, giftCost, currency) {
          _ctrl.sendGiftMessage(
            _effectiveConvId,
            giftName,
            giftIcon,
            giftCost,
            widget.conversation.otherUserId,
          );
        },
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  void _loadConversationMessages() {
    _ctrl.getMessages(_effectiveConvId);
  }

  void _sendMessage({
    String? text,
    MessageType type = MessageType.text,
    String? mediaUrl,
    int audioDuration = 0,
    String? fileName,
    int? fileSize,
    String? thumbnailUrl,
    double? locationLat,
    double? locationLng,
    String? locationName,
    String? contactName,
    String? contactPhone,
  }) async {
    final body = text ?? _msgCtrl.text.trim();
    if (body.isEmpty && mediaUrl == null && fileName == null && locationLat == null && contactPhone == null) return;

    final remainingQuota = _ctrl.getRemainingRequestQuota(_effectiveConvId, widget.conversation.otherUserId);
    if (remainingQuota <= 0) {
      MessageLimitDialog.show(
        context: context,
        targetUserId: widget.conversation.otherUserId,
        targetUserName: widget.conversation.otherUserName,
        conversationId: _effectiveConvId,
        onGiftUnlocked: () {
          setState(() {});
        },
        onFollowUpdated: () {
          setState(() {});
        },
      );
      return;
    }

    _ctrl.sendMessage(
      _effectiveConvId,
      body,
      receiverId: widget.conversation.otherUserId,
      type: type,
      audioDurationSeconds: audioDuration,
      mediaUrl: mediaUrl,
      fileName: fileName,
      fileSize: fileSize,
      thumbnailUrl: thumbnailUrl,
      locationLat: locationLat,
      locationLng: locationLng,
      locationName: locationName,
      contactName: contactName,
      contactPhone: contactPhone,
    );

    _msgCtrl.clear();
    _replyToMessage.value = null;
    HapticFeedback.lightImpact();
    _scrollToBottom();
  }

  void _startVoiceRecording() {
    final remainingQuota = _ctrl.getRemainingRequestQuota(_effectiveConvId, widget.conversation.otherUserId);
    if (remainingQuota <= 0) {
      MessageLimitDialog.show(
        context: context,
        targetUserId: widget.conversation.otherUserId,
        targetUserName: widget.conversation.otherUserName,
        conversationId: _effectiveConvId,
        onGiftUnlocked: () {},
        onFollowUpdated: () {},
      );
      return;
    }

    _isRecording.value = true;
    _recordingSeconds.value = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _recordingSeconds.value++;
    });
  }

  void _stopVoiceRecording({bool send = true}) {
    if (!_isRecording.value) return;
    _recordingTimer?.cancel();
    _isRecording.value = false;

    if (send && _recordingSeconds.value >= 1) {
      _sendMessage(
        text: '🎤 Voice Note (${_recordingSeconds.value}s)',
        type: MessageType.audio,
        audioDuration: _recordingSeconds.value,
        mediaUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      );
    }
  }

  BoxFit _parseBoxFit(String mode) {
    switch (mode) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      default:
        return BoxFit.cover;
    }
  }

  Widget _buildWallpaperBackground(Widget child) {
    return Obx(() {
      final wp = ChatWallpaperService.to.getWallpaper(_effectiveConvId);
      Widget baseWidget;

      if (wp.type == WallpaperType.customImage && File(wp.value).existsSync()) {
        baseWidget = Image.file(
          File(wp.value),
          fit: _parseBoxFit(wp.fitMode),
          width: double.infinity,
          height: double.infinity,
        );
      } else if (wp.type == WallpaperType.solidColor) {
        Color c = const Color(0xFF0F172A);
        try {
          final hexStr = wp.value.replaceAll('#', '');
          c = Color(int.parse('FF$hexStr', radix: 16));
        } catch (_) {}
        baseWidget = Container(color: c);
      } else {
        final preset = ChatWallpaperService.presets.firstWhereOrNull((x) => x['id'] == wp.value) ??
            ChatWallpaperService.presets.first;
        final List<Color> colors = List<Color>.from(preset['colors']);
        baseWidget = Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          baseWidget,
          if (wp.blur > 0)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: wp.blur, sigmaY: wp.blur),
              child: Container(color: Colors.transparent),
            ),
          Container(
            color: Colors.black.withOpacity(wp.dimness),
          ),
          child,
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _buildStitchTopAppBar(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Obx(() {
              final isBlocked = _ctrl.isUserBlocked(widget.conversation.otherUserId);
              if (isBlocked) {
                return Container(
                  color: Colors.redAccent.withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.block_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have blocked this user.',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _ctrl.toggleBlockUser(widget.conversation.otherUserId);
                        },
                        child: Text('UNBLOCK', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            Expanded(child: _buildWallpaperBackground(_buildChatArea())),
            _buildStitchBottomInputBar(),
            Obx(() {
              if (_showEmojiPanel.value) return _buildEmojiSelectorPanel();
              if (_showAttachmentPanel.value) return _buildAttachmentMenuPanel();
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
      floatingActionButton: Obx(() {
        if (_showScrollToBottom.value) {
          return FloatingActionButton.small(
            onPressed: _scrollToBottom,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF006D2F),
            elevation: 3,
            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          );
        }
        return const SizedBox.shrink();
      }),
    );
  }

  Widget _buildStitchTopAppBar() {
    final conv = widget.conversation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              onPressed: () => Get.back(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                final cached = UserProfileCacheManager.getCachedUser(conv.otherUserId);
                if (cached != null) {
                  Get.to(() => ProfileScreen(visitorUser: cached));
                } else {
                  Get.to(() => ProfileScreen(
                    visitorUser: User(
                      id: conv.otherUserId,
                      username: conv.otherUserName.toLowerCase().replaceAll(' ', '_'),
                      email: '${conv.otherUserId}@example.com',
                      displayName: conv.otherUserName,
                      avatar: conv.otherUserAvatar,
                      followers: 1240,
                      following: 380,
                      level: conv.level,
                      interests: const [],
                      communities: const [],
                      isVerified: conv.isVerified,
                      isPremium: conv.level > 0,
                      reputation: 100,
                      sid: conv.otherUserId.hashCode.abs().toString(),
                    ),
                  ));
                }
              },
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (UserProfileCacheManager.getCachedUser(conv.otherUserId)?.vipLevel != null && UserProfileCacheManager.getCachedUser(conv.otherUserId)!.vipLevel > 0) ? const Color(0xFFFFD700) : const Color(0xFF334155),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0xFF1E293B),
                          backgroundImage: conv.otherUserAvatar.isNotEmpty ? NetworkImage(conv.otherUserAvatar) : null,
                          child: conv.otherUserAvatar.isEmpty ? const Icon(Icons.person, color: Color(0xFF94A3B8)) : null,
                        ),
                      ),
                      Obx(() {
                        final isOnline = _ctrl.userPresence[conv.otherUserId] ?? false;
                        if (isOnline) {
                          return Positioned(
                            bottom: 1,
                            right: 1,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            conv.otherUserName,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (conv.isVerified || (UserProfileCacheManager.getCachedUser(conv.otherUserId)?.isVerified ?? false)) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 15),
                          ],
                        ],
                      ),
                      Obx(() {
                        final isTyping = _ctrl.typingState[conv.id] ?? false;
                        final isOnline = _ctrl.userPresence[conv.otherUserId] ?? false;
                        final lastSeenStr = _ctrl.userLastSeen[conv.otherUserId];
                        
                        String statusText = 'Offline';
                        Color statusColor = const Color(0xFF94A3B8);
                        
                        if (isTyping) {
                          statusText = 'Typing...';
                          statusColor = const Color(0xFF34D399);
                        } else if (isOnline) {
                          statusText = 'Online';
                          statusColor = const Color(0xFF34D399);
                        } else if (lastSeenStr != null) {
                          statusText = lastSeenStr;
                        }
      
                        return Text(
                          statusText,
                          style: GoogleFonts.outfit(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
              onPressed: () => Get.to(() => ChatSettingsScreen(
                    conversationId: conv.id,
                    userName: conv.otherUserName,
                    userAvatar: conv.otherUserAvatar,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return Obx(() {
      final messages = _ctrl.getMessages(_effectiveConvId);

      if (messages.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              Text(
                'No messages here yet',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Send a message to start the conversation!',
                style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 12.5),
              ),
            ],
          ),
        );
      }

      if (messages.length > _previousMessageCount) {
        _previousMessageCount = messages.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            final double distanceToBottom = _scrollCtrl.position.maxScrollExtent - _scrollCtrl.position.pixels;
            if (distanceToBottom <= 250) {
              _scrollToBottom();
            }
          }
        });
      }

      return ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemCount: messages.length + 1,
        itemBuilder: (context, index) {
          if (index == messages.length) {
            return const SizedBox(height: 30);
          }
          final msg = messages[index];
          final isMe = msg.senderId == UserProfileCacheManager.currentUserId;

          bool showDateSep = false;
          final msgLocal = msg.timestamp.toLocal();

          if (index == 0) {
            showDateSep = true;
          } else {
            final prevLocal = messages[index - 1].timestamp.toLocal();
            if (msgLocal.day != prevLocal.day || msgLocal.month != prevLocal.month || msgLocal.year != prevLocal.year) {
              showDateSep = true;
            }
          }

          // WhatsApp / StarMaker Grouping Logic
          bool isSameSenderAsPrevious = false;
          bool isSameSenderAsNext = false;

          if (index > 0) {
            final prev = messages[index - 1];
            if (prev.senderId == msg.senderId && msg.timestamp.toUtc().difference(prev.timestamp.toUtc()).inMinutes < 2 && !showDateSep) {
              isSameSenderAsPrevious = true;
            }
          }

          if (index < messages.length - 1) {
            final next = messages[index + 1];
            final nextLocal = next.timestamp.toLocal();
            if (next.senderId == msg.senderId && next.timestamp.toUtc().difference(msg.timestamp.toUtc()).inMinutes < 2 && nextLocal.day == msgLocal.day) {
              isSameSenderAsNext = true;
            }
          }

          return Column(
            children: [
              if (showDateSep) _buildStitchDateSeparator(msg.timestamp),
              _buildStitchMessageBubble(
                msg,
                isMe,
                isSameSenderAsPrevious: isSameSenderAsPrevious,
                isSameSenderAsNext: isSameSenderAsNext,
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildStitchDateSeparator(DateTime dt) {
    String label = 'Today';
    final localDt = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(localDt.year, localDt.month, localDt.day);
    final differenceInDays = today.difference(messageDate).inDays;

    if (differenceInDays == 0) {
      label = 'Today';
    } else if (differenceInDays == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, yyyy').format(localDt);
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: const Color(0xFFCBD5E1),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStitchMessageBubble(
    ChatMessage msg,
    bool isMe, {
    bool isSameSenderAsPrevious = false,
    bool isSameSenderAsNext = false,
  }) {
    final double verticalMargin = (isSameSenderAsPrevious && isSameSenderAsNext)
        ? 1.5
        : (isSameSenderAsPrevious || isSameSenderAsNext ? 2.5 : 6.0);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: verticalMargin),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => _showMessageActionMenu(msg),
            borderRadius: BorderRadius.circular(16),
            child: msg.type == MessageType.gift
                ? _buildStitchGiftMessageCard(msg, isMe)
                : msg.type == MessageType.roomInvite
                    ? _buildStitchRoomInviteCard(msg, isMe)
                    : msg.type == MessageType.document || msg.type == MessageType.file
                        ? _buildStitchDocumentCard(msg, isMe)
                        : _buildStitchStandardBubble(
                            msg,
                            isMe,
                            isSameSenderAsPrevious: isSameSenderAsPrevious,
                            isSameSenderAsNext: isSameSenderAsNext,
                          ),
          ),
        ),
      ),
    );
  }

  Widget _buildStitchStandardBubble(
    ChatMessage msg,
    bool isMe, {
    bool isSameSenderAsPrevious = false,
    bool isSameSenderAsNext = false,
  }) {
    if (msg.isPureEmoji) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.content,
              style: const TextStyle(fontSize: 34),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(msg.timestamp.toLocal()),
                  style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF94A3B8)),
                ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  _buildDeliveryStatusTick(msg.status, isMe: true),
                ],
              ],
            ),
          ],
        ),
      );
    }

    double topLeft = 16;
    double topRight = 16;
    double bottomLeft = 16;
    double bottomRight = 16;

    if (isMe) {
      bottomRight = isSameSenderAsNext ? 4 : 16;
      topRight = isSameSenderAsPrevious ? 4 : 16;
      bottomLeft = 16;
      topLeft = 16;
    } else {
      bottomLeft = isSameSenderAsNext ? 4 : 16;
      topLeft = isSameSenderAsPrevious ? 4 : 16;
      bottomRight = 16;
      topRight = 16;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF059669) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topLeft),
          topRight: Radius.circular(topRight),
          bottomLeft: Radius.circular(bottomLeft),
          bottomRight: Radius.circular(bottomRight),
        ),
        border: isMe
            ? Border.all(color: const Color(0xFF10B981).withOpacity(0.4), width: 1)
            : Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply Preview
          if (msg.replyToContent != null) ...[
            Container(
              padding: const EdgeInsets.all(7),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isMe ? Colors.black.withOpacity(0.18) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 3, height: 20, color: isMe ? Colors.white70 : const Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      msg.replyToContent!,
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white70 : const Color(0xFFE2E8F0),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Main Body
          if (msg.type == MessageType.audio) ...[
            VoiceMessagePlayerWidget(message: msg, isMe: isMe),
          ] else if (msg.type == MessageType.image || msg.type == MessageType.video) ...[
            ChatMediaAttachmentWidget(message: msg, isMe: isMe),
          ] else ...[
            Text(
              msg.content,
              style: GoogleFonts.outfit(
                color: isMe ? Colors.white : const Color(0xFFF8FAFC),
                fontSize: 14.5,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Spacer(),
              Text(
                DateFormat('h:mm a').format(msg.timestamp.toLocal()),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: isMe ? const Color(0xFFA7F3D0) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _buildDeliveryStatusTick(msg.status, isMe: true),
              ],
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildStitchGiftMessageCard(ChatMessage msg, bool isMe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF25D366) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMe ? const Color(0xFF005523).withOpacity(0.2) : const Color(0xFF25D366).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF005523).withOpacity(0.12) : const Color(0xFF25D366).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              color: isMe ? const Color(0xFF004018) : const Color(0xFF006D2F),
              size: 38,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            msg.content.isNotEmpty ? msg.content : 'A surprise for you!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isMe ? const Color(0xFF003916) : const Color(0xFF191C1E),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enjoy this little token of appreciation.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isMe ? const Color(0xFF005523) : const Color(0xFF3C4A3D),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _openGiftDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: isMe ? const Color(0xFF004018) : const Color(0xFF25D366),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'Open Gift',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                DateFormat('h:mm a').format(msg.timestamp.toLocal()),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: isMe ? const Color(0xFF005523).withOpacity(0.8) : const Color(0xFF6C7B6B),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _buildDeliveryStatusTick(msg.status, isMe: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStitchDocumentCard(ChatMessage msg, bool isMe) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF25D366) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMe ? null : Border.all(color: const Color(0xFFE0E3E6).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe ? Colors.black.withOpacity(0.08) : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.fileName ?? msg.content,
                        style: GoogleFonts.inter(
                          color: isMe ? const Color(0xFF003916) : const Color(0xFF191C1E),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        msg.fileSize != null ? '${(msg.fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB • PDF' : 'DOCUMENT',
                        style: GoogleFonts.inter(
                          color: isMe ? const Color(0xFF005523) : const Color(0xFF6C7B6B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.download_rounded, color: isMe ? const Color(0xFF003916) : const Color(0xFF191C1E), size: 22),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                DateFormat('h:mm a').format(msg.timestamp.toLocal()),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: isMe ? const Color(0xFF005523).withOpacity(0.8) : const Color(0xFF6C7B6B),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _buildDeliveryStatusTick(msg.status, isMe: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStitchRoomInviteCard(ChatMessage msg, bool isMe) {
    return Obx(() {
      String roomId = msg.inviteRoomId;
      if (roomId.isEmpty && msg.contactPhone != null && msg.contactPhone!.isNotEmpty) {
        roomId = msg.contactPhone!;
      }
      final roomTitle = msg.inviteRoomTitle;
      final hostName = msg.inviteHostName;

      VoiceRoom? roomObj;
      if (Get.isRegistered<RoomController>()) {
        final roomCtrl = Get.find<RoomController>();
        if (roomId.isNotEmpty) {
          roomObj = roomCtrl.rooms.firstWhereOrNull((r) => r.id == roomId);
        }
        if (roomObj == null && roomTitle.isNotEmpty) {
          roomObj = roomCtrl.rooms.firstWhereOrNull((r) => r.name.toLowerCase().trim() == roomTitle.toLowerCase().trim());
        }
      }

      roomObj ??= RoomMetadataCache.getRoom(roomId, roomTitle);

      if (roomObj != null) {
        roomId = roomObj.id;
      }

      String ownerName = '';
      if (roomObj != null) {
        if (roomObj.hostId.isNotEmpty) {
          final u = UserProfileCacheManager.rxCache[roomObj.hostId] ?? UserProfileCacheManager.getCachedUser(roomObj.hostId);
          if (u != null && u.username.isNotEmpty) {
            ownerName = u.username.replaceAll('@', '');
          }
        }
        if (ownerName.isEmpty && roomObj.ownerName.isNotEmpty && roomObj.ownerName != 'Host' && roomObj.ownerName != 'Anurag Kumar Bharti') {
          ownerName = roomObj.ownerName;
        }
        if (ownerName.isEmpty && roomObj.username.isNotEmpty && roomObj.username != '@host') {
          ownerName = roomObj.username.replaceAll('@', '');
        }
      }

      if (ownerName.isEmpty || ownerName == 'Owner' || ownerName == 'Host' || ownerName == 'Anurag Kumar Bharti') {
        ownerName = (hostName.isNotEmpty && hostName != 'Host' && hostName != 'Anurag Kumar Bharti')
            ? hostName
            : (roomObj?.username.replaceAll('@', '') ?? 'Arena Owner');
      }

      final String coverUrl = (msg.inviteRoomCover.isNotEmpty)
          ? msg.inviteRoomCover
          : (roomObj?.avatar ?? roomObj?.roomCoverUrl ?? '');

      final int totalUsers = roomObj?.participantCount ?? (roomObj?.totalMembers ?? 0);

      final List<String> realAvatars = [];
      if (roomObj != null) {
        if (roomObj.avatar != null && roomObj.avatar!.isNotEmpty && (roomObj.avatar!.startsWith('http://') || roomObj.avatar!.startsWith('https://'))) {
          realAvatars.add(roomObj.avatar!);
        }
        final List<String> userIds = [
          ...roomObj.speakerIds,
          ...roomObj.listenerIds,
          ...roomObj.memberIds,
        ];
        for (final uid in userIds) {
          if (realAvatars.length >= 4) break;
          final u = UserProfileCacheManager.rxCache[uid];
          if (u != null && u.avatar != null && u.avatar!.isNotEmpty && (u.avatar!.startsWith('http://') || u.avatar!.startsWith('https://')) && !realAvatars.contains(u.avatar!)) {
            realAvatars.add(u.avatar!);
          }
        }
      }

      final String displayRoomId = roomId.isNotEmpty
          ? roomId
          : (roomObj?.id != null && roomObj!.id.isNotEmpty ? roomObj.id : (roomTitle.isNotEmpty ? roomTitle : 'CRN-RM-101'));

      return Container(
        width: 270,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.cyanAccent.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.18),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.5),
          child: Stack(
            children: [
              // 1. Background Room Cover photo display
              Positioned.fill(
                child: coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF121927)),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),

              // 2. Dark Overlay for text legibility & glassmorphism finish
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.black.withOpacity(0.90),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // 3. Card Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Header with LIVE indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.cyanAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.mic_rounded, color: Colors.black, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Join Arena',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Room Name
                    Text(
                      roomTitle.isNotEmpty ? roomTitle : 'Arena Room',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // Room ID
                    Row(
                      children: [
                        Icon(Icons.tag_rounded, color: Colors.cyanAccent.withOpacity(0.8), size: 12),
                        const SizedBox(width: 2),
                        Text(
                          'ID: $displayRoomId',
                          style: GoogleFonts.poppins(
                            color: Colors.cyanAccent.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Room Owner
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 13),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Owner: $ownerName',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Real Avatars (NO Fake Avatars) + Real Member Count
                    Row(
                      children: [
                        if (realAvatars.isNotEmpty) ...[
                          SizedBox(
                            width: (realAvatars.length == 1)
                                ? 24
                                : 24 + (realAvatars.length - 1) * 16.0,
                            height: 24,
                            child: Stack(
                              children: List.generate(realAvatars.length, (index) {
                                return Positioned(
                                  left: index * 16.0,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.2),
                                      image: DecorationImage(
                                        image: NetworkImage(realAvatars[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '$totalUsers total user',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Join Room Button
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () => _handleJoinRoomFromInvite(displayRoomId, roomTitle),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          elevation: 3,
                          shadowColor: Colors.cyanAccent.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Join Room',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Timestamp & Delivery status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(msg.timestamp.toLocal()),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildDeliveryStatusTick(msg.status, isMe: true),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _handleJoinRoomFromInvite(String roomId, String roomTitle) async {
    String targetId = roomId.trim();

    // 1. If targetId is empty, attempt roomTitle search in local RoomController
    if (targetId.isEmpty && Get.isRegistered<RoomController>()) {
      final roomCtrl = Get.find<RoomController>();
      if (roomTitle.isNotEmpty) {
        final matchedRoom = roomCtrl.rooms.firstWhereOrNull(
          (r) => r.name.toLowerCase().trim() == roomTitle.toLowerCase().trim(),
        );
        if (matchedRoom != null) {
          targetId = matchedRoom.id;
        }
      }
      if (targetId.isEmpty && roomCtrl.activeRoomId != null && roomCtrl.activeRoomId!.isNotEmpty) {
        targetId = roomCtrl.activeRoomId!;
      }
    }

    // 2. If targetId is still empty, search Supabase DB by roomTitle
    if (targetId.isEmpty && roomTitle.isNotEmpty) {
      try {
        final res = await Supabase.instance.client
            .from('rooms')
            .select('id')
            .ilike('name', roomTitle)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (res != null && res['id'] != null) {
          targetId = res['id'].toString();
        }
      } catch (e) {
        debugPrint('[ChatScreen] Error querying room by title: $e');
      }
    }

    if (targetId.isEmpty) {
      Get.snackbar(
        'Invalid Room',
        'Room ID is missing.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    HapticFeedback.mediumImpact();

    VoiceRoom? roomObj;

    if (Get.isRegistered<RoomController>()) {
      final roomCtrl = Get.find<RoomController>();
      roomObj = roomCtrl.rooms.firstWhereOrNull((r) => r.id == targetId);
    }

    if (roomObj == null) {
      try {
        final res = await Supabase.instance.client
            .from('rooms')
            .select('*, profiles:host_id(id, username, avatar_url, avatar_frame, level, vip_level, novel_level)')
            .eq('id', targetId)
            .maybeSingle();

        if (res != null && res is Map<String, dynamic>) {
          roomObj = VoiceRoom.fromJson(res);
        }
      } catch (e) {
        debugPrint('[ChatScreen] Error fetching room from Supabase: $e');
      }
    }

    final targetRoom = roomObj ??
        VoiceRoom.fromJson({
          'id': targetId,
          'name': roomTitle.isNotEmpty ? roomTitle : 'Arena Room',
          'is_live': true,
          'status': 'live',
        });

    if (!targetRoom.isLive && roomObj != null) {
      Get.snackbar(
        'Room Ended',
        'This voice room has been ended by the host.',
        backgroundColor: Colors.redAccent.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Enforce room entry permission engine: password prompts if locked, VIP/role checks, etc.
    RoomEntryPermissionEngine.validateAndJoin(context, targetRoom);
  }

  void _handleShareCurrentRoomInChat() {
    VoiceRoom? activeRoom;
    if (Get.isRegistered<RoomController>()) {
      final roomCtrl = Get.find<RoomController>();
      final activeId = roomCtrl.activeRoomId;
      if (activeId != null && activeId.isNotEmpty) {
        activeRoom = roomCtrl.rooms.firstWhereOrNull((r) => r.id == activeId);
      }
    }

    if (activeRoom == null || !activeRoom.isLive) {
      Get.snackbar(
        'No Active Room',
        'You are not currently in a room. Join or host a room first!',
        backgroundColor: AppTheme.bgLight,
        colorText: AppTheme.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    _sendMessage(
      text: '🎙️ Room Invite: ${activeRoom.name} (ID: ${activeRoom.id})',
      type: MessageType.roomInvite,
      locationName: activeRoom.name,
      contactName: activeRoom.ownerName,
      contactPhone: activeRoom.id,
      mediaUrl: activeRoom.avatar,
    );

    Get.snackbar(
      'Room Shared',
      'Room invitation sent to this chat',
      backgroundColor: const Color(0xFF006D2F),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
    );
  }

  Widget _buildDeliveryStatusTick(MessageStatus status, {bool isMe = false}) {
    final color = isMe ? const Color(0xFF004018) : const Color(0xFF006D2F);
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time_rounded, size: 12, color: color.withOpacity(0.6));
      case MessageStatus.sent:
        return Icon(Icons.done_rounded, size: 13, color: color.withOpacity(0.8));
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 13, color: color.withOpacity(0.8));
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded, size: 13, color: color);
    }
  }

  Widget _buildStitchBottomInputBar() {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final isMutual = _ctrl.isMutualFollower(widget.conversation.otherUserId);
            final remaining = _ctrl.getRemainingRequestQuota(_effectiveConvId, widget.conversation.otherUserId);
            if (isMutual || remaining >= 100 || remaining > 3) return const SizedBox.shrink();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF451A03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C2D12), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💬 You have $remaining request message(s). Get a reply or send a gift to continue chatting.',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFDE68A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          Obx(() {
            if (_replyToMessage.value != null) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to: ${_replyToMessage.value!.content}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(color: const Color(0xFFF8FAFC), fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () => _replyToMessage.value = null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          Row(
            children: [
              IconButton(
                icon: Obx(() => AnimatedRotation(
                      turns: _showAttachmentPanel.value ? 0.125 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.add_rounded, color: Color(0xFF94A3B8), size: 28),
                    )),
                onPressed: () {
                  _showAttachmentPanel.value = !_showAttachmentPanel.value;
                  _showEmojiPanel.value = false;
                  if (_showAttachmentPanel.value) {
                    _focusNode.unfocus();
                  }
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          focusNode: _focusNode,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14.5),
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            hintStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onTap: () {
                            _showEmojiPanel.value = false;
                            _showAttachmentPanel.value = false;
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF10B981), size: 22),
                        onPressed: _openGiftDialog,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final hasTxt = _hasText.value;
                return GestureDetector(
                  onTap: hasTxt ? () => _sendMessage() : null,
                  onLongPressStart: hasTxt ? null : (_) => _startVoiceRecording(),
                  onLongPressEnd: hasTxt ? null : (_) => _stopVoiceRecording(send: true),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x3310B981),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        hasTxt ? Icons.send_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          Obx(() {
            if (_isRecording.value) {
              return _buildVoiceRecordingIndicator();
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildVoiceRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Obx(() => Text(
                'Recording: ${_recordingSeconds.value}s',
                style: GoogleFonts.inter(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.bold),
              )),
          const Spacer(),
          Text(
            'Release to send • Slide Left to Cancel',
            style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiSelectorPanel() {
    final List<String> dummyEmojis = ['😀', '😂', '😍', '👍', '🔥', '🎉', '❤️', '🙏', '🙌', '✨', '☕', '🎂', '🥳', '😎', '💀', '👀'];
    return Container(
      height: 200,
      color: Colors.white,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Emojis'),
              Tab(text: 'Stickers'),
              Tab(text: 'GIFs'),
            ],
            indicatorColor: const Color(0xFF006D2F),
            labelColor: const Color(0xFF006D2F),
            unselectedLabelColor: const Color(0xFF6C7B6B),
            controller: TabController(length: 3, vsync: this),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemCount: dummyEmojis.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _msgCtrl.text += dummyEmojis[index];
                  },
                  child: Center(child: Text(dummyEmojis[index], style: const TextStyle(fontSize: 24))),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAttachmentMenuPanel() {
    final items = [
      {'name': 'Share Room', 'icon': Icons.podcasts_rounded, 'color': Colors.deepOrange, 'type': 'room_share'},
      {'name': 'Gift', 'icon': Icons.card_giftcard_rounded, 'color': const Color(0xFF006D2F), 'type': 'gift'},
      {'name': 'Document', 'icon': Icons.description_rounded, 'color': Colors.blue, 'type': 'document'},
      {'name': 'Camera', 'icon': Icons.camera_alt_rounded, 'color': Colors.red, 'type': 'camera'},
      {'name': 'Gallery', 'icon': Icons.image_rounded, 'color': Colors.purple, 'type': 'gallery'},
      {'name': 'Audio', 'icon': Icons.headphones_rounded, 'color': Colors.orange, 'type': 'audio'},
      {'name': 'Location', 'icon': Icons.location_on_rounded, 'color': Colors.green, 'type': 'location'},
      {'name': 'Contact', 'icon': Icons.person_rounded, 'color': Colors.teal, 'type': 'contact'},
    ];
    return Container(
      height: 180,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1.3),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
              _showAttachmentPanel.value = false;
              final typeKey = item['type'] as String;
              if (typeKey == 'room_share') {
                _handleShareCurrentRoomInChat();
              } else if (typeKey == 'gift') {
                _openGiftDialog();
              } else if (typeKey == 'document') {
                _sendMessage(
                  text: 'Quantum_Physics_Notes.pdf',
                  type: MessageType.document,
                  fileName: 'Quantum_Physics_Notes.pdf',
                  fileSize: 2450000,
                );
              } else if (typeKey == 'camera' || typeKey == 'gallery') {
                _sendMessage(
                  text: '📷 Photo',
                  type: MessageType.image,
                  mediaUrl: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800',
                  fileName: 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
                );
              } else if (typeKey == 'audio') {
                _sendMessage(
                  text: '🎤 Voice Note',
                  type: MessageType.audio,
                  audioDuration: 14,
                  mediaUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
                );
              } else if (typeKey == 'location') {
                _sendMessage(
                  text: '📍 Central Campus Library',
                  type: MessageType.location,
                  locationLat: 28.6139,
                  locationLng: 77.2090,
                  locationName: 'Central Campus Library, Block A',
                );
              } else if (typeKey == 'contact') {
                _sendMessage(
                  text: '👤 Academic Advisor',
                  type: MessageType.contact,
                  contactName: 'Dr. Sharma (Physics Dept)',
                  contactPhone: '+91 98765 12345',
                );
              }
            },
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: (item['color'] as Color).withOpacity(0.12),
                  child: Icon(item['icon'] as IconData, color: item['color'] as Color),
                ),
                const SizedBox(height: 6),
                Text(item['name'] as String, style: GoogleFonts.inter(color: const Color(0xFF191C1E), fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMessageActionMenu(ChatMessage msg) {
    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Color(0xFF006D2F)),
              title: Text('Reply', style: GoogleFonts.inter(color: const Color(0xFF191C1E))),
              onTap: () {
                _replyToMessage.value = msg;
                Get.back();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Color(0xFF006D2F)),
              title: Text('Copy Text', style: GoogleFonts.inter(color: const Color(0xFF191C1E))),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                Get.back();
                Get.snackbar('Copied', 'Message copied to clipboard', backgroundColor: Colors.white);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: Text('Delete Message', style: GoogleFonts.inter(color: Colors.redAccent)),
              onTap: () {
                _messagesList.removeWhere((m) => m.id == msg.id);
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RoomMetadataCache {
  static final RxMap<String, VoiceRoom> roomCache = <String, VoiceRoom>{}.obs;
  static final Set<String> _pendingFetches = {};

  static VoiceRoom? getRoom(String roomId, String roomTitle) {
    if (roomId.isNotEmpty && roomCache.containsKey(roomId)) {
      return roomCache[roomId];
    }
    if (roomTitle.isNotEmpty) {
      final cleanTitle = roomTitle.toLowerCase().trim();
      for (final r in roomCache.values) {
        if (r.name.toLowerCase().trim() == cleanTitle) {
          return r;
        }
      }
    }
    fetchRoom(roomId: roomId, roomTitle: roomTitle);
    return null;
  }

  static Future<void> fetchRoom({String roomId = '', String roomTitle = ''}) async {
    final key = roomId.isNotEmpty ? roomId : roomTitle.toLowerCase().trim();
    if (key.isEmpty || _pendingFetches.contains(key)) return;
    _pendingFetches.add(key);

    try {
      var query = Supabase.instance.client
          .from('rooms')
          .select('*, profiles:host_id(id, username, avatar_url, avatar_frame, level, vip_level, novel_level)');

      dynamic res;
      if (roomId.isNotEmpty) {
        res = await query.eq('id', roomId).maybeSingle();
      } else if (roomTitle.isNotEmpty) {
        final list = await query.ilike('name', roomTitle).order('created_at', ascending: false).limit(1);
        if (list != null && list is List && list.isNotEmpty) {
          res = list.first;
        }
      }

      if (res != null && res is Map<String, dynamic>) {
        final room = VoiceRoom.fromJson(res);
        roomCache[room.id] = room;
        if (room.name.isNotEmpty) {
          roomCache[room.name.toLowerCase().trim()] = room;
        }
        final hostData = res['profiles'];
        if (hostData != null && hostData is Map<String, dynamic> && hostData['id'] != null) {
          try {
            final userObj = User.fromJson(hostData);
            UserProfileCacheManager.rxCache[userObj.id] = userObj;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[RoomMetadataCache] Error fetching room: $e');
    } finally {
      _pendingFetches.remove(key);
    }
  }
}
