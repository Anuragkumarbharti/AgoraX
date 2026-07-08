enum MessageType { text, image, audio, video, file, gif, reaction }
enum MessageStatus { sending, sent, delivered, read }

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isDeleted;
  final String? replyToId;
  final String? replyToContent;
  final List<String>? reactions; // emoji list
  final String? mediaUrl;
  final bool isEdited;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.conversationId,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    required this.timestamp,
    this.isDeleted = false,
    this.replyToId,
    this.replyToContent,
    this.reactions,
    this.mediaUrl,
    this.isEdited = false,
  });

  ChatMessage copyWith({
    MessageStatus? status,
    bool? isDeleted,
    List<String>? reactions,
    bool? isEdited,
    String? content,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      conversationId: conversationId,
      content: content ?? this.content,
      type: type,
      status: status ?? this.status,
      timestamp: timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToId: replyToId,
      replyToContent: replyToContent,
      reactions: reactions ?? this.reactions,
      mediaUrl: mediaUrl,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}

class Conversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;
  final bool otherUserOnline;
  final bool isVerified;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isBlocked;
  final String? lastMessageSenderId; // to show "You: ..." vs name
  final String levelTitle;
  final int level;

  const Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
    this.otherUserOnline = false,
    this.isVerified = false,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isBlocked = false,
    this.lastMessageSenderId,
    this.levelTitle = 'Member',
    this.level = 1,
  });
}
