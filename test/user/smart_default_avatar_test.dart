import 'package:flutter_test/flutter_test.dart';
import 'package:creania/services/user/smart_default_avatar_service.dart';

void main() {
  group('SmartDefaultAvatarService Tests', () {
    test('Male gender assigns avatar from male pool', () {
      final avatar = SmartDefaultAvatarService.getRandomDefaultAvatar('male');
      expect(avatar, startsWith('assets/creaniaa_avtar_auto/male/'));
      expect(avatar, endsWith('.jpeg'));
      expect(SmartDefaultAvatarService.maleAvatars.contains(avatar), isTrue);
    });

    test('Female gender assigns avatar from female pool', () {
      final avatar = SmartDefaultAvatarService.getRandomDefaultAvatar('female');
      expect(avatar, startsWith('assets/creaniaa_avtar_auto/female/'));
      expect(avatar, endsWith('.jpeg'));
      expect(SmartDefaultAvatarService.femaleAvatars.contains(avatar), isTrue);
    });

    test('Unknown or neutral gender assigns avatar from available pools', () {
      final avatar1 = SmartDefaultAvatarService.getRandomDefaultAvatar(null);
      final avatar2 = SmartDefaultAvatarService.getRandomDefaultAvatar('Prefer not to say');
      
      expect(avatar1, startsWith('assets/creaniaa_avtar_auto/'));
      expect(avatar2, startsWith('assets/creaniaa_avtar_auto/'));
    });

    test('hasCustomAvatar correctly identifies custom vs missing/placeholder avatars', () {
      expect(SmartDefaultAvatarService.hasCustomAvatar('https://storage.supabase.com/avatars/user1.jpg'), isTrue);
      expect(SmartDefaultAvatarService.hasCustomAvatar('assets/creaniaa_avtar_auto/male/1.jpeg'), isTrue);
      
      expect(SmartDefaultAvatarService.hasCustomAvatar(null), isFalse);
      expect(SmartDefaultAvatarService.hasCustomAvatar(''), isFalse);
      expect(SmartDefaultAvatarService.hasCustomAvatar('   '), isFalse);
      expect(SmartDefaultAvatarService.hasCustomAvatar('https://api.dicebear.com/7.x/bottts/png?seed=user1'), isFalse);
    });

    test('male and female avatar lists contain 10 avatars each', () {
      expect(SmartDefaultAvatarService.maleAvatars.length, equals(10));
      expect(SmartDefaultAvatarService.femaleAvatars.length, equals(10));
    });
  });
}
