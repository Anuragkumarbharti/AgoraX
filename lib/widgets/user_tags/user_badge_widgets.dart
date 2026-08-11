import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user/user_model.dart';
import '../../services/room/room_member_controller.dart';
import '../../services/user/user_badge_asset_registry.dart';
import '../memberships/novel_badge_widget.dart';
import '../memberships/vip_badge_widget.dart';

/// Reusable Role Tag component using official image assets
/// (Owner, Co-Owner, Admin, Host, etc.)
class UserRoleTag extends StatelessWidget {
  const UserRoleTag({
    super.key,
    required this.role,
    this.height = 19,
    this.fontSize = 11,
    this.padding,
  });

  final String? role;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final config = UserBadgeAssetRegistry.getRoleTagConfig(role);
    if (config == null) return const SizedBox.shrink();

    return Image.asset(
      config.assetPath,
      height: height,
      cacheHeight: (height * 3).toInt(),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// Reusable Official & Verified Status Tag component
/// using official image assets
class OfficialTagWidget extends StatelessWidget {
  const OfficialTagWidget({
    super.key,
    required this.label,
    this.isRole = false,
    this.height = 19,
    this.fontSize = 10,
  });

  final String label;
  final bool isRole;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    return Image.asset(
      UserBadgeAssetRegistry.officialTagAsset,
      height: height,
      cacheHeight: (height * 3).toInt(),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// Reusable Level Tag component
class LevelTagWidget extends StatelessWidget {
  const LevelTagWidget({
    super.key,
    required this.level,
    this.height = 19,
  });

  final int level;
  final double height;

  @override
  Widget build(BuildContext context) {
    final validLevel = level > 0 ? level : 1;
    final assetPath = UserBadgeAssetRegistry.getLevelTagAssetPath(validLevel);

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        height: height,
        cacheHeight: (height * 3).toInt(),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackPill(validLevel),
      );
    }

    return _buildFallbackPill(validLevel);
  }

  Widget _buildFallbackPill(int lvl) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 9.5)),
            const SizedBox(width: 3),
            Text(
              'Lv.$lvl',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

/// Reusable VIP Tag component using official image assets
class VipTagWidget extends StatelessWidget {
  const VipTagWidget({
    super.key,
    required this.level,
    this.height = 19,
  });

  final int level;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (level <= 0) return const SizedBox.shrink();
    final assetPath = UserBadgeAssetRegistry.getVipTagAssetPath(level);

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        height: height,
        cacheHeight: (height * 3).toInt(),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            VipBadgeWidget(level: level, fontSize: 10),
      );
    }

    return VipBadgeWidget(level: level, fontSize: 10);
  }
}

/// Reusable Novel Tag component using official image assets
class NovelTagWidget extends StatelessWidget {
  const NovelTagWidget({
    super.key,
    required this.level,
    this.height = 19,
  });

  final int level;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (level <= 0) return const SizedBox.shrink();
    final assetPath = UserBadgeAssetRegistry.getNovelTagAssetPath(level);

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        height: height,
        cacheHeight: (height * 3).toInt(),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            NovelBadgeWidget(level: level, fontSize: 10),
      );
    }

    return NovelBadgeWidget(level: level, fontSize: 10);
  }
}

/// Reusable Community & Custom Identity Tag component
/// using official image assets
class IdentityTagWidget extends StatelessWidget {
  const IdentityTagWidget({
    super.key,
    required this.label,
    this.type,
    this.imageUrl,
    this.height = 19,
  });

  final String label;
  final String? type;
  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    final commAsset =
        UserBadgeAssetRegistry.getCommunityTagAssetPath(label) ??
            (imageUrl != null
                ? UserBadgeAssetRegistry.getCommunityTagAssetPath(imageUrl!)
                : null);

    if (commAsset != null) {
      return Image.asset(
        commAsset,
        height: height,
        cacheHeight: (height * 3).toInt(),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPillFallback(),
      );
    }

    return _buildPillFallback();
  }

  Widget _buildPillFallback() {
    var color = const Color(0xFFBEC2FF);
    Gradient? gradient;
    var iconStr = '🏷️';

    final cleanType = (type ?? '').toLowerCase();
    if (cleanType == 'community') {
      color = const Color(0xFFEC4899);
      gradient = const LinearGradient(
        colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      iconStr = '💖';
    } else if (cleanType == 'special') {
      color = const Color(0xFF8B5CF6);
      gradient = const LinearGradient(
        colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      iconStr = '✨';
    }

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: gradient,
        color: gradient == null ? color.withValues(alpha: 0.2) : null,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(iconStr, style: const TextStyle(fontSize: 9.5)),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Unified User Badge Row / Deck component.
class UserBadgeRow extends StatelessWidget {
  const UserBadgeRow({
    super.key,
    required this.user,
    this.roomRole,
    this.targetRole,
    this.showRoleTag = true,
    this.maxWidth = 320,
  });

  final User? user;
  final String? roomRole;
  final String? targetRole;
  final bool showRoleTag;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    final tagWidgets = <Widget>[];

    // 1. Role Tag (Only added when showRoleTag is true)
    if (showRoleTag) {
      String? roleName;
      for (final r in [roomRole, targetRole]) {
        if (r == null || r.trim().isEmpty) continue;
        final l = r.trim().toLowerCase().replaceAll('-', '').replaceAll(' ', '');
        if (l == 'owner' ||
            l == 'host' ||
            l == 'coowner' ||
            l == 'cohost' ||
            l == 'admin' ||
            l == 'moderator' ||
            l == 'founder' ||
            l == 'creator' ||
            l == 'developer') {
          roleName = r.trim();
          break;
        }
      }

      if (roleName == null && user != null && Get.isRegistered<RoomMemberController>()) {
        final member = RoomMemberController.to.activeMembers.firstWhereOrNull((m) => m.userId == user!.id);
        if (member != null && member.role.isNotEmpty) {
          roleName = member.role;
        }
      }

      if (roleName == null && user!.rTags.isNotEmpty) {
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
        final rolesSet = user!.rTags.map((r) => r.trim().toLowerCase()).toSet();
        for (final role in priority) {
          if (rolesSet.contains(role.toLowerCase())) {
            roleName = role;
            break;
          }
        }
      }

      if (roleName != null && roleName.isNotEmpty) {
        final roleWidget = UserRoleTag(role: roleName);
        if (roleWidget is! SizedBox) {
          tagWidgets.add(roleWidget);
        }
      }
    }

    // 2. Official / Verified Status Tag
    final status = user!.tagSystem?.officialStatus;
    final verifiedTag = (status?.verifiedTag?.isNotEmpty == true)
        ? status!.verifiedTag
        : (user!.isVerified ? 'Verified' : null);
    final roleTag = status?.roleTag;

    if (verifiedTag != null && verifiedTag.isNotEmpty) {
      tagWidgets.add(OfficialTagWidget(label: verifiedTag, isRole: false));
    } else if (roleTag != null && roleTag.isNotEmpty) {
      tagWidgets.add(OfficialTagWidget(label: roleTag, isRole: true));
    }

    // 3. Level Tag
    final level = user!.level > 0 ? user!.level : 1;
    tagWidgets.add(LevelTagWidget(level: level));

    // 4. VIP Badge Tag
    final vipLvl =
        user!.vipLevel > 0 ? user!.vipLevel : (user!.isPremium ? 2 : 0);
    if (vipLvl > 0) {
      tagWidgets.add(VipTagWidget(level: vipLvl));
    }

    // 5. Novel Badge Tag
    final novelLvl =
        user!.novelLevel > 0 ? user!.novelLevel : (user!.isPremium ? 1 : 0);
    if (novelLvl > 0) {
      tagWidgets.add(NovelTagWidget(level: novelLvl));
    }

    // 6. Community & Custom Identity Tags (Deduplicated)
    final addedLabels = <String>{};

    if (user!.communities.isNotEmpty) {
      for (final comm in user!.communities) {
        final cleanL = comm.trim();
        if (cleanL.isNotEmpty && addedLabels.add(cleanL.toLowerCase())) {
          tagWidgets.add(IdentityTagWidget(label: cleanL, type: 'community'));
        }
      }
    }

    if (user!.tagSystem != null) {
      for (final t in user!.tagSystem!.identityTagBar) {
        final label = t.value.trim();
        final cleanL = label.toLowerCase();
        if (cleanL.startsWith('lv') ||
            cleanL.startsWith('vip') ||
            cleanL.startsWith('novel')) {
          continue;
        }
        if (addedLabels.add(cleanL)) {
          tagWidgets.add(
            IdentityTagWidget(
              label: label,
              type: t.type,
              imageUrl: t.imageUrl,
            ),
          );
        }
      }
    }

    if (addedLabels.isEmpty) {
      tagWidgets.add(
        const IdentityTagWidget(label: 'CREANIAA', type: 'community'),
      );
    }

    if (tagWidgets.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: tagWidgets,
      ),
    );
  }
}
