// test/star_gift_system_test.dart

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Star Economy & Currency Conversions', () {
    test('1 Gold Coin equals 1 Star conversion rule', () {
      const int goldCoins = 500;
      final int stars = goldCoins; // 1 Gold = 1 Star
      expect(stars, equals(500));
    });

    test('100 Silver Coins equals 1 Star conversion rule', () {
      const int silverCoins = 25000;
      final double stars = silverCoins / 100.0; // 100 Silver = 1 Star
      expect(stars, equals(250.0));
    });

    test('Silver gift item cost is represented in stars correctly', () {
      // Rose is 2 Gold Coins = 2 Stars
      // Like is 50 Silver Coins = 0.5 Stars
      const int likeCoinsCost = 50;
      final double likeStarsCost = likeCoinsCost / 100.0;
      expect(likeStarsCost, equals(0.5));

      const int coffeeCoinsCost = 100;
      final double coffeeStarsCost = coffeeCoinsCost / 100.0;
      expect(coffeeStarsCost, equals(1.0));
    });
  });

  group('Dynamic Username Gifting Message Formatting', () {
    String formatGiftingMessage({
      required String senderName,
      required String giftIcon,
      required String giftName,
      required int quantity,
      required List<String> receiverNames,
    }) {
      String action = 'sent $giftIcon $giftName to ';
      if (quantity > 1) {
        action = 'sent $quantity× $giftIcon $giftName to ';
      }

      if (receiverNames.length == 1) {
        return '$senderName $action${receiverNames[0]}';
      } else if (receiverNames.length >= 10) {
        return '$senderName gifted everyone with $giftIcon $giftName';
      } else {
        return '$senderName sent $giftIcon $giftName to ${receiverNames.length} selected users';
      }
    }

    test('Formats single recipient gift correctly', () {
      final msg = formatGiftingMessage(
        senderName: 'Anurag',
        giftIcon: '🌹',
        giftName: 'Rose',
        quantity: 1,
        receiverNames: ['Rahul'],
      );
      expect(msg, equals('Anurag sent 🌹 Rose to Rahul'));
    });

    test('Formats multiple gift combo correctly', () {
      final msg = formatGiftingMessage(
        senderName: 'Anurag',
        giftIcon: '🌹',
        giftName: 'Rose',
        quantity: 10,
        receiverNames: ['Rahul'],
      );
      expect(msg, equals('Anurag sent 10× 🌹 Rose to Rahul'));
    });

    test('Formats multi-seat recipient list correctly', () {
      final msg = formatGiftingMessage(
        senderName: 'Anurag',
        giftIcon: '❤️',
        giftName: 'Heart',
        quantity: 1,
        receiverNames: ['Seat 2', 'Seat 5', 'Seat 7'],
      );
      expect(msg, equals('Anurag sent ❤️ Heart to 3 selected users'));
    });

    test('Formats all seats gift correctly', () {
      final msg = formatGiftingMessage(
        senderName: 'Anurag',
        giftIcon: '🏰',
        giftName: 'Castle',
        quantity: 1,
        receiverNames: List.generate(10, (index) => 'Seat $index'),
      );
      expect(msg, equals('Anurag gifted everyone with 🏰 Castle'));
    });
  });
}
