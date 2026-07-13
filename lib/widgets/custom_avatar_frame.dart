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

  const CustomAvatarFrame({
    Key? key,
    required this.userId,
    required this.username,
    required this.child,
    this.size = 90,
    this.defaultVipLevel = 0,
    this.defaultNovelLevel = 0,
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

    if (isMe) {
      final custCtrl = Get.find<CustomizationController>();
      return Obx(() {
        return _buildFrameWidget(custCtrl.activeFrame.value);
      });
    }

    return Obx(() {
      final u = UserProfileCacheManager.rxCache[widget.userId];
      final frame = u?.avatarFrame ?? UserProfileCacheManager.getCachedUser(widget.userId)?.avatarFrame;
      if (frame != null) {
        return _buildFrameWidget(frame);
      }

      // Fallback behavior for other users based on default levels
      if (widget.defaultNovelLevel > 0) {
        return NovelAvatarDecorator(level: widget.defaultNovelLevel, size: widget.size, child: widget.child);
      } else if (widget.defaultVipLevel > 0) {
        return VipAvatarDecorator(level: widget.defaultVipLevel, size: widget.size, child: widget.child);
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
