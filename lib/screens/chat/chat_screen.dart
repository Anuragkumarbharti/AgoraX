import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/chat_model.dart';
import '../../services/chat_controller.dart';
import 'chat_settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({Key? key, required this.conversation}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late final ChatController _ctrl;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final RxList<ChatMessage> _messagesList = <ChatMessage>[].obs;
  final RxBool _hasText = false.obs;
  final RxBool _showEmojiPanel = false.obs;
  final RxBool _showAttachmentPanel = false.obs;
  final RxBool _isRecording = false.obs;
  final RxBool _isRecordingLocked = false.obs;
  final RxInt _recordingSeconds = 0.obs;

  Timer? _recordingTimer;
  late final AnimationController _waveAnimCtrl;

  // Custom mock reply state
  final Rxn<ChatMessage> _replyToMessage = Rxn<ChatMessage>();

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
    });

    _loadConversationMessages();

    // Initial scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _waveAnimCtrl.dispose();
    _recordingTimer?.cancel();
    super.dispose();
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
    // Populate realistic messages exactly matching the reference images
    if (widget.conversation.otherUserId == 'aisha_k' || widget.conversation.id.contains('aisha')) {
      final baseTime = DateTime.now().subtract(const Duration(hours: 1));
      _messagesList.assignAll([
        ChatMessage(
          id: 'm1',
          senderId: 'aisha_k',
          receiverId: 'me',
          conversationId: widget.conversation.id,
          content: 'Heyy! 😊',
          timestamp: baseTime,
          status: MessageStatus.read,
        ),
        ChatMessage(
          id: 'm2',
          senderId: 'me',
          receiverId: 'aisha_k',
          conversationId: widget.conversation.id,
          content: 'Hey Aisha! Kaisi ho?',
          timestamp: baseTime.add(const Duration(minutes: 1)),
          status: MessageStatus.read,
        ),
        ChatMessage(
          id: 'm3',
          senderId: 'aisha_k',
          receiverId: 'me',
          conversationId: widget.conversation.id,
          content: 'Main theek hu, tum batao?',
          timestamp: baseTime.add(const Duration(minutes: 2)),
          status: MessageStatus.read,
        ),
        ChatMessage(
          id: 'm4',
          senderId: 'me',
          receiverId: 'aisha_k',
          conversationId: widget.conversation.id,
          content: 'Main bhi theek hu 😊\nKal ka plan confirm?',
          timestamp: baseTime.add(const Duration(minutes: 3)),
          status: MessageStatus.read,
        ),
        ChatMessage(
          id: 'm5',
          senderId: 'aisha_k',
          receiverId: 'me',
          conversationId: widget.conversation.id,
          content: 'Haan yaar, kal 5 baje cafe mein?',
          timestamp: baseTime.add(const Duration(minutes: 3)),
          status: MessageStatus.read,
        ),
        ChatMessage(
          id: 'm6',
          senderId: 'me',
          receiverId: 'aisha_k',
          conversationId: widget.conversation.id,
          content: 'Done! Main 5 baje tak pahunch jaunga. 👍',
          timestamp: baseTime.add(const Duration(minutes: 4)),
          status: MessageStatus.read,
        ),
        ChatMessage(
          id: 'm7',
          senderId: 'aisha_k',
          receiverId: 'me',
          conversationId: widget.conversation.id,
          content: 'Great! See you kal 😊',
          timestamp: baseTime.add(const Duration(minutes: 5)),
          status: MessageStatus.read,
        ),
        ChatMessage(
          id: 'm8',
          senderId: 'me',
          receiverId: 'aisha_k',
          conversationId: widget.conversation.id,
          content: 'See you! Take care ✌️',
          timestamp: baseTime.add(const Duration(minutes: 5)),
          status: MessageStatus.read,
        ),
      ]);
    } else {
      // Default initial mock messages
      _messagesList.assignAll([
        ChatMessage(
          id: 'm_init',
          senderId: widget.conversation.otherUserId,
          receiverId: 'me',
          conversationId: widget.conversation.id,
          content: 'Hey there! How are you doing today?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          status: MessageStatus.read,
        ),
      ]);
    }
  }

  void _sendMessage({String? text, MessageType type = MessageType.text, String? mediaUrl}) {
    final body = text ?? _msgCtrl.text.trim();
    if (body.isEmpty && mediaUrl == null) return;

    final newMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final chatMsg = ChatMessage(
      id: newMsgId,
      senderId: 'me',
      receiverId: widget.conversation.otherUserId,
      conversationId: widget.conversation.id,
      content: body,
      type: type,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      replyToId: _replyToMessage.value?.id,
      replyToContent: _replyToMessage.value?.content,
      mediaUrl: mediaUrl,
    );

    _messagesList.add(chatMsg);
    _msgCtrl.clear();
    _replyToMessage.value = null;
    HapticFeedback.lightImpact();
    _scrollToBottom();

    // Update conversation last message in list
    final idx = _ctrl.conversations.indexWhere((c) => c.id == widget.conversation.id);
    if (idx != -1) {
      final conv = _ctrl.conversations[idx];
      _ctrl.conversations[idx] = Conversation(
        id: conv.id,
        otherUserId: conv.otherUserId,
        otherUserName: conv.otherUserName,
        otherUserAvatar: conv.otherUserAvatar,
        otherUserOnline: conv.otherUserOnline,
        isVerified: conv.isVerified,
        lastMessage: type == MessageType.audio ? '🎤 Voice note' : body,
        lastMessageTime: DateTime.now(),
        unreadCount: conv.unreadCount,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        levelTitle: conv.levelTitle,
        level: conv.level,
        lastMessageSenderId: 'me',
      );
      _ctrl.conversations.refresh();
    }

    // Simulated status update sequence: sending -> sent -> delivered -> read
    Future.delayed(const Duration(milliseconds: 600), () {
      final idx = _messagesList.indexWhere((m) => m.id == newMsgId);
      if (idx != -1) {
        _messagesList[idx] = _messagesList[idx].copyWith(status: MessageStatus.sent);
      }
    });
    Future.delayed(const Duration(seconds: 2), () {
      final idx = _messagesList.indexWhere((m) => m.id == newMsgId);
      if (idx != -1) {
        _messagesList[idx] = _messagesList[idx].copyWith(status: MessageStatus.delivered);
      }
    });
    Future.delayed(const Duration(seconds: 4), () {
      final idx = _messagesList.indexWhere((m) => m.id == newMsgId);
      if (idx != -1) {
        _messagesList[idx] = _messagesList[idx].copyWith(status: MessageStatus.read);
      }
      
      // Auto-simulate quick reply for dynamic feel
      _simulateReply();
    });
  }

  void _simulateReply() {
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 1), () {
      final replyId = 'reply_${DateTime.now().millisecondsSinceEpoch}';
      final replyMsg = ChatMessage(
        id: replyId,
        senderId: widget.conversation.otherUserId,
        receiverId: 'me',
        conversationId: widget.conversation.id,
        content: 'Awesome! Got it. 😊',
        timestamp: DateTime.now(),
        status: MessageStatus.read,
      );
      _messagesList.add(replyMsg);
      final idx = _ctrl.conversations.indexWhere((c) => c.id == widget.conversation.id);
      if (idx != -1) {
        final conv = _ctrl.conversations[idx];
        _ctrl.conversations[idx] = Conversation(
          id: conv.id,
          otherUserId: conv.otherUserId,
          otherUserName: conv.otherUserName,
          otherUserAvatar: conv.otherUserAvatar,
          otherUserOnline: conv.otherUserOnline,
          isVerified: conv.isVerified,
          lastMessage: 'Awesome! Got it. 😊',
          lastMessageTime: DateTime.now(),
          unreadCount: conv.unreadCount,
          isPinned: conv.isPinned,
          isMuted: conv.isMuted,
          levelTitle: conv.levelTitle,
          level: conv.level,
          lastMessageSenderId: widget.conversation.otherUserId,
        );
        _ctrl.conversations.refresh();
      }
      _scrollToBottom();
    });
  }

  void _startVoiceRecording() {
    _isRecording.value = true;
    _recordingSeconds.value = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _recordingSeconds.value++;
    });
    HapticFeedback.heavyImpact();
  }

  void _stopVoiceRecording({required bool send}) {
    _recordingTimer?.cancel();
    if (send) {
      _sendMessage(text: 'Audio Message (${_recordingSeconds.value}s)', type: MessageType.audio);
    }
    _isRecording.value = false;
    _isRecordingLocked.value = false;
    _recordingSeconds.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _showEmojiPanel.value = false;
                  _showAttachmentPanel.value = false;
                  _focusNode.unfocus();
                },
                child: _buildChatArea(),
              ),
            ),
            _buildInputContainer(),
            Obx(() => _showEmojiPanel.value ? _buildEmojiSelectorPanel() : const SizedBox.shrink()),
            Obx(() => _showAttachmentPanel.value ? _buildAttachmentMenuPanel() : const SizedBox.shrink()),
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
        border: Border(bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
            onPressed: () => Get.back(),
          ),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: conv.level > 0 ? AppTheme.accentColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(conv.otherUserAvatar),
                ),
              ),
              if (conv.otherUserOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.bgDark, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conv.otherUserName,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  conv.otherUserOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.outfit(
                    color: conv.otherUserOnline ? AppTheme.successColor : AppTheme.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary, size: 20),
            onPressed: () => Get.to(() => ChatSettingsScreen(
                  userName: conv.otherUserName,
                  userAvatar: conv.otherUserAvatar,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Obx(() {
      return ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _messagesList.length + 1, // Add space for date separators & bottom typing
        itemBuilder: (context, index) {
          if (index == _messagesList.length) {
            // Show custom Typing bubble if needed
            return const SizedBox(height: 40);
          }
          final msg = _messagesList[index];
          final isMe = msg.senderId == 'me';

          // Simple date separator
          bool showDateSep = false;
          if (index == 0) {
            showDateSep = true;
          } else {
            final prev = _messagesList[index - 1];
            if (msg.timestamp.day != prev.timestamp.day) {
              showDateSep = true;
            }
          }

          return Column(
            children: [
              if (showDateSep) _buildDateSeparator(msg.timestamp),
              _buildMessageBubble(msg, isMe),
            ],
          );
        },
      );
    });
  }

  Widget _buildDateSeparator(DateTime dt) {
    String label = 'Today';
    final now = DateTime.now();
    if (dt.day == now.day - 1) {
      label = 'Yesterday';
    } else if (dt.day != now.day) {
      label = DateFormat('MMMM d, yyyy').format(dt);
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.bgLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: isMe ? null : AppTheme.bgLight,
          gradient: isMe
              ? const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => _showMessageActionMenu(msg),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply Preview
                  if (msg.replyToContent != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 3, height: 24, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg.replyToContent!,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Main Content
                  if (msg.type == MessageType.audio) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 6),
                        Container(
                          width: 100,
                          height: 20,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              12,
                              (idx) => Container(
                                width: 3,
                                height: 5.0 + Random().nextInt(15),
                                decoration: BoxDecoration(
                                  color: Colors.white70,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '0:12',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      msg.content,
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Time and Status Ticks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spacer(),
                      if (msg.isEdited) ...[
                        Text(
                          'Edited  ',
                          style: TextStyle(
                            fontSize: 9,
                            color: isMe ? Colors.white70 : AppTheme.textTertiary,
                          ),
                        ),
                      ],
                      Text(
                        DateFormat('h:mm a').format(msg.timestamp),
                        style: TextStyle(
                          fontSize: 9,
                          color: isMe ? Colors.white70 : AppTheme.textTertiary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildDeliveryStatusTick(msg.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryStatusTick(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded, size: 10, color: Colors.white60);
      case MessageStatus.sent:
        return const Icon(Icons.done_rounded, size: 11, color: Colors.white60);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 11, color: Colors.white60);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 11, color: Color(0xFF60A5FA));
    }
  }

  Widget _buildInputContainer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: AppTheme.bgLight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply Box banner if active
          Obx(() {
            if (_replyToMessage.value != null) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppTheme.bgDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to: ${_replyToMessage.value!.content}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: AppTheme.textTertiary),
                      onPressed: () => _replyToMessage.value = null,
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
                icon: Obx(() => Icon(
                      _showEmojiPanel.value ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_rounded,
                      color: AppTheme.textSecondary,
                    )),
                onPressed: () {
                  _showEmojiPanel.value = !_showEmojiPanel.value;
                  _showAttachmentPanel.value = false;
                  if (_showEmojiPanel.value) {
                    _focusNode.unfocus();
                  } else {
                    _focusNode.requestFocus();
                  }
                },
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          focusNode: _focusNode,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          maxLines: 4,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                            border: InputBorder.none,
                          ),
                          onTap: () {
                            _showEmojiPanel.value = false;
                            _showAttachmentPanel.value = false;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file_rounded, color: AppTheme.textSecondary, size: 20),
                        onPressed: () {
                          _showAttachmentPanel.value = !_showAttachmentPanel.value;
                          _showEmojiPanel.value = false;
                          _focusNode.unfocus();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => _sendMessage(text: '📷 Photo message', type: MessageType.image),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Mic / Send toggle
              Obx(() {
                final hasTxt = _hasText.value;
                if (hasTxt) {
                  return GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  );
                } else {
                  // Interactive recording button
                  return GestureDetector(
                    onLongPressStart: (_) => _startVoiceRecording(),
                    onLongPressEnd: (_) => _stopVoiceRecording(send: true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Obx(() => Icon(
                            _isRecording.value ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 20,
                          )),
                    ),
                  );
                }
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
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record_rounded, color: AppTheme.errorColor, size: 16),
          const SizedBox(width: 8),
          Obx(() => Text(
                'Recording: ${_recordingSeconds.value}s',
                style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              )),
          const Spacer(),
          Text(
            'Release to send • Slide Left to Cancel',
            style: GoogleFonts.outfit(color: AppTheme.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiSelectorPanel() {
    final List<String> dummyEmojis = ['😀', '😂', '😍', '👍', '🔥', '🎉', '❤️', '🙏', '🙌', '✨', '☕', '🎂', '🥳', '😎', '💀', '👀'];
    return Container(
      height: 200,
      color: AppTheme.bgLight,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Emojis'),
              Tab(text: 'Stickers'),
              Tab(text: 'GIFs'),
            ],
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textTertiary,
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
      {'name': 'Document', 'icon': Icons.description_rounded, 'color': Colors.blue},
      {'name': 'Camera', 'icon': Icons.camera_alt_rounded, 'color': Colors.red},
      {'name': 'Gallery', 'icon': Icons.image_rounded, 'color': Colors.purple},
      {'name': 'Audio', 'icon': Icons.headphones_rounded, 'color': Colors.orange},
      {'name': 'Location', 'icon': Icons.location_on_rounded, 'color': Colors.green},
      {'name': 'Contact', 'icon': Icons.person_rounded, 'color': Colors.teal},
    ];
    return Container(
      height: 180,
      color: AppTheme.bgLight,
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.5),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
              _showAttachmentPanel.value = false;
              _sendMessage(text: 'Sent standard ${item['name']}', type: MessageType.file);
            },
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: (item['color'] as Color).withOpacity(0.2),
                  child: Icon(item['icon'] as IconData, color: item['color'] as Color),
                ),
                const SizedBox(height: 6),
                Text(item['name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
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
        color: AppTheme.bgLight,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppTheme.primaryColor),
              title: const Text('Reply'),
              onTap: () {
                _replyToMessage.value = msg;
                Get.back();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: AppTheme.primaryColor),
              title: const Text('Copy Text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                Get.back();
                Get.snackbar('Copied', 'Message copied to clipboard', backgroundColor: AppTheme.bgLight);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
              title: const Text('Delete Message'),
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
