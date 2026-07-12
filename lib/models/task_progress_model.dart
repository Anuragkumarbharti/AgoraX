class TaskProgress {
  final String id;
  final String userId;
  final String taskId;
  final String taskType;
  final int progress;
  final int requiredProgress;
  final bool completed;
  final bool claimed;
  final DateTime? completedAt;
  final DateTime? claimedAt;
  final String date;
  
  // Joined metadata fields
  final String taskCode;
  final String title;
  final String description;
  final String icon;
  final String category;
  final String verificationType;
  final int xp;
  final int silverCoin;
  final Map<String, dynamic> bonusReward;

  TaskProgress({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.taskType,
    required this.progress,
    required this.requiredProgress,
    required this.completed,
    required this.claimed,
    this.completedAt,
    this.claimedAt,
    required this.date,
    required this.taskCode,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.verificationType,
    required this.xp,
    required this.silverCoin,
    required this.bonusReward,
  });

  factory TaskProgress.fromJson(Map<String, dynamic> json) {
    return TaskProgress(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      taskId: json['task_id'] ?? json['taskId'] ?? '',
      taskType: json['task_type'] ?? json['taskType'] ?? 'career',
      progress: json['progress'] ?? 0,
      requiredProgress: json['required_progress'] ?? json['requiredProgress'] ?? 1,
      completed: json['completed'] ?? false,
      claimed: json['claimed'] ?? false,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at']) : null,
      claimedAt: json['claimed_at'] != null ? DateTime.tryParse(json['claimed_at']) : null,
      date: json['date'] ?? '',
      taskCode: json['task_code'] ?? json['taskCode'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      category: json['category'] ?? '',
      verificationType: json['verification_type'] ?? json['verificationType'] ?? '',
      xp: json['xp'] ?? 50,
      silverCoin: json['silver_coin'] ?? json['silverCoin'] ?? 50,
      bonusReward: json['bonus_reward'] != null ? Map<String, dynamic>.from(json['bonus_reward']) : {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'task_id': taskId,
    'task_type': taskType,
    'progress': progress,
    'required_progress': requiredProgress,
    'completed': completed,
    'claimed': claimed,
    'completed_at': completedAt?.toIso8601String(),
    'claimed_at': claimedAt?.toIso8601String(),
    'date': date,
    'task_code': taskCode,
    'title': title,
    'description': description,
    'icon': icon,
    'category': category,
    'verification_type': verificationType,
    'xp': xp,
    'silver_coin': silverCoin,
    'bonus_reward': bonusReward,
  };

  TaskProgress copyWith({
    String? id,
    String? userId,
    String? taskId,
    String? taskType,
    int? progress,
    int? requiredProgress,
    bool? completed,
    bool? claimed,
    DateTime? completedAt,
    DateTime? claimedAt,
    String? date,
    String? taskCode,
    String? title,
    String? description,
    String? icon,
    String? category,
    String? verificationType,
    int? xp,
    int? silverCoin,
    Map<String, dynamic>? bonusReward,
  }) {
    return TaskProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      taskType: taskType ?? this.taskType,
      progress: progress ?? this.progress,
      requiredProgress: requiredProgress ?? this.requiredProgress,
      completed: completed ?? this.completed,
      claimed: claimed ?? this.claimed,
      completedAt: completedAt ?? this.completedAt,
      claimedAt: claimedAt ?? this.claimedAt,
      date: date ?? this.date,
      taskCode: taskCode ?? this.taskCode,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      verificationType: verificationType ?? this.verificationType,
      xp: xp ?? this.xp,
      silverCoin: silverCoin ?? this.silverCoin,
      bonusReward: bonusReward ?? this.bonusReward,
    );
  }
}
