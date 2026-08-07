import '../../models/gift/gift_animation_metadata.dart';

enum AnimationStage { stageA, stageB, stageC }

class StageProgress {
  final AnimationStage stage;
  final double stageNormalizedProgress; // 0.0 to 1.0 within this specific stage

  StageProgress(this.stage, this.stageNormalizedProgress);
}

/// Enforces the 3 independent stages strictly in sequence:
/// Stage A: Launch Animation (1 to 3 sec depending on tier/distance)
/// Stage B: Main Gift Showcase (2 to 10 sec depending on tier)
/// Stage C: Receiver Delivery (1 to 6 sec depending on single vs multi-seat targets)
/// Stage B MUST finish completely before Stage C starts.
class AnimationTimeline {
  /// Returns Stage A (Launch) duration: 1 to 3 seconds based on Gift Tier
  static Duration getStageADuration(GiftTier tier) {
    switch (tier) {
      case GiftTier.basic:
        return const Duration(milliseconds: 1000); // 1.0 sec
      case GiftTier.premium:
        return const Duration(milliseconds: 1500); // 1.5 sec
      case GiftTier.epic:
        return const Duration(milliseconds: 2000); // 2.0 sec
      case GiftTier.legendary:
        return const Duration(milliseconds: 2500); // 2.5 sec
      case GiftTier.mythic:
        return const Duration(milliseconds: 3000); // 3.0 sec
    }
  }

  /// Returns Stage B (Center Showcase) duration: 2 to 10 seconds based on Gift Tier
  static Duration getStageBDuration(GiftTier tier) {
    switch (tier) {
      case GiftTier.basic:
        return const Duration(seconds: 2); // 2.0 sec
      case GiftTier.premium:
        return const Duration(seconds: 4); // 4.0 sec
      case GiftTier.epic:
        return const Duration(seconds: 6); // 6.0 sec
      case GiftTier.legendary:
        return const Duration(seconds: 8); // 8.0 sec
      case GiftTier.mythic:
        return const Duration(seconds: 10); // 10.0 sec
    }
  }

  /// Returns Stage C (Receiver Delivery) duration: 1 to 6 seconds based on Gift Tier and recipient count
  static Duration getStageCDuration(GiftTier tier, {int targetCount = 1}) {
    int baseSeconds = 1;
    switch (tier) {
      case GiftTier.basic:
        baseSeconds = 1;
        break;
      case GiftTier.premium:
        baseSeconds = 2;
        break;
      case GiftTier.epic:
        baseSeconds = 3;
        break;
      case GiftTier.legendary:
        baseSeconds = 4;
        break;
      case GiftTier.mythic:
        baseSeconds = 5;
        break;
    }

    if (targetCount > 1) {
      baseSeconds = (baseSeconds + 1).clamp(2, 6);
    }
    return Duration(seconds: baseSeconds.clamp(1, 6));
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
