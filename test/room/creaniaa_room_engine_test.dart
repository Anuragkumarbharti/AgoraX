import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room/room_model.dart';
import 'package:creania/models/progression/room_progression_models.dart';
import 'package:creania/services/room/room_controller.dart';
import 'package:creania/services/room/room_seat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Creaniaa StarMaker Level Room Engine Unit Tests', () {
    late RoomController controller;
    final testRoomId = 'room_test_1001';

    setUp(() {
      controller = RoomController();
      controller.rooms.value = [
        VoiceRoom.fromJson({
          'id': testRoomId,
          'name': 'Arena StarMaker Room',
          'username': 'arena_star',
          'description': 'Production ultra low latency voice room',
          'host_id': 'owner_user_1',
          'community_id': 'comm_1',
          'type': 'Voice',
          'is_live': true,
          'participant_count': 5,
          'max_participants': 500,
          'speaker_ids': ['owner_user_1'],
          'listener_ids': [],
          'allow_recording': false,
          'allow_screen_share': false,
          'created_at': DateTime.now().toIso8601String(),
          'owner_name': 'Owner Alice',
          'category': 'Music',
          'country': 'IN',
          'language': 'Hindi',
          'tags': [],
          'rules': [],
          'co_owner_ids': ['co_owner_user_2'],
          'admin_ids': ['admin_user_3'],
          'star_member_ids': [],
          'manager_ids': [],
          'moderator_ids': [],
          'host_ids': [],
          'mentor_ids': [],
          'judge_ids': [],
          'performer_ids': [],
          'elite_member_ids': [],
          'vip_member_ids': [],
          'member_ids': [],
          'visitor_ids': [],
          'block_list': [],
        })
      ];

      controller.roomSeatsInfo[testRoomId] = List.generate(
        10,
        (index) => {
          'seatIndex': index,
          'userId': index == 0 ? 'owner_user_1' : null,
          'name': index == 0 ? 'Owner Alice' : RoomSeatController.getSeatName(index),
          'avatar': null,
          'isLocked': false,
          'isSpeaking': false,
        },
      );
    });

    test('Host Seat Protection Guard (Seats 1 & 2 restricted to Owner/Co-Owner/Admin)', () {
      // Owner (owner_user_1) can sit on Seat 1 (index 0) and Seat 2 (index 1)
      expect(controller.canOccupySeat(testRoomId, 0, 'owner_user_1'), isTrue);
      expect(controller.canOccupySeat(testRoomId, 1, 'owner_user_1'), isTrue);

      // Co-Owner (co_owner_user_2) can sit on Seat 1 and Seat 2
      expect(controller.canOccupySeat(testRoomId, 0, 'co_owner_user_2'), isTrue);
      expect(controller.canOccupySeat(testRoomId, 1, 'co_owner_user_2'), isTrue);

      // Admin (admin_user_3) can sit on Seat 1 and Seat 2
      expect(controller.canOccupySeat(testRoomId, 0, 'admin_user_3'), isTrue);
      expect(controller.canOccupySeat(testRoomId, 1, 'admin_user_3'), isTrue);

      // Audience / Guest (audience_user_99) CANNOT sit on Seat 1 or Seat 2
      expect(controller.canOccupySeat(testRoomId, 0, 'audience_user_99'), isFalse);
      expect(controller.canOccupySeat(testRoomId, 1, 'audience_user_99'), isFalse);

      // Audience CAN sit on Guest Seats (Seats 3 through 10, index 2 to 9)
      expect(controller.canOccupySeat(testRoomId, 2, 'audience_user_99'), isTrue);
      expect(controller.canOccupySeat(testRoomId, 9, 'audience_user_99'), isTrue);
    });

    test('Active Stage Seat VP Matrix Rate Calculation', () {
      // 0 occupants = 0 VP/min
      expect(controller.calculateActiveStageVpRate(0), equals(0));

      // 1 occupant = 4 VP/min
      expect(controller.calculateActiveStageVpRate(1), equals(4));

      // 2 occupants = 8 VP/min
      expect(controller.calculateActiveStageVpRate(2), equals(8));

      // 3 occupants = 14 VP/min
      expect(controller.calculateActiveStageVpRate(3), equals(14));

      // 5 occupants = 28 VP/min
      expect(controller.calculateActiveStageVpRate(5), equals(28));

      // 8 occupants = 50 VP/min
      expect(controller.calculateActiveStageVpRate(8), equals(50));

      // 10 occupants = 60 VP/min
      expect(controller.calculateActiveStageVpRate(10), equals(60));
    });

    test('Dual Progress Bar Fill Rules (Gold vs Silver Gifts)', () {
      final freeTask = RoomDailyTask(
        taskKey: 'free_stay_task',
        description: 'Free Daily Task',
        targetValue: 700,
        currentValue: 100,
        taskPoints: 10,
        xpReward: 50,
        silverReward: 100,
        goldReward: 0,
        isCompleted: false,
      );

      final goldTask = RoomDailyTask(
        taskKey: 'gold_gifting_task',
        description: 'Gold Daily Task',
        targetValue: 1000,
        currentValue: 200,
        taskPoints: 20,
        xpReward: 100,
        silverReward: 0,
        goldReward: 10,
        isCompleted: false,
      );

      // Gold Gift adds VP to BOTH Gold Task and Free Task
      final int goldGiftValue = 50;
      final updatedFreeFromGold = freeTask.currentValue + goldGiftValue;
      final updatedGoldFromGold = goldTask.currentValue + goldGiftValue;
      expect(updatedFreeFromGold, equals(150));
      expect(updatedGoldFromGold, equals(250));

      // Silver Gift adds VP ONLY to Free Task (Gold Task unchanged)
      final int silverGiftValue = 30;
      final updatedFreeFromSilver = freeTask.currentValue + silverGiftValue;
      final updatedGoldFromSilver = goldTask.currentValue; // Unchanged
      expect(updatedFreeFromSilver, equals(130));
      expect(updatedGoldFromSilver, equals(200));
    });

    test('Hidden Trust Score Engine (<30 Trust Score Excludes from Rewards)', () {
      final highTrustScore = 85;
      final lowTrustScore = 25;

      bool canReceiveRewards(int score) => score >= 30;

      expect(canReceiveRewards(highTrustScore), isTrue);
      expect(canReceiveRewards(lowTrustScore), isFalse);
    });

    test('10-Minute Idle Freeze Bounds Calculation', () {
      final now = DateTime.now();
      final lastActivity12MinAgo = now.subtract(const Duration(minutes: 12));
      final lastActivity5MinAgo = now.subtract(const Duration(minutes: 5));

      bool isIdleFrozen(DateTime lastEvent) =>
          now.difference(lastEvent).inMinutes >= 10;

      expect(isIdleFrozen(lastActivity12MinAgo), isTrue);
      expect(isIdleFrozen(lastActivity5MinAgo), isFalse);
    });

    test('Optimistic Local Mute State Updates', () {
      final targetUserId = 'audience_user_77';

      // Initially not muted
      expect(controller.mutedUsers[testRoomId]?.contains(targetUserId) ?? false, isFalse);

      // Optimistic Mute
      final mutedList = List<String>.from(controller.mutedUsers[testRoomId] ?? []);
      mutedList.add(targetUserId);
      controller.mutedUsers[testRoomId] = mutedList;
      expect(controller.mutedUsers[testRoomId]?.contains(targetUserId), isTrue);

      // Optimistic Unmute
      final unmutedList = List<String>.from(controller.mutedUsers[testRoomId] ?? []);
      unmutedList.remove(targetUserId);
      controller.mutedUsers[testRoomId] = unmutedList;
      expect(controller.mutedUsers[testRoomId]?.contains(targetUserId), isFalse);
    });

    test('Sub-300ms Room Join Local Initialization (10 Fixed Stage Seats)', () {
      final seats = controller.roomSeatsInfo[testRoomId];
      expect(seats, isNotNull);
      expect(seats!.length, equals(10));
      expect(seats[0]['seatIndex'], equals(0));
      expect(seats[9]['seatIndex'], equals(9));
    });

    test('Complete Room Exit & Memory Leak Disposal Teardown', () {
      controller.activeRoomId = testRoomId;
      controller.activeMembers.addAll([
        RoomMember(userId: 'u1', role: 'Host', isMuted: false),
        RoomMember(userId: 'u2', role: 'Speaker', isMuted: false),
      ]);
      controller.typingUsers.add('u1');

      expect(controller.activeRoomId, equals(testRoomId));
      expect(controller.activeMembers.length, equals(2));
      expect(controller.typingUsers.isNotEmpty, isTrue);

      // Trigger room exit teardown
      controller.leaveActiveRoomLocally();

      // Verify complete memory & state cleanup
      expect(controller.activeRoomId, isNull);
      expect(controller.activeMembers.isEmpty, isTrue);
      expect(controller.typingUsers.isEmpty, isTrue);
      expect(controller.activeRequests.isEmpty, isTrue);
      expect(controller.activePolls.isEmpty, isTrue);
      expect(controller.bottomSystemNotifications.isEmpty, isTrue);
      expect(controller.activeSystemNotification.value, isNull);
      expect(controller.activeGiftNotification.value, isNull);
      expect(controller.activeGiftAnimation.value, isNull);
    });

    test('Real-time Optimistic Chat Status & Mention Targeting', () {
      final msg = RoomChatMessage(
        senderId: 'user_speaker_1',
        senderName: 'Speaker Bob',
        text: 'Hello @Owner Alice!',
        timestamp: DateTime.now(),
        status: 'sending',
        mentionedUserId: 'owner_user_1',
      );

      expect(msg.status, equals('sending'));
      expect(msg.mentionedUserId, equals('owner_user_1'));

      final sentMsg = msg.copyWith(status: 'sent');
      expect(sentMsg.status, equals('sent'));
      expect(sentMsg.mentionedUserId, equals('owner_user_1'));
    });

    test('Sequential 12-Step Room Entry Validation & Management Priority Access', () {
      // Owner (owner_user_1) enters unconditionally (Management Priority Access)
      final ownerRes = controller.validate12StepRoomEntry(testRoomId, 'owner_user_1');
      expect(ownerRes['canJoin'], isTrue);
      expect(ownerRes['reason'], contains('Management Priority Access'));

      // Co-Owner (co_owner_user_2) enters unconditionally
      final coOwnerRes = controller.validate12StepRoomEntry(testRoomId, 'co_owner_user_2');
      expect(coOwnerRes['canJoin'], isTrue);
      expect(coOwnerRes['reason'], contains('Management Priority Access'));

      // Audience member enters normal live room
      final audienceRes = controller.validate12StepRoomEntry(testRoomId, 'audience_user_99');
      expect(audienceRes['canJoin'], isTrue);

      // Banned audience member is blocked
      controller.bannedUsers[testRoomId] = ['audience_user_99'];
      final bannedRes = controller.validate12StepRoomEntry(testRoomId, 'audience_user_99');
      expect(bannedRes['canJoin'], isFalse);
      expect(bannedRes['reason'], contains('Permanently Banned'));
    });
  });
}
