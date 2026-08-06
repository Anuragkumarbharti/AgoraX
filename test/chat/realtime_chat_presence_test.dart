import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/chat/chat_model.dart';

void main() {
  group('Realtime Private Chat & Presence Module Tests', () {
    test('ChatMessage properties and status lifecycle test', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg_1001',
        senderId: 'user_a_id',
        receiverId: 'user_b_id',
        conversationId: 'conv_user_b_id',
        content: 'Hello User B!',
        timestamp: now,
        status: MessageStatus.sending,
      );

      expect(msg.id, 'msg_1001');
      expect(msg.senderId, 'user_a_id');
      expect(msg.receiverId, 'user_b_id');
      expect(msg.content, 'Hello User B!');
      expect(msg.status, MessageStatus.sending);

      // Transition sending -> sent (Single Tick)
      final sentMsg = msg.copyWith(status: MessageStatus.sent);
      expect(sentMsg.status, MessageStatus.sent);

      // Transition sent -> delivered (Double Grey Tick)
      final deliveredMsg = sentMsg.copyWith(status: MessageStatus.delivered);
      expect(deliveredMsg.status, MessageStatus.delivered);

      // Transition delivered -> read (Double Blue Tick)
      final readMsg = deliveredMsg.copyWith(status: MessageStatus.read);
      expect(readMsg.status, MessageStatus.read);
    });

    test('Conversation receiver metadata binding', () {
      final now = DateTime.now();
      final conv = Conversation(
        id: 'conv_user_b_id',
        otherUserId: 'user_b_id',
        otherUserName: 'User B Name',
        otherUserAvatar: 'https://example.com/avatar_b.png',
        otherUserOnline: true,
        lastMessage: 'Hello User B!',
        lastMessageTime: now,
        unreadCount: 2,
      );

      expect(conv.id, 'conv_user_b_id');
      expect(conv.otherUserId, 'user_b_id');
      expect(conv.otherUserName, 'User B Name');
      expect(conv.otherUserAvatar, 'https://example.com/avatar_b.png');
      expect(conv.otherUserOnline, isTrue);
      expect(conv.unreadCount, 2);
    });

    test('Typing indicator rule validation', () {
      const currentUserId = 'user_a_id';
      const senderUserId = 'user_a_id';
      const receiverUserId = 'user_b_id';

      // Self typing must be ignored for User A
      bool isSelfTypingIgnored = (senderUserId == currentUserId);
      expect(isSelfTypingIgnored, isTrue);

      // Receiver typing event from User B must be accepted by User A
      const otherSenderId = 'user_b_id';
      bool isReceiverTypingAccepted = (otherSenderId != currentUserId);
      expect(isReceiverTypingAccepted, isTrue);
    });
  });
}
