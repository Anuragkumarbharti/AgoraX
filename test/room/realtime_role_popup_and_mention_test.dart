import 'package:flutter_test/flutter_test.dart';
import 'package:creania/services/room/room_chat_controller.dart';
import 'package:creania/widgets/room/role_update_popup_dialog.dart';

void main() {
  group('Real Time Role Popup System Tests', () {
    test('RoleUpdatePopupDialog initializes correctly for assigned role', () {
      final dialog = RoleUpdatePopupDialog(
        type: RoleUpdateType.assigned,
        roleName: 'Admin',
        roomName: 'Arena Music',
      );

      expect(dialog.type, equals(RoleUpdateType.assigned));
      expect(dialog.roleName, equals('Admin'));
      expect(dialog.roomName, equals('Arena Music'));
    });

    test('RoleUpdatePopupDialog initializes correctly for removed role', () {
      final dialog = RoleUpdatePopupDialog(
        type: RoleUpdateType.removed,
        roleName: 'Audience',
        oldRoleName: 'Admin',
        roomName: 'Arena Music',
        reason: 'Inactive for 30 days',
      );

      expect(dialog.type, equals(RoleUpdateType.removed));
      expect(dialog.oldRoleName, equals('Admin'));
      expect(dialog.reason, equals('Inactive for 30 days'));
    });
  });

  group('Room Mention System Tests', () {
    test('RoomChatMessage identifies direct mentioned user ID', () {
      final msg = RoomChatMessage(
        senderId: 'user_sender',
        senderName: 'Rahul',
        text: 'Hey @Priya check this out!',
        timestamp: DateTime.now(),
        mentionedUserIds: ['user_priya_101'],
      );

      expect(msg.isMentionedForUser('user_priya_101', 'Priya'), isTrue);
      expect(msg.isMentionedForUser('user_other_202', 'Other'), isFalse);
    });

    test('RoomChatMessage matches text mention by username token', () {
      final msg = RoomChatMessage(
        senderId: 'user_sender',
        senderName: 'Rahul',
        text: 'Welcome @Anurag to the stage!',
        timestamp: DateTime.now(),
      );

      expect(msg.isMentionedForUser('uid_anurag_101', 'Anurag'), isTrue);
      expect(msg.isMentionedForUser('user_priya_101', 'Priya'), isFalse);
    });

    test('Non-room members cannot be mentioned (filtering test)', () {
      final List<Map<String, String>> activeRoomMembers = [
        {'userId': 'usr_1', 'userName': 'Rahul'},
        {'userId': 'usr_2', 'userName': 'Priya'},
      ];

      String query = 'Vikram';
      final matches = activeRoomMembers.where((m) {
        return m['userName']!.toLowerCase().contains(query.toLowerCase());
      }).toList();

      expect(matches, isEmpty);

      query = 'Rahul';
      final validMatches = activeRoomMembers.where((m) {
        return m['userName']!.toLowerCase().contains(query.toLowerCase());
      }).toList();

      expect(validMatches, hasLength(1));
      expect(validMatches.first['userName'], equals('Rahul'));
    });
  });
}
