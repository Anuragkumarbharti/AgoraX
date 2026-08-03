// test/gift_animation_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/gift_animation_metadata.dart';
import 'package:flutter/material.dart';

void main() {
  group('Gift Animation Registry & Metadata Specification Tests', () {
    test('Every gift has a unique showcase animation type', () {
      final rose = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000003');
      final heart = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000004');
      final coffee = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000005');
      final chocolate = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000006');
      final cake = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000007');
      final balloon = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000008');
      final diamond = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000010');
      final crown = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000011');
      final butterfly = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000012');
      final sportsCar = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000013');
      final privateJet = GiftMetadataRegistry.getMetadata('a2000000-0000-0000-0000-000000000014');

      expect(rose.showcaseType, ShowcaseAnimationType.roseBloom);
      expect(heart.showcaseType, ShowcaseAnimationType.heartPulse);
      expect(coffee.showcaseType, ShowcaseAnimationType.coffeeSteam);
      expect(chocolate.showcaseType, ShowcaseAnimationType.chocolateUnwrap);
      expect(cake.showcaseType, ShowcaseAnimationType.cakeSparkle);
      expect(balloon.showcaseType, ShowcaseAnimationType.balloonFloat);
      expect(diamond.showcaseType, ShowcaseAnimationType.diamondPrism);
      expect(crown.showcaseType, ShowcaseAnimationType.crownShine);
      expect(butterfly.showcaseType, ShowcaseAnimationType.butterflyWings);
      expect(sportsCar.showcaseType, ShowcaseAnimationType.carEngine);
      expect(privateJet.showcaseType, ShowcaseAnimationType.jetIgnition);

      // Verify no two distinct gifts share the exact same showcase type
      expect(rose.showcaseType, isNot(equals(heart.showcaseType)));
      expect(sportsCar.showcaseType, isNot(equals(privateJet.showcaseType)));
      expect(coffee.showcaseType, isNot(equals(rose.showcaseType)));
    });

    test('Dynamic fallback resolves unique showcase and seat landing types by name', () {
      final dragon = GiftMetadataRegistry.getMetadata('Dragon');
      final galaxy = GiftMetadataRegistry.getMetadata('Galaxy');
      final castle = GiftMetadataRegistry.getMetadata('Castle');
      final phoenix = GiftMetadataRegistry.getMetadata('Phoenix');

      expect(dragon.showcaseType, ShowcaseAnimationType.dragonFire);
      expect(dragon.seatEffect, SeatEffectType.fireAura);

      expect(galaxy.showcaseType, ShowcaseAnimationType.galaxyRotate);
      expect(galaxy.seatEffect, SeatEffectType.starRing);

      expect(castle.showcaseType, ShowcaseAnimationType.castleBuild);
      expect(castle.seatEffect, SeatEffectType.goldenThroneGlow);

      expect(phoenix.showcaseType, ShowcaseAnimationType.phoenixFlames);
      expect(phoenix.seatEffect, SeatEffectType.phoenixFlames);

      // Verify that Dragon does NOT default to Rose
      expect(dragon.showcaseType, isNot(equals(ShowcaseAnimationType.roseBloom)));
    });

    test('Every gift has seat landing effect assigned', () {
      final sportsCar = GiftMetadataRegistry.getMetadata('Sports Car');
      final rose = GiftMetadataRegistry.getMetadata('Rose');

      expect(sportsCar.seatEffect, SeatEffectType.wheelSkid);
      expect(rose.seatEffect, SeatEffectType.flowerBloom);
    });
  });
}
