// lib/widgets/gifting/creania_gift_animation_engine.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../../services/gifting/gift_pipeline_manager.dart';
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
  final Offset startOffset;
  final String receiverName;
  final String? receiverAvatar;
  final Offset targetOffset;
  final List<Offset>? targetOffsets;
  final int count;
  final Map<String, dynamic>? luckyResult;

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
    this.luckyResult,
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
  late AnimationController _controller;
  GiftAnimationMetadata? _metadata;
  final List<PooledParticle> _activeParticles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.onCompleted != null) widget.onCompleted!();
        GiftPipelineManager.to.onAnimationCompleted();
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
    _metadata = GiftMetadataRegistry.getMetadata(event.giftId.isNotEmpty ? event.giftId : event.giftName);

    final targetCount = (event.targetOffsets != null && event.targetOffsets!.isNotEmpty)
        ? event.targetOffsets!.length
        : 1;

    final duration = AnimationTimeline.getTotalDuration(_metadata!.tier, targetCount: targetCount);
    _controller.duration = duration;

    _initParticles();
    _controller.reset();
    _controller.forward();
  }

  void _initParticles() {
    ParticlePoolManager().releaseAll();
    _activeParticles.clear();
    final random = Random();
    final count = min(36, GiftPipelineManager.to.maxAllowedParticles);

    for (int i = 0; i < count; i++) {
      final p = ParticlePoolManager().obtainParticle();
      p.x = 0;
      p.y = 0;
      final angle = random.nextDouble() * 2 * pi;
      final speed = random.nextDouble() * 120 + 30;
      p.vx = cos(angle) * speed;
      p.vy = sin(angle) * speed;
      p.size = random.nextDouble() * 10 + 4;
      p.alpha = 1.0;
      p.maxLife = random.nextDouble() * 0.8 + 0.4;
      p.color = _metadata?.themeColor ?? Colors.amber;
      _activeParticles.add(p);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    ParticlePoolManager().releaseAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event == null || _metadata == null) {
      return const SizedBox.shrink();
    }

    final event = widget.event!;
    final meta = _metadata!;
    final media = MediaQuery.of(context).size;

    final startPos = event.startOffset.dx > 0 && event.startOffset.dy > 0
        ? event.startOffset
        : Offset(media.width / 2, media.height * 0.88);
    final centerStage = Offset(media.width / 2, media.height * 0.40);
    final targets = (event.targetOffsets != null && event.targetOffsets!.isNotEmpty)
        ? event.targetOffsets!
        : [event.targetOffset];

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (!_controller.isAnimating) return const SizedBox.shrink();
          final progress = _controller.value;
          final stageInfo = AnimationTimeline.getStageProgress(progress, meta.tier, targetCount: targets.length);

          // ── CHAT MODE ──
          if (event.mode == GiftAnimationMode.chat) {
            final pos = Offset.lerp(startPos, event.targetOffset, Curves.easeOut.transform(progress))!;
            return IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    left: pos.dx - 20,
                    top: pos.dy - 20,
                    child: Transform.scale(
                      scale: 0.8 + sin(progress * pi) * 0.5,
                      child: Text(event.giftIcon, style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                ],
              ),
            );
          }

          // ── ROOM MODE: Dynamic Screen Coverage Matrix by Tier ──
          final double screenWidth = media.width;
          final double tierShowcaseBoxSize = meta.tier == GiftTier.tier5
              ? screenWidth // Tier 5: 100% Full Screen
              : meta.tier == GiftTier.tier4
                  ? screenWidth * 0.70 // Tier 4: 60–80% Screen Coverage
                  : meta.tier == GiftTier.tier3
                      ? screenWidth * 0.50 // Tier 3: 40–60% Screen Coverage
                      : meta.tier == GiftTier.tier2
                          ? screenWidth * 0.35 // Tier 2: 30–40% Screen Coverage
                          : screenWidth * 0.25; // Tier 1: 20–30% Screen Coverage

          final double tierIconSize = meta.tier == GiftTier.tier5
              ? screenWidth * 0.40
              : meta.tier == GiftTier.tier4
                  ? screenWidth * 0.28
                  : meta.tier == GiftTier.tier3
                      ? screenWidth * 0.22
                      : meta.tier == GiftTier.tier2
                          ? screenWidth * 0.16
                          : screenWidth * 0.12;

          final double tierBaseScale = 1.0;

          if (stageInfo.stage == AnimationStage.stageA) {
            // ── STEP 1: Launch from Sender Seat / Audience to Screen Center (1-2s) ──
            final p = Curves.easeOutCubic.transform(stageInfo.stageNormalizedProgress);
            final currentPos = Offset.lerp(startPos, centerStage, p)!;
            final scale = (0.3 + (p * (tierBaseScale - 0.3))).clamp(0.3, tierBaseScale);
            final opacity = p.clamp(0.0, 1.0);

            return IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GiftParticlePainter(
                        center: currentPos,
                        progress: progress,
                        particles: _activeParticles,
                        showcaseType: meta.showcaseType,
                        themeColor: meta.themeColor,
                      ),
                    ),
                  ),
                  Positioned(
                    left: currentPos.dx - 80,
                    top: currentPos.dy - 80,
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                event.giftIcon,
                                style: TextStyle(
                                  fontSize: tierIconSize,
                                  shadows: [
                                    Shadow(color: meta.themeColor.withOpacity(0.8), blurRadius: 20),
                                    const Shadow(color: Colors.black54, blurRadius: 12),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: meta.themeColor.withOpacity(0.7)),
                                ),
                                child: Text(
                                  '${event.senderName} ➔ ${event.giftName} x${event.count}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else if (stageInfo.stage == AnimationStage.stageB) {
            // ── STEP 2: Showcase Animation at Center Stage by Gift Tier ──
            final p = stageInfo.stageNormalizedProgress;
            final pulseScale = tierBaseScale + sin(p * pi * 3) * 0.15;
            double rotation = 0.0;
            if (meta.showcaseType == ShowcaseAnimationType.ringSpinShine ||
                meta.showcaseType == ShowcaseAnimationType.dragonFlies) {
              rotation = sin(p * pi * 4) * 0.3;
            }

            return IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Fullscreen Cinematic Lighting for Tier 4 & Tier 5 Gifts
                  if (meta.tier == GiftTier.tier4 || meta.tier == GiftTier.tier5)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.95,
                            colors: [
                              meta.themeColor.withOpacity(0.40),
                              Colors.black.withOpacity(0.75),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GiftParticlePainter(
                        center: centerStage,
                        progress: progress,
                        particles: _activeParticles,
                        showcaseType: meta.showcaseType,
                        themeColor: meta.themeColor,
                      ),
                    ),
                  ),
                  Positioned(
                    left: centerStage.dx - (tierShowcaseBoxSize / 2),
                    top: centerStage.dy - (tierShowcaseBoxSize / 2),
                    child: SizedBox(
                      width: tierShowcaseBoxSize,
                      height: tierShowcaseBoxSize,
                      child: Transform.scale(
                        scale: pulseScale,
                        child: Transform.rotate(
                          angle: rotation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                event.giftIcon,
                                style: TextStyle(
                                  fontSize: tierIconSize,
                                  shadows: [
                                    Shadow(color: meta.themeColor.withOpacity(0.9), blurRadius: 28),
                                    const Shadow(color: Colors.black87, blurRadius: 16),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: meta.themeColor, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(color: meta.themeColor.withOpacity(0.4), blurRadius: 10),
                                  ],
                                ),
                                child: Text(
                                  '${event.senderName} ➔ ${event.giftName} x${event.count}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // ── STEP 3: Split from Center Stage & Fly to Target Receiver Seats (1-2s) ──
            final p = Curves.easeOutCubic.transform(stageInfo.stageNormalizedProgress);

            return IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int i = 0; i < targets.length; i++) ...[
                    Builder(
                      builder: (context) {
                        final targetPos = targets[i];
                        final splitPos = Offset.lerp(centerStage, targetPos, p)!;
                        final splitScale = (tierBaseScale * (1.0 - p * 0.65)).clamp(0.35, tierBaseScale);
                        final splitOpacity = (1.0 - (p * 0.4)).clamp(0.0, 1.0);
                        final isArriving = p > 0.75;
                        final burstScale = isArriving ? (1.0 + sin((p - 0.75) * 4 * pi) * 0.4) : 1.0;

                        return Positioned(
                          left: splitPos.dx - 50,
                          top: splitPos.dy - 50,
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: Opacity(
                              opacity: splitOpacity,
                              child: Transform.scale(
                                scale: splitScale * burstScale,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      event.giftIcon,
                                      style: TextStyle(
                                        fontSize: 48,
                                        shadows: [
                                          Shadow(color: meta.themeColor.withOpacity(0.8), blurRadius: 16),
                                        ],
                                      ),
                                    ),
                                    if (isArriving)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: meta.themeColor.withOpacity(0.85),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '🎁 Received!',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class GiftParticlePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final List<PooledParticle> particles;
  final ShowcaseAnimationType showcaseType;
  final Color themeColor;

  GiftParticlePainter({
    required this.center,
    required this.progress,
    required this.particles,
    required this.showcaseType,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final lifeProgress = (progress / p.maxLife).clamp(0.0, 1.0);
      final alpha = (1.0 - lifeProgress) * p.alpha;
      if (alpha <= 0) continue;

      paint.color = themeColor.withOpacity(alpha.clamp(0.0, 1.0));
      final px = center.dx + p.vx * progress;
      final py = center.dy + p.vy * progress;

      canvas.drawCircle(Offset(px, py), p.size * (1.0 - lifeProgress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GiftParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.center != center;
  }
}
