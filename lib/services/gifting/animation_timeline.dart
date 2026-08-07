import '../../models/gift/gift_animation_metadata.dart';

enum AnimationStage { stageA, stageB, stageC }

class StageProgress {
  final AnimationStage stage;
  final double stageNormalizedProgress; // 0.0 to 1.0 within this specific stage

  StageProgress(this.stage, this.stageNormalizedProgress);
}

/// Enforces 3 independent stages strictly in sequence:
/// Stage A: Launch Animation (1 to 2.5 sec depending on tier)
/// Stage B: Main Center Showcase (2 to 10 sec depending on tier)
/// Stage C: Receiver Delivery (1 to 4 sec depending on single vs multi-seat targets)
class AnimationTimeline {
  /// Returns Stage A (Launch Travel) duration based on Gift Tier
  static Duration getStageADuration(GiftTier tier) {
    switch (tier) {
      case GiftTier.tier1:
        return const Duration(milliseconds: 800); // 0.8s
      case GiftTier.tier2:
        return const Duration(milliseconds: 1000); // 1.0s
      case GiftTier.tier3:
        return const Duration(milliseconds: 1200); // 1.2s
      case GiftTier.tier4:
        return const Duration(milliseconds: 1500); // 1.5s
      case GiftTier.tier5:
        return const Duration(milliseconds: 2000); // 2.0s
    }
  }

  /// Returns Stage B (Center Showcase) duration based on Gift Tier
  static Duration getStageBDuration(GiftTier tier) {
    switch (tier) {
      case GiftTier.tier1:
        return const Duration(milliseconds: 3000); // Tier 1: 3.0s showcase (2-4s range)
      case GiftTier.tier2:
        return const Duration(milliseconds: 5000); // Tier 2: 5.0s showcase (4-6s range)
      case GiftTier.tier3:
        return const Duration(milliseconds: 7000); // Tier 3: 7.0s showcase (6-8s range)
      case GiftTier.tier4:
        return const Duration(milliseconds: 9000); // Tier 4: 9.0s showcase (8-10s range)
      case GiftTier.tier5:
        return const Duration(milliseconds: 10000); // Tier 5: 10.0s full showcase
    }
  }

  /// Returns Stage C (Receiver Delivery Travel) duration based on Gift Tier
  static Duration getStageCDuration(GiftTier tier, {int targetCount = 1}) {
    int baseMs = 800;
    switch (tier) {
      case GiftTier.tier1:
        baseMs = 800; // 0.8s
        break;
      case GiftTier.tier2:
        baseMs = 1000; // 1.0s
        break;
      case GiftTier.tier3:
        baseMs = 1200; // 1.2s
        break;
      case GiftTier.tier4:
        baseMs = 1500; // 1.5s
        break;
      case GiftTier.tier5:
        baseMs = 2000; // 2.0s
        break;
    }
    if (targetCount > 1) {
      baseMs = (baseMs + 300).clamp(1000, 2500);
    }
    return Duration(milliseconds: baseMs);
  }

  /// Calculates total timeline duration (Stage A + Stage B + Stage C)
  static Duration getTotalDuration(GiftTier tier, {int targetCount = 1}) {
    return getStageADuration(tier) + getStageBDuration(tier) + getStageCDuration(tier, targetCount: targetCount);
  }

  /// Resolves current Stage and localized 0.0-1.0 progress for given total progress (0.0 - 1.0)
  static StageProgress getStageProgress(double progress, GiftTier tier, {int targetCount = 1}) {
    final totalMs = getTotalDuration(tier, targetCount: targetCount).inMilliseconds.toDouble();
    final stageAMs = getStageADuration(tier).inMilliseconds.toDouble();
    final stageBMs = getStageBDuration(tier).inMilliseconds.toDouble();

    final thresholdA = stageAMs / totalMs;
    final thresholdB = (stageAMs + stageBMs) / totalMs;

    if (progress < thresholdA) {
      final localProgress = (progress / thresholdA).clamp(0.0, 1.0);
      return StageProgress(AnimationStage.stageA, localProgress);
    } else if (progress < thresholdB) {
      final localProgress =
          ((progress - thresholdA) / (thresholdB - thresholdA)).clamp(0.0, 1.0);
      return StageProgress(AnimationStage.stageB, localProgress);
    } else {
      final localProgress =
          ((progress - thresholdB) / (1.0 - thresholdB)).clamp(0.0, 1.0);
      return StageProgress(AnimationStage.stageC, localProgress);
    }
  }
}
