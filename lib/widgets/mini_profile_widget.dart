import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/user_model.dart';
import '../screens/profile/user_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/user_profile_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../services/vip_controller.dart';
import 'vip_badge_widget.dart';
import 'vip_avatar_decorator.dart';
import '../services/novel_controller.dart';
import 'novel_badge_widget.dart';
import 'novel_avatar_decorator.dart';
import '../services/customization_controller.dart';
import '../services/premium_identity_controller.dart';
import 'custom_avatar_frame.dart';
import 'index.dart';

enum MiniProfileVariant {
  inRoom,
  followersList,
  searchResult,
  chatMessage,
}

class MiniProfileWidget extends StatefulWidget {
  final User user;
  final MiniProfileVariant variant;
  final bool isOnline;
  final bool isMuted;
  final bool isSpeaking;
  final bool isFollowing;
  final VoidCallback? onFollowTap;
  final VoidCallback? onMessageTap;
  final VoidCallback? onTap;

  const MiniProfileWidget({
    Key? key,
    required this.user,
    this.variant = MiniProfileVariant.inRoom,
    this.isOnline = true,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isFollowing = false,
    this.onFollowTap,
    this.onMessageTap,
    this.onTap,
  }) : super(key: key);

  @override
  State<MiniProfileWidget> createState() => _MiniProfileWidgetState();
}

class _MiniProfileWidgetState extends State<MiniProfileWidget> {
  late bool _isFollowing;

  User get _user => UserProfileCacheManager.rxCache[widget.user.id] ?? widget.user;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  void _navigateToProfile() {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isMe = _user.id == 'me' || _user.id == 'uid_anurag_101' || (currentUid != null && _user.id == currentUid);
    if (isMe) {
      Get.to(() => const ProfileScreen());
    } else {
      Get.to(() => UserProfileScreen(user: _user));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Trigger reactivity on changes to this user in the cache
      final u = UserProfileCacheManager.rxCache[widget.user.id] ?? widget.user;

      return GestureDetector(
        onTap: widget.onTap ?? _navigateToProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // DP with avatar border and online status
              _buildAvatar(),
              const SizedBox(width: 12),

              // Middle Section: Name, Verified, Tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNameRow(),
                    const SizedBox(height: 2),
                    _buildStatsRow(),
                    const SizedBox(height: 4),
                    _buildTagRow(),
                  ],
                ),
              ),

              // Right Action / Info Section based on variant
              _buildRightAction(),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAvatar() {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final u = _user;
    final isMe = u.id == 'me' || u.id == 'uid_anurag_101' || (currentUid != null && u.id == currentUid) || u.username == 'Anurag Kumar' || u.displayName == 'Anurag Kumar';

    int novelLevel = 0;
    int activeNovel = 0;
    int vipLevel = 0;

    if (!isMe) {
      if (u.isPremium) {
        if (u.reputation > 6000) {
          novelLevel = 7;
          activeNovel = 7;
        } else if (u.reputation > 4000) {
          novelLevel = 5;
          activeNovel = 5;
        } else if (u.reputation > 2500) {
          novelLevel = 3;
          activeNovel = 3;
        } else if (u.reputation > 1500) {
          novelLevel = 1;
          activeNovel = 1;
        }

        if (u.reputation > 5000) {
          vipLevel = 7;
        } else if (u.reputation > 3000) {
          vipLevel = 5;
        } else if (u.reputation > 1000) {
          vipLevel = 3;
        } else {
          vipLevel = 2;
        }
      }
    }

    final custCtrl = Get.find<CustomizationController>();
    final avatarUrl = isMe 
        ? custCtrl.getAvatarUrl(custCtrl.activeAvatar.value, u.avatar ?? '')
        : (u.avatar ?? '');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomAvatarFrame(
          userId: u.id,
          username: u.username,
          size: 44,
          defaultNovelLevel: activeNovel,
          defaultVipLevel: vipLevel,
          child: SizedBox(
            width: 44,
            height: 44,
            child: avatarUrl.isNotEmpty
                ? (avatarUrl.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: AppTheme.bgLight),
                        errorWidget: (context, url, error) => _buildInitials(),
                      )
                    : Image.file(
                        File(avatarUrl),
                        fit: BoxFit.cover,
                      ))
                : _buildInitials(),
          ),
        ),
        if (widget.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F172A), width: 1.8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials() {
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.2),
      child: Center(
        child: Text(
          _user.displayName.substring(0, 1).toUpperCase(),
          style: GoogleFonts.poppins(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildVipNameText(String text, int vipLevel) {
    final style = GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    if (vipLevel <= 0) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    switch (vipLevel) {
      case 1:
        return Text(text, style: style.copyWith(color: const Color(0xFF2563EB)), maxLines: 1, overflow: TextOverflow.ellipsis);
      case 2:
        return Text(text, style: style.copyWith(color: const Color(0xFF8B5CF6)), maxLines: 1, overflow: TextOverflow.ellipsis);
      case 3:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFD97706)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      case 4:
        return Text(text, style: style.copyWith(color: const Color(0xFFF1F5F9), shadows: [
          const Shadow(color: Colors.white30, blurRadius: 4),
        ]), maxLines: 1, overflow: TextOverflow.ellipsis);
      case 5:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF22D3EE)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      case 6:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF007F), Color(0xFFFFBF00), Color(0xFF00F0FF)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      case 7:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFF1C1917), Color(0xFFFFD700)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white, shadows: [
            const Shadow(color: Color(0xFFD4AF37), blurRadius: 4),
          ]), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      default:
        return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
  }

  Widget _buildNovelNameText(String text, int novelLvl) {
    final style = GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    switch (novelLvl) {
      case 1:
        return Text(text, style: style.copyWith(color: const Color(0xFF2563EB)), maxLines: 1, overflow: TextOverflow.ellipsis);
      case 2:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFC084FC)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      case 3:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFD97706)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      case 4:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white, shadows: [
            const Shadow(color: Colors.redAccent, blurRadius: 4),
          ]), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      case 5:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFFDBA74)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      case 6:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF22D3EE), Colors.white],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white, shadows: [
            const Shadow(color: Colors.cyanAccent, blurRadius: 6),
          ]), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      case 7:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFF1C1917), Color(0xFFFFD700)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white, shadows: [
            const Shadow(color: Color(0xFFFFD700), blurRadius: 8),
          ]), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      default:
        return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
  }

  Widget _buildNameRow() {
    int novelLevel = 0;
    int activeNovel = 0;
    final u = _user;

    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (u.id == 'me' || u.id == 'uid_anurag_101' || (currentUid != null && u.id == currentUid)) {
      final novelCtrl = Get.find<NovelController>();
      novelLevel = novelCtrl.novelLevel.value;
      activeNovel = novelCtrl.activeNovelStyle.value;
    } else if (u.isPremium) {
      if (u.reputation > 6000) {
        novelLevel = 7;
        activeNovel = 7;
      } else if (u.reputation > 4000) {
        novelLevel = 5;
        activeNovel = 5;
      } else if (u.reputation > 2500) {
        novelLevel = 3;
        activeNovel = 3;
      } else if (u.reputation > 1500) {
        novelLevel = 1;
        activeNovel = 1;
      }
    }

    int vipLevel = 0;
    if (novelLevel <= 0) {
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      if (u.id == 'me' || u.id == 'uid_anurag_101' || (currentUid != null && u.id == currentUid)) {
        final vipCtrl = Get.find<VipController>();
        vipLevel = vipCtrl.vipLevel.value;
      } else if (u.isPremium) {
        if (u.reputation > 5000) {
          vipLevel = 7;
        } else if (u.reputation > 3000) {
          vipLevel = 5;
        } else if (u.reputation > 1000) {
          vipLevel = 3;
        } else {
          vipLevel = 2;
        }
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: PremiumNameWidget(
            name: u.displayName,
            userId: u.id,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          u.id.hashCode % 2 == 0 ? '♂' : '♀',
          style: TextStyle(
            color: u.id.hashCode % 2 == 0 ? const Color(0xFF38BDF8) : const Color(0xFFF43F5E),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTagRow() {
    final identity = PremiumIdentityController.getIdentity(_user.id, _user.displayName);
    return _buildBadgesRowForVariant(identity);
  }

  Widget _tagItem({
    required String label,
    required String icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightAction() {
    switch (widget.variant) {
      case MiniProfileVariant.inRoom:
        // Speaking sound waves / Mic Status
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isSpeaking)
              _buildSpeakingWaves()
            else if (widget.isMuted)
              const Icon(Icons.mic_off_rounded, color: AppTheme.errorColor, size: 16)
            else
              const Icon(Icons.mic_none_rounded, color: AppTheme.textTertiary, size: 16),
          ],
        );

      case MiniProfileVariant.followersList:
        // stylized + Follow button
        return SizedBox(
          height: 28,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _isFollowing = !_isFollowing;
              });
              if (widget.onFollowTap != null) widget.onFollowTap!();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFollowing ? AppTheme.bgLight : const Color(0xFFEF408B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: _isFollowing ? const BorderSide(color: AppTheme.borderColor) : BorderSide.none,
              ),
              elevation: 0,
            ),
            child: Text(
              _isFollowing ? 'Following' : '+ Follow',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

      case MiniProfileVariant.searchResult:
        // Arrow to visit
        return const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppTheme.textTertiary,
          size: 14,
        );

      case MiniProfileVariant.chatMessage:
        // Simple timestamp or none
        return Text(
          'Online',
          style: GoogleFonts.poppins(
            color: const Color(0xFF22C55E),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        );
    }
  }

  Widget _buildSpeakingWaves() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 2.5,
          height: 12.0 + (i % 2 == 0 ? 4 : -4),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _buildStatsRow() {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isMe = widget.user.id == 'me' || widget.user.id == 'uid_anurag_101' || (currentUid != null && widget.user.id == currentUid);
    final gifts = isMe ? '65.6K' : '14.2K';
    final points = isMe ? '9.2K' : '4.5K';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFC107), size: 12),
        const SizedBox(width: 3),
        Text(
          'Gifts: $gifts',
          style: GoogleFonts.poppins(color: const Color(0xFFFFC107), fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.bolt, color: Color(0xFFD946EF), size: 12),
        const SizedBox(width: 1),
        Text(
          'Contributed: $points',
          style: GoogleFonts.poppins(color: const Color(0xFFD946EF), fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBadgesRowForVariant(PremiumIdentity identity) {
    final List<Widget> list = [];
    final double fs = 8.0;

    final bool showVip = identity.vipLevel > 0;
    final bool showNovel = identity.novelLevel > 0;
    final bool showId = true;
    final bool showCareer = true;
    final bool showComm = identity.communityTag != null;
    final bool showVerif = identity.verification != null;
    final bool showOfficial = identity.officialTag != null;

    switch (widget.variant) {
      case MiniProfileVariant.followersList:
      case MiniProfileVariant.searchResult:
        if (showVip) list.add(_vipBadge(identity.vipLevel, fs));
        if (showNovel) list.add(_novelBadge(identity.novelLevel, fs));
        if (showVerif) list.add(_verifBadge(identity.verification!, fs));
        if (showComm) list.add(_commBadge(identity.communityTag!, fs));
        break;

      case MiniProfileVariant.chatMessage:
        if (showVip) list.add(_vipBadge(identity.vipLevel, fs));
        if (showNovel) list.add(_novelBadge(identity.novelLevel, fs));
        if (showVerif) list.add(_verifBadge(identity.verification!, fs));
        if (showOfficial) list.add(_officialBadge(identity.officialTag!, fs));
        if (showComm) list.add(_commBadge(identity.communityTag!, fs));
        if (showId) list.add(_idBadge(identity.idLevel, fs));
        if (showCareer) list.add(_careerBadge(identity.careerLevel, fs));
        break;

      case MiniProfileVariant.inRoom:
      default:
        if (showVip) list.add(_vipBadge(identity.vipLevel, fs));
        if (showNovel) list.add(_novelBadge(identity.novelLevel, fs));
        if (showId) list.add(_idBadge(identity.idLevel, fs));
        if (showCareer) list.add(_careerBadge(identity.careerLevel, fs));
        if (showComm) list.add(_commBadge(identity.communityTag!, fs));
        if (showVerif) list.add(_verifBadge(identity.verification!, fs));
        if (showOfficial) list.add(_officialBadge(identity.officialTag!, fs));
        break;
    }

    final limited = list.length > 8 ? list.sublist(0, 8) : list;

    return Wrap(
      spacing: 3,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: limited,
    );
  }

  Widget _vipBadge(int lvl, double fs) {
    return GestureDetector(
      onTap: () => _showBadgeInfo('👑 VIP Level $lvl', 'Premium VIP status.', const Color(0xFFFFD700), '👑', 'VIP level sub', ['rotating name borders']),
      child: VipBadgeWidget(level: lvl, fontSize: fs),
    );
  }
  Widget _novelBadge(int lvl, double fs) {
    return GestureDetector(
      onTap: () => _showBadgeInfo('📖 Novel Level $lvl', 'Collectible status.', const Color(0xFFEA580C), '📖', 'Novel Level', ['Wings animations']),
      child: NovelBadgeWidget(level: lvl, fontSize: fs),
    );
  }
  Widget _idBadge(int lvl, double fs) {
    return GestureDetector(
      onTap: () => _showBadgeInfo('🆔 ID Level $lvl', 'Global progress.', const Color(0xFF38BDF8), '🆔', 'Earn XP', ['Unlocks cosmetics']),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7).withOpacity(0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.5), width: 0.5),
        ),
        child: Text('Lvl $lvl', style: GoogleFonts.poppins(color: const Color(0xFF38BDF8), fontSize: fs - 1, fontWeight: FontWeight.bold)),
      ),
    );
  }
  Widget _careerBadge(int lvl, double fs) {
    return GestureDetector(
      onTap: () => _showBadgeInfo('💻 Career Level $lvl', 'Career Track level.', const Color(0xFFFFB800), '💻', 'Complete career tasks', ['Official job titles']),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFD97706).withOpacity(0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFFD97706).withOpacity(0.5), width: 0.5),
        ),
        child: Text('Career $lvl', style: GoogleFonts.poppins(color: const Color(0xFFFBBF24), fontSize: fs - 1, fontWeight: FontWeight.bold)),
      ),
    );
  }
  Widget _commBadge(CommunityTag ct, double fs) {
    return GestureDetector(
      onTap: () => _showBadgeInfo('${ct.name} (${ct.role})', 'Community Rank.', ct.gradientColors.first, '🏷️', 'Assigned role', ['Special guild powers']),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: ct.gradientColors.first.withOpacity(0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: ct.gradientColors.first.withOpacity(0.5), width: 0.5),
        ),
        child: Text(ct.role, style: GoogleFonts.poppins(color: ct.gradientColors.first, fontSize: fs - 1, fontWeight: FontWeight.bold)),
      ),
    );
  }
  Widget _verifBadge(UserVerification v, double fs) {
    return GestureDetector(
      onTap: () => _showBadgeInfo(v.title, 'Verified status.', v.color, v.icon, v.requirement, v.benefits, date: v.date, status: v.status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: v.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: v.color.withOpacity(0.6), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(v.icon, style: TextStyle(color: v.color, fontSize: fs - 2)),
            const SizedBox(width: 2),
            Text(v.title.split(' ')[0], style: GoogleFonts.poppins(color: v.color, fontSize: fs - 1, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
  Widget _officialBadge(OfficialTag ot, double fs) {
    return GestureDetector(
      onTap: () => _showBadgeInfo(ot.name, 'Official tag.', ot.color, ot.icon, 'Admin assign only', [ot.benefit]),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: ot.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: ot.color.withOpacity(0.6), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ot.icon, style: TextStyle(color: ot.color, fontSize: fs - 2)),
            const SizedBox(width: 2),
            Text(ot.name.split(' ').last, style: GoogleFonts.poppins(color: ot.color, fontSize: fs - 1, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showBadgeInfo(String title, String desc, Color color, String icon, String req, List<String> benefits, {String? date, String? status}) {
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
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
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
              Text('DATE', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
              Text(date, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
            ],
            Text('REQUIREMENT', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
            Text(req, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            Text('BENEFITS & PERKS', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
            ...benefits.map((b) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text('• ', style: TextStyle(color: color)),
                  Expanded(child: Text(b, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
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
}
