import 'package:flutter_test/flutter_test.dart';
import 'package:creania/services/room/lucky_gift_reward_calculator.dart';

void main() {
  group('CREANIA Lucky Gift AP + Gem Reward System Unit Tests', () {
    test('Boundary Value Analysis (Requirements #1, #9 & 1-4 Excluded Rule)', () {
      final testCases = <int, Map<String, dynamic>>{
        1: {'ap': 0, 'gem': 0, 'tier': 'none'},
        2: {'ap': 0, 'gem': 0, 'tier': 'none'},
        3: {'ap': 0, 'gem': 0, 'tier': 'none'},
        4: {'ap': 0, 'gem': 0, 'tier': 'none'},
        5: {'ap': 1, 'gem': 1, 'tier': '5_99'},
        50: {'ap': 1, 'gem': 1, 'tier': '5_99'},
        99: {'ap': 1, 'gem': 1, 'tier': '5_99'},
        100: {'ap': 10, 'gem': 10, 'tier': '100_1000'},
        101: {'ap': 10, 'gem': 10, 'tier': '100_1000'},
        500: {'ap': 10, 'gem': 10, 'tier': '100_1000'},
        999: {'ap': 10, 'gem': 10, 'tier': '100_1000'},
        1000: {'ap': 10, 'gem': 10, 'tier': '100_1000'},
        1001: {'ap': 50, 'gem': 50, 'tier': '1001_5000'},
        5000: {'ap': 50, 'gem': 50, 'tier': '1001_5000'},
        5001: {'ap': 100, 'gem': 100, 'tier': '5001_10000'},
        10000: {'ap': 100, 'gem': 100, 'tier': '5001_10000'},
        10001: {'ap': 200, 'gem': 200, 'tier': '10001_plus'},
      };

      testCases.forEach((goldValue, expected) {
        final result = LuckyGiftRewardCalculator.calculateLuckyGiftReward(goldValue);
        expect(result['ap'], equals(expected['ap']),
            reason: 'Failed AP calculation for Gold value: $goldValue');
        expect(result['gem'], equals(expected['gem']),
            reason: 'Failed Gem calculation for Gold value: $goldValue');
        expect(result['tier'], equals(expected['tier']),
            reason: 'Failed Tier calculation for Gold value: $goldValue');
      });
    });

    test('Independence from Random Gift Outcome (Requirement #1 & #2)', () {
      const luckyGiftGold = 500;
      final reward = LuckyGiftRewardCalculator.calculateLuckyGiftReward(luckyGiftGold);

      // Simulated random gifts output
      const randomGift1 = {'name': 'Private Jet', 'value': 20000};
      const randomGift2 = {'name': 'Chocolate', 'value': 4};

      // Ensure AP and Gem remain 10 regardless of random gift
      expect(reward['ap'], equals(10));
      expect(reward['gem'], equals(10));
      expect(reward['ap'], isNot(equals(randomGift1['value'])));
      expect(reward['ap'], isNot(equals(randomGift2['value'])));
    });

    test('Non-Linear Rewards Rule (Requirement #5)', () {
      final reward100 = LuckyGiftRewardCalculator.calculateLuckyGiftReward(100);
      final reward1000 = LuckyGiftRewardCalculator.calculateLuckyGiftReward(1000);

      // Verify reward is non-linear (1000 gold gives 10 AP, NOT 1000 AP)
      expect(reward100['ap'], equals(10));
      expect(reward1000['ap'], equals(10));
      expect(reward1000['ap'], isNot(equals(1000)));
    });

    test('Economy Isolation (Requirement #7)', () {
      const goldCoins = 500;
      final reward = LuckyGiftRewardCalculator.calculateLuckyGiftReward(goldCoins);

      expect(reward.containsKey('ap'), isTrue);
      expect(reward.containsKey('gem'), isTrue);
      expect(reward.containsKey('gold'), isFalse);
      expect(reward['ap'], isA<int>());
      expect(reward['gem'], isA<int>());
    });
  });
}
