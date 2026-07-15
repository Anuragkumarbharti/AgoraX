import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/user_model.dart';

// Standalone TagLight parsing logic matching profile/mini-profile views for unit verification
List<Map<String, dynamic>> parseTagLights(List<String> rawTags) {
  String? verifiedTag;
  int? highestVip;
  int? highestNovel;
  int? highestIdLevel;
  int? highestCommLevel;
  bool isDev = false;
  bool isMod = false;
  bool isEmp = false;
  bool isBot = false;
  bool isTop = false;
  bool isStar = false;
  List<String> others = [];

  for (var t in rawTags) {
    t = t.trim();
    if (t == 'Verified' || t == '✓') {
      verifiedTag = '✓';
    } else if (t.startsWith('VIP Level ') || (t.startsWith('V') && RegExp(r'^\d+$').hasMatch(t.substring(1)))) {
      final numStr = t.startsWith('VIP Level ') ? t.substring(10) : t.substring(1);
      final val = int.tryParse(numStr);
      if (val != null) {
        if (highestVip == null || val > highestVip) highestVip = val;
      }
    } else if (t.startsWith('Novel ') || (t.startsWith('N') && RegExp(r'^\d+$').hasMatch(t.substring(1)))) {
      final numStr = t.startsWith('Novel ') ? t.substring(6) : t.substring(1);
      final val = int.tryParse(numStr);
      if (val != null) {
        if (highestNovel == null || val > highestNovel) highestNovel = val;
      }
    } else if (t.startsWith('ID Level ') || (t.startsWith('L') && RegExp(r'^\d+$').hasMatch(t.substring(1)))) {
      final numStr = t.startsWith('ID Level ') ? t.substring(9) : t.substring(1);
      final val = int.tryParse(numStr);
      if (val != null) {
        if (highestIdLevel == null || val > highestIdLevel) highestIdLevel = val;
      }
    } else if (t.startsWith('Community Level ') || (t.startsWith('C') && RegExp(r'^\d+$').hasMatch(t.substring(1)))) {
      final numStr = t.startsWith('Community Level ') ? t.substring(16) : t.substring(1);
      final val = int.tryParse(numStr);
      if (val != null) {
        if (highestCommLevel == null || val > highestCommLevel) highestCommLevel = val;
      }
    } else if (t.toUpperCase() == 'DEVELOPER' || t.toUpperCase() == 'DEV') {
      isDev = true;
    } else if (t.toUpperCase() == 'MODERATOR' || t.toUpperCase() == 'MOD') {
      isMod = true;
    } else if (t.toUpperCase() == 'EMPLOYEE' || t.toUpperCase() == 'EMP') {
      isEmp = true;
    } else if (t.toUpperCase() == 'OFFICIAL BOT' || t.toUpperCase() == 'BOT') {
      isBot = true;
    } else if (t.toUpperCase() == 'TOP CREATOR' || t.toUpperCase() == 'TOP') {
      isTop = true;
    } else if (t.toUpperCase() == 'STAR CREATOR' || t.toUpperCase() == 'STAR') {
      isStar = true;
    } else {
      others.add(t);
    }
  }

  final List<Map<String, dynamic>> tags = [];
  if (verifiedTag != null) tags.add({'label': '✓', 'color': 'blue'});
  if (highestVip != null) tags.add({'label': 'V$highestVip', 'color': 'purple'});
  if (highestNovel != null) tags.add({'label': 'N$highestNovel', 'color': 'pink'});
  if (highestIdLevel != null) tags.add({'label': 'L$highestIdLevel', 'color': 'gold'});
  if (highestCommLevel != null) tags.add({'label': 'C$highestCommLevel', 'color': 'green'});
  if (isDev) tags.add({'label': 'DEV', 'color': 'red'});
  if (isMod) tags.add({'label': 'MOD', 'color': 'cyan'});
  if (isEmp) tags.add({'label': 'EMP', 'color': 'orange'});
  if (isBot) tags.add({'label': 'BOT', 'color': 'grey'});
  if (isTop) tags.add({'label': 'TOP', 'color': 'amber'});
  if (isStar) tags.add({'label': 'STAR', 'color': 'violet'});
  for (var o in others) {
    tags.add({'label': o, 'color': 'grey'});
  }

  return tags.take(6).toList();
}

// Standalone RTag priority logic matching profile/mini-profile views for unit verification
String? getHighestRTag(List<String> rawRoles) {
  final priority = [
    'Founder',
    'Developer',
    'Official',
    'Employee',
    'Admin',
    'Moderator',
    'Partner',
    'Verified',
    'Tester'
  ];

  final rolesSet = rawRoles.map((r) => r.trim().toLowerCase()).toSet();

  for (var role in priority) {
    if (rolesSet.contains(role.toLowerCase())) {
      return role;
    }
  }
  return null;
}

void main() {
  group('TagLight Clamping & Priority Tests', () {
    test('Should filter lower level VIP/Novel tiers and keep highest', () {
      final tags = ['VIP Level 1', 'VIP Level 5', 'Novel 2', 'Novel 4', 'Verified'];
      final parsed = parseTagLights(tags);

      // Expected output order: Verified (✓), VIP 5 (V5), Novel 4 (N4)
      expect(parsed.length, 3);
      expect(parsed[0]['label'], '✓');
      expect(parsed[1]['label'], 'V5');
      expect(parsed[2]['label'], 'N4');
    });

    test('Should clamp to max 6 tags according to priority', () {
      final tags = [
        'Verified',
        'VIP Level 7',
        'Novel 3',
        'ID Level 45',
        'Community Level 12',
        'Developer',
        'Moderator',
        'Star Creator',
        '🔥'
      ];
      final parsed = parseTagLights(tags);

      // Max 6 tags: Verified, V7, N3, L45, C12, DEV
      expect(parsed.length, 6);
      expect(parsed[0]['label'], '✓');
      expect(parsed[1]['label'], 'V7');
      expect(parsed[2]['label'], 'N3');
      expect(parsed[3]['label'], 'L45');
      expect(parsed[4]['label'], 'C12');
      expect(parsed[5]['label'], 'DEV');
    });
  });

  group('RTag (Official Roles) Priority Tests', () {
    test('Developer should hide Employee and Official roles', () {
      final roles = ['Employee', 'Developer', 'Official'];
      final highest = getHighestRTag(roles);

      expect(highest, 'Developer');
    });

    test('Founder should hide Developer and Admin roles', () {
      final roles = ['Developer', 'Founder', 'Admin'];
      final highest = getHighestRTag(roles);

      expect(highest, 'Founder');
    });

    test('Official should hide Verified role', () {
      final roles = ['Official', 'Verified'];
      final highest = getHighestRTag(roles);

      expect(highest, 'Official');
    });
  });

  group('User Model Serialization Tests', () {
    test('Should parse tag_lights, r_tags, and showcased_badges from JSON', () {
      final json = {
        'id': 'test-uuid-123',
        'username': 'tester_bob',
        'email': 'bob@creania.com',
        'tag_lights': ['Verified', 'V2'],
        'r_tags': ['Developer'],
        'showcased_badges': ['Anniversary'],
        'interests': [],
        'communities': [],
        'followers_count': 100,
        'following_count': 50,
        'verified': true,
        'reputation': 500,
      };

      final user = User.fromJson(json);

      expect(user.tagLights, containsAll(['Verified', 'V2']));
      expect(user.rTags, contains('Developer'));
      expect(user.showcasedBadges, contains('Anniversary'));
    });
  });
}
