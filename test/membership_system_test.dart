import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/user_model.dart';

void main() {
  group('Membership System Serialization & Expiry Tests', () {
    test('Should parse membership_assets from JSON correctly', () {
      final json = {
        'id': 'test-user-id',
        'username': 'premium_student',
        'email': 'premium@creania.com',
        'interests': [],
        'communities': [],
        'vip_level': 2,
        'novel_level': 1,
        'vip_expiry': '2026-08-16T12:00:00Z',
        'novel_expiry': '2026-09-16T12:00:00Z',
        'membership_assets': {
          'avatar_frame': 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_frame.webp',
          'chat_bubble': 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bubble.png',
          'name_glow': '#8B5CF6',
          'identity_tag': 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_2_tag.png',
          'profile_theme': 'amethyst_purple',
          'background_effect': 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bg.jpg'
        }
      };

      final user = User.fromJson(json);

      expect(user.vipLevel, 2);
      expect(user.novelLevel, 1);
      expect(user.vipExpiry, isNotNull);
      expect(user.vipExpiry!.year, 2026);
      expect(user.vipExpiry!.month, 8);
      expect(user.vipExpiry!.day, 16);

      expect(user.novelExpiry, isNotNull);
      expect(user.novelExpiry!.year, 2026);
      expect(user.novelExpiry!.month, 9);
      expect(user.novelExpiry!.day, 16);

      expect(user.membershipAssets, isNotNull);
      expect(user.membershipAssets['avatar_frame'], 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_frame.webp');
      expect(user.membershipAssets['chat_bubble'], 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bubble.png');
      expect(user.membershipAssets['name_glow'], '#8B5CF6');
      expect(user.membershipAssets['identity_tag'], 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_2_tag.png');
      expect(user.membershipAssets['profile_theme'], 'amethyst_purple');
      expect(user.membershipAssets['background_effect'], 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bg.jpg');
    });

    test('Should copyWith membership_assets correctly', () {
      final user = User(
        id: 'user-1',
        username: 'alice',
        email: 'alice@creania.com',
        interests: const [],
        communities: const [],
        followers: 0,
        following: 0,
        isVerified: false,
        isPremium: false,
        reputation: 0,
        sid: '123456',
        membershipAssets: const {
          'avatar_frame': 'frame_url_old',
        },
      );

      final updated = user.copyWith(
        membershipAssets: {
          'avatar_frame': 'frame_url_new',
          'chat_bubble': 'bubble_url_new',
        },
      );

      expect(updated.membershipAssets['avatar_frame'], 'frame_url_new');
      expect(updated.membershipAssets['chat_bubble'], 'bubble_url_new');
    });
  });
}
