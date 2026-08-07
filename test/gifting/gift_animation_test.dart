// test/gifting/gift_animation_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/gift/gift_animation_metadata.dart';

void main() {
  group('Gift Animation Registry & 35-Gift Specification Tests', () {
    test('Verify total count of gifts in registry is 35', () {
      expect(GiftMetadataRegistry.registry.length, 35);
    });

    test('Verify distribution: 29 Gold Gifts and 6 Silver Gifts', () {
      final goldGifts = GiftMetadataRegistry.registry.values.where((g) => g.currency == 'gold').toList();
      final silverGifts = GiftMetadataRegistry.registry.values.where((g) => g.currency == 'silver').toList();

      expect(goldGifts.length, 29);
      expect(silverGifts.length, 6);
    });

    test('Verify 6 designated Lucky Gold Gifts', () {
      final luckyGifts = GiftMetadataRegistry.registry.values.where((g) => g.isLucky).toList();
      expect(luckyGifts.length, 6);

      final luckyNames = luckyGifts.map((g) => g.giftName).toSet();
      expect(luckyNames.contains('Sakura'), true);
      expect(luckyNames.contains('Gift Box'), true);
      expect(luckyNames.contains('Diamond Ring'), true);
      expect(luckyNames.contains('Champion Trophy'), true);
      expect(luckyNames.contains('Super Car'), true);
      expect(luckyNames.contains('Golden Dragon'), true);
    });

    test('Verify updated 9 Gold prices for Gift Box and Teddy', () {
      final giftBox = GiftMetadataRegistry.getMetadata('f1000001-0000-0000-0000-000000000011');
      final teddy = GiftMetadataRegistry.getMetadata('f1000001-0000-0000-0000-000000000012');

      expect(giftBox.price, 9);
      expect(teddy.price, 9);
    });

    test('Every gift has a valid showcase animation type and duration', () {
      for (final gift in GiftMetadataRegistry.registry.values) {
        expect(gift.duration.inMilliseconds, greaterThanOrEqualTo(2000));
        expect(gift.duration.inMilliseconds, lessThanOrEqualTo(10000));
        expect(gift.giftIcon, isNotEmpty);
        expect(gift.giftName, isNotEmpty);
      }
    });

    test('Dynamic lookup by ID and Name fallback', () {
      final dragon = GiftMetadataRegistry.getMetadata('f1000004-0000-0000-0000-000000000001');
      expect(dragon.giftName, 'Golden Dragon');
      expect(dragon.price, 1999);
      expect(dragon.tier, GiftTier.tier4);

      final cosmos = GiftMetadataRegistry.getMetadata('Infinity Cosmos');
      expect(cosmos.giftName, 'Infinity Cosmos');
      expect(cosmos.price, 29999);
      expect(cosmos.tier, GiftTier.tier5);
    });
  });
}
