import 'package:flutter_test/flutter_test.dart';
import 'package:creania/services/gifting/gift_media_manager.dart';
import 'package:creania/services/memberships/entry_effect_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GiftMediaManager Tests', () {
    test('GiftMediaManager singleton instance exists', () {
      final manager = GiftMediaManager.instance;
      expect(manager, isNotNull);
    });

    test('getOrFetchAnimationFile handles empty asset string gracefully', () async {
      final result = await GiftMediaManager.instance.getOrFetchAnimationFile('');
      expect(result, isNull);
    });

    test('getOrFetchAnimationFile returns null for local assets', () async {
      final result = await GiftMediaManager.instance.getOrFetchAnimationFile('assets/gifts/rose.png');
      expect(result, isNull);
    });
  });

  group('EntryEffectManager Pool Tests', () {
    test('EntryEffectManager singleton instance exists', () {
      final manager = EntryEffectManager.instance;
      expect(manager, isNotNull);
    });

    test('acquireVideoController returns null gracefully for empty path', () async {
      final ctrl = await EntryEffectManager.instance.acquireVideoController('');
      expect(ctrl, isNull);
    });
  });
}
