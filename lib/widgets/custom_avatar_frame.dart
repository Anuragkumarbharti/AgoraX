import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/customization_controller.dart';
import '../services/user_profile_cache_manager.dart';
import 'vip_avatar_decorator.dart';
import 'novel_avatar_decorator.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class CustomAvatarFrame extends StatefulWidget {
  final String userId;
  final String username;
  final Widget child;
  final double size;
  final int defaultVipLevel;
  final int defaultNovelLevel;
  final bool isSpeaking;
  final String? role;
  final int? vipLevel;
  final int? novelLevel;
  final int? level;

  const CustomAvatarFrame({
    Key? key,
    required this.userId,
    required this.username,
    required this.child,
    this.size = 90,
    this.defaultVipLevel = 0,
    this.defaultNovelLevel = 0,
    this.isSpeaking = false,
    this.role,
    this.vipLevel,
    this.novelLevel,
    this.level,
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
    )..repeat(reverse: true);
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

  @override
  Widget build(BuildContext context) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isMe = widget.userId == 'me' || widget.userId == currentUid || widget.userId == 'uid_anurag_101';

    Widget mainWidget;
    if (isMe) {
      final custCtrl = Get.find<CustomizationController>();
      mainWidget = Obx(() {
        return _buildFrameWidget(custCtrl.activeFrame.value);
      });
    } else {
      mainWidget = Obx(() {
        final u = UserProfileCacheManager.rxCache[widget.userId];
        final frame = u?.avatarFrame ?? UserProfileCacheManager.getCachedUser(widget.userId)?.avatarFrame;
        if (frame != null) {
          return _buildFrameWidget(frame);
        }

        // Fallback behavior for other users based on default levels
        final defaultVip = widget.vipLevel ?? widget.defaultVipLevel;
        final defaultNovel = widget.novelLevel ?? widget.defaultNovelLevel;
        if (defaultNovel > 0) {
          return NovelAvatarDecorator(level: defaultNovel, size: widget.size, child: widget.child);
        } else if (defaultVip > 0) {
          return VipAvatarDecorator(level: defaultVip, size: widget.size, child: widget.child);
        } else {
          return Container(
            width: widget.size,
            height: widget.size,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: ClipOval(child: widget.child),
          );
        }
      });
    }

    Widget speakingGlow = AnimatedBuilder(
      animation: _glowAnimationController,
      builder: (context, child) {
        return Container(
          width: widget.size + (8 * _glowAnimationController.value),
          height: widget.size + (8 * _glowAnimationController.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00FF66).withOpacity(0.8 * (1 - _glowAnimationController.value)),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FF66).withOpacity(0.3 * (1 - _glowAnimationController.value)),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Speaking Effect (behind the avatar if speaking)
        if (widget.isSpeaking) speakingGlow,

        // Avatar & Frame
        mainWidget,

        // Speaking Live Audio Waveform (overlay on right side)
        if (widget.isSpeaking)
          Positioned(
            right: -2,
            bottom: widget.size * 0.1,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF66),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 1.0),
              ),
              child: const Icon(
                Icons.waves_rounded,
                color: Colors.white,
                size: 8,
              ),
            ),
          ),

        // Badges overlays (only if size is reasonable, e.g. >= 40)
        if (widget.size >= 40) ...[
          // Role Badge (Top Center)
          if (widget.role != null && widget.role != 'Guest' && widget.role != 'Listener' && widget.role != 'Audience')
            Positioned(
              top: -widget.size * 0.12,
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

          // VIP Badge (Bottom Left)
          Obx(() {
            final u = UserProfileCacheManager.rxCache[widget.userId];
            final vip = widget.vipLevel ?? u?.vipLevel ?? UserProfileCacheManager.getCachedUser(widget.userId)?.vipLevel ?? 0;
            if (vip > 0) {
              return Positioned(
                left: -widget.size * 0.05,
                bottom: -widget.size * 0.05,
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

          // Level Badge (Bottom Right)
          Obx(() {
            final u = UserProfileCacheManager.rxCache[widget.userId];
            final lv = widget.level ?? u?.level ?? UserProfileCacheManager.getCachedUser(widget.userId)?.level ?? 1;
            return Positioned(
              right: -widget.size * 0.05,
              bottom: -widget.size * 0.05,
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

  Widget _buildFrameWidget(String frame) {
    if (frame == 'Normal' || frame == 'None') {
      return Container(
        width: widget.size,
        height: widget.size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: ClipOval(child: widget.child),
      );
    }

    if (frame.contains('Royal Frame')) {
      return VipAvatarDecorator(level: 1, size: widget.size, child: widget.child);
    } else if (frame.contains('Neon Frame')) {
      return VipAvatarDecorator(level: 2, size: widget.size, child: widget.child);
    } else if (frame.contains('Gold Glow Frame')) {
      return VipAvatarDecorator(level: 3, size: widget.size, child: widget.child);
    } else if (frame.contains('Diamond Frame')) {
      return VipAvatarDecorator(level: 4, size: widget.size, child: widget.child);
    } else if (frame.contains('Crystal Cyan Frame')) {
      return VipAvatarDecorator(level: 5, size: widget.size, child: widget.child);
    } else if (frame.contains('Rainbow Frame')) {
      return VipAvatarDecorator(level: 6, size: widget.size, child: widget.child);
    } else if (frame.contains('Royal Crown')) {
      return VipAvatarDecorator(level: 7, size: widget.size, child: widget.child);
    }

    if (frame.contains('Galaxy Orbit') || frame.contains('Galaxy')) {
      return NovelAvatarDecorator(level: 2, size: widget.size, child: widget.child);
    } else if (frame.contains('Royal Gold Palace')) {
      return NovelAvatarDecorator(level: 3, size: widget.size, child: widget.child);
    } else if (frame.contains('Dragon Fire Frame') || frame.contains('Dragon')) {
      return NovelAvatarDecorator(level: 4, size: widget.size, child: widget.child);
    } else if (frame.contains('Phoenix Flame')) {
      return NovelAvatarDecorator(level: 5, size: widget.size, child: widget.child);
    } else if (frame.contains('Celestial Sky Frame')) {
      return NovelAvatarDecorator(level: 6, size: widget.size, child: widget.child);
    } else if (frame.contains('Cosmic Emperor') || frame.contains('Immortal')) {
      return NovelAvatarDecorator(level: 7, size: widget.size, child: widget.child);
    }

    return Container(
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: ClipOval(child: widget.child),
    );
  }
}
