import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/user_model.dart';
import 'package:creania/services/premium_identity_controller.dart';

void main() {
  group('Backend-Driven Tag System Model Serialization Tests', () {
    test('Should parse tag_system and its components from JSON correctly', () {
      final json = {
        'id': 'test-uuid-123',
        'username': 'tester_bob',
        'email': 'bob@creania.com',
        'tag_lights': ['ID Level 42', 'Origin', 'VIP Level 3'],
        'r_tags': ['Developer'],
        'showcased_badges': ['Anniversary', 'Founder Badge', 'Early User', 'Beta Tester', 'Champion'],
        'interests': [],
        'communities': [],
        'verified': true,
        'reputation': 500,
        'followers': 100,
        'following': 50,
        'tag_system': {
          'identityTagBar': [
            {'type': 'id_level', 'value': 'Lv.26'},
            {'type': 'community', 'value': 'Silver Couple'},
            {'type': 'vip', 'value': 'VIP 2'},
            {'type': 'noble', 'value': 'King'},
            {'type': 'special', 'value': 'Forever Friends'}
          ],
          'officialStatus': {
            'verifiedTag': 'Verified',
            'roleTag': 'Party Guru'
          },
          'profileShowcase': [
            'badge_01',
            'badge_05',
            'badge_09',
            'badge_12',
            'badge_18'
          ]
        }
      };

      final user = User.fromJson(json);

      expect(user.tagSystem, isNotNull);
      
      final tagSystem = user.tagSystem!;
      
      // Assert Identity Tag Bar
      expect(tagSystem.identityTagBar.length, 5);
      expect(tagSystem.identityTagBar[0].type, 'id_level');
      expect(tagSystem.identityTagBar[0].value, 'Lv.26');
      expect(tagSystem.identityTagBar[1].type, 'community');
      expect(tagSystem.identityTagBar[1].value, 'Silver Couple');
      expect(tagSystem.identityTagBar[2].type, 'vip');
      expect(tagSystem.identityTagBar[2].value, 'VIP 2');
      expect(tagSystem.identityTagBar[3].type, 'noble');
      expect(tagSystem.identityTagBar[3].value, 'King');
      expect(tagSystem.identityTagBar[4].type, 'special');
      expect(tagSystem.identityTagBar[4].value, 'Forever Friends');

      // Assert Official Status
      expect(tagSystem.officialStatus.verifiedTag, 'Verified');
      expect(tagSystem.officialStatus.roleTag, 'Party Guru');

      // Assert Showcase
      expect(tagSystem.profileShowcase.length, 5);
      expect(tagSystem.profileShowcase, containsAll(['badge_01', 'badge_05', 'badge_09', 'badge_12', 'badge_18']));
    });
  });

  group('PremiumIdentity Status Priority Fallback Tests', () {
    test('Founder role should hide Developer, Admin, Moderator, and Verified status', () {
      final identity = PremiumIdentity(
        vipLevel: 0,
        novelLevel: 0,
        idLevel: 1,
        careerLevel: 1,
        trustScore: 100,
        rTags: ['Developer', 'Founder', 'Admin', 'Moderator'],
        verification: UserVerification(
          title: 'Verified',
          icon: '✓',
          color: const Color(0xFF00C2FF),
          requirement: 'Verified Identity',
          benefits: [],
          date: '2026-07-16',
          status: 'Approved',
        ),
      );

      expect(identity.officialStatusTag?.name, 'Founder');
    });

    test('Developer role should hide Admin, Moderator, and Verified status', () {
      final identity = PremiumIdentity(
        vipLevel: 0,
        novelLevel: 0,
        idLevel: 1,
        careerLevel: 1,
        trustScore: 100,
        rTags: ['Developer', 'Admin', 'Moderator'],
        verification: UserVerification(
          title: 'Verified',
          icon: '✓',
          color: const Color(0xFF00C2FF),
          requirement: 'Verified Identity',
          benefits: [],
          date: '2026-07-16',
          status: 'Approved',
        ),
      );

      expect(identity.officialStatusTag?.name, 'Developer');
    });

    test('Admin role should hide Moderator and Verified status', () {
      final identity = PremiumIdentity(
        vipLevel: 0,
        novelLevel: 0,
        idLevel: 1,
        careerLevel: 1,
        trustScore: 100,
        rTags: ['Admin', 'Moderator'],
        verification: UserVerification(
          title: 'Verified',
          icon: '✓',
          color: const Color(0xFF00C2FF),
          requirement: 'Verified Identity',
          benefits: [],
          date: '2026-07-16',
          status: 'Approved',
        ),
      );

      expect(identity.officialStatusTag?.name, 'Admin');
    });
  });
}
