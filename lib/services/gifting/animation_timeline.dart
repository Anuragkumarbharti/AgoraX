import '../../models/gift/gift_animation_metadata.dart';

enum AnimationStage { stageA, stageB, stageC }

class StageProgress {
  final AnimationStage stage;
  final double stageNormalizedProgress; // 0.0 to 1.0 within this specific stage

  StageProgress(this.stage, this.stageNormalizedProgress);
}

/// Enforces the 3 independent stages strictly in sequence:
/// Stage A: Launch Animation (1 sec)
/// Stage B: Main Gift Animation (2 sec Small, 3 sec Premium, 4 sec Epic, 5 sec Legendary, 6 sec Ultra)
/// Stage C: Receiver Delivery (1 sec)
/// Stage B MUST finish completely before Stage C starts.
class AnimationTimeline {
  static const Duration stageADuration = Duration(seconds: 1); // 1 sec Launch
  static const Duration stageCDuration = Duration(seconds: 1); // 1 sec Receiver Delivery

  /// Returns Stage B duration based on Gift Tier
  static Duration getStageBDuration(GiftTier tier) {
    switch (tier) {
      case GiftTier.basic:
        return const Duration(seconds: 2);
      case GiftTier.premium:
        return const Duration(seconds: 3);
      case GiftTier.epic:
        return const Duration(seconds: 4);
      case GiftTier.legendary:
        return const Duration(seconds: 5);
      case GiftTier.mythic:
        return const Duration(seconds: 6);
    }
  }

  /// Calculates total timeline duration (Stage A + Stage B + Stage C)
  static Duration getTotalDuration(GiftTier tier) {
    return stageADuration + getStageBDuration(tier) + stageCDuration;
  }

  /// Resolves current Stage and localized 0.0-1.0 progress for given total progress (0.0 - 1.0)
  static StageProgress getStageProgress(double progress, GiftTier tier) {
    final totalMs = getTotalDuration(tier).inMilliseconds.toDouble();
    final stageAMs = stageADuration.inMilliseconds.toDouble();
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
