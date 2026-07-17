// test/star_gift_system_v2_test.dart

import 'package:flutter_test/flutter_test.dart';

// Simulating the UI format helper
String formatStarsCount(double stars) {
  if (stars >= 1000) {
    return '${(stars / 1000.0).toStringAsFixed(1).replaceAll('.0', '')}K';
  }
  return stars.toStringAsFixed(stars % 1 == 0 ? 0 : 1);
}

// Simulating the economy safety check logic in PL/pgSQL
Map<String, dynamic> drawMagicGiftLottery({
  required int costCoins,
  required double totalSold,
  required double totalPayout,
  required double maxPayoutRatio,
  required double drawProbabilityVal, // Mocking random float
  required Map<String, dynamic> selectedRule,
}) {
  final currentRatio = totalSold > 0 ? totalPayout / totalSold : 0.0;
  
  String outcomeType = selectedRule['payout_type'];
  int multiplier = selectedRule['multiplier'] ?? 0;
  int finalPayoutCost = 0;

  if (outcomeType == 'coin_back') {
    finalPayoutCost = costCoins * multiplier;
  }

  // Safeguard check
  if (currentRatio >= maxPayoutRatio && finalPayoutCost > 0) {
    outcomeType = 'nothing';
    multiplier = 0;
    finalPayoutCost = 0;
  }

  return {
    'payout_type': outcomeType,
    'multiplier': multiplier,
    'coins_back': finalPayoutCost,
  };
}

void main() {
  group('v2.0 Gifting Catalog & Star Conversion Ratios', () {
    test('Gold Rose 10 Gold Coins converts to 10 Stars', () {
      const int goldCost = 10;
      final double starsValue = goldCost.toDouble();
      expect(starsValue, equals(10.0));
    });

    test('Silver Like 200 Silver Coins converts to 2.0 Stars', () {
      const int silverCost = 200;
      final double starsValue = silverCost / 100.0;
      expect(starsValue, equals(2.0));
    });

    test('Silver Rose 1000 Silver Coins converts to 10.0 Stars', () {
      const int silverCost = 1000;
      final double starsValue = silverCost / 100.0;
      expect(starsValue, equals(10.0));
    });
  });

  group('Decimal Stars Double Cast Parsing Safety Test', () {
    double parseSeatStars(dynamic rawValue) {
      return (rawValue as num?)?.toDouble() ?? 0.0;
    }

    test('Safely parses integer seatTotalStars as double', () {
      expect(parseSeatStars(15), equals(15.0));
    });

    test('Safely parses double/decimal seatTotalStars as double', () {
      expect(parseSeatStars(12.5), equals(12.5));
    });

    test('Safely handles null value as 0.0', () {
      expect(parseSeatStars(null), equals(0.0));
    });
  });

  group('K-Format Seat & Room Stars Formatting Helper Test', () {
    test('Formats sub-1000 decimal star value correctly', () {
      expect(formatStarsCount(0.5), equals('0.5'));
    });

    test('Formats integer star value correctly without decimal', () {
      expect(formatStarsCount(5.0), equals('5'));
      expect(formatStarsCount(850.0), equals('850'));
    });

    test('Formats 1000+ star values in K notation', () {
      expect(formatStarsCount(2400.0), equals('2.4K'));
      expect(formatStarsCount(10000.0), equals('10K'));
      expect(formatStarsCount(125300.0), equals('125.3K'));
    });
  });

  group('Magic Gift Economy Safeguard Lottery Draw Test', () {
    test('Allows payout when total ratio is under threshold', () {
      final selectedRule = {
        'payout_type': 'coin_back',
        'multiplier': 5,
      };

      final result = drawMagicGiftLottery(
        costCoins: 10,
        totalSold: 100.0,
        totalPayout: 40.0, // current ratio = 40%
        maxPayoutRatio: 0.70,
        drawProbabilityVal: 0.02,
        selectedRule: selectedRule,
      );

      expect(result['payout_type'], equals('coin_back'));
      expect(result['multiplier'], equals(5));
      expect(result['coins_back'], equals(50));
    });

    test('Enforces downgrade to nothing when ratio exceeds threshold', () {
      final selectedRule = {
        'payout_type': 'coin_back',
        'multiplier': 5,
      };

      final result = drawMagicGiftLottery(
        costCoins: 10,
        totalSold: 100.0,
        totalPayout: 80.0, // current ratio = 80% (exceeds max 70% threshold!)
        maxPayoutRatio: 0.70,
        drawProbabilityVal: 0.02,
        selectedRule: selectedRule,
      );

      expect(result['payout_type'], equals('nothing'));
      expect(result['multiplier'], equals(0));
      expect(result['coins_back'], equals(0));
    });
  });

  group('Self-Gifting Anti-Abuse Policies Test', () {
    Map<String, dynamic> executeSelfGifting({
      required String senderId,
      required String receiverId,
      required int costCoins,
      required bool allowSelfGifting,
      required double selfGiftPayoutRatio,
      required bool excludeFromLeaderboards,
      required bool excludeFromXp,
    }) {
      if (senderId == receiverId) {
        if (!allowSelfGifting) {
          throw Exception('Self-gifting is disabled by administrator.');
        }
        final double payout = costCoins * selfGiftPayoutRatio;
        return {
          'payout_coins': payout.toInt(),
          'leaderboards_updated': !excludeFromLeaderboards,
          'xp_rewarded': !excludeFromXp,
        };
      } else {
        return {
          'payout_coins': costCoins,
          'leaderboards_updated': true,
          'xp_rewarded': true,
        };
      }
    }

    test('Throws exception if self-gifting is disabled', () {
      expect(
        () => executeSelfGifting(
          senderId: 'user1',
          receiverId: 'user1',
          costCoins: 10,
          allowSelfGifting: false,
          selfGiftPayoutRatio: 0.0,
          excludeFromLeaderboards: true,
          excludeFromXp: true,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Self gift returns 0 coins payout when ratio is 0.0', () {
      final res = executeSelfGifting(
        senderId: 'user1',
        receiverId: 'user1',
        costCoins: 10,
        allowSelfGifting: true,
        selfGiftPayoutRatio: 0.0,
        excludeFromLeaderboards: true,
        excludeFromXp: true,
      );
      expect(res['payout_coins'], equals(0));
      expect(res['leaderboards_updated'], isFalse);
      expect(res['xp_rewarded'], isFalse);
    });

    test('Standard gift returns full payout and triggers events', () {
      final res = executeSelfGifting(
        senderId: 'user1',
        receiverId: 'user2',
        costCoins: 10,
        allowSelfGifting: true,
        selfGiftPayoutRatio: 0.0,
        excludeFromLeaderboards: true,
        excludeFromXp: true,
      );
      expect(res['payout_coins'], equals(10));
      expect(res['leaderboards_updated'], isTrue);
      expect(res['xp_rewarded'], isTrue);
    });
  });
}
