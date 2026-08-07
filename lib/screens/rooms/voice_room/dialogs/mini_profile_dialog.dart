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
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _resolveProfile() {
    UserProfileCacheManager.fetchUserProfile(widget.targetUserId).then((u) {
      if (mounted) {
        setState(() {});
      }
    });
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

    if (userId == 'uid_anurag_101') {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    } else if (userId == 'user_co_1' || userId.contains('priya')) {
      return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150';
    } else if (userId == 'user_adm_1' || userId.contains('vikram')) {
      return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150';
    } else if (userId == 'user_perf_1' || userId.contains('rahul')) {
      return 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150';
    } else if (userId == 'user_star_1' || userId.contains('siddharth')) {
      return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150';
    } else {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    }
  }

  String _getNumericId(String userId) {
    return (userId.hashCode.abs() % 90000000 + 10000000).toString();
  }

  String _formatStatValue(int value) {
    return formatCompactNumber(value);
  }

  Widget _buildOverlappingAvatarsDialog(List<String> imageUrls) {
    return SizedBox(
      height: 16,
      width: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(imageUrls.length, (index) {
          return Positioned(
            left: index * 8.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 0.8),
              ),
              child: CircleAvatar(
                radius: 6,
                backgroundImage: NetworkImage(imageUrls[index]),
              ),
            ),
          );
        }),
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
    if (user == null || user.tagSystem == null) {
      return tags;
    }

    for (var t in user.tagSystem!.identityTagBar) {
      final label = t.value;
      final type = t.type;
      Color color = const Color(0xFFBEC2FF);
      Gradient? gradient;

      if (type == 'id_level') {
        color = const Color(0xFF3B82F6);
        gradient = const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else if (type == 'community') {
        color = t.color != null
            ? Color(int.parse(t.color!.replaceAll('#', '0xFF')))
            : const Color(0xFFEC4899);
        if (t.color == null) {
          gradient = const LinearGradient(
            colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        }
      } else if (type == 'vip') {
        color = const Color(0xFF3B82F6);
        gradient = const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else if (type == 'noble') {
        color = const Color(0xFFD97706);
        gradient = const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
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
        'icon': t.icon,
        'type': type,
      });
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
      final imageUrl = tag['imageUrl'] as String?;
      final type = tag['type'] as String?;

      String? localAsset;
      final String cleanLabel = label.trim().toLowerCase();
      final String cleanUrl = (imageUrl ?? '').trim().toLowerCase();
      final String cleanType = (type ?? '').trim().toLowerCase();

      if (cleanUrl.contains('vip') ||
          cleanUrl.contains('id_level') ||
          cleanType.contains('vip') ||
          cleanType.contains('id_level') ||
          cleanLabel.startsWith('vip') ||
          cleanLabel.startsWith('v1') ||
          cleanLabel.startsWith('v2') ||
          cleanLabel.startsWith('l1') ||
          cleanLabel.startsWith('l2') ||
          cleanLabel.startsWith('lv')) {
        return const SizedBox.shrink();
      }

      final String? officialCommAsset =
          getOfficialCommunityTagAssetPath(cleanLabel) ??
              getOfficialCommunityTagAssetPath(cleanUrl) ??
              getOfficialCommunityTagAssetPath(cleanType);
      if (officialCommAsset != null) {
        localAsset = officialCommAsset;
      }

      if (localAsset != null) {
        return Tooltip(
          message: 'Identity Tag: $label',
          child: Image.asset(
            localAsset,
            height: 19,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => MiniProfileBadges.buildTextTagFallback(label, tag),
          ),
        );
      }

      if (imageUrl != null && imageUrl.isNotEmpty) {
        Widget imgWidget;
        if (imageUrl.startsWith('asset://')) {
          imgWidget = Image.asset(
            imageUrl.replaceAll('asset://', ''),
            height: 22,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => MiniProfileBadges.buildTextTagFallback(label, tag),
          );
        } else {
          imgWidget = Image.network(
            imageUrl,
            height: 22,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => MiniProfileBadges.buildTextTagFallback(label, tag),
          );
        }
        return Tooltip(
          message: 'Identity Tag: $label',
          child: imgWidget,
        );
      }

      final color = tag['color'] as Color;
      final gradient = tag['gradient'] as Gradient?;
      final String? glow = tag['glow'] as String?;
      final String? borderType = tag['border'] as String?;
      final String? animation = tag['animation'] as String?;
      final String? icon = tag['icon'] as String?;

      Color bg = color.withOpacity(0.12);
      Color borderCol = color.withOpacity(0.4);
      Color textCol = color;

      if (gradient != null) {
        borderCol = color;
        textCol = Colors.white;
      }

      List<BoxShadow> shadows = [
        BoxShadow(
          color: borderCol.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 1),
        )
      ];

      if (glow == 'gold') {
        shadows.add(BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: 1));
      } else if (glow == 'silver') {
        shadows.add(BoxShadow(
            color: const Color(0xFFE2E8F0).withOpacity(0.4),
            blurRadius: 5,
            spreadRadius: 1));
      } else if (glow == 'neon') {
        shadows.add(BoxShadow(
            color: const Color(0xFF818CF8).withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 1.5));
      }

      BoxBorder borderStyle = Border.all(color: borderCol, width: 1.0);
      if (borderType == 'gold_glow') {
        borderStyle = Border.all(color: const Color(0xFFF59E0B), width: 1.2);
      } else if (borderType == 'silver_glow') {
        borderStyle = Border.all(color: const Color(0xFFE2E8F0), width: 1.0);
      } else if (borderType == 'rainbow_neon') {
        borderStyle = Border.all(color: const Color(0xFF818CF8), width: 1.5);
      }

      Widget tagContent = Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: gradient,
          color: gradient == null ? bg : null,
          border: borderStyle,
          boxShadow: shadows,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Text(icon, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: textCol,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );

      if (animation == 'breathing') {
        tagContent = BreathingWidget(child: tagContent);
      } else if (animation == 'rotating') {
        tagContent = PulseWidget(child: tagContent);
      }

      return Tooltip(
        message: 'Identity Tag: $label',
        child: GestureDetector(
          onTap: () {
            Get.snackbar('Tag Info', 'Details page for $label tag.');
          },
          child: tagContent,
        ),
      );
    }).toList();

    if (hasOverflow) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(4),
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 0.8),
          ),
          child: Text(
            '+$overflowCount',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.bold,
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

    final callerRole = _controller.getUserRole(room, widget.callerUserId);
    final targetRole = _controller.getUserRole(room, widget.targetUserId);
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isMe = widget.targetUserId == widget.callerUserId ||
        (currentUid != null && widget.targetUserId == currentUid);

    bool showThreeDotMenu = false;
    if (widget.callerUserId != widget.targetUserId) {
      if (callerRole == 'Owner') {
        showThreeDotMenu = true;
      } else if (callerRole == 'Co-owner') {
        if (targetRole != 'Owner' &&
            targetRole != 'Co-owner' &&
            targetRole != 'Admin') {
          showThreeDotMenu = true;
        }
      } else if (callerRole == 'Admin') {
        if (targetRole != 'Owner' &&
            targetRole != 'Co-owner' &&
            targetRole != 'Admin') {
          showThreeDotMenu = true;
        }
      }
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
      final bool isVIP = vipLevel > 0 ||
          widget.targetUserId == 'uid_anurag_101' ||
          widget.role == 'Owner' ||
          widget.role == 'Co-owner';

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
                width: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E1C2E).withOpacity(0.85),
                      const Color(0xFF0F0E17).withOpacity(0.95),
                    ],
                  ),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Bar (Bookmark/Flag and Three Dot Menu)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bookmark_border_rounded,
                              color: Colors.white70),
                          onPressed: () => MiniProfileSheets.showReportUserSheet(context, uName),
                        ),
                        if (showThreeDotMenu)
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded,
                                color: Colors.white70),
                            onPressed: () => MiniProfileSheets.showThreeDotMenuSheet(
                              context: context,
                              roomId: widget.roomId,
                              callerUserId: widget.callerUserId,
                              targetUserId: widget.targetUserId,
                              controller: _controller,
                              onStateChanged: () => setState(() {}),
                            ),
                          )
                        else
                          const SizedBox(width: 48, height: 48),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 1. Centered Avatar Stack
                    Stack(
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
                                ? CachedNetworkImageProvider(uAvatar)
                                : null,
                            child: uAvatar.isEmpty
                                ? const Icon(Icons.person,
                                    size: 36, color: Colors.white54)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: const PulsingOnlineIndicator(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 2. Username (Bold, primary focus, 18 px)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          uName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          u?.gender == 'female'
                              ? Icons.female_rounded
                              : Icons.male_rounded,
                          color: u?.gender == 'female'
                              ? const Color(0xFFF472B6)
                              : const Color(0xFF60A5FA),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 3. User ID (ID Pill)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: numericId));
                        Get.snackbar('Copied', 'ID copied to clipboard.');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ID: $numericId',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.content_copy_rounded,
                              color: Colors.white54,
                              size: 11,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 4. Identity Tags (Wrap, centered, max width 320)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: buildTagLightsWidget(
                            generateDynamicTagLights(
                                u, vipLevel, novelLevel, uLevel),
                            context),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 4.5. ROLE SHIELD (Feature 16: Displays current room role & active tenure)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade900.withOpacity(0.3),
                            Colors.purple.shade900.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🛡️ Role Shield:', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text(
                            widget.role.isNotEmpty ? widget.role : 'Audience',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          const Text('• Since 04 Aug 2026', style: TextStyle(color: Colors.white60, fontSize: 9)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 5. Official Status Tag
                    MiniProfileBadges.buildOfficialStatusRow(u, context),
                    const SizedBox(height: 6),

                    // 6. Showcase Badges
                    MiniProfileBadges.buildBadgesShowcaseWidget(
                        u?.showcasedBadges ?? [], context),
                    const SizedBox(height: 6),

                    // Bio
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        u?.bio ??
                            'Crafting intuitive digital experiences. Passionate about minimalist design and front...',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),

                    // Stats Row (Followers, Following, Gifts, Contribute)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        MiniProfileBadges.buildStatColumn(_formatStatValue(u?.followers ?? 1240),
                            'Followers'),
                        MiniProfileBadges.buildStatColumn(
                            _formatStatValue(u?.following ?? 380), 'Following'),
                        if (isMe) ...[
                          MiniProfileBadges.buildStatColumn('89', 'Friends'),
                          MiniProfileBadges.buildStatColumn('123.5K', 'Gifts'),
                        ] else ...[
                          MiniProfileBadges.buildStatColumn('123.5K', 'Gifts'),
                          MiniProfileBadges.buildStatColumn('450K', 'Contribute'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Gift Stats Section (Dialog Compact Version)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.featured_play_list_rounded,
                                  color: Color(0xFFFBBF24), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Gift Stats',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Monthly received gifts',
                                style: GoogleFonts.poppins(
                                    color: Colors.white70, fontSize: 11),
                              ),
                              Text(
                                '12.5K',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFBBF24),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'monthly contribute',
                                style: GoogleFonts.poppins(
                                    color: Colors.white70, fontSize: 11),
                              ),
                              Text(
                                '450K',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Gifts',
                                style: GoogleFonts.poppins(
                                    color: Colors.white70, fontSize: 11),
                              ),
                              Row(
                                children: [
                                  _buildOverlappingAvatarsDialog([
                                    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=80',
                                    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80',
                                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80',
                                    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
                                  ]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '123.5K',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF8B5CFF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Colors.white30, size: 14),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Contributors',
                                style: GoogleFonts.poppins(
                                    color: Colors.white70, fontSize: 11),
                              ),
                              Row(
                                children: [
                                  _buildOverlappingAvatarsDialog([
                                    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=80',
                                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80',
                                    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80',
                                    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
                                  ]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '842k',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Colors.white30, size: 14),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bottom Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5865F2), Color(0xFF4752C4)],
                              ),
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                Get.back();
                                final currentUid = Supabase
                                    .instance.client.auth.currentUser?.id;
                                Get.to(() => ProfileScreen(
                                    visitorUser: u ??
                                        User(
                                          id: widget.targetUserId,
                                          username: uName
                                              .toLowerCase()
                                              .replaceAll(' ', '_'),
                                          email:
                                              '${widget.targetUserId}@example.com',
                                          displayName: uName,
                                          avatar: uAvatar,
                                          followers: 1240,
                                          following: 380,
                                          isVerified: isVIP,
                                          isPremium: isVIP,
                                          level: uLevel,
                                          interests: const [],
                                          communities: const [],
                                          reputation: 100,
                                          sid: widget.targetUserId.hashCode
                                              .abs()
                                              .toString(),
                                        )));
                              },
                              icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.white,
                                  size: 14),
                              label: Text(
                                'Message',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withOpacity(0.06),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.12)),
                            ),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                Get.back();
                                final currentUid = Supabase
                                    .instance.client.auth.currentUser?.id;
                                final isMe = widget.targetUserId ==
                                        widget.callerUserId ||
                                    (currentUid != null &&
                                        widget.targetUserId == currentUid);
                                if (isMe) {
                                  Get.to(() => const ProfileScreen());
                                } else {
                                  Get.to(() => ProfileScreen(
                                      visitorUser: u ??
                                          User(
                                            id: widget.targetUserId,
                                            username: uName
                                                .toLowerCase()
                                                .replaceAll(' ', '_'),
                                            email:
                                                '${widget.targetUserId}@example.com',
                                            displayName: uName,
                                            avatar: uAvatar,
                                            followers: 1240,
                                            following: 380,
                                            isVerified: isVIP,
                                            isPremium: isVIP,
                                            level: uLevel,
                                            interests: const [],
                                            communities: const [],
                                            reputation: 100,
                                            sid: widget.targetUserId.hashCode
                                                .abs()
                                                .toString(),
                                          )));
                                }
                              },
                              child: Text(
                                'View Profile',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF8B5CF6).withOpacity(0.18),
                              border: Border.all(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.35)),
                            ),
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                Get.back();
                                if (Get.isRegistered<RoomController>()) {
                                  RoomController.to.mentionUserInRoomChat(uName);
                                }
                              },
                              icon: const Icon(Icons.alternate_email_rounded,
                                  color: Color(0xFFA78BFA), size: 14),
                              label: Text(
                                'Mention',
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFFA78BFA),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFFBBF24).withOpacity(0.15),
                              border: Border.all(
                                  color:
                                      const Color(0xFFFBBF24).withOpacity(0.3)),
                            ),
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                Get.back();
                                Get.dialog(SendGiftDialog(
                                  roomId: widget.roomId,
                                  occupiedSeatsCount: widget.occupiedSeatsCount,
                                  targetUserId: widget.targetUserId,
                                  targetUserName: uName,
                                ));
                              },
                              icon: const Icon(Icons.card_giftcard_rounded,
                                  color: Color(0xFFFBBF24), size: 14),
                              label: Text(
                                'Gift',
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFFFBBF24),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
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
