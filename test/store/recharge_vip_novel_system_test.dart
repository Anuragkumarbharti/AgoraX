import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Recharge, First Purchase, VIP & Novel Offer System Tests', () {

    test('Strict Coin Conversion Rule: round coins for INR - 1 prices', () {
      int calculateBaseCoins(double inr) => ((inr + 1.0) / 2.0).floor();

      expect(calculateBaseCoins(99), 50);
      expect(calculateBaseCoins(199), 100);
      expect(calculateBaseCoins(499), 250);
      expect(calculateBaseCoins(999), 500);
      expect(calculateBaseCoins(1999), 1000);
      expect(calculateBaseCoins(4999), 2500);
      expect(calculateBaseCoins(9999), 5000);
      expect(calculateBaseCoins(10000), 5000); // Fixed ₹10,000 bug
    });

    test('Recharge Package Bonus Coins Calculation', () {
      int getRechargeBonus(double inr) {
        if (inr >= 9999) return 599;
        if (inr >= 4999) return 399;
        if (inr >= 1999) return 199;
        if (inr >= 999) return 125;
        if (inr >= 499) return 50;
        if (inr >= 199) return 15;
        if (inr >= 99) return 5;
        return 0;
      }

      expect(getRechargeBonus(99), 5);
      expect(getRechargeBonus(199), 15);
      expect(getRechargeBonus(499), 50);
      expect(getRechargeBonus(999), 125);
      expect(getRechargeBonus(1999), 199);
      expect(getRechargeBonus(4999), 399);
      expect(getRechargeBonus(9999), 599);
    });

    test('First Purchase Offer Additive Calculation', () {
      Map<String, dynamic> calculateCoins(double inr, bool isFirstPurchase) {
        final base = ((inr + 1.0) / 2.0).floor();
        int bonus = 0;
        if (inr >= 9999) bonus = 599;
        else if (inr >= 4999) bonus = 399;
        else if (inr >= 1999) bonus = 199;
        else if (inr >= 999) bonus = 125;
        else if (inr >= 499) bonus = 50;
        else if (inr >= 199) bonus = 15;
        else if (inr >= 99) bonus = 5;

        final firstPurchaseBonus = isFirstPurchase ? 50 : 0;
        final total = base + bonus + firstPurchaseBonus;

        return {
          'base': base,
          'bonus': bonus,
          'first_bonus': firstPurchaseBonus,
          'total': total,
        };
      }

      // First purchase on ₹99 pack
      final first = calculateCoins(99, true);
      expect(first['base'], 50);
      expect(first['bonus'], 5);
      expect(first['first_bonus'], 50);
      expect(first['total'], 105);

      // Second purchase on ₹99 pack
      final second = calculateCoins(99, false);
      expect(second['base'], 50);
      expect(second['bonus'], 5);
      expect(second['first_bonus'], 0);
      expect(second['total'], 55);
    });

    test('VIP Duration & Extra Days Fix (1 Month = 30 Days + Bonus Days)', () {
      int calculateVipDays(String duration, bool isFirstVipPurchase) {
        int baseDays = 30;
        switch (duration) {
          case '3 Days': baseDays = 3; break;
          case '7 Days': baseDays = 7; break;
          case '15 Days': baseDays = 15; break;
          case '30 Days': case '1 Month': baseDays = 30; break;
          case '90 Days': case '3 Months': baseDays = 90; break;
          case '365 Days': case '1 Year': baseDays = 365; break;
        }

        int bonusDays = 0;
        if (baseDays == 30) bonusDays = 3;
        else if (baseDays == 90) bonusDays = 10;
        else if (baseDays == 365) bonusDays = 30;

        if (isFirstVipPurchase) {
          bonusDays += 3; // First VIP offer extra bonus days
        }

        return baseDays + bonusDays;
      }

      // Regular 1 Month VIP
      expect(calculateVipDays('1 Month', false), 33); // 30 + 3 = 33 days (Not 90 days!)
      expect(calculateVipDays('30 Days', false), 33);

      // First Time 1 Month VIP
      expect(calculateVipDays('1 Month', true), 36); // 30 + 3 + 3 = 36 days

      // Regular 90 Days VIP
      expect(calculateVipDays('90 Days', false), 100); // 90 + 10 = 100 days
    });

    test('Novel Duration & Extra Days Fix', () {
      int calculateNovelDays(String duration, bool isFirstNovelPurchase) {
        int baseDays = 30;
        switch (duration) {
          case '30 Days': case '1 Month': baseDays = 30; break;
          case '90 Days': case '3 Months': baseDays = 90; break;
          case '365 Days': case '1 Year': baseDays = 365; break;
        }

        int bonusDays = 0;
        if (baseDays == 30) bonusDays = 3;
        else if (baseDays == 90) bonusDays = 10;
        else if (baseDays == 365) bonusDays = 30;

        if (isFirstNovelPurchase) {
          bonusDays += 3;
        }

        return baseDays + bonusDays;
      }

      expect(calculateNovelDays('1 Month', false), 33);
      expect(calculateNovelDays('1 Month', true), 36);
    });

    test('Idempotent Signup Reward Logic', () {
      Map<String, dynamic> claimSignupReward(bool alreadyClaimed) {
        if (alreadyClaimed) {
          return {'success': true, 'already_claimed': true, 'coins_added': 0};
        }
        return {'success': true, 'already_claimed': false, 'coins_added': 50};
      }

      final firstClaim = claimSignupReward(false);
      expect(firstClaim['already_claimed'], false);
      expect(firstClaim['coins_added'], 50);

      final secondClaim = claimSignupReward(true);
      expect(secondClaim['already_claimed'], true);
      expect(secondClaim['coins_added'], 0);
    });

  });
}
