// lib/services/gifting/animation_timeline.dart

import '../../models/gift/gift_animation_metadata.dart';

enum AnimationStage {
  stage1Trigger, // Stage 1: Gift Trigger from Seat (0-200ms)
  stage2ZoomOut, // Stage 2: Zoom Out from Seat (200-500ms)
  stage3CenterShowcase, // Stage 3: Center Screen Showcase (Center 2.5x-3.5x size)
  stage4MidEffects, // Stage 4: Mid Animation Effects (Fireworks, clouds, rays, floating)
  stage5ZoomIn, // Stage 5: Zoom In towards receiver vector
  stage6MoveToReceiver, // Stage 6: Natural Curved Bezier path travel to receiver
  stage7ReachReceiver, // Stage 7: Reach Receiver & Elastic bounce
  stage8ImpactAnimation, // Stage 8: Impact Golden Aura/Halo burst & absorption
  stage9UpdatePoints, // Stage 9: Update Points & Total (+100 / +1000)
  stage10Finish, // Stage 10: Animation Complete & Cleanup
  // Legacy aliases
  stageA,
  stageB,
  stageC,
}

class TenStageInfo {
  final AnimationStage stage;
  final double localProgress; // 0.0 to 1.0 within current stage
  final double totalProgress; // 0.0 to 1.0 overall animation progress

  TenStageInfo({
    required this.stage,
    required this.localProgress,
    required this.totalProgress,
  });
}

class StageProgress {
  final AnimationStage stage;
  final double stageNormalizedProgress; // 0.0 to 1.0 within this specific stage

  StageProgress(this.stage, this.stageNormalizedProgress);
}

/// Enforces the 10-Stage Gift Animation Pipeline:
/// 1. Trigger from Seat
/// 2. Zoom Out
/// 3. Animate in Middle
/// 4. Mid Animation Effects
/// 5. Zoom In
/// 6. Move to Receiver (Curved Bezier Path)
/// 7. Reach Receiver
/// 8. Impact Animation
/// 9. Update Points & Total
/// 10. Animation Complete
class AnimationTimeline {
  /// 3-Part Modular 60 FPS Timeline Engine:
  /// Part 1: COME (Seat ➔ Center Showcase) = Uniform 500ms (30 frames at 60 FPS across ALL Tiers)
  /// Part 2: SHOWCASE (Center Screen Animation) = Tier-based (900ms, 1440ms, 2040ms, 3000ms, 4200ms)
  /// Part 3: GO (Center Showcase ➔ Receiver Seat) = Uniform 600ms (36 frames at 60 FPS across ALL Tiers) + 150ms Impact Badge
  static Duration getTotalDuration(GiftTier tier, {int targetCount = 1}) {
    switch (tier) {
      case GiftTier.tier1:
        return const Duration(milliseconds: 2150);
      case GiftTier.tier2:
        return const Duration(milliseconds: 2690);
      case GiftTier.tier3:
        return const Duration(milliseconds: 3290);
      case GiftTier.tier4:
        return const Duration(milliseconds: 4250);
      case GiftTier.tier5:
        return const Duration(milliseconds: 5450);
    }
  }

  /// Calculates stage durations array for the 60 FPS 3-Part Pipeline:
  /// Part 1 (COME: 500ms = 250+250) | Part 2 (SHOWCASE: Tier-based) | Part 3 (GO: 600ms = 150+330+120) | Impact: 150ms
  static List<double> getStageWeights(GiftTier tier, {int targetCount = 1}) {
    switch (tier) {
      case GiftTier.tier1:
        // COME: 500ms (250, 250) | SHOWCASE: 900ms (450, 450) | GO: 600ms (150, 330, 120) | IMPACT: 150ms (75, 38, 37)
        return [250, 250, 450, 450, 150, 330, 120, 75, 38, 37];
      case GiftTier.tier2:
        // COME: 500ms (250, 250) | SHOWCASE: 1440ms (720, 720) | GO: 600ms (150, 330, 120) | IMPACT: 150ms (75, 38, 37)
        return [250, 250, 720, 720, 150, 330, 120, 75, 38, 37];
      case GiftTier.tier3:
        // COME: 500ms (250, 250) | SHOWCASE: 2040ms (1020, 1020) | GO: 600ms (150, 330, 120) | IMPACT: 150ms (75, 38, 37)
        return [250, 250, 1020, 1020, 150, 330, 120, 75, 38, 37];
      case GiftTier.tier4:
        // COME: 500ms (250, 250) | SHOWCASE: 3000ms (1500, 1500) | GO: 600ms (150, 330, 120) | IMPACT: 150ms (75, 38, 37)
        return [250, 250, 1500, 1500, 150, 330, 120, 75, 38, 37];
      case GiftTier.tier5:
        // COME: 500ms (250, 250) | SHOWCASE: 4200ms (2100, 2100) | GO: 600ms (150, 330, 120) | IMPACT: 150ms (75, 38, 37)
        return [250, 250, 2100, 2100, 150, 330, 120, 75, 38, 37];
    }
  }

  /// Calculates exact 10-Stage progress info for total progress value (0.0 to 1.0)
  static TenStageInfo getTenStageInfo(double progress, GiftTier tier,
      {int targetCount = 1}) {
    final weights = getStageWeights(tier, targetCount: targetCount);
    final totalMs = weights.reduce((a, b) => a + b);
    final clampedP = progress.clamp(0.0, 1.0);
    final currentMs = clampedP * totalMs;

    double accumulated = 0.0;
    final stages = [
      AnimationStage.stage1Trigger,
      AnimationStage.stage2ZoomOut,
      AnimationStage.stage3CenterShowcase,
      AnimationStage.stage4MidEffects,
      AnimationStage.stage5ZoomIn,
      AnimationStage.stage6MoveToReceiver,
      AnimationStage.stage7ReachReceiver,
      AnimationStage.stage8ImpactAnimation,
      AnimationStage.stage9UpdatePoints,
      AnimationStage.stage10Finish,
    ];

    for (int i = 0; i < weights.length; i++) {
      final stageMs = weights[i];
      if (currentMs <= accumulated + stageMs || i == weights.length - 1) {
        final localP = ((currentMs - accumulated) / stageMs).clamp(0.0, 1.0);
        return TenStageInfo(
          stage: stages[i],
          localProgress: localP,
          totalProgress: clampedP,
        );
      }
      accumulated += stageMs;
    }

    return TenStageInfo(
      stage: AnimationStage.stage10Finish,
      localProgress: 1.0,
      totalProgress: 1.0,
    );
  }

  /// Legacy helper method for backward compatibility
  static StageProgress getStageProgress(double progress, GiftTier tier,
      {int targetCount = 1}) {
    final info = getTenStageInfo(progress, tier, targetCount: targetCount);
    if (info.stage == AnimationStage.stage1Trigger ||
        info.stage == AnimationStage.stage2ZoomOut) {
      return StageProgress(AnimationStage.stageA, info.localProgress);
    } else if (info.stage == AnimationStage.stage3CenterShowcase ||
        info.stage == AnimationStage.stage4MidEffects) {
      return StageProgress(AnimationStage.stageB, info.localProgress);
    } else {
      return StageProgress(AnimationStage.stageC, info.localProgress);
    }
  }
}
