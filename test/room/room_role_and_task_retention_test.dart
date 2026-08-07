import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room/room_model.dart';
import 'package:creania/services/room/room_permission_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PERMANENT ROOM ROLES & TASK RETENTION TESTS', () {
    late RoomPermissionController permissionCtrl;
    final ownerId = 'uid_owner_999';
    final coOwnerId = 'uid_co_owner_888';
    final adminId = 'uid_admin_777';
    final starMemberId = 'uid_star_member_666';
    final listenerId = 'uid_listener_555';
    final testRoomId = 'CRN-RM-777666';

    late VoiceRoom room;

    setUp(() {
      permissionCtrl = RoomPermissionController();

      room = VoiceRoom.fromJson({
        'id': testRoomId,
        'name': 'Permanent Roles Arena',
        'username': '@permanent_roles',
        'description': 'Testing role retention across disconnects',
        'hostId': ownerId,
        'host_id': ownerId,
        'room_owner': ownerId,
        'community_id': 'comm_1',
        'type': 'Voice',
        'is_live': true,
        'participant_count': 5,
        'max_participants': 500,
        'speaker_ids': [ownerId, coOwnerId],
        'listener_ids': [adminId, starMemberId, listenerId],
        'allow_recording': false,
        'allow_screen_share': false,
        'created_at': DateTime.now().toIso8601String(),
        'owner_name': 'Permanent Owner',
        'category': 'General',
        'country': 'IN',
        'language': 'English',
        'tags': [],
        'rules': [],
        'level': 5,
        'room_xp': 4500,
        'total_room_stars': 1250,
        'coOwnerIds': [coOwnerId],
        'co_owner_ids': [coOwnerId],
        'adminIds': [adminId],
        'admin_ids': [adminId],
        'starMemberIds': [starMemberId],
        'star_member_ids': [starMemberId],
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

    test('1. Assigned Roles Retention: Co-Owner, Admin, Star Member are permanent for room', () {
      expect(permissionCtrl.getUserRole(room, ownerId), equals('Creator'));
      expect(permissionCtrl.getUserRole(room, coOwnerId), equals('Co-Owner'));
      expect(permissionCtrl.getUserRole(room, adminId), equals('Admin'));
    });

    test('2. Disconnect & Rejoin Retention: Assigned roles remain unchanged when members disconnect', () {
      // Simulating all members going offline
      final roomAfterDisconnect = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [],
        'listener_ids': [],
        'participant_count': 0,
      });

      // Permanent assigned roles in coOwnerIds & adminIds MUST remain
      expect(permissionCtrl.getUserRole(roomAfterDisconnect, coOwnerId), equals('Co-Owner'));
      expect(permissionCtrl.getUserRole(roomAfterDisconnect, adminId), equals('Admin'));
      expect(permissionCtrl.canChangeEntryRules(roomAfterDisconnect, coOwnerId), isTrue);
    });

    test('3. Room Task & Progress Retention: XP and Stars belong permanently to room_id', () {
      expect(room.level, equals(5));
      expect(room.xp, equals(4500));
      expect(room.totalRoomStars, equals(1250));

      // After user leaves, room progress MUST NOT be reset or transferred
      final roomAfterLeave = VoiceRoom.fromJson({
        ...room.toJson(),
        'participant_count': 0,
      });

      expect(roomAfterLeave.xp, equals(4500));
      expect(roomAfterLeave.totalRoomStars, equals(1250));
    });
  });
}
