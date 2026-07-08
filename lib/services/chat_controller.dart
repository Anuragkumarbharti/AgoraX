import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../core/chat_crypto.dart';

class ChatController extends GetxController {
  // Current logged-in user id (mock)
  static const String currentUserId = 'me';
  static const String currentUserName = 'Anurag Kumar';
  static const String currentUserAvatar =
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200';

  // ─── Conversations list ───
  final RxList<Conversation> conversations = <Conversation>[
    Conversation(
      id: 'conv_1',
      otherUserId: 'u2',
      otherUserName: 'Priya Sharma',
      otherUserAvatar:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
      otherUserOnline: true,
      isVerified: true,
      lastMessage: 'The voice room session was amazing! 🔥',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 3,
      isPinned: true,
      levelTitle: 'Expert',
      level: 12,
    ),
    Conversation(
      id: 'conv_2',
      otherUserId: 'u3',
      otherUserName: 'Rahul Verma',
      otherUserAvatar:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
      otherUserOnline: false,
      isVerified: false,
      lastMessage: 'Can you share the Flutter resources?',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
      unreadCount: 1,
      levelTitle: 'Intermediate',
      level: 7,
      lastMessageSenderId: 'u3',
    ),
    Conversation(
      id: 'conv_3',
      otherUserId: 'u4',
      otherUserName: 'Ananya Patel',
      otherUserAvatar:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200',
      otherUserOnline: true,
      isVerified: true,
      lastMessage: 'Sure, let\'s schedule the collab next week 👍',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 0,
      levelTitle: 'Pro',
      level: 10,
      lastMessageSenderId: currentUserId,
    ),
    Conversation(
      id: 'conv_4',
      otherUserId: 'u5',
      otherUserName: 'Dev Singh',
      otherUserAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
      otherUserOnline: false,
      isVerified: false,
      lastMessage: 'Check out this new DSA problem I found!',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 6)),
      unreadCount: 0,
      isMuted: true,
      levelTitle: 'Learner',
      level: 4,
      lastMessageSenderId: 'u5',
    ),
    Conversation(
      id: 'conv_5',
      otherUserId: 'u6',
      otherUserName: 'Meera Joshi',
      otherUserAvatar:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200',
      otherUserOnline: false,
      isVerified: false,
      lastMessage: 'Thanks for the help with Dart async! 🙏',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      levelTitle: 'Member',
      level: 3,
    ),
    Conversation(
      id: 'conv_6',
      otherUserId: 'u7',
      otherUserName: 'Arjun Nair',
      otherUserAvatar:
          'https://images.unsplash.com/photo-1542080681-b52d0d523d0c?w=200',
      otherUserOnline: true,
      isVerified: true,
      lastMessage: 'The debate room was lit yesterday! 🎤',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 0,
      levelTitle: 'Expert',
      level: 15,
    ),
  ].obs;

  // ─── Messages per conversation ───
  final RxMap<String, List<ChatMessage>> _messages =
      <String, List<ChatMessage>>{}.obs;

  // ─── Typing state ───
  final RxMap<String, bool> typingState = <String, bool>{}.obs;

  // ─── Search ───
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;

  // ─── Selected messages (for multi-select) ───
  final RxSet<String> selectedMessageIds = <String>{}.obs;
  final RxBool isSelectionMode = false.obs;

  List<Conversation> get filteredConversations {
    if (searchQuery.isEmpty) return conversations;
    return conversations
        .where((c) =>
            c.otherUserName
                .toLowerCase()
                .contains(searchQuery.value.toLowerCase()) ||
            c.lastMessage
                .toLowerCase()
                .contains(searchQuery.value.toLowerCase()))
        .toList();
  }

  Conversation getOrCreateConversation(String otherUserId, String otherUserName, String otherUserAvatar) {
    final String convId = 'conv_$otherUserId';
    final int idx = conversations.indexWhere((c) => c.id == convId || c.otherUserId == otherUserId);
    if (idx != -1) {
      return conversations[idx];
    }
    final newConv = Conversation(
      id: convId,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
      lastMessage: 'Started chat',
      lastMessageTime: DateTime.now(),
      otherUserOnline: true,
    );
    conversations.add(newConv);
    return newConv;
  }

  List<ChatMessage> getMessages(String conversationId) {
    return _messages[conversationId] ?? _generateMockMessages(conversationId);
  }

  List<ChatMessage> _generateMockMessages(String conversationId) {
    final conv = conversations.firstWhere((c) => c.id == conversationId,
        orElse: () => conversations.first);
    final otherId = conv.otherUserId;

    final msgs = <ChatMessage>[
      ChatMessage(
        id: 'm1',
        senderId: otherId,
        receiverId: currentUserId,
        conversationId: conversationId,
        content: 'Hey! How are you doing? 👋',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'm2',
        senderId: currentUserId,
        receiverId: otherId,
        conversationId: conversationId,
        content: 'I\'m great! Just been working on some Flutter stuff 💪',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2, minutes: 55)),
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'm3',
        senderId: otherId,
        receiverId: currentUserId,
        conversationId: conversationId,
        content: 'Nice! I saw you joined the Flutter India community on AgoraX. That community is 🔥',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2, minutes: 30)),
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'm4',
        senderId: currentUserId,
        receiverId: otherId,
        conversationId: conversationId,
        content: 'Yeah, the discussions there are super valuable. Are you also in voice rooms regularly?',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'm5',
        senderId: otherId,
        receiverId: currentUserId,
        conversationId: conversationId,
        content: 'Absolutely! The debate rooms are my favourite 🎤\n\nI host one every weekend on system design topics.',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 40)),
        status: MessageStatus.read,
        reactions: ['❤️', '🔥'],
      ),
      ChatMessage(
        id: 'm6',
        senderId: currentUserId,
        receiverId: otherId,
        conversationId: conversationId,
        content: 'Oh wow! That sounds super interesting. Can you add me as a speaker next time?',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'm7',
        senderId: otherId,
        receiverId: currentUserId,
        conversationId: conversationId,
        content: 'Of course! I\'ll send you a room invite this Saturday at 8 PM IST 🚀',
        timestamp: DateTime.now().subtract(const Duration(hours: 4, minutes: 45)),
        status: MessageStatus.read,
        replyToId: 'm6',
        replyToContent: 'Can you add me as a speaker next time?',
      ),
      ChatMessage(
        id: 'm8',
        senderId: currentUserId,
        receiverId: otherId,
        conversationId: conversationId,
        content: 'Perfect! I\'ll be there 🙌',
        timestamp: DateTime.now().subtract(const Duration(hours: 4, minutes: 30)),
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'm9',
        senderId: otherId,
        receiverId: currentUserId,
        conversationId: conversationId,
        content: 'The voice room session was amazing! 🔥',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        status: MessageStatus.delivered,
      ),
    ];

    _messages[conversationId] = msgs;
    return msgs;
  }

  void sendMessage(String conversationId, String content) async {
    if (content.trim().isEmpty) return;

    final int idxSearch = conversations.indexWhere((c) => c.id == conversationId);
    final conv = idxSearch != -1 
        ? conversations[idxSearch] 
        : getOrCreateConversation(
            conversationId.startsWith('conv_') ? conversationId.substring(5) : conversationId,
            'User',
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
          );

    final String encrypted = ChatCrypto.encryptMessage(content.trim());

    // Try inserting into Supabase
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        await client.from('messages').insert({
          'sender_id': client.auth.currentUser!.id,
          'receiver_id': conv.otherUserId.length == 36 ? conv.otherUserId : null,
          'encrypted_content': encrypted,
          'is_private': true,
        });
      }
    } catch (_) {
      // Fail silently to allow simulated offline fallback
    }

    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUserId,
      receiverId: conv.otherUserId,
      conversationId: conversationId,
      content: content.trim(),
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    final current = getMessages(conversationId);
    _messages[conversationId] = [...current, msg];

    // Update conversation last message
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      conversations[idx] = Conversation(
        id: conv.id,
        otherUserId: conv.otherUserId,
        otherUserName: conv.otherUserName,
        otherUserAvatar: conv.otherUserAvatar,
        otherUserOnline: conv.otherUserOnline,
        isVerified: conv.isVerified,
        lastMessage: content.trim(),
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        levelTitle: conv.levelTitle,
        level: conv.level,
        lastMessageSenderId: currentUserId,
      );
    }

    // Simulate sent after delay
    Future.delayed(const Duration(milliseconds: 800), () {
      final msgs = _messages[conversationId] ?? [];
      final updatedMsgs = msgs.map((m) {
        if (m.id == msg.id) return m.copyWith(status: MessageStatus.sent);
        return m;
      }).toList();
      _messages[conversationId] = updatedMsgs;
      _messages.refresh();

      // Simulate delivered
      Future.delayed(const Duration(seconds: 2), () {
        final msgs2 = _messages[conversationId] ?? [];
        final updatedMsgs2 = msgs2.map((m) {
          if (m.id == msg.id) return m.copyWith(status: MessageStatus.delivered);
          return m;
        }).toList();
        _messages[conversationId] = updatedMsgs2;
        _messages.refresh();
      });
    });

    _messages.refresh();
    conversations.refresh();
  }

  void addReaction(String conversationId, String messageId, String emoji) {
    final msgs = _messages[conversationId] ?? [];
    final updatedMsgs = msgs.map((m) {
      if (m.id == messageId) {
        final existing = List<String>.from(m.reactions ?? []);
        if (existing.contains(emoji)) {
          existing.remove(emoji);
        } else {
          existing.add(emoji);
        }
        return m.copyWith(reactions: existing);
      }
      return m;
    }).toList();
    _messages[conversationId] = updatedMsgs;
    _messages.refresh();
  }

  void deleteMessage(String conversationId, String messageId) {
    final msgs = _messages[conversationId] ?? [];
    final updatedMsgs = msgs.map((m) {
      if (m.id == messageId) return m.copyWith(isDeleted: true);
      return m;
    }).toList();
    _messages[conversationId] = updatedMsgs;
    _messages.refresh();
  }

  void markConversationRead(String conversationId) {
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final conv = conversations[idx];
      conversations[idx] = Conversation(
        id: conv.id,
        otherUserId: conv.otherUserId,
        otherUserName: conv.otherUserName,
        otherUserAvatar: conv.otherUserAvatar,
        otherUserOnline: conv.otherUserOnline,
        isVerified: conv.isVerified,
        lastMessage: conv.lastMessage,
        lastMessageTime: conv.lastMessageTime,
        unreadCount: 0,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        levelTitle: conv.levelTitle,
        level: conv.level,
        lastMessageSenderId: conv.lastMessageSenderId,
      );
      conversations.refresh();
    }
  }

  void setTyping(String conversationId, bool value) {
    typingState[conversationId] = value;
    typingState.refresh();
  }

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);

  void togglePin(String conversationId) {
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1) return;
    final conv = conversations[idx];
    conversations[idx] = Conversation(
      id: conv.id,
      otherUserId: conv.otherUserId,
      otherUserName: conv.otherUserName,
      otherUserAvatar: conv.otherUserAvatar,
      otherUserOnline: conv.otherUserOnline,
      isVerified: conv.isVerified,
      lastMessage: conv.lastMessage,
      lastMessageTime: conv.lastMessageTime,
      unreadCount: conv.unreadCount,
      isPinned: !conv.isPinned,
      isMuted: conv.isMuted,
      levelTitle: conv.levelTitle,
      level: conv.level,
    );
    conversations.refresh();
  }

  void toggleMute(String conversationId) {
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1) return;
    final conv = conversations[idx];
    conversations[idx] = Conversation(
      id: conv.id,
      otherUserId: conv.otherUserId,
      otherUserName: conv.otherUserName,
      otherUserAvatar: conv.otherUserAvatar,
      otherUserOnline: conv.otherUserOnline,
      isVerified: conv.isVerified,
      lastMessage: conv.lastMessage,
      lastMessageTime: conv.lastMessageTime,
      unreadCount: conv.unreadCount,
      isPinned: conv.isPinned,
      isMuted: !conv.isMuted,
      levelTitle: conv.levelTitle,
      level: conv.level,
    );
    conversations.refresh();
  }

  void deleteConversation(String conversationId) {
    conversations.removeWhere((c) => c.id == conversationId);
    _messages.remove(conversationId);
  }
}
