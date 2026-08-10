import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:creania/models/room/room_activity_event.dart';
import 'package:creania/services/room/room_chat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RoomChatController chatController;
  const String testRoomId = 'CRN-ARENA-TEST-101';

  setUp(() {
    Get.reset();
    chatController = Get.put(RoomChatController());
    chatController.initializeChatForRoom(testRoomId);
  });

  tearDown(() {
    Get.reset();
  });

  group('Arena Canonical Message Formatter Tests', () {
    test('Format Room Enter & Room Leave messages correctly', () {
      final enterMsg = ArenaEventFormatter.formatRoomEnterMessage('Riya');
      expect(enterMsg, equals('👋 Riya entered the Arena'));

      final leaveMsg = ArenaEventFormatter.formatRoomLeaveMessage('Riya');
      expect(leaveMsg, equals('👋 Riya left the Arena'));
    });

    test('Format Host Seat take and leave messages correctly', () {
      final hostTake = ArenaEventFormatter.formatSeatTakeMessage('Riya', 0);
      expect(hostTake, equals('👑 Riya took Host Seat'));

      final hostLeave = ArenaEventFormatter.formatSeatLeaveMessage('Riya', 0);
      expect(hostLeave, equals('🚪 Riya left Host Seat'));
    });

    test('Format Co-Host Seat take and leave messages correctly', () {
      final cohostTake = ArenaEventFormatter.formatSeatTakeMessage('Riya', 1);
      expect(cohostTake, equals('🎙️ Riya took Co-Host Seat'));

      final cohostLeave = ArenaEventFormatter.formatSeatLeaveMessage('Riya', 1);
      expect(cohostLeave, equals('🚪 Riya left Co-Host Seat'));
    });

    test('Format Normal Seat take and leave messages correctly', () {
      // seatIndex 2 maps to Seat #1, seatIndex 5 maps to Seat #4, seatIndex 9 maps to Seat #8
      final seat1Take = ArenaEventFormatter.formatSeatTakeMessage('Riya', 2);
      expect(seat1Take, equals('🪑 Riya took Seat #1'));

      final seat4Take = ArenaEventFormatter.formatSeatTakeMessage('Aman', 5);
      expect(seat4Take, equals('🪑 Aman took Seat #4'));

      final seat8Take = ArenaEventFormatter.formatSeatTakeMessage('Rahul', 9);
      expect(seat8Take, equals('🪑 Rahul took Seat #8'));

      final seat4Leave = ArenaEventFormatter.formatSeatLeaveMessage('Aman', 5);
      expect(seat4Leave, equals('🚪 Aman left Seat #4'));
    });

    test('Format Seat Move message correctly', () {
      // Move from seatIndex 3 (Seat #2) to seatIndex 6 (Seat #5)
      final moveMsg = ArenaEventFormatter.formatSeatMoveMessage('Riya', 3, 6);
      expect(moveMsg, equals('🪑 Riya moved from Seat #2 to Seat #5'));
    });

    test('Format Lucky Coin Win message correctly with comma formatting', () {
      final lucky500 = ArenaEventFormatter.formatLuckyCoinWinMessage('Riya', 500);
      expect(lucky500, equals('🍀 Riya won 500 Coins!'));

      final lucky1000 = ArenaEventFormatter.formatLuckyCoinWinMessage('Riya', 1000);
      expect(lucky1000, equals('🍀 Riya won 1,000 Coins!'));
    });
  });

  group('Arena Event Deduplication Pipeline Tests', () {
    test('Same eventId submitted 5 times results in exactly 1 message rendered', () {
      const String eventId = 'evt_unique_uuid_999';
      const String message = '🪑 Riya took Seat #4';

      for (int i = 0; i < 5; i++) {
        chatController.addSystemActivityWithDeduplication(
          roomId: testRoomId,
          eventId: eventId,
          text: message,
          senderId: 'usr_riya_123',
          senderName: 'Riya',
          messageType: 'activity',
          activityKey: ArenaEventTypes.seatTaken,
        );
      }

      final messages = chatController.roomChats[testRoomId]!;
      expect(messages.length, equals(1));
      expect(messages.first.text, equals('🪑 Riya took Seat #4'));
    });

    test('Lucky Gift result with 0 cashback_gold is completely suppressed', () {
      final luckyResult = {
        'is_lucky_gift': true,
        'cashback_gold': 0,
        'sender_name': 'Riya',
        'transaction_id': 'tx_zero_001',
      };

      final added = chatController.addLuckyGiftMessage(testRoomId, luckyResult);
      expect(added, isFalse);

      final messages = chatController.roomChats[testRoomId]!;
      expect(messages.isEmpty, isTrue);
    });

    test('Confirmed Lucky Gift reward produces exactly 1 canonical message', () {
      final luckyResult = {
        'is_lucky_gift': true,
        'cashback_gold': 500,
        'sender_name': 'Riya',
        'multiplier': 10,
        'tier': 'gold_win',
        'transaction_id': 'tx_lucky_500_confirmed',
      };

      // First call -> True
      final addedFirst = chatController.addLuckyGiftMessage(testRoomId, luckyResult);
      expect(addedFirst, isTrue);

      // Duplicate call -> False
      final addedSecond = chatController.addLuckyGiftMessage(testRoomId, luckyResult);
      expect(addedSecond, isFalse);

      final messages = chatController.roomChats[testRoomId]!;
      expect(messages.length, equals(1));
      expect(messages.first.text, equals('🍀 Riya won 500 Coins!'));
    });
  });
}
