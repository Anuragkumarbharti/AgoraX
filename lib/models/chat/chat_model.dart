enum MessageType { text, image, audio, video, file, document, gif, sticker, location, contact, reaction, gift, roomInvite }
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
  final String? fileName;
  final int? fileSize;
  final String? thumbnailUrl;
  final double? locationLat;
  final double? locationLng;
  final String? locationName;
  final String? contactName;
  final String? contactPhone;
  final bool isEdited;
  final bool isUnlockGift;
  final int audioDurationSeconds;

  String get inviteRoomId {
    if (contactPhone != null && contactPhone!.trim().isNotEmpty) {
      return contactPhone!.trim();
    }
    if (locationName != null && (locationName!.trim().startsWith('CRN-RM-') || locationName!.trim().startsWith('room_'))) {
      return locationName!.trim();
    }
    if (content.contains('(ID:')) {
      final match = RegExp(r'\(ID:\s*([^\)]+)\)').firstMatch(content);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    final matchId = RegExp(r'(CRN-RM-[A-Za-z0-9_\-]+|room_[A-Za-z0-9_\-]+)').firstMatch(content);
    if (matchId != null && matchId.group(1) != null) {
      return matchId.group(1)!.trim();
    }
    return '';
  }
  String get inviteRoomTitle => (locationName != null && locationName!.isNotEmpty && !locationName!.startsWith('CRN-RM-'))
      ? locationName!
      : (content.startsWith('🎙️ Room Invite: ') ? content.substring(16) : 'Voice Room');
  String get inviteHostName => (contactName != null && contactName!.isNotEmpty && contactName != 'Host')
      ? contactName!
      : 'Owner';
  String get inviteRoomCover => mediaUrl ?? '';

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
    this.fileName,
    this.fileSize,
    this.thumbnailUrl,
    this.locationLat,
    this.locationLng,
    this.locationName,
    this.contactName,
    this.contactPhone,
    this.isEdited = false,
    this.isUnlockGift = false,
    this.audioDurationSeconds = 0,
  });

  ChatMessage copyWith({
    MessageStatus? status,
    bool? isDeleted,
    List<String>? reactions,
    bool? isEdited,
    String? content,
    bool? isUnlockGift,
    int? audioDurationSeconds,
    String? mediaUrl,
    String? fileName,
    int? fileSize,
    String? thumbnailUrl,
    double? locationLat,
    double? locationLng,
    String? locationName,
    String? contactName,
    String? contactPhone,
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
      mediaUrl: mediaUrl ?? this.mediaUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationName: locationName ?? this.locationName,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      isEdited: isEdited ?? this.isEdited,
      isUnlockGift: isUnlockGift ?? this.isUnlockGift,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'receiverId': receiverId,
        'conversationId': conversationId,
        'content': content,
        'type': type.index,
        'status': status.index,
        'timestamp': timestamp.toIso8601String(),
        'isDeleted': isDeleted,
        'replyToId': replyToId,
        'replyToContent': replyToContent,
        'reactions': reactions,
        'mediaUrl': mediaUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'thumbnailUrl': thumbnailUrl,
        'locationLat': locationLat,
        'locationLng': locationLng,
        'locationName': locationName,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'isEdited': isEdited,
        'isUnlockGift': isUnlockGift,
        'audioDurationSeconds': audioDurationSeconds,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? '',
        senderId: json['senderId'] ?? json['sender_id'] ?? '',
        receiverId: json['receiverId'] ?? json['receiver_id'] ?? '',
        conversationId: json['conversationId'] ?? json['conversation_id'] ?? '',
        content: json['content'] ?? '',
        type: MessageType.values[((json['type'] as int?) ?? (json['media_type'] == 'roomInvite' ? MessageType.roomInvite.index : 0)).clamp(0, MessageType.values.length - 1)],
        status: MessageStatus.values[((json['status'] as int?) ?? 0).clamp(0, MessageStatus.values.length - 1)],
        timestamp: DateTime.parse(json['timestamp'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
        isDeleted: json['isDeleted'] ?? json['is_deleted'] ?? false,
        replyToId: json['replyToId'] ?? json['reply_to_id'],
        replyToContent: json['replyToContent'] ?? json['reply_to_content'],
        reactions: json['reactions'] != null ? List<String>.from(json['reactions']) : null,
        mediaUrl: json['mediaUrl'] ?? json['media_url'],
        fileName: json['fileName'] ?? json['file_name'],
        fileSize: json['fileSize'] ?? json['file_size'],
        thumbnailUrl: json['thumbnailUrl'] ?? json['thumbnail_url'],
        locationLat: json['locationLat'] != null ? (json['locationLat'] as num).toDouble() : (json['location_lat'] != null ? (json['location_lat'] as num).toDouble() : null),
        locationLng: json['locationLng'] != null ? (json['locationLng'] as num).toDouble() : (json['location_lng'] != null ? (json['location_lng'] as num).toDouble() : null),
        locationName: json['locationName'] ?? json['location_name'],
        contactName: json['contactName'] ?? json['contact_name'],
        contactPhone: json['contactPhone'] ?? json['contact_phone'] ?? json['room_id'] ?? json['roomId'],
        isEdited: json['isEdited'] ?? json['is_edited'] ?? false,
        isUnlockGift: json['isUnlockGift'] ?? json['is_unlock_gift'] ?? false,
        audioDurationSeconds: json['audioDurationSeconds'] ?? json['audio_duration_seconds'] ?? 0,
      );
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
  final bool isMutualFollow;

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
    this.isMutualFollow = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'otherUserId': otherUserId,
        'otherUserName': otherUserName,
        'otherUserAvatar': otherUserAvatar,
        'otherUserOnline': otherUserOnline,
        'isVerified': isVerified,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime.toIso8601String(),
        'unreadCount': unreadCount,
        'isPinned': isPinned,
        'isMuted': isMuted,
        'isBlocked': isBlocked,
        'lastMessageSenderId': lastMessageSenderId,
        'levelTitle': levelTitle,
        'level': level,
        'isMutualFollow': isMutualFollow,
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] ?? '',
        otherUserId: json['otherUserId'] ?? '',
        otherUserName: json['otherUserName'] ?? '',
        otherUserAvatar: json['otherUserAvatar'] ?? '',
        otherUserOnline: json['otherUserOnline'] ?? false,
        isVerified: json['isVerified'] ?? false,
        lastMessage: json['lastMessage'] ?? '',
        lastMessageTime: DateTime.parse(json['lastMessageTime'] ?? DateTime.now().toIso8601String()),
        unreadCount: json['unreadCount'] ?? 0,
        isPinned: json['isPinned'] ?? false,
        isMuted: json['isMuted'] ?? false,
        isBlocked: json['isBlocked'] ?? false,
        lastMessageSenderId: json['lastMessageSenderId'],
        levelTitle: json['levelTitle'] ?? 'Member',
        level: json['level'] ?? 1,
        isMutualFollow: json['isMutualFollow'] ?? false,
      );
}
