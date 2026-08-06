import 'dart:io' as io;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/user/customization_controller.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../services/storage/asset_cache_manager.dart';
import '../common/optimized_image.dart';
import '../memberships/novel_avatar_decorator.dart';
import '../memberships/vip_avatar_decorator.dart'; // VIP 1 & 2 active

import 'package:supabase_flutter/supabase_flutter.dart';

class CustomAvatarFrame extends StatefulWidget {
  final String userId;
  final String username;
  final Widget child;
  final double size;
  final int defaultVipLevel;
  final int defaultNovelLevel;
  final bool isSpeaking;
  final double soundLevel;
  final String? role;
  final int? vipLevel;
  final int? novelLevel;
  final int? level;
  final bool showBadges;

  const CustomAvatarFrame({
    Key? key,
    required this.userId,
    required this.username,
    required this.child,
    this.size = 90,
    this.defaultVipLevel = 0,
    this.defaultNovelLevel = 0,
    this.isSpeaking = false,
    this.soundLevel = 0.0,
    this.role,
    this.vipLevel,
    this.novelLevel,
    this.level,
    this.showBadges = true,
  }) : super(key: key);

  @override
  State<CustomAvatarFrame> createState() => _CustomAvatarFrameState();
}

class _CustomAvatarFrameState extends State<CustomAvatarFrame> with SingleTickerProviderStateMixin {
  late AnimationController _glowAnimationController;

  @override
  void initState() {
    super.initState();
    _glowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _resolveProfile();
  }

  @override
  void dispose() {
    _glowAnimationController.dispose();
    super.dispose();
  }

  void _resolveProfile() {
    final cached = UserProfileCacheManager.getCachedUser(widget.userId);
    if (cached == null && widget.userId != 'me' && widget.userId != 'uid_anurag_101') {
      UserProfileCacheManager.fetchUserProfile(widget.userId).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant CustomAvatarFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _resolveProfile();
    }
  }

  Widget _buildEqualizerPill(double volumeFactor, double seatSize) {
    final double scale = seatSize / 56.0;
    final double pillWidth = 28.0 * scale;
    final double pillHeight = 14.0 * scale;
    final double barWidth = 2.0 * scale;
    final double maxBarHeight = 8.0 * scale;
    final double minBarHeight = 2.0 * scale;

    double calculateBarHeight(double phaseOffset) {
      final double bounce = (0.2 + 0.8 * math.sin((_glowAnimationController.value + phaseOffset) * 2 * math.pi).abs());
      return minBarHeight + (maxBarHeight - minBarHeight) * volumeFactor * bounce;
    }

    return Container(
      width: pillWidth,
      height: pillHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF09090B).withOpacity(0.85),
        borderRadius: BorderRadius.circular(pillHeight / 2),
        border: Border.all(
          color: const Color(0xFF00FF66).withOpacity(0.4),
          width: 0.8 * scale,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 3.0 * scale),
      child: AnimatedBuilder(
        animation: _glowAnimationController,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildBar(calculateBarHeight(0.0), barWidth),
              _buildBar(calculateBarHeight(0.25), barWidth),
              _buildBar(calculateBarHeight(0.55), barWidth),
              _buildBar(calculateBarHeight(0.8), barWidth),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBar(double height, double width) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF00FF66),
        borderRadius: BorderRadius.circular(0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isMe = widget.userId == 'me' || widget.userId == currentUid || widget.userId == 'uid_anurag_101';

    final double seatSize = widget.size;
    final double avatarSize = seatSize * 0.96; // Avatar fills 96% of seat
    final double frameSize = seatSize;         // Frame occupies 100% of seat

    // Determine if frame is equipped
    final resolvedId = (widget.userId == 'me' || widget.userId == 'uid_anurag_101' || widget.userId == currentUid)
        ? (currentUid ?? '')
        : widget.userId;

    final u = UserProfileCacheManager.rxCache[resolvedId];
    final String? dynamicFrameUrl = u?.membershipAssets['avatar_frame'];
    final frame = u?.avatarFrame ?? UserProfileCacheManager.getCachedUser(resolvedId)?.avatarFrame;
    final String lowerFrame = (frame ?? '').toLowerCase().trim();
    
    final int defaultVip = widget.vipLevel ?? widget.defaultVipLevel;
    final int defaultNovel = widget.novelLevel ?? widget.defaultNovelLevel;

    final bool hasFrame = (dynamicFrameUrl != null && dynamicFrameUrl.isNotEmpty) || 
                         (frame != null && lowerFrame != 'normal' && lowerFrame != 'none' && lowerFrame.isNotEmpty) ||
                         defaultVip > 0 ||
                         defaultNovel > 0;

    final double volumeFactor = widget.isSpeaking
        ? (0.4 + 0.6 * (widget.soundLevel / 40.0).clamp(0.0, 1.0))
        : 0.0;

    Widget mainWidget = Obx(() {
      // Touch equip trigger to force reactive rebuild when equipment changes
      final _ = UserProfileCacheManager.equipEventTrigger.value;
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      final resolvedId = (widget.userId == 'me' || widget.userId == 'uid_anurag_101' || widget.userId == currentUid)
          ? (currentUid ?? '')
          : widget.userId;

      final u = UserProfileCacheManager.rxCache[resolvedId] ??
          UserProfileCacheManager.getCachedUser(resolvedId) ??
          (resolvedId == currentUid ? UserProfileCacheManager.currentUser : null);
      final rawAvatar = u?.avatar ?? '';
      final currentAvatarUrl = (rawAvatar.isNotEmpty && !rawAvatar.contains('lh3.googleusercontent.com'))
          ? rawAvatar
          : '';
      
      final Widget reactiveAvatarChild;
      if (currentAvatarUrl.isNotEmpty) {
        reactiveAvatarChild = SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: ClipOval(
            child: OptimizedImage(
              imageUrl: currentAvatarUrl,
              quality: ImageQuality.thumbnail,
              width: avatarSize,
              height: avatarSize,
              errorWidget: widget.child,
            ),
          ),
        );
      } else {
        reactiveAvatarChild = SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: ClipOval(child: widget.child),
        );
      }

      final String? dynamicFrameUrl = u?.membershipAssets['avatar_frame'];
      if (dynamicFrameUrl != null && dynamicFrameUrl.isNotEmpty) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: ClipOval(child: reactiveAvatarChild),
            ),
            IgnorePointer(
              child: Image.network(
                dynamicFrameUrl,
                width: frameSize,
                height: frameSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        );
      }

      String? frame;
      if (isMe && Get.isRegistered<CustomizationController>()) {
        final active = Get.find<CustomizationController>().activeFrame.value;
        if (active.isNotEmpty && active != 'Normal') {
          frame = active;
        }
      }
      frame ??= u?.avatarFrame ?? UserProfileCacheManager.getCachedUser(resolvedId)?.avatarFrame;

      if (frame != null && frame.isNotEmpty && frame != 'Normal') {
        return _buildFrameWidget(frame, reactiveAvatarChild, frameSize);
      }

      // Fallback behavior for other users based on default levels
      final defaultVip = widget.vipLevel ?? widget.defaultVipLevel;
      final defaultNovel = widget.novelLevel ?? widget.defaultNovelLevel;
      if (defaultNovel > 0) {
        return NovelAvatarDecorator(level: defaultNovel, size: frameSize, child: reactiveAvatarChild);
      } else if (defaultVip > 0) {
        // Route VIP 1 & 2 to their PNG frames; higher levels still use Novel 1 fallback
        if (defaultVip <= 2) {
          return VipAvatarDecorator(level: defaultVip, size: frameSize, child: reactiveAvatarChild);
        }
        return NovelAvatarDecorator(level: 1, size: frameSize, child: reactiveAvatarChild);
      } else {
        return Container(
          width: avatarSize,
          height: avatarSize,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: ClipOval(child: reactiveAvatarChild),
        );
      }
    });

    Widget seatBody = SizedBox(
      width: seatSize,
      height: seatSize,
      child: mainWidget,
    );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        seatBody,

        if (widget.isSpeaking)
          Positioned(
            bottom: -6 * (seatSize / 56.0),
            child: _buildEqualizerPill(volumeFactor, seatSize),
          ),

        if (widget.showBadges && seatSize >= 40) ...[
          if (widget.role != null && widget.role != 'Guest' && widget.role != 'Listener' && widget.role != 'Audience')
            Positioned(
              top: -seatSize * 0.12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: widget.role == 'Owner' || widget.role == 'Host'
                      ? const Color(0xFF8A2BE2)
                      : (widget.role == 'Co-owner' || widget.role == 'Co-Host' ? const Color(0xFFFF8C00) : const Color(0xFF007AFF)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.role == 'Moderator' ? 'Admin' : widget.role!,
                  style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          Obx(() {
            final u = UserProfileCacheManager.rxCache[widget.userId];
            final vip = widget.vipLevel ?? u?.vipLevel ?? UserProfileCacheManager.getCachedUser(widget.userId)?.vipLevel ?? 0;
            if (vip > 0) {
              return Positioned(
                left: -seatSize * 0.05,
                bottom: -seatSize * 0.05,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD946EF), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Text(
                    'V$vip',
                    style: const TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          Obx(() {
            final u = UserProfileCacheManager.rxCache[widget.userId];
            final lv = widget.level ?? u?.level ?? UserProfileCacheManager.getCachedUser(widget.userId)?.level ?? 1;
            return Positioned(
              right: -seatSize * 0.05,
              bottom: -seatSize * 0.05,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Text(
                  'L$lv',
                  style: const TextStyle(color: Colors.black, fontSize: 6.5, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildFrameWidget(String frame, Widget avatarChild, double frameSize) {
    final String lowerFrame = frame.toLowerCase().trim();
    if (lowerFrame == 'normal' || lowerFrame == 'none' || lowerFrame.isEmpty) {
      return SizedBox(
        width: frameSize,
        height: frameSize,
        child: ClipOval(child: avatarChild),
      );
    }

    // ✅ ACTIVE: Novel Level 1 — uses the official PNG asset
    if (lowerFrame.contains('novel level 1') || lowerFrame.contains('novel 1')) {
      return NovelAvatarDecorator(level: 1, size: frameSize, child: avatarChild);
    }

    // ✅ ACTIVE: VIP Level 1 — Royal Blue Crown PNG
    if (frame.contains('Royal Frame')) {
      return VipAvatarDecorator(level: 1, size: frameSize, child: avatarChild);
    }
    // ✅ ACTIVE: VIP Level 2 — Mystic Purple Crown PNG
    if (frame.contains('Neon Frame')) {
      return VipAvatarDecorator(level: 2, size: frameSize, child: avatarChild);
    }

    // ── DISABLED VIP Frames (levels 3-7) — restore later ──
    if (frame.contains('Gold Glow Frame') ||
        frame.contains('Diamond Frame') || frame.contains('Crystal Cyan Frame') ||
        frame.contains('Rainbow Frame') || frame.contains('Royal Crown')) {
      return NovelAvatarDecorator(level: 1, size: frameSize, child: avatarChild);
    }

    // Novel Frames (levels 2-7) — disabled, restore later
    if (frame.contains('Galaxy Orbit') || frame.contains('Royal Gold Palace') ||
        frame.contains('Dragon Fire Frame') || frame.contains('Phoenix Flame') ||
        frame.contains('Celestial Sky Frame') || frame.contains('Cosmic Emperor')) {
      return NovelAvatarDecorator(level: 1, size: frameSize, child: avatarChild);
    }

    return Container(
      width: frameSize,
      height: frameSize,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: ClipOval(child: avatarChild),
    );
  }
}
