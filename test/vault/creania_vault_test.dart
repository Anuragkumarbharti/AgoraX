// test/creania_vault_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/vault/vault_models.dart';

void main() {
  group('Creaniaa Vault Model Parsing Tests', () {
    test('VaultItem parsing test', () {
      final json = {
        'id': 'item-123',
        'asset_id': 'asset-456',
        'category': 'Cosmetics',
        'sub_category': 'avatar_frame',
        'display_name': 'Mythic Dragon Frame',
        'short_description': 'A fiery dragon frame',
        'long_description': 'A premium animated dragon frame for special beta users.',
        'thumbnail_url': 'https://creaniaa.com/cdn/dragon_thumb.png',
        'animation_url': 'https://creaniaa.com/cdn/dragon_anim.png',
        'preview_url': 'https://creaniaa.com/cdn/dragon_preview.png',
        'rarity': 'Mythic',
        'quantity': 3,
        'status': 'Unlocked',
        'purchase_source': 'Admin Grant',
        'purchase_date': '2026-07-17T12:00:00Z',
        'expires_at': '2026-07-27T12:00:00Z',
        'activated_at': '2026-07-17T12:00:00Z',
        'is_equipped': true,
        'last_equipped_at': '2026-07-17T12:30:00Z',
        'custom_metadata': {'author': 'Google DeepMind'},
        'tradable': true,
        'giftable': true,
        'stackable': true,
        'consumable': false,
        'permanent': false,
        'duration_seconds': 864000
      };

      final item = VaultItem.fromJson(json);

      expect(item.id, 'item-123');
      expect(item.assetId, 'asset-456');
      expect(item.category, 'Cosmetics');
      expect(item.subCategory, 'avatar_frame');
      expect(item.displayName, 'Mythic Dragon Frame');
      expect(item.rarity, 'Mythic');
      expect(item.quantity, 3);
      expect(item.status, 'Unlocked');
      expect(item.isEquipped, true);
      expect(item.customMetadata['author'], 'Google DeepMind');
      expect(item.permanent, false);
      expect(item.durationSeconds, 864000);
      expect(item.remainingDuration, isNotNull);
      expect(item.remainingDuration!.isNegative, false);
    });

    test('VaultHistoryEntry parsing test', () {
      final json = {
        'id': 'history-789',
        'action_type': 'Gifted',
        'quantity': 1,
        'details': {'receiver_id': 'receiver-abc'},
        'created_at': '2026-07-17T13:00:00Z',
        'asset_name': 'Epic Spin Ticket',
        'thumbnail_url': 'https://creaniaa.com/cdn/ticket.png',
        'rarity': 'Epic'
      };

      final entry = VaultHistoryEntry.fromJson(json);

      expect(entry.id, 'history-789');
      expect(entry.actionType, 'Gifted');
      expect(entry.quantity, 1);
      expect(entry.details['receiver_id'], 'receiver-abc');
      expect(entry.assetName, 'Epic Spin Ticket');
      expect(entry.rarity, 'Epic');
    });
  });
}
