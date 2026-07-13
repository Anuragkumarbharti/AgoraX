class RoomDailyTask {
  final String taskKey;
  final String description;
  final int targetValue;
  final int currentValue;
  final int taskPoints;
  final int xpReward;
  final int silverReward;
  final int goldReward;
  final bool isCompleted;

  RoomDailyTask({
    required this.taskKey,
    required this.description,
    required this.targetValue,
    required this.currentValue,
    required this.taskPoints,
    required this.xpReward,
    required this.silverReward,
    required this.goldReward,
    required this.isCompleted,
  });

  factory RoomDailyTask.fromJson(Map<String, dynamic> json) {
    return RoomDailyTask(
      taskKey: json['task_key'] ?? json['taskKey'] ?? '',
      description: json['description'] ?? '',
      targetValue: json['target_value'] ?? json['targetValue'] ?? 0,
      currentValue: json['current_value'] ?? json['currentValue'] ?? 0,
      taskPoints: json['task_points'] ?? json['taskPoints'] ?? 0,
      xpReward: json['xp_reward'] ?? json['xpReward'] ?? 0,
      silverReward: json['silver_reward'] ?? json['silverReward'] ?? 0,
      goldReward: json['gold_reward'] ?? json['goldReward'] ?? 0,
      isCompleted: json['is_completed'] ?? json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_key': taskKey,
      'description': description,
      'target_value': targetValue,
      'current_value': currentValue,
      'task_points': taskPoints,
      'xp_reward': xpReward,
      'silver_reward': silverReward,
      'gold_reward': goldReward,
      'is_completed': isCompleted,
    };
  }
}

class RoomLevelProgress {
  final String roomId;
  final int currentLevel;
  final int currentXp;
  final int consecutiveDaysCompleted;
  final DateTime? lastCompletedDate;

  RoomLevelProgress({
    required this.roomId,
    required this.currentLevel,
    required this.currentXp,
    required this.consecutiveDaysCompleted,
    this.lastCompletedDate,
  });

  factory RoomLevelProgress.fromJson(Map<String, dynamic> json) {
    return RoomLevelProgress(
      roomId: json['room_id'] ?? json['roomId'] ?? '',
      currentLevel: json['current_level'] ?? json['currentLevel'] ?? 1,
      currentXp: int.tryParse((json['current_xp'] ?? json['currentXp'] ?? 0).toString()) ?? 0,
      consecutiveDaysCompleted: json['consecutive_days_completed'] ?? json['consecutiveDaysCompleted'] ?? 0,
      lastCompletedDate: json['last_completed_date'] != null ? DateTime.parse(json['last_completed_date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'current_level': currentLevel,
      'current_xp': currentXp,
      'consecutive_days_completed': consecutiveDaysCompleted,
      'last_completed_date': lastCompletedDate?.toIso8601String(),
    };
  }
}

class RoomStatistics {
  final String roomId;
  final int totalVisitors;
  final int todayVisitors;
  final int todaySilverCoins;
  final int todayGoldCoins;
  final int todayTaskPoints;
  final int todayExtraXpPoints;
  final DateTime? lastHeartbeatAt;

  RoomStatistics({
    required this.roomId,
    required this.totalVisitors,
    required this.todayVisitors,
    required this.todaySilverCoins,
    required this.todayGoldCoins,
    required this.todayTaskPoints,
    required this.todayExtraXpPoints,
    this.lastHeartbeatAt,
  });

  factory RoomStatistics.fromJson(Map<String, dynamic> json) {
    return RoomStatistics(
      roomId: json['room_id'] ?? json['roomId'] ?? '',
      totalVisitors: int.tryParse((json['total_visitors'] ?? json['totalVisitors'] ?? 0).toString()) ?? 0,
      todayVisitors: json['today_visitors'] ?? json['todayVisitors'] ?? 0,
      todaySilverCoins: json['today_silver_coins'] ?? json['todaySilverCoins'] ?? 0,
      todayGoldCoins: json['today_gold_coins'] ?? json['todayGoldCoins'] ?? 0,
      todayTaskPoints: json['today_task_points'] ?? json['todayTaskPoints'] ?? 0,
      todayExtraXpPoints: json['today_extra_xp_points'] ?? json['todayExtraXpPoints'] ?? 0,
      lastHeartbeatAt: json['last_heartbeat_at'] != null ? DateTime.parse(json['last_heartbeat_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'total_visitors': totalVisitors,
      'today_visitors': todayVisitors,
      'today_silver_coins': todaySilverCoins,
      'today_gold_coins': todayGoldCoins,
      'today_task_points': todayTaskPoints,
      'today_extra_xp_points': todayExtraXpPoints,
      'last_heartbeat_at': lastHeartbeatAt?.toIso8601String(),
    };
  }
}
