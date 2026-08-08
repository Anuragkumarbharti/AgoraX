// test/gifting/gift_multiplier_and_cost_test.dart

import 'package:flutter_test/flutter_test.dart';

// Helper class replicating effective multiplier and cost logic
class GiftMultiplierEngine {
  static int calculateEffectiveMultiplier({
    required int selectedRecipientCount,
    int? customMultiplier,
  }) {
    if (selectedRecipientCount <= 0) return 0;
    final maxAllowed = selectedRecipientCount > 100 ? 100 : selectedRecipientCount;
    if (customMultiplier == null || customMultiplier <= 0 || customMultiplier > maxAllowed) {
      return maxAllowed;
    }
    return customMultiplier;
  }

  static double calculateTotalCost({
    required double singleGiftPrice,
    required int selectedRecipientCount,
    int? customMultiplier,
  }) {
    final multiplier = calculateEffectiveMultiplier(
      selectedRecipientCount: selectedRecipientCount,
      customMultiplier: customMultiplier,
    );
    return singleGiftPrice * multiplier;
  }

  static String getSendButtonText({
    required int selectedRecipientCount,
    int? customMultiplier,
  }) {
    final multiplier = calculateEffectiveMultiplier(
      selectedRecipientCount: selectedRecipientCount,
      customMultiplier: customMultiplier,
    );
    if (selectedRecipientCount == 0 || multiplier == 0) {
      return 'SELECT SEAT';
    }
    return 'SEND ($multiplier)';
  }

  static bool isMultiplierPresetEnabled({
    required int presetMultiplier,
    required int selectedRecipientCount,
  }) {
    final maxAllowed = selectedRecipientCount > 100 ? 100 : selectedRecipientCount;
    return presetMultiplier <= maxAllowed && presetMultiplier >= 1;
  }
}

void main() {
  group('Gift Multiplier & Recipient Count Exact Match Tests', () {
    test('1 selected recipient produces 1x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 1), equals(1));
    });

    test('2 selected recipients produce 2x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 2), equals(2));
    });

    test('3 selected recipients produce 3x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 3), equals(3));
    });

    test('5 selected recipients produce 5x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 5), equals(5));
    });

    test('10 selected recipients produce 10x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 10), equals(10));
    });

    test('20 selected recipients produce 20x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 20), equals(20));
    });

    test('50 selected recipients produce 50x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 50), equals(50));
    });

    test('100 selected recipients produce 100x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 100), equals(100));
    });

    test('Selected recipients > 100 cap at 100x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 120), equals(100));
    });

    test('0 selected recipients produce 0x multiplier', () {
      expect(GiftMultiplierEngine.calculateEffectiveMultiplier(selectedRecipientCount: 0), equals(0));
    });
  });

  group('Gift Cost Logic Tests (P x N)', () {
    test('Sakura (price=2), 10 recipients selected -> total cost = 20 (NOT 200)', () {
      final total = GiftMultiplierEngine.calculateTotalCost(
        singleGiftPrice: 2.0,
        selectedRecipientCount: 10,
      );
      expect(total, equals(20.0));
    });

    test('Rose (price=100), 5 recipients selected -> total cost = 500', () {
      final total = GiftMultiplierEngine.calculateTotalCost(
        singleGiftPrice: 100.0,
        selectedRecipientCount: 5,
      );
      expect(total, equals(500.0));
    });

    test('Super Car (price=299), 1 recipient selected -> total cost = 299', () {
      final total = GiftMultiplierEngine.calculateTotalCost(
        singleGiftPrice: 299.0,
        selectedRecipientCount: 1,
      );
      expect(total, equals(299.0));
    });

    test('0 recipients selected -> total cost = 0', () {
      final total = GiftMultiplierEngine.calculateTotalCost(
        singleGiftPrice: 2.0,
        selectedRecipientCount: 0,
      );
      expect(total, equals(0.0));
    });
  });

  group('Send Button Text Format Tests', () {
    test('10 recipients selected -> SEND (10)', () {
      expect(GiftMultiplierEngine.getSendButtonText(selectedRecipientCount: 10), equals('SEND (10)'));
    });

    test('5 recipients selected -> SEND (5)', () {
      expect(GiftMultiplierEngine.getSendButtonText(selectedRecipientCount: 5), equals('SEND (5)'));
    });

    test('2 recipients selected -> SEND (2)', () {
      expect(GiftMultiplierEngine.getSendButtonText(selectedRecipientCount: 2), equals('SEND (2)'));
    });

    test('100 recipients selected -> SEND (100)', () {
      expect(GiftMultiplierEngine.getSendButtonText(selectedRecipientCount: 100), equals('SEND (100)'));
    });

    test('0 recipients selected -> SELECT SEAT', () {
      expect(GiftMultiplierEngine.getSendButtonText(selectedRecipientCount: 0), equals('SELECT SEAT'));
    });
  });

  group('Custom Multiplier Range & Preset Disabled Rules', () {
    test('10 recipients selected: 2x, 5x, 10x enabled; 20x, 50x, 100x disabled', () {
      const count = 10;
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 2, selectedRecipientCount: count), isTrue);
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 5, selectedRecipientCount: count), isTrue);
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 10, selectedRecipientCount: count), isTrue);
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 20, selectedRecipientCount: count), isFalse);
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 50, selectedRecipientCount: count), isFalse);
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 100, selectedRecipientCount: count), isFalse);
    });

    test('50 recipients selected: 2x to 50x enabled; 100x disabled', () {
      const count = 50;
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 50, selectedRecipientCount: count), isTrue);
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 100, selectedRecipientCount: count), isFalse);
    });

    test('100 recipients selected: 2x to 100x all enabled', () {
      const count = 100;
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 2, selectedRecipientCount: count), isTrue);
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 50, selectedRecipientCount: count), isTrue);
      expect(GiftMultiplierEngine.isMultiplierPresetEnabled(presetMultiplier: 100, selectedRecipientCount: count), isTrue);
    });

    test('Manipulated custom multiplier exceeding selected count is rejected/clamped', () {
      final effective = GiftMultiplierEngine.calculateEffectiveMultiplier(
        selectedRecipientCount: 10,
        customMultiplier: 100,
      );
      // Even if user attempts to pass 100 with only 10 selected, effective stays 10
      expect(effective, equals(10));
    });
  });
}
