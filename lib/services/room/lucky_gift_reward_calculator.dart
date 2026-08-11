import 'package:flutter/foundation.dart';

/// Single Authoritative Reward Contract for Creania Lucky Gifts.
///
/// Rules:
/// - Lucky Gifts start at 5 Gold Coins and above (1-4 Gold Coins are NOT Lucky Gifts).
/// - 1 - 4 Gold Coins -> 0 AP, 0 Gem (tier: 'none')
/// - 5 - 99 Gold Coins -> 1 Room AP, 1 Gem Value (tier: '5_99')
/// - 100 - 1,000 Gold Coins -> 10 Room AP, 10 Gem Value (tier: '100_1000')
/// - 1,001 - 5,000 Gold Coins -> 50 Room AP, 50 Gem Value (tier: '1001_5000')
/// - 5,001 - 10,000 Gold Coins -> 100 Room AP, 100 Gem Value (tier: '5001_10000')
/// - 10,001+ Gold Coins -> 200 Room AP, 200 Gem Value (tier: '10001_plus')
///
/// NOTE: The reward MUST be calculated strictly from the Gold Coin value of the
/// Lucky Gift itself, NOT from any random gift received inside the Lucky Gift.
class LuckyGiftRewardCalculator {
  static Map<String, dynamic> calculateLuckyGiftReward(int goldCoinValue) {
    if (goldCoinValue < 5) {
      return {
        'ap': 0,
        'gem': 0,
        'tier': 'none',
      };
    } else if (goldCoinValue >= 5 && goldCoinValue <= 99) {
      return {
        'ap': 1,
        'gem': 1,
        'tier': '5_99',
      };
    } else if (goldCoinValue >= 100 && goldCoinValue <= 1000) {
      return {
        'ap': 10,
        'gem': 10,
        'tier': '100_1000',
      };
    } else if (goldCoinValue >= 1001 && goldCoinValue <= 5000) {
      return {
        'ap': 50,
        'gem': 50,
        'tier': '1001_5000',
      };
    } else if (goldCoinValue >= 5001 && goldCoinValue <= 10000) {
      return {
        'ap': 100,
        'gem': 100,
        'tier': '5001_10000',
      };
    } else {
      return {
        'ap': 200,
        'gem': 200,
        'tier': '10001_plus',
      };
    }
  }
}
