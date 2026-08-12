import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room/room_model.dart';
import 'package:creania/services/room/room_permission_controller.dart';
import 'package:creania/services/room/room_moderation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PERMANENT ROOM OWNERSHIP SYSTEM (STARMAKER MODEL) TESTS', () {
    late RoomPermissionController permissionCtrl;
    final ownerId = 'uid_permanent_owner_101';
    final coOwnerId = 'uid_co_owner_202';
    final adminId = 'uid_admin_303';
    final audienceId = 'uid_audience_404';
    final testRoomId = 'CRN-RM-888999';

    late VoiceRoom room;

    setUp(() {
      permissionCtrl = RoomPermissionController();

      room = VoiceRoom.fromJson({
        'id': testRoomId,
        'name': 'StarMaker Permanent Room',
        'username': '@starmaker_room',
        'description': 'Permanent Room Test',
        'host_id': ownerId,
        'room_owner': ownerId,
        'community_id': 'comm_1',
        'type': 'Voice',
        'is_live': true,
        'participant_count': 5,
        'max_participants': 500,
        'speaker_ids': [ownerId, coOwnerId],
        'listener_ids': [adminId, audienceId],
        'allow_recording': false,
        'allow_screen_share': false,
        'created_at': DateTime.now().toIso8601String(),
        'owner_name': 'Original Owner',
        'category': 'General',
        'country': 'IN',
        'language': 'English',
        'tags': [],
        'rules': [],
        'level': 5,
        'is_permanent': true,
        'co_owner_ids': [coOwnerId],
        'admin_ids': [adminId],
        'star_member_ids': [],
        'manager_ids': [],
        'moderator_ids': [adminId],
        'host_ids': [],
        'mentor_ids': [],
        'judge_ids': [],
        'performer_ids': [],
        'elite_member_ids': [],
        'vip_member_ids': [],
        'member_ids': [],
        'visitor_ids': [],
        'block_list': [],
      });
    });

    test('1. Requirement 1 & 8: Permanent Owner linkage via hostId', () {
      expect(room.hostId, equals(ownerId));
      expect(permissionCtrl.getUserRole(room, ownerId), equals('Owner'));
      expect(permissionCtrl.getRoleWeight('Owner'), equals(10));
      expect(permissionCtrl.isHost(testRoomId, ownerId, room: room), isTrue);
    });

    test('2. Requirement 3 & 5: Disconnect simulation does NOT change room.hostId', () {
      // Simulating owner disconnect by removing owner from online speakers/listeners
      final roomAfterDisconnect = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [coOwnerId],
        'listener_ids': [adminId, audienceId],
        'participant_count': 3,
      });

      // hostId MUST remain original owner
      expect(roomAfterDisconnect.hostId, equals(ownerId));
      // Co-owner stays Co-Owner and NEVER becomes Owner
      expect(permissionCtrl.getUserRole(roomAfterDisconnect, coOwnerId), equals('Co-Owner'));
    });

    test('3. Requirement 4: Temporary Host Control (Co-Owner/Admin moderation, non-owner)', () {
      // Co-owner has co-host privileges
      expect(permissionCtrl.isCoHost(testRoomId, coOwnerId, room: room), isTrue);
      // Co-owner CAN change entry rules
      expect(permissionCtrl.canChangeEntryRules(room, coOwnerId), isTrue);
      // Co-owner role is NOT Owner
      expect(permissionCtrl.getUserRole(room, coOwnerId), isNot(equals('Owner')));
    });

    test('4. Requirement 9: Owner rejoin instantly restores Owner role and permissions', () {
      // Owner rejoins after disconnect
      final roomAfterRejoin = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [ownerId, coOwnerId],
        'participant_count': 4,
      });

      expect(roomAfterRejoin.hostId, equals(ownerId));
      expect(permissionCtrl.getUserRole(roomAfterRejoin, ownerId), equals('Owner'));
      expect(permissionCtrl.canChangeEntryRules(roomAfterRejoin, ownerId), isTrue);
    });

    test('5. Requirement 6 & 11: Ownership Transfer is permanently disabled', () async {
      final moderationCtrl = RoomModerationController();
      final newOwnerId = 'uid_new_owner_505';

      expect(
        () async => await moderationCtrl.transferHost(testRoomId, newOwnerId),
        throwsA(isA<Exception>()),
      );

      final result = await moderationCtrl.transferRoomOwnership(testRoomId, newOwnerId);
      expect(result, isFalse);
    });
  });
}
