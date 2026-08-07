import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lucky Gift Coin Back Probability Engine Tests', () {
    double calculateLuckyMultiplier(int roll) {
      if (roll <= 150000) return 0.0;
      if (roll <= 300000) return 0.1;
      if (roll <= 410000) return 0.2;
      if (roll <= 500000) return 0.3;
      if (roll <= 580000) return 0.4;
      if (roll <= 650000) return 0.5;
      if (roll <= 730000) return 0.6;
      if (roll <= 780000) return 0.7;
      if (roll <= 830000) return 0.8;
      if (roll <= 980000) return 1.0;
      if (roll <= 992000) return 1.5;
      if (roll <= 997000) return 2.0;
      if (roll <= 999000) return 3.0;
      if (roll <= 999800) return 5.0;
      if (roll <= 999950) return 10.0;
      if (roll <= 999990) return 20.0;
      if (roll <= 999999) return 50.0;
      return 100.0;
    }

    String getTier(double mult) {
      if (mult == 0.0) return 'no_reward';
      if (mult < 1.0) return 'partial';
      if (mult == 1.0) return 'full';
      if (mult < 5.0) return 'bonus';
      return 'jackpot';
    }

    test('Verify exact boundary multipliers matching user probability table', () {
      expect(calculateLuckyMultiplier(1), 0.0);
      expect(calculateLuckyMultiplier(150000), 0.0);

      expect(calculateLuckyMultiplier(150001), 0.1);
      expect(calculateLuckyMultiplier(300000), 0.1);

      expect(calculateLuckyMultiplier(300001), 0.2);
      expect(calculateLuckyMultiplier(410000), 0.2);

      expect(calculateLuckyMultiplier(410001), 0.3);
      expect(calculateLuckyMultiplier(500000), 0.3);

      expect(calculateLuckyMultiplier(500001), 0.4);
      expect(calculateLuckyMultiplier(580000), 0.4);

      expect(calculateLuckyMultiplier(580001), 0.5);
      expect(calculateLuckyMultiplier(650000), 0.5);

      expect(calculateLuckyMultiplier(650001), 0.6);
      expect(calculateLuckyMultiplier(730000), 0.6);

      expect(calculateLuckyMultiplier(730001), 0.7);
      expect(calculateLuckyMultiplier(780000), 0.7);

      expect(calculateLuckyMultiplier(780001), 0.8);
      expect(calculateLuckyMultiplier(830000), 0.8);

      expect(calculateLuckyMultiplier(830001), 1.0);
      expect(calculateLuckyMultiplier(980000), 1.0);

      expect(calculateLuckyMultiplier(980001), 1.5);
      expect(calculateLuckyMultiplier(992000), 1.5);

      expect(calculateLuckyMultiplier(992001), 2.0);
      expect(calculateLuckyMultiplier(997000), 2.0);

      expect(calculateLuckyMultiplier(997001), 3.0);
      expect(calculateLuckyMultiplier(999000), 3.0);

      expect(calculateLuckyMultiplier(999001), 5.0);
      expect(calculateLuckyMultiplier(999800), 5.0);

      expect(calculateLuckyMultiplier(999801), 10.0);
      expect(calculateLuckyMultiplier(999950), 10.0);

      expect(calculateLuckyMultiplier(999951), 20.0);
      expect(calculateLuckyMultiplier(999990), 20.0);

      expect(calculateLuckyMultiplier(999991), 50.0);
      expect(calculateLuckyMultiplier(999999), 50.0);

      expect(calculateLuckyMultiplier(1000000), 100.0);
    });

    test('Verify Coin Back calculation and tier assignments', () {
      final cost = 50; // Diamond (50 Gold Coins)
      expect(getTier(calculateLuckyMultiplier(150000)), 'no_reward');
      expect(getTier(calculateLuckyMultiplier(300000)), 'partial');
      expect(getTier(calculateLuckyMultiplier(980000)), 'full');
      expect(getTier(calculateLuckyMultiplier(992000)), 'bonus');
      expect(getTier(calculateLuckyMultiplier(999800)), 'jackpot');

      expect((cost * calculateLuckyMultiplier(830001)).round(), 50); // 1x = 50 coins back
      expect((cost * calculateLuckyMultiplier(992001)).round(), 100); // 2x = 100 coins back
      expect((cost * calculateLuckyMultiplier(999001)).round(), 250); // 5x = 250 coins back
      expect((cost * calculateLuckyMultiplier(999801)).round(), 500); // 10x = 500 coins back
      expect((cost * calculateLuckyMultiplier(1000000)).round(), 5000); // 100x = 5000 coins back
    });

    test('Verify 0x message suppression and transaction ID deduplication logic', () {
      final Set<String> processedTxIds = {};
      bool processTransaction(String txId, int cashbackGold) {
        if (cashbackGold <= 0) return false; // 0x message suppression
        if (processedTxIds.contains(txId)) return false;
        processedTxIds.add(txId);
        return true;
      }

      final tx0 = 'tx-uuid-0000';
      expect(processTransaction(tx0, 0), false); // 0x suppressed!

      final tx1 = 'tx-uuid-1001';
      expect(processTransaction(tx1, 50), true);
      expect(processTransaction(tx1, 50), false); // Blocked duplicate
    });
  });
}
