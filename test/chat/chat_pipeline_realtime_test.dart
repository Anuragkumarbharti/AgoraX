import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/chat/chat_model.dart';

void main() {
  group('Realtime Chat Pipeline & Media Unit Tests', () {
    test('ChatMessage JSON Serialization for Text and Media Types', () {
      final now = DateTime.now();
      
      final textMsg = ChatMessage(
        id: 'msg_101',
        senderId: 'user_a',
        receiverId: 'user_b',
        conversationId: 'conv_user_a',
        content: 'Hello Realtime',
        type: MessageType.text,
        timestamp: now,
      );

      final docMsg = ChatMessage(
        id: 'msg_102',
        senderId: 'user_a',
        receiverId: 'user_b',
        conversationId: 'conv_user_a',
        content: 'Quantum_Physics.pdf',
        type: MessageType.document,
        fileName: 'Quantum_Physics.pdf',
        fileSize: 1024000,
        timestamp: now,
      );

      final locMsg = ChatMessage(
        id: 'msg_103',
        senderId: 'user_a',
        receiverId: 'user_b',
        conversationId: 'conv_user_a',
        content: 'Location Card',
        type: MessageType.location,
        locationLat: 28.6139,
        locationLng: 77.2090,
        locationName: 'Main Library',
        timestamp: now,
      );

      final contactMsg = ChatMessage(
        id: 'msg_104',
        senderId: 'user_a',
        receiverId: 'user_b',
        conversationId: 'conv_user_a',
        content: 'Contact Card',
        type: MessageType.contact,
        contactName: 'Dr. Sharma',
        contactPhone: '+919876543210',
        timestamp: now,
      );

      // Verify JSON outputs
      final textJson = textMsg.toJson();
      final docJson = docMsg.toJson();
      final locJson = locMsg.toJson();
      final contactJson = contactMsg.toJson();

      expect(textJson['type'], equals(MessageType.text.index));
      expect(docJson['fileName'], equals('Quantum_Physics.pdf'));
      expect(docJson['fileSize'], equals(1024000));
      expect(locJson['locationLat'], equals(28.6139));
      expect(contactJson['contactName'], equals('Dr. Sharma'));

      // Verify deserialization
      final restoredDoc = ChatMessage.fromJson(docJson);
      expect(restoredDoc.id, equals('msg_102'));
      expect(restoredDoc.type, equals(MessageType.document));
      expect(restoredDoc.fileName, equals('Quantum_Physics.pdf'));

      final restoredLoc = ChatMessage.fromJson(locJson);
      expect(restoredLoc.type, equals(MessageType.location));
      expect(restoredLoc.locationName, equals('Main Library'));
    });

    test('Unread Badge Count Formatting Logic', () {
      String getBadgeLabel(int unread) => unread > 99 ? '99+' : '$unread';

      expect(getBadgeLabel(1), equals('1'));
      expect(getBadgeLabel(4), equals('4'));
      expect(getBadgeLabel(12), equals('12'));
      expect(getBadgeLabel(99), equals('99'));
      expect(getBadgeLabel(100), equals('99+'));
      expect(getBadgeLabel(542), equals('99+'));
    });

    test('Conversation List Sorting and Instant Top Re-ordering', () {
      final now = DateTime.now();
      final convList = [
        Conversation(
          id: 'conv_1',
          otherUserId: 'u1',
          otherUserName: 'Alice',
          otherUserAvatar: '',
          lastMessage: 'Old Message',
          lastMessageTime: now.subtract(const Duration(hours: 2)),
        ),
        Conversation(
          id: 'conv_2',
          otherUserId: 'u2',
          otherUserName: 'Bob',
          otherUserAvatar: '',
          lastMessage: 'Recent Message',
          lastMessageTime: now.subtract(const Duration(minutes: 10)),
        ),
      ];

      // Initial sort (Bob should be first because lastMessageTime is more recent)
      convList.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      expect(convList.first.id, equals('conv_2'));

      // Simulate sending new message to Alice (conv_1)
      final updatedAlice = Conversation(
        id: 'conv_1',
        otherUserId: 'u1',
        otherUserName: 'Alice',
        otherUserAvatar: '',
        lastMessage: 'Newest Message!',
        lastMessageTime: now,
      );

      convList.removeWhere((c) => c.id == updatedAlice.id);
      convList.add(updatedAlice);
      convList.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      // Alice (conv_1) must move to index 0 instantly
      expect(convList.first.id, equals('conv_1'));
      expect(convList.first.lastMessage, equals('Newest Message!'));
    });
  });
}
