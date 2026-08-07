// lib/services/gifting/animation_timeline.dart

import '../../models/gift/gift_animation_metadata.dart';

enum AnimationStage {
  stage1Trigger,        // Stage 1: Gift Trigger from Seat (0-200ms)
  stage2ZoomOut,        // Stage 2: Zoom Out from Seat (200-500ms)
  stage3CenterShowcase, // Stage 3: Center Screen Showcase (Center 2.5x-3.5x size)
  stage4MidEffects,     // Stage 4: Mid Animation Effects (Fireworks, clouds, rays, floating)
  stage5ZoomIn,         // Stage 5: Zoom In towards receiver vector
  stage6MoveToReceiver, // Stage 6: Natural Curved Bezier path travel to receiver
  stage7ReachReceiver,  // Stage 7: Reach Receiver & Elastic bounce
  stage8ImpactAnimation, // Stage 8: Impact Golden Aura/Halo burst & absorption
  stage9UpdatePoints,   // Stage 9: Update Points & Total (+100 / +1000)
  stage10Finish,        // Stage 10: Animation Complete & Cleanup
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
  /// Returns Center Showcase duration (Stage 3 & 4 combined) based on Gift Tier
  static Duration getShowcaseDuration(GiftTier tier) {
    switch (tier) {
      case GiftTier.tier1:
        return const Duration(milliseconds: 3000); // Tier 1: Minimum 3.0s center showcase
      case GiftTier.tier2:
        return const Duration(milliseconds: 5000); // Tier 2: 5.0s center showcase
      case GiftTier.tier3:
        return const Duration(milliseconds: 7000); // Tier 3: 7.0s center showcase
      case GiftTier.tier4:
        return const Duration(milliseconds: 9000); // Tier 4: 9.0s center showcase
      case GiftTier.tier5:
        return const Duration(milliseconds: 10000); // Tier 5: 10.0s legendary showcase
    }
  }

  /// Calculates stage durations array for given Gift Tier & target count
  static List<double> getStageWeights(GiftTier tier, {int targetCount = 1}) {
    final showcaseMs = getShowcaseDuration(tier).inMilliseconds.toDouble();

    // Base durations in ms:
    // Stage 1: 200ms (Trigger)
    // Stage 2: 300ms (Zoom Out)
    // Stage 3: showcaseMs * 0.45 (Center Showcase Entry)
    // Stage 4: showcaseMs * 0.55 (Mid Animation Effects)
    // Stage 5: 300ms (Zoom In / Direction Align)
    // Stage 6: 800ms (Move to Receiver Curved Path)
    // Stage 7: 200ms (Reach Receiver & Bounce)
    // Stage 8: 400ms (Impact Golden Halo Burst)
    // Stage 9: 200ms (Update Points & Total)
    // Stage 10: 200ms (Animation Complete Fade)
    final double s1 = 200;
    final double s2 = 300;
    final double s3 = showcaseMs * 0.45;
    final double s4 = showcaseMs * 0.55;
    final double s5 = 300;
    final double s6 = targetCount > 1 ? 1100 : 800;
    final double s7 = 200;
    final double s8 = 400;
    final double s9 = 200;
    final double s10 = 200;

    return [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10];
  }

  /// Returns total animation timeline duration
  static Duration getTotalDuration(GiftTier tier, {int targetCount = 1}) {
    final weights = getStageWeights(tier, targetCount: targetCount);
    final totalMs = weights.reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs.toInt());
  }

  /// Calculates exact 10-Stage progress info for total progress value (0.0 to 1.0)
  static TenStageInfo getTenStageInfo(double progress, GiftTier tier, {int targetCount = 1}) {
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
  static StageProgress getStageProgress(double progress, GiftTier tier, {int targetCount = 1}) {
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
