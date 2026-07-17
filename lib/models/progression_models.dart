import 'dart:convert';

class UserProgressModel {
  final String id;
  final int level;
  final int xp;
  final int totalXp;
  final int todayEarnedXp;
  final int todayBonusXp;
  final int weeklyXp;
  final int monthlyXp;
  final DateTime? lastXpUpdate;

  UserProgressModel({
    required this.id,
    required this.level,
    required this.xp,
    required this.totalXp,
    required this.todayEarnedXp,
    required this.todayBonusXp,
    required this.weeklyXp,
    required this.monthlyXp,
    this.lastXpUpdate,
  });

  factory UserProgressModel.fromJson(Map<String, dynamic> json) {
    return UserProgressModel(
      id: json['id'] ?? '',
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      totalXp: json['total_xp'] ?? 0,
      todayEarnedXp: json['today_earned_xp'] ?? 0,
      todayBonusXp: json['today_bonus_xp'] ?? 0,
      weeklyXp: json['weekly_xp'] ?? 0,
      monthlyXp: json['monthly_xp'] ?? 0,
      lastXpUpdate: json['last_xp_update'] != null
          ? DateTime.tryParse(json['last_xp_update'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level,
      'xp': xp,
      'total_xp': totalXp,
      'today_earned_xp': todayEarnedXp,
      'today_bonus_xp': todayBonusXp,
      'weekly_xp': weeklyXp,
      'monthly_xp': monthlyXp,
      'last_xp_update': lastXpUpdate?.toIso8601String(),
    };
  }
}

class TaskRewardModel {
  final String rewardType;
  final int amount;
  final String? cosmeticId;

  TaskRewardModel({
    required this.rewardType,
    required this.amount,
    this.cosmeticId,
  });

  factory TaskRewardModel.fromJson(Map<String, dynamic> json) {
    return TaskRewardModel(
      rewardType: json['reward_type'] ?? '',
      amount: json['amount'] ?? 0,
      cosmeticId: json['cosmetic_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reward_type': rewardType,
      'amount': amount,
      'cosmetic_id': cosmeticId,
    };
  }
}

class TaskModel {
  final String taskId;
  final String type; // daily, weekly, monthly, season
  final String title;
  final String? description;
  final String requiredAction;
  final int requiredCount;
  final int priority;
  final int currentCount;
  final bool isCompleted;
  final bool isClaimed;
  final List<TaskRewardModel> rewards;

  TaskModel({
    required this.taskId,
    required this.type,
    required this.title,
    this.description,
    required this.requiredAction,
    required this.requiredCount,
    required this.priority,
    required this.currentCount,
    required this.isCompleted,
    required this.isClaimed,
    required this.rewards,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    var rawRewards = json['rewards'] as List?;
    List<TaskRewardModel> parsedRewards = rawRewards != null
        ? rawRewards.map((r) => TaskRewardModel.fromJson(r)).toList()
        : [];

    return TaskModel(
      taskId: json['task_id'] ?? '',
      type: json['type'] ?? 'daily',
      title: json['title'] ?? '',
      description: json['description'],
      requiredAction: json['required_action'] ?? '',
      requiredCount: json['required_count'] ?? 1,
      priority: json['priority'] ?? 0,
      currentCount: json['current_count'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      isClaimed: json['is_claimed'] ?? false,
      rewards: parsedRewards,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'type': type,
      'title': title,
      'description': description,
      'required_action': requiredAction,
      'required_count': requiredCount,
      'priority': priority,
      'current_count': currentCount,
      'is_completed': isCompleted,
      'is_claimed': isClaimed,
      'rewards': rewards.map((r) => r.toJson()).toList(),
    };
  }
}

class CheckinStatusModel {
  final String monthKey;
  final List<int> claimedDays;
  final bool canClaimToday;
  final int nextDayToClaim;
  final int streakCount;
  final int weekStart;
  final int weekEnd;

  CheckinStatusModel({
    required this.monthKey,
    required this.claimedDays,
    required this.canClaimToday,
    required this.nextDayToClaim,
    required this.streakCount,
    required this.weekStart,
    required this.weekEnd,
  });

  factory CheckinStatusModel.fromJson(Map<String, dynamic> json) {
    var rawDays = json['claimed_days'] as List?;
    List<int> parsedDays = rawDays != null ? List<int>.from(rawDays) : [];

    return CheckinStatusModel(
      monthKey: json['month_key'] ?? '',
      claimedDays: parsedDays,
      canClaimToday: json['can_claim_today'] ?? false,
      nextDayToClaim: json['next_day_to_claim'] ?? 1,
      streakCount: json['streak_count'] ?? 0,
      weekStart: json['week_start'] ?? 1,
      weekEnd: json['week_end'] ?? 7,
    );
  }
}

class SpinRewardModel {
  final String id;
  final String spinType;
  final String rewardType;
  final int amount;
  final String? cosmeticId;
  final double probability;
  final bool isActive;

  SpinRewardModel({
    required this.id,
    required this.spinType,
    required this.rewardType,
    required this.amount,
    this.cosmeticId,
    required this.probability,
    required this.isActive,
  });

  factory SpinRewardModel.fromJson(Map<String, dynamic> json) {
    return SpinRewardModel(
      id: json['id'] ?? '',
      spinType: json['spin_type'] ?? '',
      rewardType: json['reward_type'] ?? '',
      amount: json['amount'] ?? 0,
      cosmeticId: json['cosmetic_id'],
      probability: (json['probability'] ?? 0.0).toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }
}

class SpinResultModel {
  final bool success;
  final String? wonRewardType;
  final int wonAmount;
  final String? wonCosmeticId;
  final String? reason;

  SpinResultModel({
    required this.success,
    this.wonRewardType,
    required this.wonAmount,
    this.wonCosmeticId,
    this.reason,
  });

  factory SpinResultModel.fromJson(Map<String, dynamic> json) {
    return SpinResultModel(
      success: json['success'] ?? false,
      wonRewardType: json['won_reward_type'],
      wonAmount: json['won_amount'] ?? 0,
      wonCosmeticId: json['won_cosmetic_id'],
      reason: json['reason'],
    );
  }
}

class AchievementModel {
  final String achievementId;
  final String title;
  final String? description;
  final String requiredAction;
  final int requiredCount;
  final String rewardType;
  final int rewardAmount;
  final String? rewardCosmeticId;
  final int currentCount;
  final bool isCompleted;
  final bool isClaimed;

  AchievementModel({
    required this.achievementId,
    required this.title,
    this.description,
    required this.requiredAction,
    required this.requiredCount,
    required this.rewardType,
    required this.rewardAmount,
    this.rewardCosmeticId,
    required this.currentCount,
    required this.isCompleted,
    required this.isClaimed,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      achievementId: json['achievement_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      requiredAction: json['required_action'] ?? '',
      requiredCount: json['required_count'] ?? 1,
      rewardType: json['reward_type'] ?? 'xp',
      rewardAmount: json['reward_amount'] ?? 0,
      rewardCosmeticId: json['reward_cosmetic_id'],
      currentCount: json['current_count'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      isClaimed: json['is_claimed'] ?? false,
    );
  }
}

class LoyaltyMilestoneModel {
  final int requiredDays;
  final String rewardType;
  final int amount;
  final String? cosmeticId;
  final bool isClaimed;

  LoyaltyMilestoneModel({
    required this.requiredDays,
    required this.rewardType,
    required this.amount,
    this.cosmeticId,
    required this.isClaimed,
  });

  factory LoyaltyMilestoneModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyMilestoneModel(
      requiredDays: json['required_days'] ?? 0,
      rewardType: json['reward_type'] ?? 'silver',
      amount: json['amount'] ?? 0,
      cosmeticId: json['cosmetic_id'],
      isClaimed: json['is_claimed'] ?? false,
    );
  }
}

class LoyaltyStatusModel {
  final int totalActiveDays;
  final List<LoyaltyMilestoneModel> milestones;

  LoyaltyStatusModel({
    required this.totalActiveDays,
    required this.milestones,
  });

  factory LoyaltyStatusModel.fromJson(Map<String, dynamic> json) {
    var rawMilestones = json['milestones'] as List?;
    List<LoyaltyMilestoneModel> parsedMilestones = rawMilestones != null
        ? rawMilestones.map((m) => LoyaltyMilestoneModel.fromJson(m)).toList()
        : [];

    return LoyaltyStatusModel(
      totalActiveDays: json['total_active_days'] ?? 0,
      milestones: parsedMilestones,
    );
  }
}
