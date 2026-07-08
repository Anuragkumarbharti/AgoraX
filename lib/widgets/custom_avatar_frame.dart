import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/customization_controller.dart';
import 'vip_avatar_decorator.dart';
import 'novel_avatar_decorator.dart';

class CustomAvatarFrame extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isMe = userId == 'me' || userId == 'uid_anurag_101' || username == 'Anurag Kumar' || username == 'Anurag Kumar Bharti';

    if (isMe) {
      final custCtrl = Get.find<CustomizationController>();
      return Obx(() {
        final frame = custCtrl.activeFrame.value;

        if (frame == 'Normal' || frame == 'None') {
          return Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: ClipOval(child: child),
          );
        }

        // Animated and premium VIP frames mapping
        if (frame.contains('Royal Frame')) {
          return VipAvatarDecorator(level: 1, size: size, child: child);
        } else if (frame.contains('Neon Frame')) {
          return VipAvatarDecorator(level: 2, size: size, child: child);
        } else if (frame.contains('Gold Glow Frame')) {
          return VipAvatarDecorator(level: 3, size: size, child: child);
        } else if (frame.contains('Diamond Frame')) {
          return VipAvatarDecorator(level: 4, size: size, child: child);
        } else if (frame.contains('Crystal Cyan Frame')) {
          return VipAvatarDecorator(level: 5, size: size, child: child);
        } else if (frame.contains('Rainbow Frame')) {
          return VipAvatarDecorator(level: 6, size: size, child: child);
        } else if (frame.contains('Royal Crown')) {
          return VipAvatarDecorator(level: 7, size: size, child: child);
        }

        // Animated and premium Novel frames mapping
        if (frame.contains('Galaxy Orbit')) {
          return NovelAvatarDecorator(level: 2, size: size, child: child);
        } else if (frame.contains('Royal Gold Palace')) {
          return NovelAvatarDecorator(level: 3, size: size, child: child);
        } else if (frame.contains('Dragon Fire Frame')) {
          return NovelAvatarDecorator(level: 4, size: size, child: child);
        } else if (frame.contains('Phoenix Flame')) {
          return NovelAvatarDecorator(level: 5, size: size, child: child);
        } else if (frame.contains('Celestial Sky Frame')) {
          return NovelAvatarDecorator(level: 6, size: size, child: child);
        } else if (frame.contains('Cosmic Emperor')) {
          return NovelAvatarDecorator(level: 7, size: size, child: child);
        }

        // Fallbacks for general names matching old DB strings
        if (frame.contains('Galaxy')) {
          return NovelAvatarDecorator(level: 2, size: size, child: child);
        } else if (frame.contains('Dragon')) {
          return NovelAvatarDecorator(level: 4, size: size, child: child);
        } else if (frame.contains('Immortal')) {
          return NovelAvatarDecorator(level: 7, size: size, child: child);
        }

        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: ClipOval(child: child),
        );
      });
    } else {
      // Fallback behavior for other users based on default levels
      if (defaultNovelLevel > 0) {
        return NovelAvatarDecorator(level: defaultNovelLevel, size: size, child: child);
      } else if (defaultVipLevel > 0) {
        return VipAvatarDecorator(level: defaultVipLevel, size: size, child: child);
      } else {
        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: ClipOval(child: child),
        );
      }
    }
  }
}
