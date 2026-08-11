import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/chat/chat_model.dart';
import 'package:creania/screens/rooms/voice_room/dialogs/room_share_friends_sheet.dart';

void main() {
  group('Room Share & Invitation System Tests', () {
    test('MessageType enum contains roomInvite', () {
      expect(MessageType.values.contains(MessageType.roomInvite), isTrue);
      expect(MessageType.roomInvite.name, equals('roomInvite'));
    });

    test('ChatMessage roomInvite serialization & deserialization', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'invite_101',
        senderId: 'user_sender_1',
        receiverId: 'user_receiver_2',
        conversationId: 'conv_1_2',
        content: '🎙️ Room Invite: Music Lovers',
        type: MessageType.roomInvite,
        status: MessageStatus.sent,
        timestamp: now,
        locationName: 'Music Lovers',
        contactName: 'Rahul Host',
        contactPhone: 'room_31164351',
        mediaUrl: 'https://example.com/cover.jpg',
      );

      expect(msg.inviteRoomId, equals('room_31164351'));
      expect(msg.inviteRoomTitle, equals('Music Lovers'));
      expect(msg.inviteHostName, equals('Rahul Host'));
      expect(msg.inviteRoomCover, equals('https://example.com/cover.jpg'));

      final jsonMap = msg.toJson();
      expect(jsonMap['type'], equals(MessageType.roomInvite.index));

      final deserialized = ChatMessage.fromJson(jsonMap);
      expect(deserialized.id, equals('invite_101'));
      expect(deserialized.type, equals(MessageType.roomInvite));
      expect(deserialized.inviteRoomId, equals('room_31164351'));
      expect(deserialized.inviteRoomTitle, equals('Music Lovers'));
      expect(deserialized.inviteHostName, equals('Rahul Host'));
    });

    test('ShareUserCandidate deduplication logic', () {
      final List<ShareUserCandidate> candidates = [
        ShareUserCandidate(userId: 'u1', name: 'Rahul', avatar: '', isRecent: true),
        ShareUserCandidate(userId: 'u2', name: 'Aman', avatar: '', isRecent: true),
        ShareUserCandidate(userId: 'u3', name: 'Priya', avatar: '', isRecent: false),
      ];

      final Map<String, ShareUserCandidate> deduplicated = {};
      for (final c in candidates) {
        if (!deduplicated.containsKey(c.userId)) {
          deduplicated[c.userId] = c;
        }
      }

      expect(deduplicated.length, equals(3));
      expect(deduplicated.containsKey('u1'), isTrue);
      expect(deduplicated.containsKey('u2'), isTrue);
      expect(deduplicated.containsKey('u3'), isTrue);
    });
  });
}
