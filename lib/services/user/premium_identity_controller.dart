import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../memberships/vip_controller.dart';
import '../memberships/novel_controller.dart';
import '../progression/career_progression_controller.dart';
import '../../widgets/memberships/vip_badge_widget.dart';
import '../../widgets/memberships/novel_badge_widget.dart';
import 'user_badge_asset_registry.dart';

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
  final List<String> rTags;

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
    this.rTags = const [],
  });

  OfficialTag? get officialStatusTag {
    // 1. Founder
    if (rTags.any((r) => r.trim().toLowerCase() == 'founder')) {
      return OfficialTag(name: 'Founder', icon: '👑', color: const Color(0xFFFFB020), benefit: 'Founding Member of Creaniaa');
    }
    // 2. Developer
    if (rTags.any((r) => r.trim().toLowerCase() == 'developer')) {
      return OfficialTag(name: 'Developer', icon: '💻', color: const Color(0xFF00C2FF), benefit: 'Creaniaa Platform Engineer');
    }
    // 3. Official
    if (rTags.any((r) => r.trim().toLowerCase() == 'official')) {
      return OfficialTag(name: 'Official', icon: '👑', color: const Color(0xFFFFD700), benefit: 'Official Platform Account');
    }
    // 4. Employee
    if (rTags.any((r) => r.trim().toLowerCase() == 'employee')) {
      return OfficialTag(name: 'Employee', icon: '🛠️', color: const Color(0xFFEC4899), benefit: 'Creaniaa Company Employee');
    }
    // 5. Admin
    if (rTags.any((r) => r.trim().toLowerCase() == 'admin')) {
      return OfficialTag(name: 'Admin', icon: '👑', color: const Color(0xFFFF7A09), benefit: 'Platform Administrator');
    }
    // 6. Moderator
    if (rTags.any((r) => r.trim().toLowerCase() == 'moderator')) {
      return OfficialTag(name: 'Moderator', icon: '🛡️', color: const Color(0xFF10B981), benefit: 'Global room moderation power');
    }
    // 7. Party Guru
    if (rTags.any((r) => r.trim().toLowerCase() == 'party guru')) {
      return OfficialTag(name: 'Party Guru', icon: '🎉', color: const Color(0xFFFF4D8D), benefit: 'Arena celebration specialist');
    }
    // 8. Host
    if (rTags.any((r) => r.trim().toLowerCase() == 'host')) {
      return OfficialTag(name: 'Host', icon: '🎤', color: const Color(0xFF8B5CF6), benefit: 'Verified speaker/host for events');
    }
    // 9. Partner
    if (rTags.any((r) => r.trim().toLowerCase() == 'partner')) {
      return OfficialTag(name: 'Partner', icon: '🤝', color: const Color(0xFF06B6D4), benefit: 'Authorized enterprise partner');
    }
    // 10. Verified (if user is verified, show Verified)
    if (verification != null) {
      return OfficialTag(
        name: verification!.title,
        icon: verification!.icon,
        color: verification!.color,
        benefit: verification!.requirement,
      );
    }
    // 11. Tester
    if (rTags.any((r) => r.trim().toLowerCase() == 'tester')) {
      return OfficialTag(name: 'Tester', icon: '🧪', color: const Color(0xFF6B7280), benefit: 'Beta testing volunteer');
    }
    return null;
  }

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
            requirement: 'Purchase VIP status tier.',
            benefits: ['VIP profile badge styling', 'Premium avatar framing', 'Priority room seating features'],
            status: 'Active',
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
            title: 'Novel Level $novelLevel',
            description: 'Novel reader badge level.',
            color: const Color(0xFFEA580C),
            icon: '📖',
            requirement: 'Earn levels from novel reading.',
            benefits: ['Novel badge display', 'Special reading progress tracker animations'],
            status: 'Active',
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
          description: 'Creaniaa Career progression level.',
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

    // 5. Community Tag (Official Community Tags: Connect, Campus, ArenaX, Studio, Origin)
    if (communityTag != null) {
      final ct = communityTag!;
      final officialAsset = getOfficialCommunityTagAssetPath(ct.role) ??
          getOfficialCommunityTagAssetPath(ct.name);

      Widget tagContent;
      if (officialAsset != null) {
        tagContent = Image.asset(
          officialAsset,
          height: 19,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } else {
        tagContent = Container(
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
      }

      badgeWidgets.add(
        GestureDetector(
          onTap: () => showBadgeInfoDialog(
            context,
            title: '${ct.name} (${ct.role})',
            description: 'Official Community Identity Tag.',
            color: ct.gradientColors.first,
            icon: '🏷️',
            requirement: 'Official Community Member.',
            benefits: [
              'Premium Identity Tag displayed across platform',
              'Special community badge status',
              'Exclusive identity presentation',
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
            description: 'Creaniaa platform designation.',
            color: ot.color,
            icon: ot.icon,
            requirement: 'Manually verified and assigned by the Creaniaa platform administration.',
            benefits: [
              ot.benefit,
              'Exclusive priority verification status',
              'Creaniaa official crown decoration',
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

String? getOfficialCommunityTagAssetPath(String tagLabel) {
  return UserBadgeAssetRegistry.getCommunityTagAssetPath(tagLabel);
}

class PremiumIdentityController extends GetxController {
  final RxString currentVerification = 'Verified'.obs;
  final RxString currentOfficialTag = 'None'.obs;
  final RxString currentAchievementTag = '🔥 Top Contributor'.obs;
  final RxInt currentTrustScore = 100.obs;

  static PremiumIdentity getIdentity(
    String userId,
    String username, {
    int? vipLevel,
    int? novelLevel,
    int? idLevel,
    int? careerLevel,
    List<String>? badgesList,
  }) {
    dynamic u;
    try {
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      final resolvedId = (userId == 'me' || userId == 'uid_anurag_101' || userId == currentUid)
          ? (currentUid ?? userId)
          : userId;
      u = rxCacheGet(resolvedId);
    } catch (_) {}

    int vip = vipLevel ?? u?.vipLevel ?? 0;
    if (vipLevel == null && Get.isRegistered<VipController>()) {
      final vc = Get.find<VipController>();
      if (vc.vipLevel.value > vip) {
        vip = vc.vipLevel.value;
      }
    }

    int novel = novelLevel ?? u?.novelLevel ?? 0;
    if (novelLevel == null && Get.isRegistered<NovelController>()) {
      final nc = Get.find<NovelController>();
      if (nc.novelLevel.value > novel) {
        novel = nc.novelLevel.value;
      }
    }

    int idLvl = idLevel ?? u?.level ?? 1;
    int careerLvl = careerLevel ?? u?.careerLevel ?? 1;
    List<String> userBadges = badgesList ?? u?.badges ?? [];
    List<String> tagLights = u?.tagLights ?? [];
    List<String> rTags = u?.rTags ?? [];

    final now = DateTime.now();
    if (u != null) {
      if (u.vipExpiry != null && u.vipExpiry!.isBefore(now)) {
        vip = 0;
      }
      if (u.novelExpiry != null && u.novelExpiry!.isBefore(now)) {
        novel = 0;
      }
    }

    CommunityTag? commTag;
    String? activeCommTag;
    for (final tag in tagLights) {
      final clean = tag.trim();
      if (clean == 'Origin' || clean == 'Studio' || clean == 'ArenaX' || clean == 'Campus' || clean == 'Connect') {
        activeCommTag = clean;
        break;
      }
    }

    if (activeCommTag != null) {
      String commName = '';
      List<Color> colors = [Colors.grey, Colors.grey.shade600];
      bool isAnimated = false;
      
      if (activeCommTag == 'Origin') {
        commName = 'Creaniaa Official';
        colors = [const Color(0xFFFFD700), const Color(0xFFB45309)];
        isAnimated = true;
      } else if (activeCommTag == 'Studio') {
        commName = 'Creaniaa Creators';
        colors = [Colors.purple, Colors.purple.shade800];
      } else if (activeCommTag == 'ArenaX') {
        commName = 'Creaniaa Gamers';
        colors = [Colors.blue, Colors.blue.shade800];
      } else if (activeCommTag == 'Campus') {
        commName = 'Creaniaa Campus';
        colors = [const Color(0xFF10B981), const Color(0xFF047857)];
      } else if (activeCommTag == 'Connect') {
        commName = 'Creaniaa Connect';
        colors = [const Color(0xFF6366F1), const Color(0xFF4338CA)];
      }

      commTag = CommunityTag(
        name: commName,
        role: activeCommTag,
        level: idLvl,
        gradientColors: colors,
        isAnimated: isAnimated,
      );
    }

    UserVerification? verification;
    for (final b in userBadges) {
      final mappedVer = _mapVerification(b);
      if (mappedVer != null) {
        verification = mappedVer;
        break;
      }
    }

    OfficialTag? officialTag;
    final priorityRoles = [
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
    String? highestRTag;
    for (final role in priorityRoles) {
      if (rTags.any((rt) => rt.trim().toLowerCase() == role.toLowerCase())) {
        highestRTag = role;
        break;
      }
    }
    if (highestRTag != null) {
      officialTag = _mapOfficialTag(highestRTag);
    }

    String? achievementTag;
    for (final b in userBadges) {
      if (b.startsWith('🔥') || b.startsWith('🏆') || b.startsWith('⭐') || b.startsWith('💎') || b.startsWith('💡') || b.startsWith('🚀') || b.startsWith('👑') || b.startsWith('🏅') || b.contains('Top') || b.startsWith('🎯')) {
        achievementTag = b;
        break;
      }
    }

    int trust = u?.reputation ?? 100;

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

  static dynamic rxCacheGet(String key) {
    try {
      return Get.find<dynamic>(tag: key); 
    } catch (_) {
      try {
        final cacheMap = Get.find<Map<String, dynamic>>(tag: 'user_profile_cache');
        return cacheMap[key];
      } catch (_) {}
    }
    return null;
  }

  static UserVerification? _mapVerification(String key) {
    switch (key) {
      case 'Verified':
        return UserVerification(
          title: 'Verified',
          icon: '✔',
          color: const Color(0xFF2563EB),
          requirement: 'Identity Verification approved by Creaniaa Security Team.',
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
      case 'Creaniaa Official':
        return OfficialTag(name: 'Creaniaa Official', icon: '👑', color: const Color(0xFFFFD700), benefit: 'Highest trust, administrator privilege');
      case 'Creaniaa Employee':
        return OfficialTag(name: 'Creaniaa Employee', icon: '🛠️', color: const Color(0xFFEC4899), benefit: 'Official company employee');
      case 'Creaniaa Developer':
        return OfficialTag(name: 'Creaniaa Developer', icon: '💻', color: const Color(0xFF3B82F6), benefit: 'Creaniaa platform engineer');
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
      'Creaniaa Official',
      'Creaniaa Employee',
      'Creaniaa Developer',
      'Official Moderator',
      'Official Host',
      'Official Coin Seller',
      'Official Partner'
    ];
    return _mapOfficialTag(keys[index])!;
  }
}
