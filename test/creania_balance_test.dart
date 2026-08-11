import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/wallet/creania_balance_model.dart';

void main() {
  group('Creania Balance Base Value Conversion Tests (500 CB = ₹2.00)', () {
    test('Verifies 500 CB = ₹2.00', () {
      expect(CreaniaBalanceConverter.cbToInr(500), equals(2.0));
      expect(CreaniaBalanceConverter.formatWithInr(500), equals('500 CB (≈ ₹2.00)'));
    });

    test('Verifies 1,000 CB = ₹4.00', () {
      expect(CreaniaBalanceConverter.cbToInr(1000), equals(4.0));
      expect(CreaniaBalanceConverter.formatWithInr(1000), equals('1,000 CB (≈ ₹4.00)'));
    });

    test('Verifies 5,000 CB = ₹20.00', () {
      expect(CreaniaBalanceConverter.cbToInr(5000), equals(20.0));
      expect(CreaniaBalanceConverter.formatWithInr(5000), equals('5,000 CB (≈ ₹20.00)'));
    });

    test('Verifies 10,000 CB = ₹40.00', () {
      expect(CreaniaBalanceConverter.cbToInr(10000), equals(40.0));
      expect(CreaniaBalanceConverter.formatWithInr(10000), equals('10,000 CB (≈ ₹40.00)'));
    });

    test('Verifies 25,000 CB = ₹100.00', () {
      expect(CreaniaBalanceConverter.cbToInr(25000), equals(100.0));
      expect(CreaniaBalanceConverter.formatWithInr(25000), equals('25,000 CB (≈ ₹100.00)'));
    });

    test('Verifies 50,000 CB = ₹200.00', () {
      expect(CreaniaBalanceConverter.cbToInr(50000), equals(200.0));
      expect(CreaniaBalanceConverter.formatWithInr(50000), equals('50,000 CB (≈ ₹200.00)'));
    });

    test('Verifies 100,000 CB = ₹400.00', () {
      expect(CreaniaBalanceConverter.cbToInr(100000), equals(400.0));
      expect(CreaniaBalanceConverter.formatWithInr(100000), equals('1,00,000 CB (≈ ₹400.00)'));
    });
  });

  group('Gem-Driven Creania Balance Reward Calculation Engine Tests', () {
    test('Verifies 100 Gems generated from 100 Gold Gift: Receiver 5,000 CB, Room 2,500 CB, Community 1,500 CB', () {
      const int generatedGems = 100; // 100 Gold Gift = 100 Gems
      const double receiverRatio = 50.0;
      const double roomOwnerRatio = 25.0;
      const double communityRatio = 15.0;
      const double familyRatio = 10.0;

      final int receiverCb = (generatedGems * receiverRatio).round();
      final int roomOwnerCb = (generatedGems * roomOwnerRatio).round();
      final int communityCb = (generatedGems * communityRatio).round();
      final int familyCb = (generatedGems * familyRatio).round();

      expect(receiverCb, equals(5000));
      expect(CreaniaBalanceConverter.cbToInr(receiverCb), equals(20.0));

      expect(roomOwnerCb, equals(2500));
      expect(CreaniaBalanceConverter.cbToInr(roomOwnerCb), equals(10.0));

      expect(communityCb, equals(1500));
      expect(CreaniaBalanceConverter.cbToInr(communityCb), equals(6.0));

      expect(familyCb, equals(1000));
      expect(CreaniaBalanceConverter.cbToInr(familyCb), equals(4.0));

      final int totalCb = receiverCb + roomOwnerCb + communityCb;
      expect(totalCb, equals(9000));
      expect(CreaniaBalanceConverter.cbToInr(totalCb), equals(36.0));
    });
  });

  group('Exchange Promotional Bonus Calculation Tests', () {
    test('Verifies Standard 10,000 CB Exchange to Gold Coins without bonus', () {
      const int inputCb = 10000;
      final double inrVal = CreaniaBalanceConverter.cbToInr(inputCb); // ₹40.00
      final int baseGold = (inrVal * 2.5).floor(); // 100 Gold
      final bool isBonusEligible = inputCb >= 50000;
      final int bonusGold = isBonusEligible ? (baseGold * 0.05).floor() : 0;
      final int totalGold = baseGold + bonusGold;

      expect(inrVal, equals(40.0));
      expect(baseGold, equals(100));
      expect(bonusGold, equals(0));
      expect(totalGold, equals(100));
    });

    test('Verifies Promotional 50,000 CB Exchange to Gold Coins with 5% bonus', () {
      const int inputCb = 50000;
      final double inrVal = CreaniaBalanceConverter.cbToInr(inputCb); // ₹200.00
      final int baseGold = (inrVal * 2.5).floor(); // 500 Gold
      final bool isBonusEligible = inputCb >= 50000;
      final int bonusGold = isBonusEligible ? (baseGold * 0.05).floor() : 0; // 25 Gold bonus
      final int totalGold = baseGold + bonusGold;

      expect(inrVal, equals(200.0));
      expect(baseGold, equals(500));
      expect(bonusGold, equals(25));
      expect(totalGold, equals(525));
    });
  });

  group('Weekend Family Settlement Ledger Logic Tests', () {
    test('Verifies Settlement Calculation (Eligible + Pending - Fraud Adjustment)', () {
      const int previousPending = 25000;
      const int eligibleAdded = 8500;
      const int fraudAdjustment = 1000;

      final int finalSettled = (previousPending + eligibleAdded) - fraudAdjustment;
      final double inrValue = CreaniaBalanceConverter.cbToInr(finalSettled);

      expect(finalSettled, equals(32500));
      expect(inrValue, equals(130.0));
    });
  });
}
