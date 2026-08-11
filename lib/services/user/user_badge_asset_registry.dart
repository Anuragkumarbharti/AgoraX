import 'package:flutter/material.dart';

/// Configuration definition for Role Tags
class RoleTagConfig {
  const RoleTagConfig({
    required this.roleName,
    required this.displayTitle,
    required this.assetPath,
  });

  final String roleName;
  final String displayTitle;
  final String assetPath;
}

/// Single Source of Truth Asset Registry for all User Tags,
/// Badges, Roles, and Identity Assets.
class UserBadgeAssetRegistry {
  UserBadgeAssetRegistry._();

  // Known community tag assets map
  static const Map<String, String> _communityAssets = {
    'arenax': 'assets/identity_tags/officialcomunity_tags/arenax.webp',
    'arena x': 'assets/identity_tags/officialcomunity_tags/arenax.webp',
    'campus': 'assets/identity_tags/officialcomunity_tags/campus.webp',
    'connect': 'assets/identity_tags/officialcomunity_tags/cannect.webp',
    'cannect': 'assets/identity_tags/officialcomunity_tags/cannect.webp',
    'origin': 'assets/identity_tags/officialcomunity_tags/origin.webp',
    'studio': 'assets/identity_tags/officialcomunity_tags/studio.webp',
  };

  // Known level asset map
  static const Map<int, String> _levelAssets = {
    1: 'assets/identity_tags/ID_LEVAL/id_level_1.webp',
    2: 'assets/identity_tags/ID_LEVAL/id_level_2.webp',
  };

  // Known VIP asset map
  static const Map<int, String> _vipAssets = {
    1: 'assets/identity_tags/VIP/VIP-1.webp',
    2: 'assets/identity_tags/VIP/VIP-2.webp',
  };

  // Known Novel asset map
  static const Map<int, String> _novelAssets = {
    1: 'assets/identity_tags/NOVEL/NOVEL_1.webp',
  };

  // Official Status asset path
  static const String officialTagAsset =
      'assets/identity_tags/OFFICIAL_TAG/OFFCIALLVTAG.webp';

  /// Returns the asset path for a community tag if available, or null.
  static String? getCommunityTagAssetPath(String tagLabel) {
    final clean = tagLabel.trim().toLowerCase();
    for (final entry in _communityAssets.entries) {
      if (clean == entry.key || clean.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Returns the asset path for a level tag if an image asset exists, or null.
  static String? getLevelTagAssetPath(int level) => _levelAssets[level];

  /// Returns the asset path for a VIP tag if an image asset exists, or null.
  static String? getVipTagAssetPath(int level) => _vipAssets[level];

  /// Returns the asset path for a Novel tag if an image asset exists, or null.
  static String? getNovelTagAssetPath(int level) => _novelAssets[level];

  /// Single Source of Truth for Role Tag configurations
  /// using exact official assets.
  static RoleTagConfig? getRoleTagConfig(String? role) {
    if (role == null || role.trim().isEmpty) return null;
    final lower = role.trim().toLowerCase().replaceAll('-', '').replaceAll(' ', '');

    if (lower == 'speaker' ||
        lower == 'listener' ||
        lower == 'audience' ||
        lower == 'member' ||
        lower == 'cohost' ||
        lower == 'starmember' ||
        lower == 'user') {
      return null;
    }

    if (lower == 'owner' || lower == 'founder' || lower == 'creator' || lower == 'developer') {
      return const RoleTagConfig(
        roleName: 'owner',
        displayTitle: 'OWNER',
        assetPath: 'assets/identity_tags/ROLL_TAG/OWNER.webp',
      );
    } else if (lower == 'coowner') {
      return const RoleTagConfig(
        roleName: 'co-owner',
        displayTitle: 'CO-OWNER',
        assetPath: 'assets/identity_tags/ROLL_TAG/CO-OWNER.webp',
      );
    } else if (lower == 'admin') {
      return const RoleTagConfig(
        roleName: 'admin',
        displayTitle: 'ADMIN',
        assetPath: 'assets/identity_tags/ROLL_TAG/ADMIN.webp',
      );
    } else if (lower == 'mod' || lower == 'moderator' || lower == 'host') {
      return const RoleTagConfig(
        roleName: 'mod',
        displayTitle: 'MOD',
        assetPath: 'assets/identity_tags/ROLL_TAG/HOST.webp',
      );
    }

    return null;
  }

  /// Pre-caches essential badge image assets into memory
  static void preloadEssentialBadgeAssets(BuildContext context) {
    final assetsToPreload = [
      ..._levelAssets.values,
      ..._vipAssets.values,
      ..._novelAssets.values,
      officialTagAsset,
      'assets/identity_tags/ROLL_TAG/OWNER.webp',
      'assets/identity_tags/ROLL_TAG/CO-OWNER.webp',
      'assets/identity_tags/ROLL_TAG/ADMIN.webp',
      'assets/identity_tags/ROLL_TAG/HOST.webp',
      'assets/identity_tags/officialcomunity_tags/arenax.webp',
      'assets/identity_tags/officialcomunity_tags/campus.webp',
      'assets/identity_tags/officialcomunity_tags/cannect.webp',
      'assets/identity_tags/officialcomunity_tags/origin.webp',
      'assets/identity_tags/officialcomunity_tags/studio.webp',
    ];

    for (final assetPath in assetsToPreload) {
      precacheImage(AssetImage(assetPath), context).catchError((err) {
        debugPrint('[BadgeRegistry] Preload ignored for $assetPath: $err');
      });
    }
  }
}
