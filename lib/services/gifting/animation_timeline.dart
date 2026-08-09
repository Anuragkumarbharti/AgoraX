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
  /// Returns total animation timeline duration matching exact tier timing rules:
  /// Tier 1: 1.2s (1200ms)
  /// Tier 2: 1.8s (1800ms)
  /// Tier 3: 2.5s (2500ms)
  /// Tier 4: 3.5s (3500ms)
  /// Tier 5: 5.0s (5000ms)
  static Duration getTotalDuration(GiftTier tier, {int targetCount = 1}) {
    switch (tier) {
      case GiftTier.tier1:
        return const Duration(milliseconds: 1200);
      case GiftTier.tier2:
        return const Duration(milliseconds: 1800);
      case GiftTier.tier3:
        return const Duration(milliseconds: 2500);
      case GiftTier.tier4:
        return const Duration(milliseconds: 3500);
      case GiftTier.tier5:
        return const Duration(milliseconds: 5000);
    }
  }

  /// Calculates stage durations array matching exact stage timeline flow
  static List<double> getStageWeights(GiftTier tier, {int targetCount = 1}) {
    final double totalMs = getTotalDuration(tier, targetCount: targetCount).inMilliseconds.toDouble();

    switch (tier) {
      case GiftTier.tier1:
        // 0-150ms entry | 150-900ms main (750ms) | 900-1200ms exit (300ms)
        return [75, 75, 375, 375, 50, 100, 50, 50, 25, 25];
      case GiftTier.tier2:
        // 0-200ms entry | 200-1400ms main (1200ms) | 1400-1800ms exit (400ms)
        return [100, 100, 600, 600, 60, 140, 60, 60, 40, 40];
      case GiftTier.tier3:
        // 0-300ms entry | 300-2000ms main (1700ms) | 2000-2500ms exit (500ms)
        return [150, 150, 850, 850, 80, 180, 80, 80, 40, 40];
      case GiftTier.tier4:
        // 0-400ms entry | 400-2900ms main (2500ms) | 2900-3500ms exit (600ms)
        return [200, 200, 1250, 1250, 100, 200, 100, 100, 50, 50];
      case GiftTier.tier5:
        // 0-500ms entry | 500-4000ms main (3500ms) | 4000-5000ms exit (1000ms)
        return [250, 250, 1750, 1750, 150, 350, 150, 150, 100, 100];
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
