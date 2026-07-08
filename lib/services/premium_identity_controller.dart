import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'vip_controller.dart';
import 'novel_controller.dart';
import '../widgets/vip_badge_widget.dart';
import '../widgets/novel_badge_widget.dart';

class UserVerification {
  final String title;
  final String icon;
  final Color color;
  final String requirement;
  final List<String> benefits;
  final String date;
  final String status;

  UserVerification({
    required this.title,
    required this.icon,
    required this.color,
    required this.requirement,
    required this.benefits,
    required this.date,
    required this.status,
  });
}

class OfficialTag {
  final String name;
  final String icon;
  final Color color;
  final String benefit;

  OfficialTag({
    required this.name,
    required this.icon,
    required this.color,
    required this.benefit,
  });
}

class CommunityTag {
  final String name;
  final String role;
  final int level;
  final List<Color> gradientColors;
  final bool isAnimated;

  CommunityTag({
    required this.name,
    required this.role,
    required this.level,
    required this.gradientColors,
    this.isAnimated = false,
  });
}

class PremiumIdentity {
  final int vipLevel;
  final int novelLevel;
  final int idLevel;
  final int careerLevel;
  final CommunityTag? communityTag;
  final UserVerification? verification;
  final OfficialTag? officialTag;
  final String? achievementTag;
  final int trustScore;

  PremiumIdentity({
    required this.vipLevel,
    required this.novelLevel,
    required this.idLevel,
    required this.careerLevel,
    this.communityTag,
    this.verification,
    this.officialTag,
    this.achievementTag,
    required this.trustScore,
  });

  void showBadgeInfoDialog(
    BuildContext context, {
    required String title,
    required String description,
    required Color color,
    required String icon,
    required String requirement,
    required List<String> benefits,
    String? date,
    String? status,
  }) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF151518),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status != null) ...[
              Text('STATUS', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
              Text(status, style: GoogleFonts.poppins(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
            ],
            if (date != null) ...[
              Text('VERIFIED DATE', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
              Text(date, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
            ],
            Text('REQUIREMENT', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
            Text(requirement, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            Text('BENEFITS & PERKS', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
            ...benefits.map((b) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: color)),
                      Expanded(
                        child: Text(
                          b,
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<Widget> buildBadges(BuildContext context, {double fontSize = 9}) {
    final List<Widget> badgeWidgets = [];

    // 1. VIP Badge
    if (vipLevel > 0) {
      badgeWidgets.add(
        GestureDetector(
          onTap: () => showBadgeInfoDialog(
            context,
            title: 'VIP Level $vipLevel',
            description: 'Premium VIP status.',
            color: const Color(0xFFFFD700),
            icon: '👑',
            requirement: 'Accumulate purchases to raise VIP membership tier.',
            benefits: [
              'Rotating sweep name border',
              'Glowing name styles',
              'Special premium entry banner announcements',
            ],
            status: 'Active',
            date: 'Subscribed',
          ),
          child: VipBadgeWidget(level: vipLevel, fontSize: fontSize),
        ),
      );
    }

    // 2. Novel Badge
    if (novelLevel > 0) {
      badgeWidgets.add(
        GestureDetector(
          onTap: () => showBadgeInfoDialog(
            context,
            title: 'Novel Tier $novelLevel',
            description: 'Collectible high-value Novel status.',
            color: const Color(0xFFEA580C),
            icon: '📖',
            requirement: 'Obtain designated Novel artifacts from events or store.',
            benefits: [
              'Custom magical sparkles names',
              'Magical entry wings animation',
              'Unique Novel border styling',
            ],
            status: 'Active',
            date: 'Unlocked',
          ),
          child: NovelBadgeWidget(level: novelLevel, fontSize: fontSize),
        ),
      );
    }

    // 3. ID Level Badge
    badgeWidgets.add(
      GestureDetector(
        onTap: () => showBadgeInfoDialog(
          context,
          title: 'ID Level $idLevel',
          description: 'User profile level.',
          color: const Color(0xFF38BDF8),
          icon: '🆔',
          requirement: 'Interact and gain experience points (XP) in rooms, chats, and posts.',
          benefits: [
            'Level tag multiplier',
            'Unlocks advanced room capabilities',
            'Gain reputation bonuses',
          ],
          status: 'Permanent',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.5), width: 0.5),
          ),
          child: Text(
            'Lvl $idLevel',
            style: GoogleFonts.poppins(
              color: const Color(0xFF38BDF8),
              fontSize: fontSize - 1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );

    // 4. Career Level Badge
    badgeWidgets.add(
      GestureDetector(
        onTap: () => showBadgeInfoDialog(
          context,
          title: 'Career Tier $careerLevel',
          description: 'AgoraX Career progression level.',
          color: const Color(0xFFFFB800),
          icon: '💻',
          requirement: 'Submit and get verified for domain expertise tasks and courses.',
          benefits: [
            'Display official job titles',
            'Priority visibility in professional search',
            'Access to exclusive industry group rooms',
          ],
          status: 'Permanent',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFD97706).withOpacity(0.5), width: 0.5),
          ),
          child: Text(
            'Career $careerLevel',
            style: GoogleFonts.poppins(
              color: const Color(0xFFFBBF24),
              fontSize: fontSize - 1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );

    // 5. Community Tag
    if (communityTag != null) {
      final ct = communityTag!;
      Widget tagContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: ct.gradientColors.first.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: ct.gradientColors.first.withOpacity(0.5), width: 0.5),
        ),
        child: Text(
          '${ct.role}',
          style: GoogleFonts.poppins(
            color: ct.gradientColors.first,
            fontSize: fontSize - 1,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      if (ct.isAnimated) {
        tagContent = Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: ct.gradientColors),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: ct.gradientColors.first.withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 0.5,
              )
            ],
          ),
          child: Text(
            '${ct.role}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: fontSize - 1,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      badgeWidgets.add(
        GestureDetector(
          onTap: () => showBadgeInfoDialog(
            context,
            title: '${ct.name} (${ct.role})',
            description: 'Community ranking tag.',
            color: ct.gradientColors.first,
            icon: '🏷️',
            requirement: 'Assigned as a community organizer inside target guild/community.',
            benefits: [
              'Role title displayed inside community screens',
              'Special community action powers',
              'Exclusive level tag glows',
            ],
            status: 'Active',
          ),
          child: tagContent,
        ),
      );
    }

    // 6. Verification
    if (verification != null) {
      final v = verification!;
      badgeWidgets.add(
        GestureDetector(
          onTap: () => showBadgeInfoDialog(
            context,
            title: v.title,
            description: 'Manual verified credentials.',
            color: v.color,
            icon: v.icon,
            requirement: v.requirement,
            benefits: v.benefits,
            date: v.date,
            status: v.status,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: v.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: v.color.withOpacity(0.6), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(v.icon, style: TextStyle(color: v.color, fontSize: fontSize - 2)),
                const SizedBox(width: 2),
                Text(
                  v.title.split(' ')[0],
                  style: GoogleFonts.poppins(
                    color: v.color,
                    fontSize: fontSize - 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 7. Official Tag
    if (officialTag != null) {
      final ot = officialTag!;
      badgeWidgets.add(
        GestureDetector(
          onTap: () => showBadgeInfoDialog(
            context,
            title: ot.name,
            description: 'AgoraX platform designation.',
            color: ot.color,
            icon: ot.icon,
            requirement: 'Manually verified and assigned by the AgoraX platform administration.',
            benefits: [
              ot.benefit,
              'Exclusive priority verification status',
              'AgoraX official crown decoration',
            ],
            status: 'Verified Official',
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: ot.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ot.color.withOpacity(0.6), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ot.icon, style: TextStyle(color: ot.color, fontSize: fontSize - 2)),
                const SizedBox(width: 2),
                Text(
                  ot.name.split(' ').last,
                  style: GoogleFonts.poppins(
                    color: ot.color,
                    fontSize: fontSize - 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 8. Achievement Tag
    if (achievementTag != null) {
      badgeWidgets.add(
        GestureDetector(
          onTap: () => showBadgeInfoDialog(
            context,
            title: achievementTag!,
            description: 'Earned achievement.',
            color: const Color(0xFFEF4444),
            icon: achievementTag!.split(' ').first,
            requirement: 'Earned by accomplishing a platform-wide gamification milestone.',
            benefits: [
              'Visually distinct gold/red badge tag',
              'Special prestige ranking',
            ],
            status: 'Unlocked',
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 0.5),
            ),
            child: Text(
              achievementTag!.split(' ').sublist(1).join(' '),
              style: GoogleFonts.poppins(
                color: const Color(0xFFFCA5A5),
                fontSize: fontSize - 1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    if (badgeWidgets.length > 8) {
      return badgeWidgets.sublist(0, 8);
    }
    return badgeWidgets;
  }

  Widget buildBadgeRow(BuildContext context, {double fontSize = 9}) {
    final list = buildBadges(context, fontSize: fontSize);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: list,
    );
  }
}

class PremiumIdentityController extends GetxController {
  final RxString currentVerification = 'Verified'.obs;
  final RxString currentOfficialTag = 'None'.obs;
  final RxString currentAchievementTag = '🔥 Top Contributor'.obs;
  final RxInt currentTrustScore = 95.obs;

  static PremiumIdentity getIdentity(String userId, String username) {
    final int hash = (userId.isEmpty ? username : userId).hashCode.abs();

    int vip = hash % 8;
    if (username.toLowerCase().contains('anurag') || username == 'me' || userId == 'me') {
      try {
        vip = Get.find<VipController>().vipLevel.value;
      } catch (_) {}
    }

    int novel = hash % 6;
    if (username.toLowerCase().contains('anurag') || username == 'me' || userId == 'me') {
      try {
        novel = Get.find<NovelController>().novelLevel.value;
      } catch (_) {}
    }

    int idLvl = (hash % 60) + 1;
    int careerLvl = (hash % 10) + 1;

    CommunityTag? commTag;
    if (hash % 3 != 0) {
      final roles = ['Owner', 'Co-Owner', 'Admin', 'Moderator', 'Mentor', 'Champion', 'Member'];
      final role = roles[hash % roles.length];
      final level = (hash % 60) + 1;
      List<Color> colors = [Colors.grey, Colors.grey.shade600];
      bool isAnimated = false;
      if (level >= 11 && level <= 20) {
        colors = [Colors.blue, Colors.blue.shade800];
      } else if (level >= 21 && level <= 30) {
        colors = [Colors.purple, Colors.purple.shade800];
      } else if (level >= 31 && level <= 40) {
        colors = [const Color(0xFFFFD700), const Color(0xFFB45309)];
      } else if (level >= 41 && level <= 50) {
        colors = [const Color(0xFFFFD700), Colors.amber, const Color(0xFFFFD700)];
        isAnimated = true;
      } else if (level >= 51) {
        colors = [const Color(0xFFFF007F), const Color(0xFF00F0FF), const Color(0xFFFF007F)];
        isAnimated = true;
      }
      commTag = CommunityTag(
        name: 'AgoraX Devs',
        role: role,
        level: level,
        gradientColors: colors,
        isAnimated: isAnimated,
      );
    }

    UserVerification? verification;
    final verType = hash % 7;
    String resolvedVer = '';
    if (username.toLowerCase().contains('anurag') || username == 'me' || userId == 'me') {
      try {
        resolvedVer = Get.find<PremiumIdentityController>().currentVerification.value;
      } catch (_) {}
    }

    if (resolvedVer.isNotEmpty && resolvedVer != 'None') {
      verification = _mapVerification(resolvedVer);
    } else if (resolvedVer.isEmpty && hash % 4 != 0) {
      verification = _mapVerificationByIndex(verType);
    }

    OfficialTag? officialTag;
    String resolvedOfficial = '';
    if (username.toLowerCase().contains('anurag') || username == 'me' || userId == 'me') {
      try {
        resolvedOfficial = Get.find<PremiumIdentityController>().currentOfficialTag.value;
      } catch (_) {}
    }

    if (resolvedOfficial.isNotEmpty && resolvedOfficial != 'None') {
      officialTag = _mapOfficialTag(resolvedOfficial);
    } else if (resolvedOfficial.isEmpty && hash % 6 == 0) {
      officialTag = _mapOfficialTagByIndex(hash % 7);
    }

    String? achievementTag;
    if (username.toLowerCase().contains('anurag') || username == 'me' || userId == 'me') {
      try {
        final val = Get.find<PremiumIdentityController>().currentAchievementTag.value;
        achievementTag = val == 'None' ? null : val;
      } catch (_) {}
    } else if (hash % 5 != 0) {
      final achievements = [
        '🏆 Season Champion',
        '🔥 Top Contributor',
        '⭐ Top Supporter',
        '💯 365 Day Streak',
        '🚀 Pioneer Member',
        '👑 Hall of Fame',
        '🏅 Career Master',
        '🎯 Community Champion'
      ];
      achievementTag = achievements[hash % achievements.length];
    }

    int trust = 80 + (hash % 21);
    if (username.toLowerCase().contains('anurag') || username == 'me' || userId == 'me') {
      try {
        trust = Get.find<PremiumIdentityController>().currentTrustScore.value;
      } catch (_) {}
    }

    return PremiumIdentity(
      vipLevel: vip,
      novelLevel: novel,
      idLevel: idLvl,
      careerLevel: careerLvl,
      communityTag: commTag,
      verification: verification,
      officialTag: officialTag,
      achievementTag: achievementTag,
      trustScore: trust,
    );
  }

  static UserVerification? _mapVerification(String key) {
    switch (key) {
      case 'Verified':
        return UserVerification(
          title: 'Verified',
          icon: '✔',
          color: const Color(0xFF2563EB),
          requirement: 'Identity Verification approved by Agorax Security Team.',
          benefits: ['Verified Badge display', 'Higher trust rating', 'Priority profile search'],
          date: '2026-03-12',
          status: 'Approved',
        );
      case 'Student Verified':
        return UserVerification(
          title: 'Student Verified',
          icon: '🎓',
          color: const Color(0xFF06B6D4),
          requirement: 'Valid University Student Identity verified.',
          benefits: ['Student Badge display', 'Student community forums access', 'Education benefits & coupons'],
          date: '2026-05-18',
          status: 'Approved',
        );
      case 'Teacher Verified':
        return UserVerification(
          title: 'Teacher Verified',
          icon: '👨‍🏫',
          color: const Color(0xFF10B981),
          requirement: 'Valid Educator Identity credentials verified.',
          benefits: ['Teacher Badge display', 'Educators lounge access', 'Teaching events priority'],
          date: '2026-01-20',
          status: 'Approved',
        );
      case 'Professor Verified':
        return UserVerification(
          title: 'Professor Verified',
          icon: '🎓',
          color: const Color(0xFF8B5CF6),
          requirement: 'University Academic Professor status approved.',
          benefits: ['Professor Badge display', 'Academic research feeds', 'Priority query searches'],
          date: '2025-11-05',
          status: 'Approved',
        );
      case 'Professional Verified':
        return UserVerification(
          title: 'Professional Verified',
          icon: '💼',
          color: const Color(0xFFFFD700),
          requirement: 'Industry Professional resume review completed.',
          benefits: ['Professional Badge display', 'Corporate network channels', 'Career recognition status'],
          date: '2026-02-14',
          status: 'Approved',
        );
      case 'Trusted User':
        return UserVerification(
          title: 'Trusted User',
          icon: '🛡️',
          color: const Color(0xFF94A3B8),
          requirement: 'Long-term positive reputation score, 0 violations.',
          benefits: ['Trusted User Badge', 'Higher trust multipliers', 'Community moderator recommendations'],
          date: '2025-08-22',
          status: 'Approved',
        );
      case 'Organization Verified':
        return UserVerification(
          title: 'Organization Verified',
          icon: '🏢',
          color: const Color(0xFF1E3A8A),
          requirement: 'Corporate or NGO registration verified.',
          benefits: ['Organization Badge display', 'Verified Organization channels', 'Official events creation permission'],
          date: '2026-04-01',
          status: 'Approved',
        );
      default:
        return null;
    }
  }

  static UserVerification _mapVerificationByIndex(int index) {
    final keys = [
      'Verified',
      'Student Verified',
      'Teacher Verified',
      'Professor Verified',
      'Professional Verified',
      'Trusted User',
      'Organization Verified'
    ];
    return _mapVerification(keys[index])!;
  }

  static OfficialTag? _mapOfficialTag(String key) {
    switch (key) {
      case 'Agorax Official':
        return OfficialTag(name: 'Agorax Official', icon: '👑', color: const Color(0xFFFFD700), benefit: 'Highest trust, administrator privilege');
      case 'Agorax Employee':
        return OfficialTag(name: 'Agorax Employee', icon: '🛠️', color: const Color(0xFFEC4899), benefit: 'Official company employee');
      case 'Agorax Developer':
        return OfficialTag(name: 'Agorax Developer', icon: '💻', color: const Color(0xFF3B82F6), benefit: 'AgoraX platform engineer');
      case 'Official Moderator':
        return OfficialTag(name: 'Official Moderator', icon: '🛡️', color: const Color(0xFF10B981), benefit: 'Global room moderation power');
      case 'Official Host':
        return OfficialTag(name: 'Official Host', icon: '🎤', color: const Color(0xFF8B5CF6), benefit: 'Verified speaker/host for events');
      case 'Official Coin Seller':
        return OfficialTag(name: 'Official Coin Seller', icon: '🪙', color: const Color(0xFFFBBF24), benefit: 'Verified point/currency dealer');
      case 'Official Partner':
        return OfficialTag(name: 'Official Partner', icon: '🤝', color: const Color(0xFF06B6D4), benefit: 'Authorized enterprise business associate');
      default:
        return null;
    }
  }

  static OfficialTag _mapOfficialTagByIndex(int index) {
    final keys = [
      'Agorax Official',
      'Agorax Employee',
      'Agorax Developer',
      'Official Moderator',
      'Official Host',
      'Official Coin Seller',
      'Official Partner'
    ];
    return _mapOfficialTag(keys[index])!;
  }
}
