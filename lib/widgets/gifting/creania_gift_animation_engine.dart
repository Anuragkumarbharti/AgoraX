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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GiftRequestEvent &&
          runtimeType == other.runtimeType &&
          giftId == other.giftId &&
          giftName == other.giftName &&
          senderName == other.senderName &&
          receiverName == other.receiverName &&
          count == other.count &&
          startOffset == other.startOffset &&
          targetOffset == other.targetOffset;

  @override
  int get hashCode =>
      giftId.hashCode ^
      giftName.hashCode ^
      senderName.hashCode ^
      receiverName.hashCode ^
      count.hashCode ^
      startOffset.hashCode ^
      targetOffset.hashCode;
}

class CreaniaGiftAnimationEngine extends StatefulWidget {
  final GiftRequestEvent? event;
  final VoidCallback? onCompleted;
  final VoidCallback? onImpact;

  const CreaniaGiftAnimationEngine({
    Key? key,
    this.event,
    this.onCompleted,
    this.onImpact,
  }) : super(key: key);

  @override
  State<CreaniaGiftAnimationEngine> createState() => _CreaniaGiftAnimationEngineState();
}

class _CreaniaGiftAnimationEngineState extends State<CreaniaGiftAnimationEngine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  GiftAnimationMetadata? _metadata;
  final List<PooledParticle> _activeParticles = [];
  bool _hasTriggeredImpact = false;

  // FIX: Use explicit start/complete flags instead of _controller.isAnimating.
  // isAnimating returns false during the reset()→forward() transition window,
  // causing a single-frame blank render that Flutter interprets as animation end.
  bool _hasStarted = false;
  bool _isCompleted = false;

  // ── Diagnostic timing fields (remove after root cause is confirmed) ──
  int _forwardCallCount = 0;
  int? _startTimestampMs;
  int? _firstFrameTimestampMs;
  bool _firstFrameLogged = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[GIFT] CONTROLLER CREATED | gift=${widget.event?.giftName}');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[GIFT] FIRST FRAME | gift=${widget.event?.giftName}');
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final endMs = DateTime.now().millisecondsSinceEpoch;
        final totalPlaybackMs = endMs - (_startTimestampMs ?? endMs);
        final configuredMs = _controller.duration?.inMilliseconds ?? 0;
        final speedRatio = totalPlaybackMs > 0
            ? (configuredMs / totalPlaybackMs).toStringAsFixed(2)
            : 'N/A';
        debugPrint('╔══════════════════════════════════════════════════════╗');
        debugPrint('[GIFT_TIMING] EFFECT END TIMESTAMP   : $endMs ms');
        debugPrint('[GIFT_TIMING] CONFIGURED DURATION    : ${configuredMs}ms');
        debugPrint('[GIFT_TIMING] TOTAL ACTUAL PLAYBACK  : ${totalPlaybackMs}ms');
        debugPrint('[GIFT_TIMING] SPEED RATIO            : ${speedRatio}x (1.0 = correct)');
        debugPrint('[GIFT_TIMING] FINAL CONTROLLER VALUE : ${_controller.value}');
        debugPrint('[GIFT_TIMING] FINAL STATUS           : ${_controller.status}');
        debugPrint('[GIFT_TIMING] FORWARD CALLS TOTAL    : $_forwardCallCount');
        debugPrint('[GIFT_TIMING] GIFT                   : ${widget.event?.giftName}');
        debugPrint('╚══════════════════════════════════════════════════════╝');
        _isCompleted = true;
        if (mounted && widget.onCompleted != null) widget.onCompleted!();
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
    if (widget.event != null && oldWidget.event != null) {
      if (widget.event != oldWidget.event) {
        debugPrint('[GIFT] WIDGET REBUILD (Updated Payload) | gift=${widget.event?.giftName}');
        _startAnimation(widget.event!);
      }
    }
  }

  void _startAnimation(GiftRequestEvent event) {
    _forwardCallCount++;
    _startTimestampMs = DateTime.now().millisecondsSinceEpoch;
    _firstFrameLogged = false;
    _hasTriggeredImpact = false;
    _isCompleted = false;
    _metadata = GiftMetadataRegistry.getMetadata(event.giftId.isNotEmpty ? event.giftId : event.giftName);

    final targetCount = (event.targetOffsets != null && event.targetOffsets!.isNotEmpty)
        ? event.targetOffsets!.length
        : 1;

    final duration = AnimationTimeline.getTotalDuration(_metadata!.tier, targetCount: targetCount);

    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('[GIFT_TIMING] EFFECT START TIMESTAMP : $_startTimestampMs ms');
    debugPrint('[GIFT_TIMING] CONFIGURED DURATION    : ${duration.inMilliseconds}ms');
    debugPrint('[GIFT_TIMING] CTRL DURATION BEFORE   : ${_controller.duration?.inMilliseconds}ms');
    debugPrint('[GIFT_TIMING] CTRL VALUE BEFORE RESET: ${_controller.value}');
    debugPrint('[GIFT_TIMING] CTRL STATUS BEFORE     : ${_controller.status}');
    debugPrint('[GIFT_TIMING] FORWARD CALL COUNT     : $_forwardCallCount (should be 1)');
    debugPrint('[GIFT_TIMING] GIFT                   : ${event.giftName} | tier: ${_metadata?.tier}');

    _controller.duration = duration;
    debugPrint('[GIFT_TIMING] CTRL DURATION AFTER SET: ${_controller.duration?.inMilliseconds}ms');

    _initParticles();
    // Mark started BEFORE reset+forward so no parent rebuild can blank us mid-transition.
    _hasStarted = true;
    _controller.reset();
    debugPrint('[GIFT_TIMING] VALUE AFTER RESET       : ${_controller.value} | status: ${_controller.status}');
    _controller.forward();
    debugPrint('[GIFT_TIMING] VALUE AFTER FORWARD     : ${_controller.value} | status: ${_controller.status} | isAnimating: ${_controller.isAnimating}');
    debugPrint('╚══════════════════════════════════════════════════════╝');
  }

  void _initParticles() {
    _activeParticles.clear();
    final random = Random();
    final count = min(42, GiftPipelineManager.to.maxAllowedParticles);

    for (int i = 0; i < count; i++) {
      final p = ParticlePoolManager().obtainParticle();
      p.x = 0;
      p.y = 0;
      final angle = random.nextDouble() * 2 * pi;
      final speed = random.nextDouble() * 140 + 30;
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
    final progress = (_controller.value * 100).toStringAsFixed(1);
    debugPrint('[GIFT] WIDGET DISPOSE | gift=${widget.event?.giftName}');
    debugPrint('[GIFT] CONTROLLER DISPOSE | gift=${widget.event?.giftName} | Progress: $progress%');
    _controller.dispose();
    ParticlePoolManager().releaseAll();
    super.dispose();
  }

  Widget _buildGiftVisual({required double size, Color? themeColor}) {
    final meta = _metadata;
    final event = widget.event!;
    final primaryAssetPath = meta?.resolvedGifAssetPath ?? 'assets/GIFTS_SHOWCCASE/${event.giftName.toUpperCase().replaceAll(' ', '_')}.gif';

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        primaryAssetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Secondary fallback to ROSE.gif if specific gift GIF is not added yet
          return Image.asset(
            'assets/GIFTS_SHOWCCASE/ROSE.gif',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, err, st) {
              // Final fallback to high-res icon
              return Center(
                child: Text(
                  event.giftIcon,
                  style: TextStyle(
                    fontSize: size * 0.65,
                    shadows: [
                      Shadow(
                        color: (themeColor ?? Colors.amber).withOpacity(0.9),
                        blurRadius: 24,
                      ),
                      const Shadow(color: Colors.black87, blurRadius: 14),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event == null || _metadata == null) {
      return const SizedBox.shrink();
    }

    final event = widget.event!;
    final meta = _metadata!;
    final media = MediaQuery.of(context).size;

    final startPos = (event.startOffset.dx > 0 && event.startOffset.dy > 0)
        ? event.startOffset
        : Offset(media.width * 0.20, media.height * 0.75);
    final centerStage = Offset(media.width / 2, media.height * 0.40);
    final rawTargets = (event.targetOffsets != null && event.targetOffsets!.isNotEmpty)
        ? event.targetOffsets!
        : [event.targetOffset];

    // Fallback off-seat / unseated targets to top of screen exit Offset(width/2, -100)
    final targets = rawTargets.map((t) {
      if (t.dx <= 0 || t.dy <= 0 || t == Offset.zero) {
        return Offset(media.width / 2, -100);
      }
      return t;
    }).toList();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // FIX: Do NOT use _controller.isAnimating — it returns false during
          // the reset()→forward() window (1 frame) AND before first start.
          // Use explicit flags that are immune to transient dismissed state.
          if (!_hasStarted || _isCompleted) return const SizedBox.shrink();

          // ── First frame timing log ──
          if (!_firstFrameLogged) {
            _firstFrameLogged = true;
            _firstFrameTimestampMs = DateTime.now().millisecondsSinceEpoch;
            final elapsedSinceStart = _firstFrameTimestampMs! - (_startTimestampMs ?? _firstFrameTimestampMs!);
            debugPrint('[GIFT_TIMING] FIRST FRAME TIMESTAMP  : $_firstFrameTimestampMs ms');
            debugPrint('[GIFT_TIMING] ELAPSED SINCE START     : ${elapsedSinceStart}ms');
            debugPrint('[GIFT_TIMING] CTRL VALUE AT 1ST FRAME : ${_controller.value}');
            debugPrint('[GIFT_TIMING] CTRL STATUS AT 1ST FRAME: ${_controller.status}');
          }

          final progress = _controller.value;
          final tenInfo = AnimationTimeline.getTenStageInfo(progress, meta.tier, targetCount: targets.length);
          final currentStage = tenInfo.stage;
          final localP = tenInfo.localProgress;

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

          // ── ROOM MODE: Dynamic Tier Showcase Dimensions Matrix ──
          final double baseShowcaseSize = meta.tier == GiftTier.tier5
              ? media.width * 1.00 // Tier 5: 100% Full Screen
              : meta.tier == GiftTier.tier4
                  ? media.width * 0.85 // Tier 4: 85% Screen Width
                  : meta.tier == GiftTier.tier3
                      ? media.width * 0.65 // Tier 3: 65% Screen Width
                      : meta.tier == GiftTier.tier2
                          ? media.width * 0.45 // Tier 2: 45% Screen Width
                          : media.width * 0.25; // Tier 1: 25% (20% - 30%) Screen Width

          // ── STAGE 1 & 2: Trigger from Seat -> Zoom Out from Seat ──
          if (currentStage == AnimationStage.stage1Trigger ||
              currentStage == AnimationStage.stage2ZoomOut) {
            final isTrigger = currentStage == AnimationStage.stage1Trigger;
            final p = isTrigger ? localP * 0.5 : 0.5 + (localP * 0.5);
            final easeP = Curves.easeOutBack.transform(p);
            final currentPos = Offset.lerp(startPos, centerStage, easeP)!;

            // Start size equals mic seat size (60px) -> scales up to baseShowcaseSize
            final currentVisualSize = 60.0 + (easeP * (baseShowcaseSize - 60.0));
            final opacity = (p * 2.5).clamp(0.0, 1.0);

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
                        stage: currentStage,
                      ),
                    ),
                  ),
                  Positioned(
                    left: currentPos.dx - (currentVisualSize / 2),
                    top: currentPos.dy - (currentVisualSize / 2),
                    child: SizedBox(
                      width: currentVisualSize,
                      height: currentVisualSize,
                      child: Opacity(
                        opacity: opacity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildGiftVisual(size: currentVisualSize * 0.70, themeColor: meta.themeColor),
                            const SizedBox(height: 2),
                            // Sender to Receiver Banner Text Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: meta.themeColor, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: meta.themeColor.withOpacity(0.40),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${event.senderName} sent ${event.giftName} x${event.count} to ${event.receiverName}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // ── STAGE 3 & 4: Center Screen Showcase & Mid Animation Effects ──
          if (currentStage == AnimationStage.stage3CenterShowcase ||
              currentStage == AnimationStage.stage4MidEffects) {
            final floatY = sin(progress * pi * 4) * 14.0;
            final rotationAngle = sin(progress * pi * 2) * 0.12;

            // Enlarge pulse for Center Showcase
            final showcaseScale = meta.tier == GiftTier.tier2
                ? 1.0 + sin(localP * pi) * 0.25 // Smooth pulse
                : 1.0 + sin(localP * pi) * 0.10;

            return IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Fullscreen Cinematic Grand Entrance Atmosphere for Tier 4 & Tier 5
                  if (meta.tier == GiftTier.tier4 || meta.tier == GiftTier.tier5)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.0,
                            colors: [
                              meta.themeColor.withOpacity(0.45),
                              Colors.black.withOpacity(0.85),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Atmospheric Smoke Clouds, Energy Particles, Fireworks & Radial Rays
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GiftParticlePainter(
                        center: centerStage,
                        progress: progress,
                        particles: _activeParticles,
                        showcaseType: meta.showcaseType,
                        themeColor: meta.themeColor,
                        stage: currentStage,
                      ),
                    ),
                  ),
                  Positioned(
                    left: centerStage.dx - (baseShowcaseSize / 2),
                    top: centerStage.dy - (baseShowcaseSize / 2) + floatY,
                    child: SizedBox(
                      width: baseShowcaseSize,
                      height: baseShowcaseSize,
                      child: Transform.scale(
                        scale: showcaseScale,
                        child: Transform.rotate(
                          angle: rotationAngle,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGiftVisual(size: baseShowcaseSize * 0.60, themeColor: meta.themeColor),
                              const SizedBox(height: 6),
                              // Sender Username sent Gift to Receiver Username Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: meta.themeColor, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: meta.themeColor.withOpacity(0.50),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${event.senderName} sent ${event.giftName} x${event.count} to ${event.receiverName}',
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
          }

          // ── STAGE 5 & 6: Split & Move to Receiver Seats (Shrinking to Mic Seat Size) ──
          if (currentStage == AnimationStage.stage5ZoomIn ||
              currentStage == AnimationStage.stage6MoveToReceiver) {
            final isZoomIn = currentStage == AnimationStage.stage5ZoomIn;
            final moveP = isZoomIn ? 0.0 : Curves.easeInCubic.transform(localP);

            return IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int i = 0; i < targets.length; i++) ...[
                    Builder(
                      builder: (context) {
                        final targetPos = targets[i];
                        // Quadratic Bezier curve calculation: Control point offset gives smooth natural curve
                        final curveOffset = Offset(sin(moveP * pi) * 60, -sin(moveP * pi) * 80);
                        final linearPos = Offset.lerp(centerStage, targetPos, moveP)!;
                        final bezierPos = linearPos + curveOffset;

                        // Smoothly shrink down from baseShowcaseSize to Mic Seat size (60px) as it approaches receiver seat
                        final currentSize = baseShowcaseSize - (moveP * (baseShowcaseSize - 60.0));
                        final flyOpacity = (1.0 - (moveP * 0.15)).clamp(0.0, 1.0);

                        return Positioned(
                          left: bezierPos.dx - (currentSize / 2),
                          top: bezierPos.dy - (currentSize / 2),
                          child: SizedBox(
                            width: currentSize,
                            height: currentSize,
                            child: Opacity(
                              opacity: flyOpacity,
                              child: _buildGiftVisual(size: currentSize * 0.70, themeColor: meta.themeColor),
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

          // ── STAGE 7, 8, 9, 10: Reach Receiver, Impact Halo Burst & Points ──
          final impactP = (currentStage == AnimationStage.stage7ReachReceiver)
              ? localP * 0.5
              : 0.5 + (localP * 0.5);

          final isArrived = currentStage == AnimationStage.stage7ReachReceiver ||
              currentStage == AnimationStage.stage8ImpactAnimation ||
              currentStage == AnimationStage.stage9UpdatePoints ||
              currentStage == AnimationStage.stage10Finish;

          if (isArrived && !_hasTriggeredImpact) {
            _hasTriggeredImpact = true;
            if (widget.onImpact != null) widget.onImpact!();
          }

          final pointsAdd = meta.tier == GiftTier.tier2 ? '+1000' : '+100';

          return IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < targets.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final targetPos = targets[i];
                      final elasticBounce = 1.0 + sin(impactP * pi) * 0.22;
                      final haloScale = 1.0 + (impactP * 0.8);
                      final haloOpacity = (1.0 - impactP).clamp(0.0, 1.0);

                      return Stack(
                        children: [
                          // Bright Golden Halo / Aura Impact Ring around Receiver Avatar
                          Positioned(
                            left: targetPos.dx - 55 * haloScale,
                            top: targetPos.dy - 55 * haloScale,
                            child: SizedBox(
                              width: 110 * haloScale,
                              height: 110 * haloScale,
                              child: Opacity(
                                opacity: haloOpacity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: meta.themeColor, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: meta.themeColor.withOpacity(0.85),
                                        blurRadius: 20 * haloScale,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Receiver Seat Impact Gift Absorption & Points Popup
                          Positioned(
                            left: targetPos.dx - 50,
                            top: targetPos.dy - 50,
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: Transform.scale(
                                scale: elasticBounce,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildGiftVisual(size: 44, themeColor: meta.themeColor),
                                    const SizedBox(height: 2),
                                    // +Points Badge Popup
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            meta.themeColor,
                                            Colors.orange.shade800,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black54, blurRadius: 4),
                                        ],
                                      ),
                                      child: Text(
                                        '🎁 $pointsAdd',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          );
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
  final AnimationStage stage;

  GiftParticlePainter({
    required this.center,
    required this.progress,
    required this.particles,
    required this.showcaseType,
    required this.themeColor,
    required this.stage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    if (stage == AnimationStage.stage3CenterShowcase ||
        stage == AnimationStage.stage4MidEffects) {
      // 1. Draw Volumetric Atmospheric Smoke / Cloud Energy Puffs (matching Mic Seat Smoke image)
      final smokePaint = Paint()
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

      final random = Random(center.dx.toInt() + 42);
      for (int i = 0; i < 8; i++) {
        final angle = (i * (2 * pi / 8)) + (progress * pi);
        final dist = 40.0 + sin(progress * pi * 3 + i) * 20.0;
        final cx = center.dx + cos(angle) * dist;
        final cy = center.dy + sin(angle) * dist;

        final smokeAlpha = (0.35 + 0.15 * sin(progress * pi * 4 + i)).clamp(0.0, 0.55);
        smokePaint.color = Colors.white.withOpacity(smokeAlpha * 0.45);
        canvas.drawCircle(Offset(cx, cy), 45.0 + (i * 6.0), smokePaint);

        smokePaint.color = themeColor.withOpacity(smokeAlpha * 0.50);
        canvas.drawCircle(Offset(cx + 10, cy - 10), 35.0, smokePaint);
      }

      // 2. Rotating Radial Energy Rays
      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      for (int r = 0; r < 12; r++) {
        final rayAngle = (r * (2 * pi / 12)) + (progress * pi * 2);
        final rayLen = 90.0 + sin(progress * pi * 6 + r) * 30.0;
        final rayStart = Offset(center.dx + cos(rayAngle) * 30, center.dy + sin(rayAngle) * 30);
        final rayEnd = Offset(center.dx + cos(rayAngle) * rayLen, center.dy + sin(rayAngle) * rayLen);

        final rayAlpha = (0.6 - (rayLen / 150.0)).clamp(0.1, 0.6);
        rayPaint.color = themeColor.withOpacity(rayAlpha);
        canvas.drawLine(rayStart, rayEnd, rayPaint);
      }

      // 3. Central Glowing Aura Ring
      final auraPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..color = themeColor.withOpacity(0.70);
      canvas.drawCircle(center, 70.0 + sin(progress * pi * 4) * 15.0, auraPaint);
    }

    // 4. Draw background fireworks & sparkle particles during center showcase
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
    return oldDelegate.progress != progress || oldDelegate.center != center || oldDelegate.stage != stage;
  }
}

