import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Smart Default Avatar Assignment Service
/// Automatically assigns a random gender-based default avatar from assets/creaniaa_avtar_auto/
/// when a user skips profile setup or has no profile picture.
class SmartDefaultAvatarService {
  static final Random _random = Random();

  static final List<String> maleAvatars = List.generate(
    10,
    (index) => 'assets/creaniaa_avtar_auto/male/${index + 1}.jpeg',
  );

  static final List<String> femaleAvatars = List.generate(
    10,
    (index) => 'assets/creaniaa_avtar_auto/female/${index + 1}.jpeg',
  );

  /// Returns true if the user already has a custom or previously assigned non-placeholder avatar
  static bool hasCustomAvatar(String? avatarUrl) {
    if (avatarUrl == null) return false;
    final trimmed = avatarUrl.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('dicebear')) return false;
    return true;
  }

  /// Selects a random default avatar path based on gender
  static String getRandomDefaultAvatar(String? gender) {
    final normalizedGender = (gender ?? '').trim().toLowerCase();

    if (normalizedGender == 'male' ||
        normalizedGender == 'm' ||
        normalizedGender == 'boy' ||
        normalizedGender == 'man') {
      return maleAvatars[_random.nextInt(maleAvatars.length)];
    } else if (normalizedGender == 'female' ||
        normalizedGender == 'f' ||
        normalizedGender == 'girl' ||
        normalizedGender == 'woman') {
      return femaleAvatars[_random.nextInt(femaleAvatars.length)];
    } else {
      // Neutral / Unknown / Prefer not to say
      final isMalePool = _random.nextBool();
      final pool = isMalePool ? maleAvatars : femaleAvatars;
      return pool[_random.nextInt(pool.length)];
    }
  }

  /// Ensures that a user has a permanent avatar assigned in the DB.
  /// If an avatar already exists, it is NEVER overwritten.
  static Future<String> ensureDefaultAvatarAssigned({
    required String userId,
    required String? currentAvatar,
    String? gender,
  }) async {
    if (hasCustomAvatar(currentAvatar)) {
      return currentAvatar!;
    }

    final assignedAvatar = getRandomDefaultAvatar(gender);

    try {
      if (userId.isNotEmpty) {
        await Supabase.instance.client.from('profiles').update({
          'avatar_url': assignedAvatar,
          'avatar': assignedAvatar,
          'profile_photo': assignedAvatar,
        }).eq('id', userId);
        debugPrint('[SmartDefaultAvatar] Assigned default avatar for $userId: $assignedAvatar');
      }
    } catch (e) {
      debugPrint('[SmartDefaultAvatar] Failed to persist assigned avatar: $e');
    }

    return assignedAvatar;
  }
}
