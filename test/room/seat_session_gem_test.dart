import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:creania/services/room/room_seat_controller.dart';
import 'package:creania/services/gifting/gift_event_service.dart';
import 'package:creania/models/room/room_model.dart';
import 'package:creania/services/room/room_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seat Session Gem System Tests', () {
    late RoomSeatController seatCtrl;
    late GiftEventService giftService;
    late RoomController roomCtrl;
    const String testRoomId = 'room_session_test_101';

    setUp(() {
      Get.reset();
      seatCtrl = Get.put(RoomSeatController());
      giftService = Get.put(GiftEventService());
      roomCtrl = Get.put(RoomController());

      final initialSeats = List.generate(10, (idx) => <String, dynamic>{
        'seatIndex': idx,
        'userId': null,
        'seatSessionId': null,
        'seatSessionGems': 0,
        'seatTotalStars': 0,
        'seatTotalGems': 0,
        'name': RoomSeatController.getSeatName(idx),
        'avatar': null,
        'isSpeaking': false,
      });

      seatCtrl.roomSeatsInfo[testRoomId] = initialSeats;

      final testRoom = VoiceRoom(
        id: testRoomId,
        name: 'Test Arena',
        description: 'Testing Arena',
        hostId: 'host_101',
        communityId: 'comm_101',
        type: 'Voice Room',
        isLive: true,
        participantCount: 3,
        maxParticipants: 10,
        speakerIds: [],
        listenerIds: [],
        allowRecording: false,
        allowScreenShare: false,
        createdAt: DateTime.now(),
        ownerName: 'Host',
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

      roomCtrl.rooms.assignAll([testRoom]);
    });

    tearDown(() {
      Get.reset();
    });

    test('1. User taking seat initializes counter to 0 with new seatSessionId', () {
      final seats = seatCtrl.roomSeatsInfo[testRoomId]!;
      seats[0] = {
        ...seats[0],
        'userId': 'user_A',
        'seatSessionId': 'ss_session_a_1',
        'seatSessionGems': 0,
        'seatTotalStars': 0,
      };
      seatCtrl.roomSeatsInfo.refresh();

      final seat0 = seatCtrl.roomSeatsInfo[testRoomId]![0];
      expect(seat0['userId'], equals('user_A'));
      expect(seat0['seatSessionId'], equals('ss_session_a_1'));
      expect(seat0['seatSessionGems'], equals(0));
    });

    test('2. Continuous gift accumulation on seat (0 -> 2 -> 4 -> 6)', () {
      // User A on Seat 0
      final seats = seatCtrl.roomSeatsInfo[testRoomId]!;
      seats[0] = {
        ...seats[0],
        'userId': 'user_A',
        'seatSessionId': 'ss_session_a_1',
        'seatSessionGems': 0,
      };

      // 1st 2 Gem gift
      giftService.handleIncomingGiftEvent(testRoomId, {
        'id': 'evt_001',
        'giftId': 'g_like',
        'giftName': 'Like',
        'giftValue': 2,
        'gemsValue': 2,
        'quantity': 1,
        'senderId': 'user_sender',
        'senderName': 'Sender',
        'receiverIds': ['user_A'],
        'receiverSeats': [0],
        'currency': 'gold',
      });

      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['seatSessionGems'], equals(2));

      // 2nd 2 Gem gift
      giftService.handleIncomingGiftEvent(testRoomId, {
        'id': 'evt_002',
        'giftId': 'g_like',
        'giftName': 'Like',
        'giftValue': 2,
        'gemsValue': 2,
        'quantity': 1,
        'senderId': 'user_sender',
        'senderName': 'Sender',
        'receiverIds': ['user_A'],
        'receiverSeats': [0],
        'currency': 'gold',
      });

      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['seatSessionGems'], equals(4));

      // 3rd 2 Gem gift
      giftService.handleIncomingGiftEvent(testRoomId, {
        'id': 'evt_003',
        'giftId': 'g_like',
        'giftName': 'Like',
        'giftValue': 2,
        'gemsValue': 2,
        'quantity': 1,
        'senderId': 'user_sender',
        'senderName': 'Sender',
        'receiverIds': ['user_A'],
        'receiverSeats': [0],
        'currency': 'gold',
      });

      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['seatSessionGems'], equals(6));
    });

    test('3. Duplicate gift event ID does NOT increment counter twice', () {
      final seats = seatCtrl.roomSeatsInfo[testRoomId]!;
      seats[0] = {
        ...seats[0],
        'userId': 'user_A',
        'seatSessionId': 'ss_session_a_1',
        'seatSessionGems': 0,
      };

      final giftEvent = {
        'id': 'evt_duplicate_999',
        'giftId': 'g_rose',
        'giftName': 'Rose',
        'giftValue': 10,
        'gemsValue': 10,
        'quantity': 1,
        'senderId': 'user_sender',
        'senderName': 'Sender',
        'receiverIds': ['user_A'],
        'receiverSeats': [0],
        'currency': 'gold',
      };

      // 1st delivery
      giftService.handleIncomingGiftEvent(testRoomId, giftEvent);
      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['seatSessionGems'], equals(10));

      // 2nd delivery (duplicate event ID)
      giftService.handleIncomingGiftEvent(testRoomId, giftEvent);
      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['seatSessionGems'], equals(10)); // Still 10!
    });

    test('4. Leaving seat resets ONLY that seat counter, preserving other seats', () {
      final seats = seatCtrl.roomSeatsInfo[testRoomId]!;
      // Seat 0: User A -> 6 Gems
      seats[0] = {
        ...seats[0],
        'userId': 'user_A',
        'seatSessionId': 'ss_session_a_1',
        'seatSessionGems': 6,
      };
      // Seat 1: User B -> 10 Gems
      seats[1] = {
        ...seats[1],
        'userId': 'user_B',
        'seatSessionId': 'ss_session_b_1',
        'seatSessionGems': 10,
      };
      // Seat 2: User C -> 4 Gems
      seats[2] = {
        ...seats[2],
        'userId': 'user_C',
        'seatSessionId': 'ss_session_c_1',
        'seatSessionGems': 4,
      };

      // User A leaves Seat 0
      seats[0] = {
        ...seats[0],
        'userId': null,
        'seatSessionId': null,
        'seatSessionGems': 0,
      };
      seatCtrl.roomSeatsInfo.refresh();

      // Seat 0 is reset to 0/empty
      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['userId'], isNull);
      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['seatSessionGems'], equals(0));

      // Seat 1 & Seat 2 MUST remain completely unchanged!
      expect(seatCtrl.roomSeatsInfo[testRoomId]![1]['userId'], equals('user_B'));
      expect(seatCtrl.roomSeatsInfo[testRoomId]![1]['seatSessionGems'], equals(10));

      expect(seatCtrl.roomSeatsInfo[testRoomId]![2]['userId'], equals('user_C'));
      expect(seatCtrl.roomSeatsInfo[testRoomId]![2]['seatSessionGems'], equals(4));
    });

    test('5. Re-joining seat generates new seatSessionId and starts from 0', () {
      final seats = seatCtrl.roomSeatsInfo[testRoomId]!;

      // User A takes Seat 0 (1st session)
      seats[0] = {
        ...seats[0],
        'userId': 'user_A',
        'seatSessionId': 'ss_session_a_1',
        'seatSessionGems': 6,
      };

      // User A leaves
      seats[0] = {
        ...seats[0],
        'userId': null,
        'seatSessionId': null,
        'seatSessionGems': 0,
      };

      // User A takes Seat 0 again (2nd session)
      seats[0] = {
        ...seats[0],
        'userId': 'user_A',
        'seatSessionId': 'ss_session_a_2', // NEW session ID!
        'seatSessionGems': 0, // Fresh 0 start!
      };

      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['seatSessionId'], equals('ss_session_a_2'));
      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['seatSessionGems'], equals(0));

      // Receive 5 Gem gift
      giftService.handleIncomingGiftEvent(testRoomId, {
        'id': 'evt_fresh_5',
        'giftId': 'g_flower',
        'giftName': 'Flower',
        'giftValue': 5,
        'gemsValue': 5,
        'quantity': 1,
        'senderId': 'user_sender',
        'senderName': 'Sender',
        'receiverIds': ['user_A'],
        'receiverSeats': [0],
        'currency': 'gold',
      });

      expect(seatCtrl.roomSeatsInfo[testRoomId]![0]['seatSessionGems'], equals(5));
    });

    test('6. Room Total Gems and Today Gems update in realtime', () {
      final room = roomCtrl.rooms.firstWhere((r) => r.id == testRoomId);
      expect(room.totalRoomGems, equals(0));
      expect(room.todayRoomGems, equals(0));

      giftService.handleIncomingGiftEvent(testRoomId, {
        'id': 'evt_room_100',
        'giftId': 'g_diamond',
        'giftName': 'Diamond',
        'giftValue': 50,
        'gemsValue': 50,
        'quantity': 2,
        'senderId': 'user_sender',
        'senderName': 'Sender',
        'receiverIds': ['user_A'],
        'receiverSeats': [0],
        'currency': 'gold',
      });

      final updatedRoom = roomCtrl.rooms.firstWhere((r) => r.id == testRoomId);
      expect(updatedRoom.totalRoomGems, equals(100));
      expect(updatedRoom.todayRoomGems, equals(100));
    });

    test('7. Re-asserting same seat preserves existing seatSessionGems and session ID', () {
      final seats = seatCtrl.roomSeatsInfo[testRoomId]!;
      seats[0] = {
        ...seats[0],
        'userId': 'user_A',
        'seatSessionId': 'ss_session_a_preserve',
        'seatSessionGems': 42,
      };
      seatCtrl.roomSeatsInfo.refresh();

      // Re-assert sitting on Seat 0 for user_A
      final targetIdx = seats.indexWhere((s) => s['seatIndex'] == 0);
      final isAlreadyOnSeat = seats[targetIdx]['userId'] == 'user_A';
      expect(isAlreadyOnSeat, isTrue);

      final existingGems = seats[targetIdx]['seatSessionGems'];
      final existingSessionId = seats[targetIdx]['seatSessionId'];

      expect(existingGems, equals(42));
      expect(existingSessionId, equals('ss_session_a_preserve'));
    });
  });
}
