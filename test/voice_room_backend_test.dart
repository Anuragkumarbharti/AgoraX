import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room_model.dart';
import 'package:creania/models/community_model.dart';

void main() {
  group('Voice Room Backend Model Tests', () {
    test('VoiceRoom serialization and parsing works correctly', () {
      final json = {
        'id': 'CRN-RM-8F4K2X',
        'name': 'Code & Coffee',
        'username': 'codecoffee',
        'description': 'A nice study lounge',
        'host_id': 'uid_anurag_101',
        'community_id': 'CRN-CM-7H9P1L',
        'type': 'Study Room',
        'is_live': true,
        'participant_count': 5,
        'max_participants': 20,
        'speaker_ids': ['uid_anurag_101', 'user_star_1'],
        'listener_ids': ['listener_1', 'listener_2'],
        'recording_url': null,
        'allow_recording': true,
        'allow_screen_share': false,
        'created_at': '2026-07-12T12:00:00.000Z',
        'started_at': '2026-07-12T12:05:00.000Z',
        'ended_at': null,
        'avatar': 'https://example.com/avatar.png',
        'banner': 'https://example.com/banner.png',
        'owner_name': 'Anurag Kumar Bharti',
        'category': 'Study Room',
        'country': 'India',
        'language': 'English',
        'tags': ['Coding', 'Tech'],
        'rules': ['Respect others'],
        'level': 1,
        'xp': 100,
      };

      final room = VoiceRoom.fromJson(json);

      expect(room.id, 'CRN-RM-8F4K2X');
      expect(room.username, '@codecoffee');
      expect(room.name, 'Code & Coffee');
      expect(room.isLive, true);
      expect(room.tags, contains('Coding'));
      expect(room.rules, contains('Respect others'));

      final outJson = room.toJson();
      expect(outJson['username'], 'codecoffee');
    });

    test('Community serialization and parsing works correctly', () {
      final json = {
        'id': 'CRN-CM-7H9P1L',
        'name': 'Developers Hub',
        'username': 'developers',
        'description': 'Main community for developers',
        'avatar_url': 'https://example.com/avatar.png',
        'banner_url': 'https://example.com/banner.png',
        'member_count': 150,
        'created_at': '2026-07-12T12:00:00.000Z',
        'is_private': false,
      };

      final community = Community.fromJson(json);

      expect(community.id, 'CRN-CM-7H9P1L');
      expect(community.username, '@developers');
      expect(community.name, 'Developers Hub');
      expect(community.isPrivate, false);

      final outJson = community.toJson();
      expect(outJson['username'], 'developers');
    });

    test('Username parsing rules formatting checks', () {
      const usernameRaw1 = 'gamingzone';
      final formatted1 = usernameRaw1.startsWith('@') ? usernameRaw1 : '@$usernameRaw1';
      expect(formatted1, '@gamingzone');

      const usernameRaw2 = '@studyhub';
      final formatted2 = usernameRaw2.startsWith('@') ? usernameRaw2 : '@$usernameRaw2';
      expect(formatted2, '@studyhub');
    });
  });
}
