class RoomDualProgress {
  static const int FREE_TASK_LIMIT = 700;
  static const int GOLD_TASK_LIMIT = 1000;

  static bool get isWeekend {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)).subtract(const Duration(hours: 4));
    return now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  }

  static int get defaultFreeTaskLimit => isWeekend ? 1400 : 700;
  static int get defaultGoldTaskLimit => isWeekend ? 2000 : 1000;

  final String roomId;
  final int dailyFreeProgress;
  final int freeTaskLimit;
  final int dailyGoldProgress;
  final int goldTaskLimit;
  final int totalTask;
  final int totalTaskTarget;
  final int totalLifetimeTask;
  final String? lastResetDate;
  final int goldPoints;
  final int goldTarget;
  final int normalPoints;
  final int normalTarget;
  final int overflowPoints;
  final int roomLevel;
  final DateTime? updatedAt;

  const RoomDualProgress({
    required this.roomId,
    this.dailyFreeProgress = 0,
    int? freeTaskLimit,
    this.dailyGoldProgress = 0,
    int? goldTaskLimit,
    this.totalTask = 0,
    this.totalTaskTarget = 35500,
    this.totalLifetimeTask = 0,
    this.lastResetDate,
    this.goldPoints = 0,
    int? goldTarget,
    this.normalPoints = 0,
    int? normalTarget,
    this.overflowPoints = 0,
    this.roomLevel = 1,
    this.updatedAt,
  })  : freeTaskLimit = freeTaskLimit ?? FREE_TASK_LIMIT,
        goldTaskLimit = goldTaskLimit ?? GOLD_TASK_LIMIT,
        goldTarget = goldTarget ?? goldTaskLimit ?? GOLD_TASK_LIMIT,
        normalTarget = normalTarget ?? freeTaskLimit ?? FREE_TASK_LIMIT;

  static int getRequiredTaskForLevel(int level) {
    if (level == 1) return 35500;
    if (level == 2) return 59500;
    if (level == 3) return 95000;
    if (level == 4) return 490000;
    if (level == 5) return 940000;
    return 1590000;
  }

  double get freeRatio {
    final limit = freeTaskLimit > 0 ? freeTaskLimit : FREE_TASK_LIMIT;
    return (dailyFreeProgress / limit).clamp(0.0, 1.0);
  }

  double get goldRatio {
    final limit = goldTarget > 0 ? goldTarget : (goldTaskLimit > 0 ? goldTaskLimit : GOLD_TASK_LIMIT);
    final points = dailyGoldProgress > 0 ? dailyGoldProgress : goldPoints;
    return (points / limit).clamp(0.0, 1.0);
  }

  double get normalRatio {
    final limit = normalTarget > 0 ? normalTarget : (freeTaskLimit > 0 ? freeTaskLimit : FREE_TASK_LIMIT);
    final points = dailyFreeProgress > 0 ? dailyFreeProgress : normalPoints;
    return (points / limit).clamp(0.0, 1.0);
  }

  double get totalTaskRatio {
    final target = totalTaskTarget > 0 ? totalTaskTarget : getRequiredTaskForLevel(roomLevel);
    return (totalTask / target).clamp(0.0, 1.0);
  }

  bool get isFreeLimitReached => dailyFreeProgress >= freeTaskLimit && freeTaskLimit > 0;
  bool get isGoldLimitReached => dailyGoldProgress >= goldTaskLimit && goldTaskLimit > 0;
  bool get isGoldFull => isGoldLimitReached || (goldPoints >= goldTarget && goldTarget > 0);
  bool get isNormalFull => isFreeLimitReached || (normalPoints >= normalTarget && normalTarget > 0);
  bool get isOverflowActive => isGoldFull || overflowPoints > 0;

  int get totalDailyPoints => dailyFreeProgress + dailyGoldProgress;
  int get totalDailyLimit => (freeTaskLimit > 0 ? freeTaskLimit : FREE_TASK_LIMIT) + (goldTaskLimit > 0 ? goldTaskLimit : GOLD_TASK_LIMIT);

  int get totalPoints => totalDailyPoints > 0 ? totalDailyPoints : (goldPoints + normalPoints);
  int get totalTarget => totalDailyLimit;

  double get overallRatio {
    final limit = totalDailyLimit > 0 ? totalDailyLimit : (FREE_TASK_LIMIT + GOLD_TASK_LIMIT);
    return (totalPoints / limit).clamp(0.0, 1.0);
  }

  factory RoomDualProgress.fromJson(Map<String, dynamic> json) {
    final free = int.tryParse((json['daily_free_progress'] ?? json['normal_points'] ?? json['normalPoints'] ?? 0).toString()) ?? 0;
    final freeLimit = int.tryParse((json['free_task_limit'] ?? json['normal_target'] ?? json['normalTarget'] ?? FREE_TASK_LIMIT).toString()) ?? FREE_TASK_LIMIT;
    final gold = int.tryParse((json['daily_gold_progress'] ?? json['gold_points'] ?? json['goldPoints'] ?? 0).toString()) ?? 0;
    final goldLimit = int.tryParse((json['gold_task_limit'] ?? json['gold_target'] ?? json['goldTarget'] ?? GOLD_TASK_LIMIT).toString()) ?? GOLD_TASK_LIMIT;

    final level = int.tryParse((json['room_level'] ?? json['roomLevel'] ?? 1).toString()) ?? 1;
    final defaultTarget = getRequiredTaskForLevel(level);

    final totTask = int.tryParse((json['total_task'] ?? 0).toString()) ?? 0;
    final totTarget = int.tryParse((json['total_task_target'] ?? defaultTarget).toString()) ?? defaultTarget;
    final lifetime = int.tryParse((json['total_lifetime_task'] ?? json['room_xp'] ?? json['total_xp'] ?? 0).toString()) ?? 0;

    return RoomDualProgress(
      roomId: json['room_id'] ?? json['roomId'] ?? '',
      dailyFreeProgress: free,
      freeTaskLimit: freeLimit,
      dailyGoldProgress: gold,
      goldTaskLimit: goldLimit,
      totalTask: totTask,
      totalTaskTarget: totTarget,
      totalLifetimeTask: lifetime,
      lastResetDate: json['last_reset_date']?.toString(),
      goldPoints: gold,
      goldTarget: goldLimit,
      normalPoints: free,
      normalTarget: freeLimit,
      overflowPoints: int.tryParse((json['overflow_points'] ?? json['overflowPoints'] ?? 0).toString()) ?? 0,
      roomLevel: level,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'daily_free_progress': dailyFreeProgress,
      'free_task_limit': freeTaskLimit,
      'daily_gold_progress': dailyGoldProgress,
      'gold_task_limit': goldTaskLimit,
      'total_task': totalTask,
      'total_task_target': totalTaskTarget,
      'total_lifetime_task': totalLifetimeTask,
      'last_reset_date': lastResetDate,
      'gold_points': dailyGoldProgress > 0 ? dailyGoldProgress : goldPoints,
      'gold_target': goldTaskLimit,
      'normal_points': dailyFreeProgress > 0 ? dailyFreeProgress : normalPoints,
      'normal_target': freeTaskLimit,
      'overflow_points': overflowPoints,
      'room_level': roomLevel,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  RoomDualProgress copyWith({
    String? roomId,
    int? dailyFreeProgress,
    int? freeTaskLimit,
    int? dailyGoldProgress,
    int? goldTaskLimit,
    int? totalTask,
    int? totalTaskTarget,
    int? totalLifetimeTask,
    String? lastResetDate,
    int? goldPoints,
    int? goldTarget,
    int? normalPoints,
    int? normalTarget,
    int? overflowPoints,
    int? roomLevel,
    DateTime? updatedAt,
  }) {
    final free = dailyFreeProgress ?? normalPoints ?? (this.dailyFreeProgress > 0 ? this.dailyFreeProgress : this.normalPoints);
    final fLimit = freeTaskLimit ?? normalTarget ?? this.freeTaskLimit;
    final gold = dailyGoldProgress ?? goldPoints ?? (this.dailyGoldProgress > 0 ? this.dailyGoldProgress : this.goldPoints);
    final gLimit = goldTaskLimit ?? goldTarget ?? this.goldTaskLimit;
    final rLevel = roomLevel ?? this.roomLevel;

    return RoomDualProgress(
      roomId: roomId ?? this.roomId,
      dailyFreeProgress: free,
      freeTaskLimit: fLimit,
      dailyGoldProgress: gold,
      goldTaskLimit: gLimit,
      totalTask: totalTask ?? this.totalTask,
      totalTaskTarget: totalTaskTarget ?? (totalTaskTarget == null ? getRequiredTaskForLevel(rLevel) : this.totalTaskTarget),
      totalLifetimeTask: totalLifetimeTask ?? this.totalLifetimeTask,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      goldPoints: gold,
      goldTarget: gLimit,
      normalPoints: free,
      normalTarget: fLimit,
      overflowPoints: overflowPoints ?? this.overflowPoints,
      roomLevel: rLevel,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
