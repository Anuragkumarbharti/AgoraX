import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room/room_model.dart';
import 'package:creania/services/room/room_entry_permission_engine.dart';
import 'package:creania/services/room/room_moderation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Creania Voice Room Entry Permission Engine Tests', () {
    late VoiceRoom publicRoom;
    late VoiceRoom lockedRoom;
    late RoomEntryPermissionEngine engine;

    setUp(() {
      engine = RoomEntryPermissionEngine();

      publicRoom = VoiceRoom(
        id: 'CRN-RM-101',
        name: 'Public Debate Arena',
        description: 'Open to all',
        hostId: 'owner_uid_1',
        communityId: 'comm_1',
        type: 'Social',
        isLive: true,
        participantCount: 10,
        maxParticipants: 500,
        speakerIds: [],
        listenerIds: [],
        allowRecording: true,
        allowScreenShare: true,
        createdAt: DateTime.now(),
        ownerName: 'Owner Student',
        category: 'General',
        country: 'Global',
        language: 'English',
        tags: [],
        rules: [],
        coOwnerIds: ['coowner_uid_1'],
        adminIds: ['admin_uid_1'],
        starMemberIds: [],
        managerIds: [],
        moderatorIds: [],
        hostIds: ['host_uid_1'],
        mentorIds: [],
        judgeIds: [],
        performerIds: [],
        eliteMemberIds: [],
        vipMemberIds: [],
        memberIds: [],
        visitorIds: [],
        blockList: [],
      );

      lockedRoom = VoiceRoom(
        id: 'CRN-RM-202',
        name: 'VIP Password Room',
        description: 'Restricted access',
        hostId: 'owner_uid_1',
        communityId: 'comm_1',
        type: 'Social',
        isLive: true,
        participantCount: 5,
        maxParticipants: 500,
        speakerIds: [],
        listenerIds: [],
        allowRecording: true,
        allowScreenShare: true,
        createdAt: DateTime.now(),
        ownerName: 'Owner Student',
        category: 'General',
        country: 'Global',
        language: 'English',
        tags: [],
        rules: [],
        entryPermission: 'password',
        entryPermissions: ['password', 'followers_only', 'vip_only'],
        roomPassword: '5555',
        requiredVipLevel: 3,
        coOwnerIds: ['coowner_uid_1'],
        adminIds: ['admin_uid_1'],
        starMemberIds: [],
        managerIds: [],
        moderatorIds: [],
        hostIds: ['host_uid_1'],
        mentorIds: [],
        judgeIds: [],
        performerIds: [],
        eliteMemberIds: [],
        vipMemberIds: [],
        memberIds: [],
        visitorIds: [],
        blockList: [],
      );
    });

    test('1. Role Determination Test', () {
      expect(engine.getUserRole(publicRoom, 'owner_uid_1'), equals('Creator'));
      expect(engine.getUserRole(publicRoom, 'coowner_uid_1'), equals('Co-Owner'));
      expect(engine.getUserRole(publicRoom, 'admin_uid_1'), equals('Admin'));
      expect(engine.getUserRole(publicRoom, 'host_uid_1'), equals('Host'));
      expect(engine.getUserRole(publicRoom, 'audience_uid_999'), equals('Audience'));
    });

    test('2. Priority Access Rule Bypass Test', () {
      // Owner trying to enter lockedRoom (Password + Followers + VIP)
      final ownerResult = engine.validateEntry(
        room: lockedRoom,
        userId: 'owner_uid_1',
      );
      expect(ownerResult.isAllowed, isTrue);
      expect(ownerResult.isPriorityBypass, isTrue);
      expect(ownerResult.role, equals('Creator'));

      // Co-Owner trying to enter lockedRoom
      final coOwnerResult = engine.validateEntry(
        room: lockedRoom,
        userId: 'coowner_uid_1',
      );
      expect(coOwnerResult.isAllowed, isTrue);
      expect(coOwnerResult.isPriorityBypass, isTrue);

      // Admin trying to enter lockedRoom
      final adminResult = engine.validateEntry(
        room: lockedRoom,
        userId: 'admin_uid_1',
      );
      expect(adminResult.isAllowed, isTrue);
      expect(adminResult.isPriorityBypass, isTrue);
    });

    test('3. Audience Lock Rejections Test', () {
      // Audience user fails followers check first in lock sequence
      final audienceResult1 = engine.validateEntry(
        room: lockedRoom,
        userId: 'audience_uid_1',
        isFollowingOwner: false,
        userVipLevel: 1,
      );
      expect(audienceResult1.isAllowed, isFalse);
      expect(audienceResult1.status, equals(RoomEntryStatus.followersOnly));

      // Audience user passes followers check, but fails VIP check
      final audienceResult2 = engine.validateEntry(
        room: lockedRoom,
        userId: 'audience_uid_1',
        isFollowingOwner: true,
        userVipLevel: 1, // Required VIP 3
      );
      expect(audienceResult2.isAllowed, isFalse);
      expect(audienceResult2.status, equals(RoomEntryStatus.vipOnly));

      // Audience user passes followers & VIP check, but requires Password
      final audienceResult3 = engine.validateEntry(
        room: lockedRoom,
        userId: 'audience_uid_1',
        isFollowingOwner: true,
        userVipLevel: 3,
        providedPassword: null,
      );
      expect(audienceResult3.isAllowed, isFalse);
      expect(audienceResult3.status, equals(RoomEntryStatus.passwordRequired));

      // Audience enters correct password -> Success!
      final audienceResult4 = engine.validateEntry(
        room: lockedRoom,
        userId: 'audience_uid_1',
        isFollowingOwner: true,
        userVipLevel: 3,
        providedPassword: '5555',
      );
      expect(audienceResult4.isAllowed, isTrue);
    });

    test('4. Room Active Check Test', () {
      final closedRoom = VoiceRoom(
        id: 'CRN-RM-CLOSED',
        name: 'Closed Room',
        description: '',
        hostId: 'owner_uid_1',
        communityId: 'comm_1',
        type: 'Social',
        isLive: false,
        participantCount: 0,
        maxParticipants: 500,
        speakerIds: [],
        listenerIds: [],
        allowRecording: true,
        allowScreenShare: true,
        createdAt: DateTime.now(),
        ownerName: 'Owner Student',
        category: 'General',
        country: 'Global',
        language: 'English',
        tags: [],
        rules: [],
        coOwnerIds: [],
        adminIds: [],
        starMemberIds: [],
        managerIds: [],
        moderatorIds: [],
        hostIds: [],
        mentorIds: [],
        judgeIds: [],
        performerIds: [],
        eliteMemberIds: [],
        vipMemberIds: [],
        memberIds: [],
        visitorIds: [],
        blockList: [],
      );

      final result = engine.validateEntry(
        room: closedRoom,
        userId: 'audience_uid_1',
      );
      expect(result.isAllowed, isFalse);
      expect(result.status, equals(RoomEntryStatus.roomClosed));
    });

    test('5. Room Active Locks Helper Test', () {
      expect(lockedRoom.activeLocks, containsAll(['password', 'followers_only', 'vip_only']));
      expect(lockedRoom.hasLock('password'), isTrue);
      expect(lockedRoom.hasLock('vip_only'), isTrue);
      expect(lockedRoom.hasLock('friends_only'), isFalse);
    });
  });
}
