import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/user/user_model.dart';
import '../../../../services/user/customization_controller.dart';
import '../../../../widgets/user_tags/user_badge_widgets.dart';

class MiniProfileBadges {
  static Widget buildTextTagFallback(String label, Map<String, dynamic> tag) {
    final color = tag['color'] as Color? ?? const Color(0xFFBEC2FF);
    final gradient = tag['gradient'] as Gradient?;

    Color bg = color.withOpacity(0.12);
    Color borderCol = color.withOpacity(0.4);
    Color textCol = color;

    if (gradient != null) {
      borderCol = color;
      textCol = Colors.white;
    }

    return Tooltip(
      message: 'Identity Tag: $label',
      child: GestureDetector(
        onTap: () {
          Get.snackbar(
              'Tag Info', 'Details page for $label tag (coming soon).');
        },
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: gradient,
            color: gradient == null ? bg : null,
            border: Border.all(color: borderCol, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: borderCol.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: textCol,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String? getHighestRTag(List<String> rawRoles) {
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

  /// Single centralized method to render the unified tag deck (Role Tag + Official Status + Identity Tags)
  static Widget buildUserTagDeck({
    required User? user,
    String? roomRole,
    String? targetRole,
    BuildContext? context,
    double maxWidth = 320,
  }) {
    return UserBadgeRow(
      user: user,
      roomRole: roomRole,
      targetRole: targetRole,
      showRoleTag: true,
      maxWidth: maxWidth,
    );
  }

  static Widget buildSingleRoleTag(
      String? roomRole, String? targetRole, User? user) {
    String? roleName;

    for (final r in [roomRole, targetRole]) {
      if (r == null || r.trim().isEmpty) continue;
      final l = r.trim().toLowerCase();
      if (l == 'owner' ||
          l == 'host' ||
          l == 'co-owner' ||
          l == 'co-host' ||
          l == 'admin' ||
          l == 'moderator' ||
          l == 'founder' ||
          l == 'creator' ||
          l == 'developer') {
        roleName = r.trim();
        break;
      }
    }

    if (roleName == null && user?.rTags.isNotEmpty == true) {
      roleName = getHighestRTag(user!.rTags);
    }

    return UserRoleTag(role: roleName);
  }

  static List<Widget> buildOfficialStatusBadges(User? user) {
    if (user == null) return [];
    final status = user.tagSystem?.officialStatus;

    String? verifiedTag = status?.verifiedTag;
    String? roleTag = status?.roleTag;

    if ((verifiedTag == null || verifiedTag.isEmpty) && user.isVerified) {
      verifiedTag = 'Verified';
    }

    final highestRTag = getHighestRTag(user.rTags);
    if ((roleTag == null || roleTag.isEmpty) && highestRTag != null) {
      roleTag = highestRTag;
    }

    final List<Widget> widgets = [];
    if (verifiedTag != null && verifiedTag.isNotEmpty) {
      widgets.add(buildSingleStatusBadge(verifiedTag, isRole: false));
    }
    if (roleTag != null && roleTag.isNotEmpty) {
      widgets.add(buildSingleStatusBadge(roleTag, isRole: true));
    }
    return widgets;
  }

  static List<Widget> buildIdentityTagWidgets(User? user) {
    if (user == null) return [];

    final List<Widget> widgets = [];

    // 1. Level Tag
    final int level = user.level > 0 ? user.level : 1;
    widgets.add(LevelTagWidget(level: level));

    // 2. VIP Tag
    final int vipLvl =
        user.vipLevel > 0 ? user.vipLevel : (user.isPremium ? 2 : 0);
    if (vipLvl > 0) {
      widgets.add(VipTagWidget(level: vipLvl));
    }

    // 3. Novel Tag
    final int novelLvl =
        user.novelLevel > 0 ? user.novelLevel : (user.isPremium ? 1 : 0);
    if (novelLvl > 0) {
      widgets.add(NovelTagWidget(level: novelLvl));
    }

    // 4. Community & Custom Identity Tags (Deduplicated)
    final addedLabels = <String>{};

    if (user.communities.isNotEmpty) {
      for (final comm in user.communities) {
        final cleanL = comm.trim();
        if (cleanL.isNotEmpty && addedLabels.add(cleanL.toLowerCase())) {
          widgets.add(IdentityTagWidget(label: cleanL, type: 'community'));
        }
      }
    }

    if (user.tagSystem != null) {
      for (var t in user.tagSystem!.identityTagBar) {
        final label = t.value.trim();
        final cleanL = label.toLowerCase();
        if (cleanL.startsWith('lv') ||
            cleanL.startsWith('vip') ||
            cleanL.startsWith('novel')) {
          continue;
        }

        if (addedLabels.add(cleanL)) {
          widgets.add(
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
      widgets.add(const IdentityTagWidget(label: 'CREANIAA', type: 'community'));
    }

    return widgets;
  }

  static Widget _buildLevelPill(int level) {
    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
            color: const Color(0xFF3B82F6).withOpacity(0.5), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 9.5)),
          const SizedBox(width: 3),
          Text(
            'Lv.$level',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCommunityPill(String comm) {
    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
            color: const Color(0xFFEC4899).withOpacity(0.5), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('❤️', style: TextStyle(fontSize: 9.5)),
          const SizedBox(width: 3),
          Text(
            comm,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildOfficialStatusRow(User? user, BuildContext context) {
    final widgets = buildOfficialStatusBadges(user);
    if (widgets.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widgets,
    );
  }

  static Widget buildSingleStatusBadge(String label, {required bool isRole}) {
    return OfficialTagWidget(label: label, isRole: isRole);
  }

  static Widget buildBadgesShowcaseWidget(
      List<String> activeBadgesList, BuildContext context) {
    final custCtrl = Get.find<CustomizationController>();
    final badgesToUse = activeBadgesList;
    if (badgesToUse.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: badgesToUse.take(5).map((bName) {
              final meta = custCtrl.badgeMetadata[bName] ??
                  {'icon': '🏅', 'rarity': 'Common'};
              final iconStr = meta['icon'] as String? ?? '🏅';
              final rarity = meta['rarity'] as String? ?? 'Common';

              Color glowColor = const Color(0xFFFFB020);
              if (rarity == 'Legendary') {
                glowColor = const Color(0xFFFFD700);
              } else if (rarity == 'Mythic') {
                glowColor = const Color(0xFFEF4444);
              } else if (rarity == 'Epic') {
                glowColor = const Color(0xFF8B5CFF);
              } else if (rarity == 'Rare') {
                glowColor = const Color(0xFF3B82F6);
              }

              return Tooltip(
                message: '$bName Badge ($rarity)',
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(color: glowColor, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      iconStr,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'User can equip up to 5 badges. Drag to change order.',
            style: GoogleFonts.poppins(
              color: Colors.white38,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildStatColumn(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
