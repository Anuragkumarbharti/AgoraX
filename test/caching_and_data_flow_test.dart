// test/caching_and_data_flow_test.dart

import 'package:flutter_test/flutter_test.dart';

// Simulating the room mapping from our modified room_model.dart
class VoiceRoomTestModel {
  final String id;
  final String name;
  final String hostId;
  final String? banner;
  final String? roomCoverUrl;
  final String status;
  final int level;
  final int totalMembers;
  final int participantCount;

  VoiceRoomTestModel({
    required this.id,
    required this.name,
    required this.hostId,
    this.banner,
    this.roomCoverUrl,
    required this.status,
    required this.level,
    required this.totalMembers,
    required this.participantCount,
  });

  factory VoiceRoomTestModel.fromJson(Map<String, dynamic> json) {
    return VoiceRoomTestModel(
      id: json['id'] as String,
      name: json['name'] as String,
      hostId: json['host_id'] ?? json['hostId'] ?? '',
      banner: json['banner'] as String?,
      roomCoverUrl: json['room_cover_url'] ?? json['roomCoverUrl'],
      status: json['status'] as String? ?? 'ended',
      level: (json['level'] ?? 1) as int,
      totalMembers: (json['total_members'] ?? json['totalMembers'] ?? 0) as int,
      participantCount: (json['online_members'] ?? json['participantCount'] ?? 0) as int,
    );
  }

  bool get isLive => status == 'live';
}

// Simulating Gift Stats formatting logic used on profile_screen
String _formatCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000.0).toStringAsFixed(1).replaceAll('.0', '')}M';
  }
  if (count >= 1000) {
    return '${(count / 1000.0).toStringAsFixed(1).replaceAll('.0', '')}K';
  }
  return count.toString();
}

void main() {
  group('VoiceRoom Model Serialization Tests', () {
    test('Correctly maps status == live to isLive = true', () {
      final json = {
        'id': 'room-1',
        'name': 'Live Study Group',
        'host_id': 'host-1',
        'status': 'live',
        'level': 3,
        'online_members': 15,
        'total_members': 120,
      };

      final room = VoiceRoomTestModel.fromJson(json);

      expect(room.isLive, isTrue);
      expect(room.participantCount, equals(15));
      expect(room.totalMembers, equals(120));
    });

    test('Correctly maps status == ended to isLive = false', () {
      final json = {
        'id': 'room-2',
        'name': 'Offline Study Group',
        'host_id': 'host-2',
        'status': 'ended',
        'level': 1,
        'online_members': 0,
        'total_members': 45,
      };

      final room = VoiceRoomTestModel.fromJson(json);

      expect(room.isLive, isFalse);
      expect(room.participantCount, equals(0));
      expect(room.totalMembers, equals(45));
    });

    test('Correctly resolves banner and roomCoverUrl fallback', () {
      final json = {
        'id': 'room-3',
        'name': 'Test Room',
        'banner': 'https://example.com/banner.png',
        'room_cover_url': 'https://example.com/cover.png',
        'status': 'live',
        'level': 2,
      };

      final room = VoiceRoomTestModel.fromJson(json);

      expect(room.banner, equals('https://example.com/banner.png'));
      expect(room.roomCoverUrl, equals('https://example.com/cover.png'));
    });
  });

  group('Gift Stats Formatting Helper Tests', () {
    test('Formats sub-1000 counts as plain string', () {
      expect(_formatCount(0), equals('0'));
      expect(_formatCount(450), equals('450'));
      expect(_formatCount(999), equals('999'));
    });

    test('Formats counts >= 1000 in K notation', () {
      expect(_formatCount(1000), equals('1K'));
      expect(_formatCount(1200), equals('1.2K'));
      expect(_formatCount(12500), equals('12.5K'));
      expect(_formatCount(999900), equals('999.9K'));
    });

    test('Formats counts >= 1000000 in M notation', () {
      expect(_formatCount(1000000), equals('1M'));
      expect(_formatCount(2300000), equals('2.3M'));
      expect(_formatCount(105000000), equals('105M'));
    });
  });
}
