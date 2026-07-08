import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/novel_controller.dart';
import '../services/vip_controller.dart';
import '../services/customization_controller.dart';

class PremiumEffectsResolver {
  static int getNovelLevel(String userId, String username) {
    if (userId == 'me' || userId == 'uid_anurag_101' || username == 'Anurag Kumar' || username == 'Anurag Kumar Bharti') {
      try {
        final novelCtrl = Get.find<NovelController>();
        return novelCtrl.novelLevel.value;
      } catch (_) {}
    }
    // Heuristics for mock users in explore/rooms based on name hash
    if (username.hashCode % 5 == 0) {
      return (username.hashCode % 7) + 1;
    }
    return 0;
  }

  static int getVipLevel(String userId, String username) {
    final novelLvl = getNovelLevel(userId, username);
    if (novelLvl > 0) return 0; // Novel takes precedence

    if (userId == 'me' || userId == 'uid_anurag_101' || username == 'Anurag Kumar' || username == 'Anurag Kumar Bharti') {
      try {
        final vipCtrl = Get.find<VipController>();
        return vipCtrl.vipLevel.value;
      } catch (_) {}
    }
    // Heuristics for mock users in explore/rooms
    if (username.contains('Priya') || username.contains('Owner')) return 7;
    if (username.contains('Vikram') || username.contains('Admin')) return 5;
    if (username.contains('Rahul') || username.contains('VIP')) return 3;
    if (username.contains('Divya') || username.contains('Aleena')) return 6;
    return 0;
  }

  static String getAvatarFrame(String userId, String username) {
    if (userId == 'me' || userId == 'uid_anurag_101' || username == 'Anurag Kumar' || username == 'Anurag Kumar Bharti') {
      try {
        final custCtrl = Get.find<CustomizationController>();
        return custCtrl.activeFrame.value;
      } catch (_) {}
    }
    // For other premium users, mock a frame depending on their VIP/Novel tier
    final novelLvl = getNovelLevel(userId, username);
    if (novelLvl > 0) {
      if (novelLvl >= 7) return 'Cosmic Emperor';
      if (novelLvl >= 5) return 'Phoenix Flame';
      if (novelLvl >= 3) return 'Royal Gold Palace';
      return 'Galaxy Orbit';
    }
    final vipLvl = getVipLevel(userId, username);
    if (vipLvl > 0) {
      if (vipLvl >= 7) return 'Royal Crown';
      if (vipLvl >= 5) return 'Crystal Cyan Frame';
      if (vipLvl >= 3) return 'Gold Glow Frame';
      return 'Royal Frame';
    }
    return 'Normal';
  }
}

class PremiumNameWidget extends StatefulWidget {
  final String name;
  final String userId;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PremiumNameWidget({
    Key? key,
    required this.name,
    required this.userId,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  }) : super(key: key);

  @override
  State<PremiumNameWidget> createState() => _PremiumNameWidgetState();
}

class _PremiumNameWidgetState extends State<PremiumNameWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    final novelLevel = PremiumEffectsResolver.getNovelLevel(widget.userId, widget.name);
    final vipLevel = PremiumEffectsResolver.getVipLevel(widget.userId, widget.name);

    if (novelLevel <= 0 && vipLevel <= 0) {
      return Text(
        widget.name,
        style: baseStyle,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    // Determine Glow Color and gradients
    List<Shadow> shadows = [];
    Color textColor = baseStyle.color ?? Colors.white;
    List<Color>? gradientColors;

    if (novelLevel > 0) {
      switch (novelLevel) {
        case 1:
          textColor = const Color(0xFF60A5FA);
          shadows = [
            const Shadow(color: Color(0xFF2563EB), blurRadius: 4),
            const Shadow(color: Color(0xFF3B82F6), blurRadius: 8),
          ];
          break;
        case 2:
          gradientColors = [const Color(0xFFC084FC), const Color(0xFF8B5CF6)];
          shadows = [
            const Shadow(color: Color(0xFF7C3AED), blurRadius: 6),
            const Shadow(color: Color(0xFFA78BFA), blurRadius: 10),
          ];
          break;
        case 3:
          gradientColors = [const Color(0xFFFCD34D), const Color(0xFFF59E0B)];
          shadows = [
            const Shadow(color: Color(0xFFD97706), blurRadius: 8),
            const Shadow(color: Color(0xFFFFD700), blurRadius: 12),
          ];
          break;
        case 4:
          gradientColors = [const Color(0xFFFCA5A5), const Color(0xFFEF4444)];
          shadows = [
            const Shadow(color: Color(0xFFDC2626), blurRadius: 10),
            const Shadow(color: Color(0xFFF87171), blurRadius: 15),
          ];
          break;
        case 5:
          gradientColors = [const Color(0xFFFED7AA), const Color(0xFFF97316)];
          shadows = [
            const Shadow(color: Color(0xFFEA580C), blurRadius: 12),
            const Shadow(color: Color(0xFFFB923C), blurRadius: 18),
          ];
          break;
        case 6:
          gradientColors = [const Color(0xFF99F6E4), const Color(0xFF0D9488), Colors.white];
          shadows = [
            const Shadow(color: Color(0xFF06B6D4), blurRadius: 15),
            const Shadow(color: Color(0xFF22D3EE), blurRadius: 20),
          ];
          break;
        case 7:
        default:
          gradientColors = [const Color(0xFFFFE082), const Color(0xFFFFB300), const Color(0xFFFFE082)];
          shadows = [
            const Shadow(color: Color(0xFFFFD700), blurRadius: 20),
            const Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
          ];
          break;
      }
    } else if (vipLevel > 0) {
      if (vipLevel >= 1 && vipLevel <= 4) {
        // Soft elegant glow
        textColor = const Color(0xFFFCD34D);
        shadows = [
          Shadow(color: const Color(0xFFF59E0B).withOpacity(0.5), blurRadius: 5),
        ];
      } else {
        // Strong premium glow (VIP 5+)
        gradientColors = [const Color(0xFFFFD700), const Color(0xFFFFF7C2), const Color(0xFFFFD700)];
        shadows = [
          const Shadow(color: Color(0xFFFFD700), blurRadius: 12),
          const Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
        ];
      }
    }

    final textStyle = baseStyle.copyWith(
      color: gradientColors != null ? Colors.white : textColor,
      shadows: shadows,
    );

    final textWidget = Text(
      widget.name,
      style: textStyle,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );

    if (gradientColors != null) {
      final isVip5Plus = vipLevel >= 5;
      if (isVip5Plus) {
        // slight animated shimmer for VIP 5+
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: gradientColors!,
                    stops: const [0.0, 0.5, 1.0],
                    transform: GradientRotation(_shimmerController.value * 2 * 3.14159),
                  ).createShader(bounds);
                },
                child: textWidget,
              );
            },
          ),
        );
      } else {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: gradientColors!,
            ).createShader(bounds);
          },
          child: textWidget,
        );
      }
    }

    return textWidget;
  }
}
