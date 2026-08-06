import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/user/user_model.dart';
import '../../../../services/user/customization_controller.dart';

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

  static Widget buildOfficialStatusRow(User? user, BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    final status = user.tagSystem?.officialStatus;

    if (status == null) {
      return const SizedBox.shrink();
    }

    final List<Widget> widgets = [];

    if (status.verifiedTag != null && status.verifiedTag!.isNotEmpty) {
      widgets.add(buildSingleStatusBadge(status.verifiedTag!, isRole: false));
    }

    if (status.roleTag != null && status.roleTag!.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(width: 8));
      widgets.add(buildSingleStatusBadge(status.roleTag!, isRole: true));
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widgets,
    );
  }

  static Widget buildSingleStatusBadge(String label, {required bool isRole}) {
    Gradient gradient;
    Color borderColor;
    IconData icon;

    if (!isRole) {
      // Verified Tag
      gradient = const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      );
      borderColor = const Color(0xFF3B82F6).withOpacity(0.5);
      icon = Icons.verified_user_rounded;
    } else {
      // Role Tag
      gradient = const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
      );
      borderColor = const Color(0xFF8B5CF6).withOpacity(0.5);
      icon = Icons.shield_rounded;
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: gradient,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
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
