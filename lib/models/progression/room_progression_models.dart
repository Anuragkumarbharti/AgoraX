class RoomLevelMatrixConfig {
  final int level;
  final int requiredVp;
  final int maxCoOwners;
  final int maxAdmins;
  final int maxHostSeats;
  final bool hasRoomMusic;
  final bool hasShowcaseBadge;
  final bool hasPermanentChatBubble;
  final int grandPrizeCoins;
  final int grandPrizeVipLevel;
  final int grandPrizeVipDays;
  final String title;
  final String description;

  const RoomLevelMatrixConfig({
    required this.level,
    required this.requiredVp,
    required this.maxCoOwners,
    required this.maxAdmins,
    required this.maxHostSeats,
    required this.hasRoomMusic,
    required this.hasShowcaseBadge,
    required this.hasPermanentChatBubble,
    this.grandPrizeCoins = 0,
    this.grandPrizeVipLevel = 0,
    this.grandPrizeVipDays = 0,
    required this.title,
    required this.description,
  });

  static const List<RoomLevelMatrixConfig> levels = [
    RoomLevelMatrixConfig(
      level: 1,
      requiredVp: 0,
      maxCoOwners: 1,
      maxAdmins: 4,
      maxHostSeats: 4,
      hasRoomMusic: true,
      hasShowcaseBadge: false,
      hasPermanentChatBubble: false,
      title: 'Basic Arena',
      description:
          'Basic background, basic announcement, normal daily tasks, arena music',
    ),
    RoomLevelMatrixConfig(
      level: 2,
      requiredVp: 35500,
      maxCoOwners: 1,
      maxAdmins: 7,
      maxHostSeats: 6,
      hasRoomMusic: true,
      hasShowcaseBadge: false,
      hasPermanentChatBubble: false,
      title: 'Premium Arena',
      description:
          'Premium background, welcome banner, arena statistics, arena music',
    ),
    RoomLevelMatrixConfig(
      level: 3,
      requiredVp: 59500,
      maxCoOwners: 2,
      maxAdmins: 11,
      maxHostSeats: 8,
      hasRoomMusic: true,
      hasShowcaseBadge: true,
      hasPermanentChatBubble: false,
      title: 'Animated Arena',
      description: 'Animated arena frame, gift wall, showcase badge, arena music',
    ),
    RoomLevelMatrixConfig(
      level: 4,
      requiredVp: 95000,
      maxCoOwners: 2,
      maxAdmins: 14,
      maxHostSeats: 11,
      hasRoomMusic: true,
      hasShowcaseBadge: true,
      hasPermanentChatBubble: false,
      title: 'Dynamic Arena',
      description:
          'Dynamic background, premium arena effects, event scheduler, arena music',
    ),
    RoomLevelMatrixConfig(
      level: 5,
      requiredVp: 490000,
      maxCoOwners: 3,
      maxAdmins: 16,
      maxHostSeats: 13,
      hasRoomMusic: true,
      hasShowcaseBadge: true,
      hasPermanentChatBubble: true,
      grandPrizeCoins: 2000,
      grandPrizeVipLevel: 2,
      grandPrizeVipDays: 60,
      title: 'Official Arena',
      description:
          'GRAND PRIZE: 2,000 Gold Coins + VIP 2 (60 Days)! Official badge, permanent chat bubble, analytics, arena music',
    ),
    RoomLevelMatrixConfig(
      level: 6,
      requiredVp: 940000,
      maxCoOwners: 3,
      maxAdmins: 18,
      maxHostSeats: 14,
      hasRoomMusic: true,
      hasShowcaseBadge: true,
      hasPermanentChatBubble: true,
      grandPrizeCoins: 5000,
      grandPrizeVipLevel: 2,
      grandPrizeVipDays: 180,
      title: 'Luxury Arena',
      description:
          'GRAND PRIZE: 5,000 Gold Coins + VIP 2 (6 Months)! Luxury theme, animated entry, VIP features, arena music',
    ),
    RoomLevelMatrixConfig(
      level: 7,
      requiredVp: 1590000,
      maxCoOwners: 3,
      maxAdmins: 20,
      maxHostSeats: 15,
      hasRoomMusic: true,
      hasShowcaseBadge: true,
      hasPermanentChatBubble: true,
      grandPrizeCoins: 12000,
      grandPrizeVipLevel: 3,
      grandPrizeVipDays: 365,
      title: 'Legendary Arena',
      description:
          'GRAND PRIZE: 12,000 Gold Coins + VIP 3 (1 Year)! Legendary crown, exclusive backgrounds, official recommendation',
    ),
  ];

  static RoomLevelMatrixConfig getForLevel(int level) {
    final clampedLevel = level.clamp(1, 7);
    return levels.firstWhere(
      (cfg) => cfg.level == clampedLevel,
      orElse: () => levels.first,
    );
  }
}

class RoomDailyVpConfig {
  static const int weekdayFreeTarget = 700;
  static const int weekdayGoldTarget = 1000;
  static const int weekendFreeTarget = 1250;
  static const int weekendGoldTarget = 1250;

  static const int firstSeatBonusVp = 20;
  static const int firstFiveGiftsBonusVp = 25;

  static int getFreeTarget(bool isWeekend) => isWeekend ? weekendFreeTarget : weekdayFreeTarget;
  static int getGoldTarget(bool isWeekend) => isWeekend ? weekendGoldTarget : weekdayGoldTarget;
  static int getTotalTarget(bool isWeekend) => getFreeTarget(isWeekend) + getGoldTarget(isWeekend);

  static int getStarGiftVp(int starCount) {
    switch (starCount) {
      case 1:
        return 2;
      case 2:
        return 5;
      case 3:
        return 10;
      case 4:
        return 20;
      case 5:
        return 40;
      case 6:
      default:
        return 70;
    }
  }

  static int getGoldGiftVp(int goldAmount) {
    if (goldAmount >= 700) return 700;
    if (goldAmount >= 500) return 500;
    if (goldAmount >= 100) return 350;
    if (goldAmount >= 20) return 120;
    if (goldAmount >= 5) return 40;
    return (goldAmount * 8).clamp(1, 700);
  }
}

class RoomDailyTask {
  final String taskKey;
  final String title;
  final String description;
  final String category; // 'normal', 'gold', 'team', 'community'
  final int targetValue;
  final int currentValue;
  final int minActiveMembers;
  final int taskPoints;
  final int xpReward;
  final int coinReward;
  final int silverReward;
  final int goldReward;
  final String treasureBoxTier; // 'normal', 'gold', 'room', 'legendary'
  final String iconName;
  final bool isCompleted;

  RoomDailyTask({
    required this.taskKey,
    this.title = '',
    required this.description,
    this.category = 'normal',
    required this.targetValue,
    required this.currentValue,
    this.minActiveMembers = 1,
    required this.taskPoints,
    required this.xpReward,
    this.coinReward = 0,
    required this.silverReward,
    required this.goldReward,
    this.treasureBoxTier = 'normal',
    this.iconName = 'task',
    required this.isCompleted,
  });

  factory RoomDailyTask.fromJson(Map<String, dynamic> json) {
    return RoomDailyTask(
      taskKey: json['task_key'] ?? json['taskKey'] ?? '',
      title: json['title'] ?? json['task_name'] ?? json['description'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ??
          (json['task_key']?.toString().contains('gold') == true
              ? 'gold'
              : 'normal'),
      targetValue: json['target_value'] ?? json['targetValue'] ?? 1,
      currentValue: json['current_value'] ?? json['currentValue'] ?? 0,
      minActiveMembers:
          json['min_active_members'] ?? json['minActiveMembers'] ?? 1,
      taskPoints:
          json['task_points'] ?? json['taskPoints'] ?? json['vp_reward'] ?? 50,
      xpReward:
          json['xp_reward'] ?? json['xpReward'] ?? json['vp_reward'] ?? 50,
      coinReward: json['coin_reward'] ?? json['coinReward'] ?? 0,
      silverReward: json['silver_reward'] ?? json['silverReward'] ?? 0,
      goldReward: json['gold_reward'] ?? json['goldReward'] ?? 0,
      treasureBoxTier:
          json['treasure_box_tier'] ?? json['treasureBoxTier'] ?? 'normal',
      iconName: json['icon_name'] ?? json['iconName'] ?? 'task',
      isCompleted: json['is_completed'] ?? json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_key': taskKey,
      'title': title,
      'description': description,
      'category': category,
      'target_value': targetValue,
      'current_value': currentValue,
      'min_active_members': minActiveMembers,
      'task_points': taskPoints,
      'xp_reward': xpReward,
      'coin_reward': coinReward,
      'silver_reward': silverReward,
      'gold_reward': goldReward,
      'treasure_box_tier': treasureBoxTier,
      'icon_name': iconName,
      'is_completed': isCompleted,
    };
  }

  RoomDailyTask copyWith({
    int? currentValue,
    bool? isCompleted,
  }) {
    return RoomDailyTask(
      taskKey: taskKey,
      title: title,
      description: description,
      category: category,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      minActiveMembers: minActiveMembers,
      taskPoints: taskPoints,
      xpReward: xpReward,
      coinReward: coinReward,
      silverReward: silverReward,
      goldReward: goldReward,
      treasureBoxTier: treasureBoxTier,
      iconName: iconName,
      isCompleted: isCompleted ?? this.isCompleted,
    );
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
      currentXp: int.tryParse(
              (json['current_xp'] ?? json['currentXp'] ?? 0).toString()) ??
          0,
      consecutiveDaysCompleted: json['consecutive_days_completed'] ??
          json['consecutiveDaysCompleted'] ??
          0,
      lastCompletedDate: json['last_completed_date'] != null
          ? DateTime.parse(json['last_completed_date'])
          : null,
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
      totalVisitors: int.tryParse(
              (json['total_visitors'] ?? json['totalVisitors'] ?? 0)
                  .toString()) ??
          0,
      todayVisitors: json['today_visitors'] ?? json['todayVisitors'] ?? 0,
      todaySilverCoins:
          json['today_silver_coins'] ?? json['todaySilverCoins'] ?? 0,
      todayGoldCoins: json['today_gold_coins'] ?? json['todayGoldCoins'] ?? 0,
      todayTaskPoints:
          json['today_task_points'] ?? json['todayTaskPoints'] ?? 0,
      todayExtraXpPoints:
          json['today_extra_xp_points'] ?? json['todayExtraXpPoints'] ?? 0,
      lastHeartbeatAt: json['last_heartbeat_at'] != null
          ? DateTime.parse(json['last_heartbeat_at'])
          : null,
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
