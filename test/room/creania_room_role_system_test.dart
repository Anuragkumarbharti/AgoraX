import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room/room_model.dart';
import 'package:creania/services/room/room_permission_controller.dart';
import 'package:creania/services/room/room_seat_controller.dart';
import 'package:creania/services/room/room_controller.dart';
import 'package:creania/services/room/room_moderation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CREANIA ROOM ROLE SYSTEM Unit Tests', () {
    late RoomPermissionController permissionCtrl;
    late RoomController roomCtrl;
    final testRoomId = 'room_creania_101';
    final creatorId = 'creator_user_1';
    final coOwnerId = 'co_owner_user_2';
    final adminId = 'admin_user_3';
    final audienceId = 'audience_user_4';

    late VoiceRoom level1Room;
    late VoiceRoom level3Room;
    late VoiceRoom level7Room;

    setUp(() {
      permissionCtrl = RoomPermissionController();
      roomCtrl = RoomController();

      level1Room = VoiceRoom.fromJson({
        'id': testRoomId,
        'name': 'Creania Main Arena',
        'username': 'creania_main',
        'description': 'Official Creania Voice Room',
        'host_id': creatorId,
        'founderId': creatorId,
        'community_id': 'comm_1',
        'type': 'Voice',
        'is_live': true,
        'participant_count': 10,
        'max_participants': 500,
        'speaker_ids': [creatorId],
        'listener_ids': [audienceId],
        'allow_recording': false,
        'allow_screen_share': false,
        'created_at': DateTime.now().toIso8601String(),
        'owner_name': 'Creator Anurag',
        'category': 'General',
        'country': 'IN',
        'language': 'Hindi',
        'tags': [],
        'rules': [],
        'level': 1,
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

      level3Room = VoiceRoom.fromJson({
        ...level1Room.toJson(),
        'level': 3,
      });

      level7Room = VoiceRoom.fromJson({
        ...level1Room.toJson(),
        'level': 7,
      });
    });

    test('1. Role Hierarchy Resolution & Weights Verification', () {
      // Creator IS Owner
      expect(permissionCtrl.getUserRole(level1Room, creatorId), equals('Owner'));
      expect(permissionCtrl.getRoleWeight('Owner'), equals(10));

      // Co-Owner
      expect(permissionCtrl.getUserRole(level1Room, coOwnerId), equals('Co-Owner'));
      expect(permissionCtrl.getRoleWeight('Co-Owner'), equals(8));

      // Admin
      expect(permissionCtrl.getUserRole(level1Room, adminId), equals('Admin'));
      expect(permissionCtrl.getRoleWeight('Admin'), equals(7));

      // Mod
      expect(permissionCtrl.getRoleWeight('Mod'), equals(5));

      // Audience
      expect(permissionCtrl.getUserRole(level1Room, audienceId), equals('Audience'));
      expect(permissionCtrl.getRoleWeight('Audience'), equals(1));
    });

    test('2. Seat Position Role Independence (Seats 1-10 do NOT grant roles)', () {
      final seatsWithAudienceOnSeat1 = [
        {'seatIndex': 0, 'userId': audienceId, 'name': 'Seat 1'},
        {'seatIndex': 1, 'userId': null, 'name': 'Seat 2'},
      ];

      final seatsWithAudienceOnSeat2 = [
        {'seatIndex': 0, 'userId': null, 'name': 'Seat 1'},
        {'seatIndex': 1, 'userId': audienceId, 'name': 'Seat 2'},
      ];

      // Sitting on Seat 1 (Seat Index 0) does NOT grant any role (remains Audience)
      expect(
        permissionCtrl.getUserRole(level1Room, audienceId, seatsInfo: seatsWithAudienceOnSeat1),
        equals('Audience'),
      );

      // Sitting on Seat 2 (Seat Index 1) does NOT grant any role (remains Audience)
      expect(
        permissionCtrl.getUserRole(level1Room, audienceId, seatsInfo: seatsWithAudienceOnSeat2),
        equals('Audience'),
      );
    });

    test('3. Room Level Role Capacities Calculation', () {
      // Level 1: 1 Co Owner, 4 Admins
      final limitsL1 = permissionCtrl.getRoomRoleLimits(1);
      expect(limitsL1['co_owners'], equals(1));
      expect(limitsL1['admins'], equals(4));

      // Level 2: 1 Co Owner, 10 Admins
      final limitsL2 = permissionCtrl.getRoomRoleLimits(2);
      expect(limitsL2['co_owners'], equals(1));
      expect(limitsL2['admins'], equals(10));

      // Level 3: 2 Co Owners, 15 Admins
      final limitsL3 = permissionCtrl.getRoomRoleLimits(3);
      expect(limitsL3['co_owners'], equals(2));
      expect(limitsL3['admins'], equals(15));

      // Level 4: 2 Co Owners, 20 Admins
      final limitsL4 = permissionCtrl.getRoomRoleLimits(4);
      expect(limitsL4['co_owners'], equals(2));
      expect(limitsL4['admins'], equals(20));

      // Level 5: 3 Co Owners, 25 Admins
      final limitsL5 = permissionCtrl.getRoomRoleLimits(5);
      expect(limitsL5['co_owners'], equals(3));
      expect(limitsL5['admins'], equals(25));

      // Level 6: 4 Co Owners, 35 Admins
      final limitsL6 = permissionCtrl.getRoomRoleLimits(6);
      expect(limitsL6['co_owners'], equals(4));
      expect(limitsL6['admins'], equals(35));

      // Level 7+: 5 Co Owners, 50 Admins
      final limitsL7 = permissionCtrl.getRoomRoleLimits(7);
      expect(limitsL7['co_owners'], equals(5));
      expect(limitsL7['admins'], equals(50));
    });

    test('4. Room Entry Rule Permissions Matrix', () {
      // Creator/Owner CAN change entry rules
      expect(permissionCtrl.canChangeEntryRules(level1Room, creatorId), isTrue);

      // Co-Owner CAN change entry rules
      expect(permissionCtrl.canChangeEntryRules(level1Room, coOwnerId), isTrue);

      // Admin CANNOT change entry rules
      expect(permissionCtrl.canChangeEntryRules(level1Room, adminId), isFalse);

      // Audience CANNOT change entry rules
      expect(permissionCtrl.canChangeEntryRules(level1Room, audienceId), isFalse);
    });

    test('5. Role Hierarchy Manage Button Visibility Matrix', () {
      final ownerWeight = permissionCtrl.getRoleWeight('Owner');
      final coOwnerWeight = permissionCtrl.getRoleWeight('Co-Owner');
      final adminWeight = permissionCtrl.getRoleWeight('Admin');
      final modWeight = permissionCtrl.getRoleWeight('Mod');
      final audienceWeight = permissionCtrl.getRoleWeight('Audience');

      // OWNER sees Manage on Co-Owner, Admin, Mod, Audience
      expect(ownerWeight > coOwnerWeight, isTrue);
      expect(ownerWeight > adminWeight, isTrue);
      expect(ownerWeight > modWeight, isTrue);
      expect(ownerWeight > audienceWeight, isTrue);

      // CO-OWNER sees Manage on Admin, Mod, Audience
      expect(coOwnerWeight > ownerWeight, isFalse);
      expect(coOwnerWeight > adminWeight, isTrue);
      expect(coOwnerWeight > modWeight, isTrue);
      expect(coOwnerWeight > audienceWeight, isTrue);

      // ADMIN sees Manage on Mod, Audience
      expect(adminWeight > ownerWeight, isFalse);
      expect(adminWeight > coOwnerWeight, isFalse);
      expect(adminWeight > modWeight, isTrue);
      expect(adminWeight > audienceWeight, isTrue);

      // MOD sees Manage on Audience
      expect(modWeight > adminWeight, isFalse);
      expect(modWeight > audienceWeight, isTrue);

      // AUDIENCE sees Manage on no one
      expect(audienceWeight > modWeight, isFalse);
      expect(audienceWeight > audienceWeight, isFalse);
    });

    test('6. Role Assignment and Removal Granular Permissions Matrix', () {
      final ownerWeight = permissionCtrl.getRoleWeight('Owner');
      final coOwnerWeight = permissionCtrl.getRoleWeight('Co-Owner');
      final adminWeight = permissionCtrl.getRoleWeight('Admin');

      // Owner can assign/remove Co-Owner (8), Admin (7), Mod (5)
      final ownerCanAssignCoOwner = ownerWeight >= 10;
      final ownerCanAssignAdmin = ownerWeight >= 10 || ownerWeight >= 8;
      final ownerCanAssignMod = ownerWeight >= 10 || ownerWeight >= 8 || ownerWeight >= 7;
      expect(ownerCanAssignCoOwner, isTrue);
      expect(ownerCanAssignAdmin, isTrue);
      expect(ownerCanAssignMod, isTrue);

      // Co-Owner can assign/remove Admin (7), Mod (5) but NOT Co-Owner (8)
      final coOwnerCanAssignCoOwner = coOwnerWeight >= 10;
      final coOwnerCanAssignAdmin = coOwnerWeight >= 8;
      final coOwnerCanAssignMod = coOwnerWeight >= 8 || coOwnerWeight >= 7;
      expect(coOwnerCanAssignCoOwner, isFalse);
      expect(coOwnerCanAssignAdmin, isTrue);
      expect(coOwnerCanAssignMod, isTrue);

      // Admin can assign/remove Mod (5) but NOT Admin (7) or Co-Owner (8)
      final adminCanAssignCoOwner = adminWeight >= 10;
      final adminCanAssignAdmin = adminWeight >= 8;
      final adminCanAssignMod = adminWeight >= 7;
      expect(adminCanAssignCoOwner, isFalse);
      expect(adminCanAssignAdmin, isFalse);
      expect(adminCanAssignMod, isTrue);
    });

    test('7. Assigned Role Protection & Moderation List Management Verification', () async {
      roomCtrl.rooms.add(level1Room);

      // Check isAssignedRole
      expect(permissionCtrl.isAssignedRole('Creator'), isTrue);
      expect(permissionCtrl.isAssignedRole('Co-Owner'), isTrue);
      expect(permissionCtrl.isAssignedRole('Admin'), isTrue);
      expect(permissionCtrl.isAssignedRole('Mod'), isTrue);
      expect(permissionCtrl.isAssignedRole('Star Member'), isFalse);
      expect(permissionCtrl.isAssignedRole('Audience'), isFalse);

      // Verify Co-Owner role protection
      final coOwnerRole = permissionCtrl.getUserRole(level1Room, coOwnerId);
      expect(permissionCtrl.isAssignedRole(coOwnerRole), isTrue);

      // Verify Admin role protection
      final adminRole = permissionCtrl.getUserRole(level1Room, adminId);
      expect(permissionCtrl.isAssignedRole(adminRole), isTrue);

      // Record and Unkick Audience user test
      roomCtrl.moderationCtrl.recordTemporaryKick(RoomKickEntry(
        roomId: testRoomId,
        userId: audienceId,
        userName: 'Audience User',
        removedBy: creatorId,
        reason: 'Kicked by moderator',
        restrictionDuration: const Duration(hours: 24),
        kickedAt: DateTime.now(),
      ));

      final kickEntry = roomCtrl.moderationCtrl.getKickEntry(testRoomId, audienceId);
      expect(kickEntry, isNotNull);
      expect(kickEntry?.userId, equals(audienceId));

      // Unkick Audience user -> removes kick restriction
      await roomCtrl.unkickUser(testRoomId, audienceId);
      expect(roomCtrl.moderationCtrl.getKickEntry(testRoomId, audienceId), isNull);
    });
  });
}
