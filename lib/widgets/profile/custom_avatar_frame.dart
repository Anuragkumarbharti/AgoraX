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

import '../voice/single_voice_ripple.dart';

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

class _CustomAvatarFrameState extends State<CustomAvatarFrame> {
  @override
  void initState() {
    super.initState();
    _resolveProfile();
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

  @override
  Widget build(BuildContext context) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isMe = widget.userId == 'me' || widget.userId == currentUid || widget.userId == 'uid_anurag_101';

    final double seatSize = widget.size;
    final double avatarSize = seatSize;          // Avatar completely fills seat with 100% coverage
    final double frameSize = seatSize * 1.065;   // Avatar frame is +6.5% larger

    // Determine if frame is equipped
    final resolvedId = (widget.userId == 'me' || widget.userId == 'uid_anurag_101' || widget.userId == currentUid)
        ? (currentUid ?? '')
        : widget.userId;

    final u = UserProfileCacheManager.rxCache[resolvedId] ??
        UserProfileCacheManager.getCachedUser(resolvedId) ??
        (resolvedId == currentUid ? UserProfileCacheManager.currentUser : null);
    final String? dynamicFrameUrl = u?.membershipAssets['avatar_frame'];

    final String activeFrameName = isMe && Get.isRegistered<CustomizationController>()
        ? Get.find<CustomizationController>().activeFrame.value
        : (u?.avatarFrame ?? UserProfileCacheManager.getCachedUser(resolvedId)?.avatarFrame ?? '');
    final String lowerActiveFrame = activeFrameName.toLowerCase().trim();
    final bool isExplicitlyUnequipped = lowerActiveFrame == 'normal' ||
        lowerActiveFrame == 'none' ||
        lowerActiveFrame == 'unequipped' ||
        lowerActiveFrame.isEmpty;

    final bool hasFrame = !isExplicitlyUnequipped &&
        ((dynamicFrameUrl != null && dynamicFrameUrl.isNotEmpty) ||
         (activeFrameName.isNotEmpty && !isExplicitlyUnequipped));

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

      String? frame;
      if (isMe && Get.isRegistered<CustomizationController>()) {
        frame = Get.find<CustomizationController>().activeFrame.value;
      }
      frame ??= u?.avatarFrame ?? UserProfileCacheManager.getCachedUser(resolvedId)?.avatarFrame;
      final String lowerF = (frame ?? '').toLowerCase().trim();
      final bool unequipped = lowerF == 'normal' || lowerF == 'none' || lowerF == 'unequipped' || lowerF.isEmpty;

      final String? dynamicFrameUrl = u?.membershipAssets['avatar_frame'];
      if (!unequipped && dynamicFrameUrl != null && dynamicFrameUrl.isNotEmpty) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: ClipOval(child: reactiveAvatarChild),
            ),
            IgnorePointer(
              child: OptimizedImage(
                imageUrl: dynamicFrameUrl,
                width: frameSize,
                height: frameSize,
                preset: frameSize <= 64 ? MediaSizePreset.sm : MediaSizePreset.md,
                fit: BoxFit.contain,
                errorWidget: const SizedBox.shrink(),
              ),
            ),
          ],
        );
      }

      if (!unequipped && frame != null && frame.isNotEmpty) {
        return _buildFrameWidget(frame, reactiveAvatarChild, frameSize);
      }

      return Container(
        width: avatarSize,
        height: avatarSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(child: reactiveAvatarChild),
      );
    });

    final double targetSize = hasFrame ? frameSize : seatSize;

    Widget seatBody = SizedBox(
      width: targetSize,
      height: targetSize,
      child: mainWidget,
    );

    return SizedBox(
      width: targetSize,
      height: targetSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Visual-only Circular Voice Ripple (never affects layout bounds)
          if (widget.isSpeaking)
            Positioned.fill(
              child: SingleVoiceRipple(
                isSpeaking: widget.isSpeaking,
                soundLevel: widget.soundLevel,
                baseSize: targetSize,
              ),
            ),

          seatBody,

          if (widget.showBadges && seatSize >= 40) ...[
            if (widget.role != null && widget.role != 'Guest' && widget.role != 'Listener' && widget.role != 'Audience')
              Positioned(
                top: -seatSize * 0.12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.role == 'Owner'
                        ? const Color(0xFF8A2BE2)
                        : (widget.role == 'Co-Owner' || widget.role == 'Co-owner'
                            ? const Color(0xFFFF8C00)
                            : (widget.role == 'Admin' ? const Color(0xFF007AFF) : const Color(0xFF059669))),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.role == 'Moderator' || widget.role == 'Host' ? 'Mod' : widget.role!,
                    style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ],
      ),
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
