import 'package:isar/isar.dart';

part 'isar_chat_model.g.dart';

@collection
class IsarConversation {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid; // e.g. 'conv_aisha'

  late String otherUserId;
  late String otherUserName;
  late String otherUserAvatar;
  late bool otherUserOnline;
  late bool isVerified;
  late String lastMessage;
  late DateTime lastMessageTime;
  late int unreadCount;
  late bool isPinned;
  late bool isMuted;
  late String levelTitle;
  late int level;
  late String lastMessageSenderId;
}

@collection
class IsarChatMessage {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid; // e.g. 'msg_12345'

  late String senderId;
  late String receiverId;

  @Index()
  late String conversationId;

  late String content;

  late int typeValue; // index of MessageType enum
  late int statusValue; // index of MessageStatus enum

  late DateTime timestamp;
  late bool isDeleted;

  String? replyToId;
  String? replyToContent;

  List<String>? reactions;
  String? mediaUrl;
  late bool isEdited;
}
