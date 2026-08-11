import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../models/user/user_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/index.dart';
import '../../../../utils/number_formatter.dart';
import '../../../../widgets/gifting/send_gift_dialog.dart';
import '../../../profile/profile_screen.dart';
import '../widgets/breathing_indicators.dart';
import 'mini_profile_sheets.dart';
import 'mini_profile_badges.dart';
import '../../../../widgets/memberships/vip_badge_widget.dart';
import '../../../../widgets/memberships/novel_badge_widget.dart';

class MiniProfileDialog extends StatefulWidget {
  final String roomId;
  final String callerUserId;
  final String targetUserId;
  final String targetUserName;
  final String role;
  final int seatIndex;
  final bool isHost;
  final int occupiedSeatsCount;
  final VoidCallback? onMoveToAudience;

  const MiniProfileDialog({
    Key? key,
    required this.roomId,
    required this.callerUserId,
    required this.targetUserId,
    required this.targetUserName,
    required this.role,
    required this.seatIndex,
    required this.isHost,
    required this.occupiedSeatsCount,
    this.onMoveToAudience,
  }) : super(key: key);

  @override
  State<MiniProfileDialog> createState() => _MiniProfileDialogState();
}

class _MiniProfileDialogState extends State<MiniProfileDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final RoomController _controller = RoomController.to;

  final RxDouble monthlyReceivedGifts = 0.0.obs;
  final RxDouble monthlyContribution = 0.0.obs;
  final RxDouble totalGiftsReceived = 0.0.obs;
  final RxInt contributorsCount = 0.obs;
  late final Worker _giftWorker;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _resolveProfile();

    _giftWorker = ever(UserProfileCacheManager.giftTransactionsTrigger, (_) {
      _resolveProfile();
    });
  }

  @override
  void dispose() {
    _giftWorker.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _resolveProfile() async {
    final targetId = widget.targetUserId;
    if (targetId.isEmpty) return;

    try {
      final u = await UserProfileCacheManager.fetchUserProfile(targetId,
          forceRefresh: true);

      final followerRes = await Supabase.instance.client
          .from('connections')
          .select('follower_id')
          .eq('following_id', targetId);
      final int actualFollowers = (followerRes as List).length;

      final followingRes = await Supabase.instance.client
          .from('connections')
          .select('following_id')
          .eq('follower_id', targetId);
      final int actualFollowing = (followingRes as List).length;

      final friendsRes = await Supabase.instance.client
          .from('connections')
          .select('follower_id')
          .eq('follower_id', targetId)
          .eq('status', 'friends');
      final int actualFriends = (friendsRes as List).length;

      double actualReceived = 0.0;
      double actualMonthlyReceived = 0.0;
      double actualMonthlySent = 0.0;
      int contributors = actualFollowers;

      try {
        final rpcStats = await Supabase.instance.client
            .rpc('get_user_gift_stats_v2', params: {'p_user_id': targetId});
        if (rpcStats != null && rpcStats is Map) {
          actualMonthlyReceived =
              (rpcStats['monthly_received'] as num?)?.toDouble() ?? 0.0;
          actualMonthlySent =
              (rpcStats['monthly_sent'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (_) {}

      try {
        final giftData = await Supabase.instance.client
            .from('gift_transactions')
            .select('stars_value, sender_id')
            .eq('receiver_id', targetId);
        if (giftData != null) {
          final Set<String> uniqueSenders = {};
          for (final item in giftData as List<dynamic>) {
            actualReceived += (item['stars_value'] as num?)?.toDouble() ?? 0.0;
            final sId = item['sender_id'] as String?;
            if (sId != null && sId.isNotEmpty) uniqueSenders.add(sId);
          }
          if (uniqueSenders.isNotEmpty) contributors = uniqueSenders.length;
        }
      } catch (_) {}

      monthlyReceivedGifts.value =
          actualMonthlyReceived > 0 ? actualMonthlyReceived : actualReceived;
      monthlyContribution.value = actualMonthlySent;
      totalGiftsReceived.value =
          actualReceived > 0 ? actualReceived : u.totalStarsReceived.toDouble();
      contributorsCount.value = contributors;

      final updatedUser = u.copyWith(
        followers: actualFollowers,
        following: actualFollowing,
        friendsCount: actualFriends,
        totalStarsReceived: actualReceived.toInt() > 0
            ? actualReceived.toInt()
            : u.totalStarsReceived,
      );

      UserProfileCacheManager.rxCache[targetId] = updatedUser;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[MiniProfileDialog] _resolveProfile error: $e');
    }
  }

  void _navigateToProfile(User? u) {
    Get.back();
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isMe = widget.targetUserId == widget.callerUserId ||
        (currentUid != null && widget.targetUserId == currentUid);
    if (isMe) {
      Get.to(() => const ProfileScreen());
    } else {
      final uName = u?.username ?? widget.targetUserName;
      final uAvatar = u?.avatar ?? _getUserDp(widget.targetUserId);
      Get.to(() => ProfileScreen(
          visitorUser: u ??
              User(
                id: widget.targetUserId,
                username: uName.toLowerCase().replaceAll(' ', '_'),
                email: '${widget.targetUserId}@example.com',
                displayName: uName,
                avatar: uAvatar,
                followers: 0,
                following: 0,
                isVerified: widget.role == 'Owner' || widget.role == 'Co-owner',
                isPremium: false,
                level: 1,
                interests: const [],
                communities: const [],
                reputation: 100,
                sid: widget.targetUserId.hashCode.abs().toString(),
              )));
    }
  }

  String _getUserDp(String userId) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (userId == 'uid_anurag_101' ||
        userId == 'me' ||
        (currentUid != null && userId == currentUid)) {
      final avatarUrl = UserProfileCacheManager.currentUser?.avatar;
      if (avatarUrl != null && avatarUrl.isNotEmpty) return avatarUrl;
    }
    final u = UserProfileCacheManager.getCachedUser(userId);
    if (u != null && u.avatar != null && u.avatar!.isNotEmpty) return u.avatar!;
    return '';
  }

  String _getNumericId(String userId) {
    final u = UserProfileCacheManager.getCachedUser(userId);
    if (u != null && u.sid.isNotEmpty) return u.sid;
    return (userId.hashCode.abs() % 900000 + 100000).toString();
  }

  String _formatStatValue(int value) {
    return formatCompactNumber(value);
  }

  Widget _buildLightStatCol({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: const Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLightGiftStatRow(String label, String value,
      {required Color valColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: const Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: valColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicRoleTag(String roomRole, String targetRole, User? user) {
    String? roleName;

    for (final r in [roomRole, targetRole]) {
      final l = r.trim().toLowerCase().replaceAll('-', '').replaceAll(' ', '');
      if (l == 'owner' || l == 'founder' || l == 'creator' || l == 'developer') {
        roleName = 'Owner';
        break;
      } else if (l == 'coowner') {
        roleName = 'Co-Owner';
        break;
      } else if (l == 'admin') {
        roleName = 'Admin';
        break;
      } else if (l == 'mod' || l == 'moderator' || l == 'host') {
        roleName = 'Mod';
        break;
      }
    }

    if (roleName == null && user?.rTags.isNotEmpty == true) {
      roleName = MiniProfileBadges.getHighestRTag(user!.rTags);
    }

    if (roleName == null || roleName.isEmpty) {
      return const SizedBox.shrink();
    }
    final lowerRole = roleName.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
    if (lowerRole == 'speaker' ||
        lowerRole == 'listener' ||
        lowerRole == 'audience' ||
        lowerRole == 'cohost' ||
        lowerRole == 'starmember' ||
        lowerRole == 'member' ||
        lowerRole == 'user') {
      return const SizedBox.shrink();
    }

    IconData iconData = Icons.shield_rounded;
    List<Color> gradientColors = [
      const Color(0xFF7C3AED),
      const Color(0xFF6D28D9),
    ];
    Color accentColor = const Color(0xFFA78BFA);

    if (lowerRole == 'owner' || lowerRole == 'founder' || lowerRole == 'creator') {
      iconData = Icons.workspace_premium_rounded;
      gradientColors = [
        const Color(0xFFD97706),
        const Color(0xFFB45309),
      ];
      accentColor = const Color(0xFFFBBF24);
    } else if (lowerRole == 'coowner') {
      iconData = Icons.shield_rounded;
      gradientColors = [
        const Color(0xFF7C3AED),
        const Color(0xFF6D28D9),
      ];
      accentColor = const Color(0xFFA78BFA);
    } else if (lowerRole == 'admin') {
      iconData = Icons.star_rounded;
      gradientColors = [
        const Color(0xFF2563EB),
        const Color(0xFF1D4ED8),
      ];
      accentColor = const Color(0xFF60A5FA);
    } else if (lowerRole == 'mod' || lowerRole == 'moderator' || lowerRole == 'host') {
      iconData = Icons.security_rounded;
      gradientColors = [
        const Color(0xFF059669),
        const Color(0xFF047857),
      ];
      accentColor = const Color(0xFF34D399);
    } else if (lowerRole == 'creator' || lowerRole == 'developer') {
      iconData = Icons.code_rounded;
      gradientColors = [
        const Color(0xFFEC4899),
        const Color(0xFFBE185D),
      ];
      accentColor = const Color(0xFFF472B6);
    }

    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accentColor.withOpacity(0.5), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData, color: accentColor, size: 11),
          const SizedBox(width: 4),
          Text(
            roleName,
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

  String getVTagLevel(User? user) {
    if (user == null) return 'blue';
    final name = user.displayName.toLowerCase();
    if (name.contains('president') ||
        name.contains('minister') ||
        user.rTags.contains('Founder')) {
      return 'diamond';
    } else if (user.tagLights.contains('STAR') ||
        user.tagLights.contains('TOP') ||
        name.contains('anurag')) {
      return 'gold';
    } else if (user.tagLights.contains('Official') ||
        user.rTags.contains('Official')) {
      return 'purple';
    }
    return 'blue';
  }

  List<Map<String, dynamic>> generateDynamicTagLights(
      User? user, int fallbackVip, int fallbackNovel, int fallbackLevel) {
    final List<Map<String, dynamic>> tags = [];

    // 1. Level Tag (Realtime from user.level)
    final int level = (user != null && user.level > 0)
        ? user.level
        : (fallbackLevel > 0 ? fallbackLevel : 1);
    tags.add({
      'label': 'Lv.$level',
      'color': const Color(0xFF3B82F6),
      'gradient': const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'icon': '⚡',
      'type': 'id_level',
    });

    // 2. Community Tag (Realtime from user.communities if user belongs to one)
    if (user != null && user.communities.isNotEmpty) {
      for (final comm in user.communities) {
        if (comm.trim().isNotEmpty) {
          tags.add({
            'label': comm.trim(),
            'color': const Color(0xFFEC4899),
            'gradient': const LinearGradient(
              colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            'icon': '❤️',
            'type': 'community',
          });
        }
      }
    }

    // 3. VIP Tag (ONLY if user.vipLevel > 0!)
    final int vip =
        (user != null && user.vipLevel > 0) ? user.vipLevel : fallbackVip;
    if (vip > 0) {
      tags.add({
        'label': 'VIP $vip',
        'color': const Color(0xFFEF4444),
        'gradient': const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        'icon': '⭐',
        'type': 'vip',
      });
    }

    // 4. Novel Tag (ONLY if user.novelLevel > 0!)
    final int novel =
        (user != null && user.novelLevel > 0) ? user.novelLevel : fallbackNovel;
    if (novel > 0) {
      tags.add({
        'label': 'Novel $novel',
        'color': const Color(0xFFD97706),
        'gradient': const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        'icon': '📖',
        'type': 'noble',
      });
    }

    // 5. Custom identity tags from user tag system (if defined)
    if (user != null && user.tagSystem != null) {
      for (var t in user.tagSystem!.identityTagBar) {
        final label = t.value;
        final type = t.type;
        final cleanL = label.toLowerCase();
        if (cleanL.startsWith('lv') ||
            cleanL.startsWith('vip') ||
            cleanL.startsWith('novel')) {
          continue;
        }

        Color color = const Color(0xFFBEC2FF);
        Gradient? gradient;

        if (type == 'community') {
          color = t.color != null
              ? Color(int.parse(t.color!.replaceAll('#', '0xFF')))
              : const Color(0xFFEC4899);
          gradient = const LinearGradient(
            colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } else if (type == 'special') {
          color = const Color(0xFF8B5CF6);
          gradient = const LinearGradient(
            colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        }

        tags.add({
          'label': label,
          'color': color,
          'gradient': gradient,
          'imageUrl': t.imageUrl,
          'customColor': t.color,
          'border': t.border,
          'glow': t.glow,
          'animation': t.animation,
          'effects': t.effects,
          'icon': t.icon ?? '🏷️',
          'type': type,
        });
      }
    }

    return tags;
  }

  String? getOfficialCommunityTagAssetPath(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('official') || lower.contains('admin')) {
      return 'assets/badges/official_badge.png';
    }
    return null;
  }

  Widget _buildTagTile(Map<String, dynamic> tag) {
    return const SizedBox.shrink();
  }

  List<Widget> buildTagLightsWidget(
      List<Map<String, dynamic>> tags, BuildContext context) {
    final List<Map<String, dynamic>> displayTags = [];
    bool hasOverflow = false;
    int overflowCount = 0;

    if (tags.length <= 6) {
      displayTags.addAll(tags);
    } else {
      displayTags.addAll(tags.take(5));
      hasOverflow = true;
      overflowCount = tags.length - 5;
    }

    final List<Widget> widgets = displayTags.map((tag) {
      final label = tag['label'] as String;
      final type = tag['type'] as String?;
      if (type == 'vip') {
        final level =
            int.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        return VipBadgeWidget(level: level, fontSize: 10);
      }
      if (type == 'noble') {
        final level =
            int.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        return NovelBadgeWidget(level: level, fontSize: 10);
      }

      final imageUrl = tag['imageUrl'] as String?;
      final String? iconStr = tag['icon'] as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        Widget imgWidget;
        if (imageUrl.startsWith('asset://')) {
          imgWidget = Image.asset(
            imageUrl.replaceAll('asset://', ''),
            height: 19,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                MiniProfileBadges.buildTextTagFallback(label, tag),
          );
        } else {
          imgWidget = OptimizedImage(
            imageUrl: imageUrl,
            height: 19,
            preset: MediaSizePreset.xs,
            fit: BoxFit.contain,
            errorWidget: MiniProfileBadges.buildTextTagFallback(label, tag),
          );
        }
        return Tooltip(
          message: 'Identity Tag: $label',
          child: imgWidget,
        );
      }

      final color = tag['color'] as Color? ?? const Color(0xFF3B82F6);
      final gradient = tag['gradient'] as Gradient?;

      Color borderCol = color.withOpacity(0.5);
      Color textCol = Colors.white;

      return Container(
        height: 19,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: gradient,
          color: gradient == null ? color.withOpacity(0.2) : null,
          border: Border.all(color: borderCol, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (iconStr != null && iconStr.isNotEmpty) ...[
              Text(iconStr, style: const TextStyle(fontSize: 9.5)),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                color: textCol,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }).toList();

    if (hasOverflow) {
      widgets.add(
        Container(
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 0.8),
          ),
          child: Center(
            child: Text(
              '+$overflowCount',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final numericId = _getNumericId(widget.targetUserId);
    final avatarUrl = _getUserDp(widget.targetUserId);
    final room = _controller.rooms.firstWhere((r) => r.id == widget.roomId);

    final String currentUid =
        Supabase.instance.client.auth.currentUser?.id ?? widget.callerUserId;
    final String actualCallerId =
        (currentUid.isNotEmpty) ? currentUid : widget.callerUserId;

    final String callerRole = _controller.getUserRole(room, actualCallerId);
    final String targetRole = _controller.getUserRole(room, widget.targetUserId);

    final int callerWeight =
        _controller.permissionCtrl.getRoleWeight(callerRole);
    int targetWeight =
        _controller.permissionCtrl.getRoleWeight(targetRole);

    if (widget.role.isNotEmpty) {
      final widgetRoleWeight =
          _controller.permissionCtrl.getRoleWeight(widget.role);
      if (widgetRoleWeight > targetWeight) {
        targetWeight = widgetRoleWeight;
      }
    }

    final bool isMe = widget.targetUserId == actualCallerId;

    bool showThreeDotMenu = false;
    if (!isMe) {
      showThreeDotMenu = callerWeight > targetWeight;
    }

    return Obx(() {
      final _ = UserProfileCacheManager.rxCache.length;
      final u = UserProfileCacheManager.rxCache[widget.targetUserId] ??
          UserProfileCacheManager.getCachedUser(widget.targetUserId);
      final String uName = u?.username ?? widget.targetUserName;
      final String uAvatar = u?.avatar ?? avatarUrl;
      final int uLevel = u?.level ?? 25;
      final int vipLevel = u?.vipLevel ?? 0;
      final int novelLevel = u?.novelLevel ?? 0;

      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: 330,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFF3F4F6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Bar (Bookmark/Flag and Three Dot Menu in Light Circles)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.bookmark_border_rounded,
                                color: Color(0xFF111827), size: 18),
                            onPressed: () =>
                                MiniProfileSheets.showReportUserSheet(
                                    context, uName),
                          ),
                        ),
                        if (showThreeDotMenu)
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_horiz_rounded,
                                  color: Color(0xFF111827), size: 18),
                              onPressed: () =>
                                  MiniProfileSheets.showThreeDotMenuSheet(
                                context: context,
                                roomId: widget.roomId,
                                callerUserId: widget.callerUserId,
                                targetUserId: widget.targetUserId,
                                controller: _controller,
                                onStateChanged: () => setState(() {}),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 36, height: 36),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 1. Centered Avatar Stack
                    GestureDetector(
                      onTap: () => _navigateToProfile(u),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            CustomAvatarFrame(
                              userId: widget.targetUserId,
                              username: uName,
                              size: (vipLevel > 0 ||
                                      novelLevel > 0 ||
                                      (u?.avatarFrame != null &&
                                          u!.avatarFrame!.isNotEmpty &&
                                          u.avatarFrame != 'none' &&
                                          u.avatarFrame != 'normal'))
                                  ? 112
                                  : 96,
                              defaultVipLevel: vipLevel,
                              defaultNovelLevel: novelLevel,
                              child: CircleAvatar(
                                radius: 48,
                                backgroundImage: uAvatar.isNotEmpty
                                    ? OptimizedImage.getOptimizedImageProvider(
                                        uAvatar,
                                        preset: MediaSizePreset.md,
                                      )
                                    : null,
                                child: uAvatar.isEmpty
                                    ? const Icon(Icons.person,
                                        size: 36, color: Colors.black38)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2. Username (Clickable to open profile)
                    GestureDetector(
                      onTap: () => _navigateToProfile(u),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              uName,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF111827),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              u?.gender == 'female'
                                  ? Icons.female_rounded
                                  : Icons.male_rounded,
                              color: u?.gender == 'female'
                                  ? const Color(0xFFEC4899)
                                  : const Color(0xFF3B82F6),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 3. ROLE TAG (Placed RIGHT BELOW Username, BEFORE ID Pill)
                    MiniProfileBadges.buildSingleRoleTag(
                        widget.role, targetRole, u),
                    if (widget.role.isNotEmpty ||
                        (targetRole != null && targetRole.isNotEmpty) ||
                        (u?.rTags.isNotEmpty == true))
                      const SizedBox(height: 6),

                    // 4. User ID (ID Pill)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: numericId));
                        Get.snackbar('Copied', 'ID copied to clipboard.');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFE5E7EB), width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ID: $numericId',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.content_copy_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 5. IDENTITY TAGS ROW (Right below ID Pill - horizontal side-by-side row: Level, VIP, Novel, Community)
                    Builder(
                      builder: (context) {
                        final identityTags =
                            MiniProfileBadges.buildIdentityTagWidgets(u);
                        final officialBadges =
                            MiniProfileBadges.buildOfficialStatusBadges(u);
                        final allTags = [...officialBadges, ...identityTags];
                        if (allTags.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 6,
                              children: allTags,
                            ),
                          ),
                        );
                      },
                    ),

                    // 6. Stats Card Container (Followers, Following, Friends, Gifts - REAL DATA)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildLightStatCol(
                              icon: Icons.groups_rounded,
                              iconColor: const Color(0xFFA855F7),
                              value: _formatStatValue(u?.followers ?? 0),
                              label: 'Followers',
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 32,
                              color: const Color(0xFFF3F4F6)),
                          Expanded(
                            child: _buildLightStatCol(
                              icon: Icons.person_add_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              value: _formatStatValue(u?.following ?? 0),
                              label: 'Following',
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 32,
                              color: const Color(0xFFF3F4F6)),
                          Expanded(
                            child: _buildLightStatCol(
                              icon: Icons.people_alt_rounded,
                              iconColor: const Color(0xFF10B981),
                              value: _formatStatValue(isMe
                                  ? (u?.friendsCount ?? 0)
                                  : (u?.friendsCount ?? 0)),
                              label: 'Friends',
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 32,
                              color: const Color(0xFFF3F4F6)),
                          Expanded(
                            child: _buildLightStatCol(
                              icon: Icons.card_giftcard_rounded,
                              iconColor: const Color(0xFFEC4899),
                              value: _formatStatValue(
                                  totalGiftsReceived.value.toInt() > 0
                                      ? totalGiftsReceived.value.toInt()
                                      : (u?.totalStarsReceived ?? 0)),
                              label: 'Gifts',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 7. Gift Stats Card Section (REAL DATA)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.card_giftcard_rounded,
                                  color: Color(0xFFF59E0B), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Gift Stats',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF111827),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildLightGiftStatRow(
                            'Monthly received gifts',
                            _formatStatValue(
                                monthlyReceivedGifts.value.toInt() > 0
                                    ? monthlyReceivedGifts.value.toInt()
                                    : (u?.totalStarsReceived ?? 0)),
                            valColor: const Color(0xFFF97316),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: Color(0xFFF3F4F6), height: 1),
                          ),
                          _buildLightGiftStatRow(
                            'Monthly contribute',
                            _formatStatValue(
                                monthlyContribution.value.toInt() > 0
                                    ? monthlyContribution.value.toInt()
                                    : (u?.totalStarsGifted ?? 0)),
                            valColor: const Color(0xFF111827),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: Color(0xFFF3F4F6), height: 1),
                          ),
                          _buildLightGiftStatRow(
                            'Gifts',
                            _formatStatValue(
                                totalGiftsReceived.value.toInt() > 0
                                    ? totalGiftsReceived.value.toInt()
                                    : (u?.totalStarsReceived ?? 0)),
                            valColor: const Color(0xFF8B5CF6),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: Color(0xFFF3F4F6), height: 1),
                          ),
                          _buildLightGiftStatRow(
                            'Contributors',
                            _formatStatValue(contributorsCount.value > 0
                                ? contributorsCount.value
                                : (u?.followers ?? 0)),
                            valColor: const Color(0xFF111827),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 8. Bottom Action Buttons Row (Sequence: 1. Message, 2. Gift, 3. Mention [LAST])
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _navigateToProfile(u),
                            icon: const Icon(Icons.chat_bubble_outline_rounded,
                                color: Colors.white, size: 16),
                            label: Text(
                              'Message',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFBBF24),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Get.back();
                              Get.dialog(
                                SendGiftDialog(
                                  roomId: widget.roomId,
                                  occupiedSeatsCount: widget.occupiedSeatsCount,
                                  targetUserId: widget.targetUserId,
                                  targetUserName: uName,
                                ),
                              );
                            },
                            icon: const Icon(Icons.card_giftcard_rounded,
                                color: Colors.white, size: 16),
                            label: Text(
                              'Gift',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC084FC),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Get.back();
                              if (Get.isRegistered<RoomController>()) {
                                RoomController.to.mentionUserInRoomChat(uName);
                              }
                            },
                            icon: const Icon(Icons.alternate_email_rounded,
                                color: Colors.white, size: 16),
                            label: Text(
                              'Mention',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
