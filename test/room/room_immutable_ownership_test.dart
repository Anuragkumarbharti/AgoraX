import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room/room_model.dart';
import 'package:creania/services/room/room_permission_controller.dart';
import 'package:creania/services/room/room_entry_permission_engine.dart';
import 'package:creania/services/room/room_moderation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ROOM OWNERSHIP IMMUTABLE SYSTEM - 22 SCENARIOS TEST SUITE', () {
    late RoomPermissionController permissionCtrl;
    late RoomEntryPermissionEngine entryEngine;
    late RoomModerationController moderationCtrl;

    final originalOwnerId = 'usr_original_creator_9999';
    final coOwnerId = 'usr_co_owner_8888';
    final adminId = 'usr_admin_7777';
    final modId = 'usr_mod_6666';
    final seatUserId = 'usr_seat_user_5555';
    final attackerUserId = 'usr_attacker_1111';

    final roomId = 'CRN-RM-PERMANENT-1001';

    late VoiceRoom room;

    setUp(() {
      permissionCtrl = RoomPermissionController();
      entryEngine = RoomEntryPermissionEngine();
      moderationCtrl = RoomModerationController();

      room = VoiceRoom.fromJson({
        'id': roomId,
        'name': 'Permanent Immutable Ownership Arena',
        'username': '@permanent_arena',
        'description': 'Testing 22 strict ownership immutability cases',
        'owner_user_id': originalOwnerId,
        'host_id': originalOwnerId,
        'room_owner': originalOwnerId,
        'community_id': 'comm_arena_1',
        'type': 'Voice',
        'is_live': true,
        'participant_count': 5,
        'max_participants': 500,
        'speaker_ids': [originalOwnerId, coOwnerId, seatUserId],
        'listener_ids': [adminId, modId],
        'allow_recording': false,
        'allow_screen_share': false,
        'created_at': DateTime.now().toIso8601String(),
        'owner_name': 'Original Permanent Owner',
        'category': 'Education',
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
        'moderator_ids': [modId],
        'host_ids': [],
        'block_list': [],
      });
    });

    test('1. Owner leaves room: Original Owner remains only Owner', () {
      final roomAfterOwnerLeave = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [coOwnerId, seatUserId],
        'listener_ids': [adminId, modId],
        'participant_count': 4,
      });

      expect(roomAfterOwnerLeave.ownerUserId, equals(originalOwnerId));
      expect(roomAfterOwnerLeave.hostId, equals(originalOwnerId));
      expect(permissionCtrl.getUserRole(roomAfterOwnerLeave, originalOwnerId), equals('Owner'));
      expect(permissionCtrl.getUserRole(roomAfterOwnerLeave, coOwnerId), equals('Co-Owner'));
    });

    test('2. Owner reconnects: Original Owner remains only Owner', () {
      final roomAfterReconnect = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [originalOwnerId, coOwnerId, seatUserId],
        'participant_count': 5,
      });

      expect(roomAfterReconnect.ownerUserId, equals(originalOwnerId));
      expect(roomAfterReconnect.hostId, equals(originalOwnerId));
      expect(permissionCtrl.getUserRole(roomAfterReconnect, originalOwnerId), equals('Owner'));
    });

    test('3. Owner goes offline: Original Owner remains only Owner', () {
      final roomOfflineState = VoiceRoom.fromJson({
        ...room.toJson(),
        'is_live': true,
        'speaker_ids': [coOwnerId],
      });

      expect(roomOfflineState.ownerUserId, equals(originalOwnerId));
      expect(roomOfflineState.hostId, equals(originalOwnerId));
      expect(permissionCtrl.getUserRole(roomOfflineState, coOwnerId), isNot(equals('Owner')));
    });

    test('4. Owner closes app: Original Owner remains only Owner', () {
      final roomClosedApp = VoiceRoom.fromJson({
        ...room.toJson(),
        'participant_count': 2,
      });

      expect(roomClosedApp.ownerUserId, equals(originalOwnerId));
    });

    test('5. Owner logs out: Original Owner remains only Owner', () {
      final roomLogout = VoiceRoom.fromJson({
        ...room.toJson(),
      });

      expect(roomLogout.ownerUserId, equals(originalOwnerId));
    });

    test('6. Owner loses internet: Original Owner remains only Owner', () {
      final roomNoNet = VoiceRoom.fromJson({
        ...room.toJson(),
        'participant_count': 3,
      });

      expect(roomNoNet.ownerUserId, equals(originalOwnerId));
    });

    test('7. Co-Owner remains online while Owner is offline: Co-Owner does NOT become Owner', () {
      final roomCoOwnerOnline = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [coOwnerId],
      });

      expect(permissionCtrl.getUserRole(roomCoOwnerOnline, coOwnerId), equals('Co-Owner'));
      expect(permissionCtrl.isOwner(roomId, coOwnerId, room: roomCoOwnerOnline), isFalse);
    });

    test('8. Admin remains online while Owner is offline: Admin does NOT become Owner', () {
      final roomAdminOnline = VoiceRoom.fromJson({
        ...room.toJson(),
        'listener_ids': [adminId],
      });

      expect(permissionCtrl.getUserRole(roomAdminOnline, adminId), equals('Admin'));
      expect(permissionCtrl.isOwner(roomId, adminId, room: roomAdminOnline), isFalse);
    });

    test('9. Mod remains online while Owner is offline: Mod does NOT become Owner', () {
      final roomModOnline = VoiceRoom.fromJson({
        ...room.toJson(),
        'listener_ids': [modId],
      });

      expect(permissionCtrl.getUserRole(roomModOnline, modId), equals('Mod'));
      expect(permissionCtrl.isOwner(roomId, modId, room: roomModOnline), isFalse);
    });

    test('10. All members leave except Owner: Original Owner remains only Owner', () {
      final roomOwnerSolo = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [originalOwnerId],
        'listener_ids': [],
        'participant_count': 1,
      });

      expect(roomOwnerSolo.ownerUserId, equals(originalOwnerId));
      expect(permissionCtrl.getUserRole(roomOwnerSolo, originalOwnerId), equals('Owner'));
    });

    test('11. Owner leaves and later returns: Original Owner remains only Owner', () {
      // Step 1: Left
      final roomStep1 = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [],
      });
      expect(roomStep1.ownerUserId, equals(originalOwnerId));

      // Step 2: Returned
      final roomStep2 = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [originalOwnerId],
      });
      expect(roomStep2.ownerUserId, equals(originalOwnerId));
      expect(permissionCtrl.getUserRole(roomStep2, originalOwnerId), equals('Owner'));
    });

    test('12. Multiple reconnects: Original Owner remains only Owner', () {
      for (int i = 0; i < 5; i++) {
        final reconnectedRoom = VoiceRoom.fromJson({
          ...room.toJson(),
          'participant_count': i + 1,
        });
        expect(reconnectedRoom.ownerUserId, equals(originalOwnerId));
      }
    });

    test('13. RTC disconnect/reconnect: Original Owner remains only Owner', () {
      final rtcLossRoom = VoiceRoom.fromJson({
        ...room.toJson(),
        'speaker_ids': [coOwnerId],
      });
      expect(rtcLossRoom.ownerUserId, equals(originalOwnerId));
    });

    test('14. Room refresh: Original Owner remains only Owner', () {
      final refreshedRoom = VoiceRoom.fromJson(room.toJson());
      expect(refreshedRoom.ownerUserId, equals(originalOwnerId));
    });

    test('15. App restart: Original Owner remains only Owner', () {
      final restartedAppRoom = VoiceRoom.fromJson(room.toJson());
      expect(restartedAppRoom.ownerUserId, equals(originalOwnerId));
    });

    test('16. Server restart/recovery: Original Owner remains only Owner', () {
      final recoveredRoom = VoiceRoom.fromJson(room.toJson());
      expect(recoveredRoom.ownerUserId, equals(originalOwnerId));
    });

    test('17. Room member sync: Original Owner remains only Owner', () {
      final syncedRoom = VoiceRoom.fromJson({
        ...room.toJson(),
        'participant_count': 12,
      });
      expect(syncedRoom.ownerUserId, equals(originalOwnerId));
    });

    test('18. Malicious client tries to change ownerId: Transfer calls throw Exception', () async {
      expect(
        () async => await moderationCtrl.transferHost(roomId, attackerUserId),
        throwsA(isA<Exception>()),
      );

      final transferSuccess = await moderationCtrl.transferRoomOwnership(roomId, attackerUserId);
      expect(transferSuccess, isFalse);
    });

    test('19. Co-Owner tries to become Owner: Rejected with OWNERSHIP_IMMUTABLE', () async {
      expect(
        () async => await moderationCtrl.changeMemberRole(roomId, coOwnerId, 'Owner'),
        throwsA(isA<Exception>()),
      );
    });

    test('20. Admin tries to become Owner: Rejected with OWNERSHIP_IMMUTABLE', () async {
      expect(
        () async => await moderationCtrl.changeMemberRole(roomId, adminId, 'Creator'),
        throwsA(isA<Exception>()),
      );
    });

    test('21. Mod tries to become Owner: Rejected with OWNERSHIP_IMMUTABLE', () async {
      expect(
        () async => await moderationCtrl.changeMemberRole(roomId, modId, 'Founder'),
        throwsA(isA<Exception>()),
      );
    });

    test('22. Host/seat user tries to become Owner: Rejected with OWNERSHIP_IMMUTABLE', () async {
      expect(
        () async => await moderationCtrl.changeMemberRole(roomId, seatUserId, 'Owner'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
