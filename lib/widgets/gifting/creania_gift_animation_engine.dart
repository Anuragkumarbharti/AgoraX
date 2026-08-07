// lib/widgets/creania_gift_animation_engine.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../../services/gifting/animation_timeline.dart';

class GiftRequestEvent {
  final String giftId;
  final String giftName;
  final String giftIcon;
  final int price;
  final String currency;
  final GiftAnimationMode mode;
  final String senderName;
  final String? senderAvatar;
  final Offset startOffset; // Start position (Bottom near Gift Panel)
  final String receiverName;
  final String? receiverAvatar;
  final Offset targetOffset; // Primary target receiver seat
  final List<Offset>? targetOffsets; // Multi-recipient split seat targets
  final int count; // Combo count (e.g. 1, 5, 10, 20, 50, 99, 520, 1314)

  GiftRequestEvent({
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.price,
    required this.currency,
    required this.mode,
    required this.senderName,
    this.senderAvatar,
    required this.startOffset,
    required this.receiverName,
    this.receiverAvatar,
    required this.targetOffset,
    this.targetOffsets,
    this.count = 1,
  });
}

class CreaniaGiftAnimationEngine extends StatefulWidget {
  final GiftRequestEvent? event;
  final VoidCallback? onCompleted;

  const CreaniaGiftAnimationEngine({
    Key? key,
    this.event,
    this.onCompleted,
  }) : super(key: key);

  @override
  State<CreaniaGiftAnimationEngine> createState() => _CreaniaGiftAnimationEngineState();
}

class _CreaniaGiftAnimationEngineState extends State<CreaniaGiftAnimationEngine>
    with SingleTickerProviderStateMixin {
  late AnimationController _flightController;
  GiftAnimationMetadata? _meta;
  bool _isStackedCombo = false;
  final List<_ParticleInfo> _particles = [];

  @override
  void initState() {
    super.initState();
    // Default 5.0 Seconds duration, dynamically adjusted per gift tier in _startAnimation
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _flightController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.onCompleted != null) widget.onCompleted!();
      }
    });

    if (widget.event != null) {
      _startAnimation(widget.event!);
    }
  }

  @override
  void didUpdateWidget(CreaniaGiftAnimationEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.event != oldWidget.event && widget.event != null) {
      _startAnimation(widget.event!);
    }
  }

  void _startAnimation(GiftRequestEvent event) {
    _meta = GiftMetadataRegistry.getMetadata(event.giftId);

    final totalDuration = AnimationTimeline.getTotalDuration(_meta!.tier);
    _flightController.duration = totalDuration;

    _initParticles();
    _flightController.reset();
    _flightController.forward();
  }

  void _initParticles() {
    _particles.clear();
    final random = Random();
    for (int i = 0; i < 32; i++) {
      _particles.add(_ParticleInfo(
        angle: random.nextDouble() * 2 * pi,
        speed: random.nextDouble() * 60 + 20,
        size: random.nextDouble() * 10 + 4,
        opacity: random.nextDouble() * 0.8 + 0.2,
      ));
    }
  }

  @override
  void dispose() {
    _flightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event == null || _meta == null) {
      return const SizedBox.shrink();
    }

    final event = widget.event!;
    final meta = _meta!;
    final media = MediaQuery.of(context).size;

    // Center Stage & Target Seats
    final bottomPanelOrigin = event.startOffset.dx > 0 && event.startOffset.dy > 0
        ? event.startOffset
        : Offset(media.width / 2, media.height * 0.92);
    final centerStage = Offset(media.width / 2, media.height * 0.42);
    final targets = (event.targetOffsets != null && event.targetOffsets!.isNotEmpty)
        ? event.targetOffsets!
        : [event.targetOffset];

    // Dynamic icon retrieval (always preserve selected gift icon)
    final activeIcon = event.giftIcon.isNotEmpty
        ? event.giftIcon
        : (meta.giftIcon.isNotEmpty ? meta.giftIcon : '✨');

    return AnimatedBuilder(
      animation: _flightController,
      builder: (context, child) {
        if (!_flightController.isAnimating) return const SizedBox.shrink();
        final progress = _flightController.value;

        // ── CHAT MODE ──
        if (event.mode == GiftAnimationMode.chat) {
          final chatPos = Offset.lerp(bottomPanelOrigin, event.targetOffset, Curves.easeOut.transform(progress))!;
          return IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  left: chatPos.dx - 18,
                  top: chatPos.dy - 18,
                  child: Opacity(
                    opacity: (1 - progress * 0.2).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.8 + sin(progress * pi) * 0.4,
                      child: Text(activeIcon, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
                if (progress > 0.6)
                  Positioned(
                    left: event.targetOffset.dx - 40,
                    top: event.targetOffset.dy - 40,
                    child: _buildLocalizedChatEffect(meta.chatEffect, (progress - 0.6) / 0.4, meta.themeColor),
                  ),
              ],
            ),
          );
        }

        // ── ROOM MODE: MANDATORY 3-STAGE FLOW ──
        // Stage A (1.0s): Launch Animation from sender seat/profile to Center
        // Stage B (2-6s depending on tier): Main Center Showcase (Finishes completely before Stage C)
        // Stage C (1.0s): Receiver Delivery (Single receiver or duplicated to all receiver seats)
        final stageInfo = AnimationTimeline.getStageProgress(progress, meta.tier);

        return IgnorePointer(
          child: Stack(
            children: [
              // ── STAGE A: LAUNCH ANIMATION (1.0 sec) ──
              if (stageInfo.stage == AnimationStage.stageA) ...[
                _buildStep1BottomRise(
                  bottomPanelOrigin,
                  centerStage,
                  stageInfo.stageNormalizedProgress,
                  activeIcon,
                  meta,
                ),
              ],

              // ── STAGE B: MAIN GIFT SHOWCASE (2.0 to 6.0 sec) ──
              if (stageInfo.stage == AnimationStage.stageB) ...[
                _buildLeftSenderBannerCard(
                  media,
                  event,
                  meta,
                  activeIcon,
                  stageInfo.stageNormalizedProgress,
                ),
                _buildStep2CenterShowcase(
                  centerStage,
                  event,
                  meta,
                  activeIcon,
                  stageInfo.stageNormalizedProgress,
                ),
              ],

              // ── STAGE C: RECEIVER DELIVERY (1.0 sec) ──
              if (stageInfo.stage == AnimationStage.stageC) ...[
                for (final targetPos in targets) ...[
                  _buildStep3FlightAndLanding(
                    centerStage,
                    targetPos,
                    meta,
                    activeIcon,
                    stageInfo.stageNormalizedProgress,
                    _isStackedCombo,
                    event.count,
                  ),
                ],
                if ((meta.tier == GiftTier.epic ||
                        meta.tier == GiftTier.legendary ||
                        meta.tier == GiftTier.mythic))
                  _buildCinematicOverlay(meta, activeIcon, stageInfo.stageNormalizedProgress),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Step 1: Rise from Bottom Panel to Center Stage (1.0 to 1.5 seconds)
  Widget _buildStep1BottomRise(
    Offset bottom,
    Offset center,
    double stepT,
    String icon,
    GiftAnimationMetadata meta,
  ) {
    final pos = Offset.lerp(bottom, center, Curves.easeOutCubic.transform(stepT))!;
    final scale = (stepT * 0.85).clamp(0.1, 0.85);

    return Stack(
      children: [
        // Small Particle Trail during rise
        CustomPaint(
          size: Size.infinite,
          painter: _RiseTrailPainter(
            bottom: bottom,
            current: pos,
            progress: stepT,
            themeColor: meta.themeColor,
          ),
        ),
        Positioned(
          left: pos.dx - 28,
          top: pos.dy - 28,
          child: Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: meta.themeColor.withOpacity(0.4 * stepT),
                    blurRadius: 20 * stepT,
                  )
                ],
              ),
              child: Text(icon, style: const TextStyle(fontSize: 52)),
            ),
          ),
        ),
      ],
    );
  }

  /// Step 2: Center Stage Showcase & Unique Gift Particle Animation (2.0 to 5.0 seconds)
  Widget _buildStep2CenterShowcase(
    Offset center,
    GiftRequestEvent event,
    GiftAnimationMetadata meta,
    String icon,
    double stepT,
  ) {
    // Zoom curve: 0% -> 120% -> settles to 100%
    double zoomScale = 1.0;
    if (stepT < 0.35) {
      zoomScale = Curves.easeOutBack.transform(stepT / 0.35) * 1.2;
    } else {
      zoomScale = 1.2 - (stepT - 0.35) * 0.3;
    }

    final fadeOut = stepT > 0.88 ? (1.0 - (stepT - 0.88) * 8.33).clamp(0.0, 1.0) : 1.0;

    return Stack(
      children: [
        // Center Stage Unique Gift Showcase Container
        Positioned(
          left: center.dx - 120,
          top: center.dy - 120,
          child: Opacity(
            opacity: fadeOut,
            child: Transform.scale(
              scale: zoomScale,
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Render Unique Gift-Specific Showcase Animation
                    _buildUniqueGiftShowcase(meta, icon, stepT),

                    // Center Gift Hero Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: meta.themeColor.withOpacity(0.6),
                            blurRadius: 50,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 84)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Large Animated Gold Combo Text "×1", "×5", "×10", "×99", "×520", "×1314"
        Positioned(
          left: center.dx + 65,
          top: center.dy - 40,
          child: Opacity(
            opacity: fadeOut,
            child: Transform.scale(
              scale: 0.85 + sin(stepT * pi * 3) * 0.2,
              child: _buildGoldComboBadge(event.count),
            ),
          ),
        ),
      ],
    );
  }

  /// Large Animated Gold Combo Badge Widget
  Widget _buildGoldComboBadge(int count) {
    final textStr = '×$count';
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFFFFF7AD),
          Color(0xFFFFAA00),
          Color(0xFFFFD700),
          Color(0xFFFF8C00),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bounds),
      child: Text(
        textStr,
        style: GoogleFonts.outfit(
          fontSize: count >= 100 ? 44 : 52,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: Colors.white,
          shadows: [
            const Shadow(
              color: Color(0xFF7C3AED),
              blurRadius: 20,
              offset: Offset(2, 2),
            ),
            Shadow(
              color: Colors.black.withOpacity(0.9),
              blurRadius: 10,
              offset: const Offset(1, 1),
            )
          ],
        ),
      ),
    );
  }

  /// Renders dynamic, gift-specific showcase animation per ShowcaseAnimationType
  Widget _buildUniqueGiftShowcase(GiftAnimationMetadata meta, String icon, double stepT) {
    switch (meta.showcaseType) {
      case ShowcaseAnimationType.roseBloom:
        return _RoseShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.heartPulse:
        return _HeartShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.coffeeSteam:
        return _CoffeeShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.chocolateUnwrap:
        return _ChocolateShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.balloonFloat:
        return _BalloonShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.butterflyWings:
        return _ButterflyShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.cakeSparkle:
        return _CakeShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.diamondPrism:
        return _DiamondShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.ringSparkle:
        return _RingShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.crownShine:
        return _CrownShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.carEngine:
        return _CarShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.jetIgnition:
        return _JetShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.yachtSplash:
        return _YachtShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.dragonFire:
        return _DragonShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.galaxyRotate:
        return _GalaxyShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.castleBuild:
        return _CastleShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.phoenixFlames:
        return _PhoenixShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.likePop:
        return _LikeShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.flowerBloom:
        return _FlowerShowcaseWidget(stepT: stepT, color: meta.themeColor);
      case ShowcaseAnimationType.giftBoxExplode:
        return _GiftBoxShowcaseWidget(stepT: stepT, color: meta.themeColor);
      default:
        return _GenericShowcaseWidget(stepT: stepT, color: meta.themeColor, particles: _particles);
    }
  }

  /// Floating Left Sender Card Banner
  Widget _buildLeftSenderBannerCard(
    Size media,
    GiftRequestEvent event,
    GiftAnimationMetadata meta,
    String icon,
    double stepT,
  ) {
    final slideIn = Curves.easeOutCubic.transform((stepT * 2.5).clamp(0.0, 1.0));
    final fadeOut = stepT > 0.85 ? (1.0 - (stepT - 0.85) * 6.6).clamp(0.0, 1.0) : 1.0;

    return Positioned(
      left: 14 + (slideIn - 1.0) * 140,
      top: media.height * 0.42,
      child: Opacity(
        opacity: fadeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F111A).withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: meta.themeColor.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: meta.themeColor.withOpacity(0.35),
                blurRadius: 16,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: event.senderAvatar != null && event.senderAvatar!.isNotEmpty
                    ? NetworkImage(event.senderAvatar!)
                    : const AssetImage('assets/images/placeholder.png') as ImageProvider,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.senderName,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Sent ${meta.giftName}',
                    style: GoogleFonts.poppins(color: meta.themeColor, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '×${event.count}',
                style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w900),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// Step 3: Flight from Center to Receiver Seat(s) & Landing Reaction (1.0 to 1.5 seconds)
  Widget _buildStep3FlightAndLanding(
    Offset center,
    Offset target,
    GiftAnimationMetadata meta,
    String icon,
    double stepT,
    bool isStacked,
    int count,
  ) {
    if (stepT < 0.5) {
      // Flight phase (0.0 -> 0.5)
      final flightT = stepT / 0.5;
      final easedT = Curves.easeInOutCubic.transform(flightT);
      final pos = _computeFlightPathPosition(center, target, easedT, meta.flightPath);

      return Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _FlightTrailPainter(
              start: center,
              current: pos,
              progress: flightT,
              themeColor: meta.themeColor,
            ),
          ),
          Positioned(
            left: pos.dx - 22,
            top: pos.dy - 22,
            child: Transform.scale(
              scale: (1.0 - flightT * 0.3) * (0.9 + sin(flightT * pi) * 0.2),
              child: Text(icon, style: const TextStyle(fontSize: 38)),
            ),
          ),
        ],
      );
    } else {
      // Receiver seat landing phase (0.5 -> 1.0)
      final landingT = (stepT - 0.5) / 0.5;
      return Positioned(
        left: target.dx - 65,
        top: target.dy - 65,
        child: _buildSeatLandingStage(meta, icon, landingT, isStacked, count),
      );
    }
  }

  /// Receiver Seat Landing Effect Widget
  Widget _buildSeatLandingStage(
    GiftAnimationMetadata meta,
    String icon,
    double landingT,
    bool isStacked,
    int count,
  ) {
    return Container(
      width: 130,
      height: 130,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: meta.themeColor.withOpacity(0.6 * sin(landingT * pi)),
            blurRadius: 35 * landingT,
            spreadRadius: 8 * landingT,
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Render Gift-Specific Landing Effect
          _buildSeatLandingEffect(meta.seatEffect, meta.themeColor, icon, landingT),

          // Receiver Seat Landing Icon
          Transform.scale(
            scale: sin(landingT * pi) * 1.2,
            child: Text(
              icon,
              style: TextStyle(fontSize: isStacked ? 38 : 32),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders seat landing effects on receiver seat
  Widget _buildSeatLandingEffect(SeatEffectType type, Color color, String icon, double landingT) {
    return CustomPaint(
      size: const Size(130, 130),
      painter: _SeatLandingPainter(effectType: type, themeColor: color, progress: landingT),
    );
  }

  Offset _computeFlightPathPosition(Offset start, Offset end, double t, FlightPathType pathType) {
    switch (pathType) {
      case FlightPathType.straight:
        return Offset.lerp(start, end, t)!;

      case FlightPathType.curve:
        final control = Offset((start.dx + end.dx) / 2, min(start.dy, end.dy) - 100);
        final x = (1 - t) * (1 - t) * start.dx + 2 * (1 - t) * t * control.dx + t * t * end.dx;
        final y = (1 - t) * (1 - t) * start.dy + 2 * (1 - t) * t * control.dy + t * t * end.dy;
        return Offset(x, y);

      case FlightPathType.wave:
        final linear = Offset.lerp(start, end, t)!;
        return Offset(linear.dx + sin(t * pi * 4) * 30, linear.dy);

      case FlightPathType.spiral:
        final linear = Offset.lerp(start, end, t)!;
        final radius = (1 - t) * 40;
        final angle = t * pi * 6;
        return Offset(linear.dx + cos(angle) * radius, linear.dy + sin(angle) * radius);

      case FlightPathType.infinity:
        final linear = Offset.lerp(start, end, t)!;
        final angle = t * pi * 4;
        return Offset(linear.dx + sin(angle) * 25, linear.dy + sin(angle * 2) * 12);

      case FlightPathType.orbit:
        if (t < 0.6) return Offset.lerp(start, end, t / 0.6)!;
        final orbitT = (t - 0.6) / 0.4;
        final angle = orbitT * pi * 4;
        return Offset(end.dx + cos(angle) * 40, end.dy + sin(angle) * 40);

      case FlightPathType.bounce:
        final linear = Offset.lerp(start, end, t)!;
        final bounceY = (sin(t * pi * 3)).abs() * 35;
        return Offset(linear.dx, linear.dy - bounceY);

      case FlightPathType.zigzag:
        final linear = Offset.lerp(start, end, t)!;
        final shift = (t * 8).floor() % 2 == 0 ? 20.0 : -20.0;
        return Offset(linear.dx + shift, linear.dy);
    }
  }

  Widget _buildLocalizedChatEffect(ChatEffectType effect, double progress, Color color) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      child: Transform.scale(
        scale: progress,
        child: Text(
          effect == ChatEffectType.hearts ? '💖' : (effect == ChatEffectType.confetti ? '🎉' : '✨'),
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildCinematicOverlay(GiftAnimationMetadata meta, String icon, double progress) {
    final scale = meta.screenCoverage;

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * scale,
        height: MediaQuery.of(context).size.height * (scale * 0.45),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A).withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: meta.themeColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: meta.themeColor.withOpacity(0.4),
              blurRadius: 40,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(
              '${meta.tier.name.toUpperCase()} CINEMATIC SHOWCASE',
              style: GoogleFonts.poppins(color: meta.themeColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticleInfo {
  final double angle;
  final double speed;
  final double size;
  final double opacity;

  _ParticleInfo({
    required this.angle,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCER CANVAS SHOWCASE PAINTERS (100% Unique per Gift)
// ─────────────────────────────────────────────────────────────────────────────

class _RoseShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _RoseShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _RosePainter(stepT: stepT, color: color),
    );
  }
}

class _RosePainter extends CustomPainter {
  final double stepT;
  final Color color;
  _RosePainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Petals blooming and rotating in spiral
    for (int i = 0; i < 12; i++) {
      final angle = (i * (2 * pi / 12)) + (stepT * pi * 2);
      final dist = (30 + stepT * 65);
      final px = center.dx + cos(angle) * dist;
      final py = center.dy + sin(angle) * dist + (stepT * 20);

      paint.color = Colors.pinkAccent.withOpacity((1 - stepT * 0.5) * 0.7);
      canvas.drawCircle(Offset(px, py), 8 * (1 - stepT * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RosePainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _HeartShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _HeartShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _HeartPainter(stepT: stepT, color: color),
    );
  }
}

class _HeartPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _HeartPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Beating pulsing rings
    for (int i = 0; i < 3; i++) {
      final radius = ((stepT * 100) + (i * 30)) % 110.0;
      paint.color = Colors.redAccent.withOpacity((1.0 - (radius / 110.0)).clamp(0.0, 1.0) * 0.8);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeartPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _CoffeeShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _CoffeeShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _CoffeePainter(stepT: stepT, color: color),
    );
  }
}

class _CoffeePainter extends CustomPainter {
  final double stepT;
  final Color color;
  _CoffeePainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Wavy rising steam
    for (int i = -2; i <= 2; i++) {
      final xOffset = center.dx + (i * 18);
      final path = Path();
      path.moveTo(xOffset, center.dy + 10);
      for (double y = 0; y < 80; y += 5) {
        final curY = center.dy + 10 - y - (stepT * 30);
        final curX = xOffset + sin((y / 15) + (stepT * 10)) * 8;
        if (y == 0) {
          path.moveTo(curX, curY);
        } else {
          path.lineTo(curX, curY);
        }
      }
      paint.color = Colors.amber.withOpacity((1 - stepT * 0.6) * 0.5);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoffeePainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _ChocolateShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _ChocolateShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _ChocolatePainter(stepT: stepT, color: color),
    );
  }
}

class _ChocolatePainter extends CustomPainter {
  final double stepT;
  final Color color;
  _ChocolatePainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Sweet sparkle bursts
    for (int i = 0; i < 8; i++) {
      final angle = i * (pi / 4);
      final length = 40 + stepT * 60;
      final px = center.dx + cos(angle) * length;
      final py = center.dy + sin(angle) * length;
      paint.color = Colors.amberAccent.withOpacity((1 - stepT * 0.7) * 0.8);
      canvas.drawCircle(Offset(px, py), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChocolatePainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _BalloonShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _BalloonShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _BalloonPainter(stepT: stepT, color: color),
    );
  }
}

class _BalloonPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _BalloonPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Upward floating balloons
    final colors = [Colors.purpleAccent, Colors.pinkAccent, Colors.cyanAccent, Colors.yellowAccent];
    for (int i = 0; i < 6; i++) {
      final xOffset = center.dx + (sin(i + stepT * 6) * 45);
      final yOffset = center.dy + 60 - (stepT * 140) - (i * 20);
      paint.color = colors[i % colors.length].withOpacity(0.7);
      canvas.drawOval(Rect.fromCenter(center: Offset(xOffset, yOffset), width: 18, height: 24), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BalloonPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _ButterflyShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _ButterflyShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _ButterflyPainter(stepT: stepT, color: color),
    );
  }
}

class _ButterflyPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _ButterflyPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Orbital butterfly flight path rings
    for (int b = 0; b < 4; b++) {
      final angle = (b * (pi / 2)) + (stepT * pi * 4);
      final radius = 55.0 + sin(stepT * pi * 2 + b) * 15;
      final bx = center.dx + cos(angle) * radius;
      final by = center.dy + sin(angle) * radius;

      paint.color = Colors.deepPurpleAccent.withOpacity(0.8);
      canvas.drawCircle(Offset(bx, by), 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ButterflyPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _CakeShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _CakeShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _CakePainter(stepT: stepT, color: color),
    );
  }
}

class _CakePainter extends CustomPainter {
  final double stepT;
  final Color color;
  _CakePainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Confetti burst
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.amber, Colors.purple];
    for (int i = 0; i < 20; i++) {
      final angle = (i * (2 * pi / 20));
      final dist = stepT * 90;
      final cx = center.dx + cos(angle) * dist;
      final cy = center.dy + sin(angle) * dist;

      paint.color = colors[i % colors.length].withOpacity((1 - stepT) * 0.9);
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 6), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CakePainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _DiamondShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _DiamondShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _DiamondPainter(stepT: stepT, color: color),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _DiamondPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Prism light rays radiating outward
    for (int i = 0; i < 12; i++) {
      final angle = (i * (pi / 6)) + (stepT * pi);
      final rayLength = 95.0 * stepT;
      final destX = center.dx + cos(angle) * rayLength;
      final destY = center.dy + sin(angle) * rayLength;

      paint.color = Colors.cyanAccent.withOpacity((1 - stepT * 0.5) * 0.7);
      canvas.drawLine(center, Offset(destX, destY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _RingShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _RingShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _RingPainter(stepT: stepT, color: color),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _RingPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    paint.color = Colors.amberAccent.withOpacity((1 - stepT * 0.3) * 0.8);
    canvas.drawCircle(center, 50 + sin(stepT * pi * 4) * 10, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _CrownShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _CrownShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _CrownPainter(stepT: stepT, color: color),
    );
  }
}

class _CrownPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _CrownPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Royal halo rings
    paint.color = Colors.amber.withOpacity((1 - stepT) * 0.7);
    canvas.drawCircle(center, 70 + stepT * 30, paint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _CarShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _CarShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _CarPainter(stepT: stepT, color: color),
    );
  }
}

class _CarPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _CarPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Speed lines & smoke
    for (int i = 0; i < 5; i++) {
      final startX = center.dx - 80 + (i * 20);
      final yPos = center.dy + 30 + (i % 2 * 10);
      paint.color = Colors.deepOrangeAccent.withOpacity((1 - stepT) * 0.6);
      canvas.drawLine(Offset(startX, yPos), Offset(startX - 50, yPos), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CarPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _JetShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _JetShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _JetPainter(stepT: stepT, color: color),
    );
  }
}

class _JetPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _JetPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Sonic boom expansion ring
    paint.color = Colors.cyanAccent.withOpacity((1 - stepT) * 0.8);
    canvas.drawCircle(center, 40 + stepT * 70, paint);
  }

  @override
  bool shouldRepaint(covariant _JetPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _YachtShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _YachtShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _YachtPainter(stepT: stepT, color: color),
    );
  }
}

class _YachtPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _YachtPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Water splash droplets
    for (int i = 0; i < 10; i++) {
      final angle = (i * (pi / 5));
      final dist = 40 + stepT * 50;
      final wx = center.dx + cos(angle) * dist;
      final wy = center.dy + sin(angle) * dist + 20;

      paint.color = Colors.lightBlueAccent.withOpacity((1 - stepT) * 0.7);
      canvas.drawCircle(Offset(wx, wy), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _YachtPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _DragonShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _DragonShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _DragonPainter(stepT: stepT, color: color),
    );
  }
}

class _DragonPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _DragonPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Fire breath cone
    for (int i = 0; i < 16; i++) {
      final angle = (-pi / 4) + (i * (pi / 32));
      final length = 30 + stepT * 90;
      final fx = center.dx + cos(angle) * length;
      final fy = center.dy + sin(angle) * length;

      paint.color = (i % 2 == 0 ? Colors.redAccent : Colors.orangeAccent).withOpacity((1 - stepT) * 0.8);
      canvas.drawCircle(Offset(fx, fy), 6 * (1 - stepT * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DragonPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _GalaxyShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _GalaxyShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _GalaxyPainter(stepT: stepT, color: color),
    );
  }
}

class _GalaxyPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _GalaxyPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Rotating spiral arms
    for (int arm = 0; arm < 3; arm++) {
      final armAngle = arm * (2 * pi / 3);
      for (double r = 10; r < 80; r += 5) {
        final angle = armAngle + (r / 20) + (stepT * pi * 4);
        final gx = center.dx + cos(angle) * r;
        final gy = center.dy + sin(angle) * r;

        paint.color = Colors.indigoAccent.withOpacity((1 - r / 80) * 0.7);
        canvas.drawCircle(Offset(gx, gy), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _CastleShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _CastleShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _CastlePainter(stepT: stepT, color: color),
    );
  }
}

class _CastlePainter extends CustomPainter {
  final double stepT;
  final Color color;
  _CastlePainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Golden light pillar vertical beams
    paint.color = Colors.yellowAccent.withOpacity((1 - stepT) * 0.8);
    canvas.drawLine(Offset(center.dx - 40, center.dy + 60), Offset(center.dx - 40, center.dy - 60), paint);
    canvas.drawLine(Offset(center.dx + 40, center.dy + 60), Offset(center.dx + 40, center.dy - 60), paint);
  }

  @override
  bool shouldRepaint(covariant _CastlePainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _PhoenixShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _PhoenixShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _PhoenixPainter(stepT: stepT, color: color),
    );
  }
}

class _PhoenixPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _PhoenixPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Phoenix fiery wings expansion
    for (int i = 0; i < 14; i++) {
      final angle = (i % 2 == 0 ? -1 : 1) * (pi / 6 + (i * 0.1));
      final wingSpan = 30 + stepT * 80;
      final px = center.dx + cos(angle) * wingSpan * (i % 2 == 0 ? 1 : -1);
      final py = center.dy - sin(angle) * wingSpan;

      paint.color = Colors.orangeAccent.withOpacity((1 - stepT) * 0.8);
      canvas.drawCircle(Offset(px, py), 7, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PhoenixPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _LikeShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _LikeShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _LikePainter(stepT: stepT, color: color),
    );
  }
}

class _LikePainter extends CustomPainter {
  final double stepT;
  final Color color;
  _LikePainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    paint.color = Colors.blueAccent.withOpacity((1 - stepT) * 0.8);
    canvas.drawCircle(center, 40 + stepT * 50, paint);
  }

  @override
  bool shouldRepaint(covariant _LikePainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _FlowerShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _FlowerShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _FlowerPainter(stepT: stepT, color: color),
    );
  }
}

class _FlowerPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _FlowerPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i * (pi / 4)) + (stepT * pi);
      final dist = 35 + stepT * 40;
      paint.color = Colors.orangeAccent.withOpacity((1 - stepT) * 0.8);
      canvas.drawCircle(Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist), 7, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowerPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _GiftBoxShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  const _GiftBoxShowcaseWidget({Key? key, required this.stepT, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _GiftBoxPainter(stepT: stepT, color: color),
    );
  }
}

class _GiftBoxPainter extends CustomPainter {
  final double stepT;
  final Color color;
  _GiftBoxPainter({required this.stepT, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final angle = (i * (pi / 6));
      final dist = stepT * 80;
      paint.color = Colors.redAccent.withOpacity((1 - stepT) * 0.8);
      canvas.drawCircle(Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GiftBoxPainter oldDelegate) => oldDelegate.stepT != stepT;
}

class _GenericShowcaseWidget extends StatelessWidget {
  final double stepT;
  final Color color;
  final List<_ParticleInfo> particles;
  const _GenericShowcaseWidget({
    Key? key,
    required this.stepT,
    required this.color,
    required this.particles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _GenericPainter(stepT: stepT, color: color, particles: particles),
    );
  }
}

class _GenericPainter extends CustomPainter {
  final double stepT;
  final Color color;
  final List<_ParticleInfo> particles;
  _GenericPainter({required this.stepT, required this.color, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      final px = center.dx + cos(p.angle) * (p.speed * stepT * 1.5);
      final py = center.dy + sin(p.angle) * (p.speed * stepT * 1.5);

      paint.color = color.withOpacity(p.opacity * (1 - stepT * 0.7));
      canvas.drawCircle(Offset(px, py), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GenericPainter oldDelegate) => oldDelegate.stepT != stepT;
}

// ─────────────────────────────────────────────────────────────────────────────
// SEAT LANDING IMPACT PAINTER (After Flight Arrival)
// ─────────────────────────────────────────────────────────────────────────────

class _SeatLandingPainter extends CustomPainter {
  final SeatEffectType effectType;
  final Color themeColor;
  final double progress;

  _SeatLandingPainter({
    required this.effectType,
    required this.themeColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    switch (effectType) {
      case SeatEffectType.flowerBloom:
        paint.color = Colors.pinkAccent.withOpacity((1 - progress) * 0.8);
        paint.strokeWidth = 3;
        canvas.drawCircle(center, 20 + progress * 35, paint);
        break;
      case SeatEffectType.heartExplosion:
        paint.color = Colors.redAccent.withOpacity((1 - progress) * 0.8);
        paint.strokeWidth = 3.5;
        canvas.drawCircle(center, 25 + progress * 40, paint);
        break;
      case SeatEffectType.wheelSkid:
        paint.color = Colors.deepOrange.withOpacity((1 - progress) * 0.8);
        paint.strokeWidth = 4;
        canvas.drawCircle(center, 30 + progress * 35, paint);
        break;
      case SeatEffectType.windBurst:
        paint.color = Colors.cyanAccent.withOpacity((1 - progress) * 0.8);
        paint.strokeWidth = 3;
        canvas.drawCircle(center, 20 + progress * 45, paint);
        break;
      case SeatEffectType.fireAura:
        paint.color = Colors.red.withOpacity((1 - progress) * 0.8);
        paint.strokeWidth = 4;
        canvas.drawCircle(center, 25 + progress * 35, paint);
        break;
      case SeatEffectType.starRing:
        paint.color = Colors.indigoAccent.withOpacity((1 - progress) * 0.8);
        paint.strokeWidth = 3;
        canvas.drawCircle(center, 30 + progress * 40, paint);
        break;
      case SeatEffectType.goldenThroneGlow:
      case SeatEffectType.royalAura:
        paint.color = Colors.amberAccent.withOpacity((1 - progress) * 0.9);
        paint.strokeWidth = 5;
        canvas.drawCircle(center, 35 + progress * 30, paint);
        break;
      default:
        paint.color = themeColor.withOpacity((1 - progress) * 0.8);
        paint.strokeWidth = 3;
        canvas.drawCircle(center, 25 + progress * 30, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SeatLandingPainter oldDelegate) => oldDelegate.progress != progress;
}

class _RiseTrailPainter extends CustomPainter {
  final Offset bottom;
  final Offset current;
  final double progress;
  final Color themeColor;

  _RiseTrailPainter({
    required this.bottom,
    required this.current,
    required this.progress,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = themeColor.withOpacity((1 - progress * 0.6) * 0.5)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(bottom, current, paint);
  }

  @override
  bool shouldRepaint(covariant _RiseTrailPainter oldDelegate) => true;
}

class _FlightTrailPainter extends CustomPainter {
  final Offset start;
  final Offset current;
  final double progress;
  final Color themeColor;

  _FlightTrailPainter({
    required this.start,
    required this.current,
    required this.progress,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = themeColor.withOpacity(0.5 * (1 - progress * 0.5))
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, current, paint);
  }

  @override
  bool shouldRepaint(covariant _FlightTrailPainter oldDelegate) => true;
}
