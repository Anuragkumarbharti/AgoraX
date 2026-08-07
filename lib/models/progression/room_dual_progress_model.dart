class RoomDualProgress {
  final String roomId;
  final int goldPoints;
  final int goldTarget;
  final int normalPoints;
  final int normalTarget;
  final int overflowPoints;
  final int roomLevel;
  final DateTime? updatedAt;

  const RoomDualProgress({
    required this.roomId,
    this.goldPoints = 0,
    this.goldTarget = 1000,
    this.normalPoints = 0,
    this.normalTarget = 700,
    this.overflowPoints = 0,
    this.roomLevel = 1,
    this.updatedAt,
  });

  double get goldRatio {
    final target = goldTarget > 0 ? goldTarget : 1000;
    return (goldPoints / target).clamp(0.0, 1.0);
  }

  double get normalRatio {
    final target = normalTarget > 0 ? normalTarget : 700;
    return (normalPoints / target).clamp(0.0, 1.0);
  }

  bool get isGoldFull => goldPoints >= goldTarget && goldTarget > 0;
  bool get isNormalFull => normalPoints >= normalTarget && normalTarget > 0;
  bool get isOverflowActive => isGoldFull || overflowPoints > 0;

  int get totalPoints => goldPoints + normalPoints;
  int get totalTarget => (goldTarget > 0 ? goldTarget : 1000) + (normalTarget > 0 ? normalTarget : 700);

  double get overallRatio {
    final target = totalTarget > 0 ? totalTarget : 1700;
    return (totalPoints / target).clamp(0.0, 1.0);
  }

  factory RoomDualProgress.fromJson(Map<String, dynamic> json) {
    return RoomDualProgress(
      roomId: json['room_id'] ?? json['roomId'] ?? '',
      goldPoints: int.tryParse((json['gold_points'] ?? json['goldPoints'] ?? 0).toString()) ?? 0,
      goldTarget: int.tryParse((json['gold_target'] ?? json['goldTarget'] ?? 1000).toString()) ?? 1000,
      normalPoints: int.tryParse((json['normal_points'] ?? json['normalPoints'] ?? 0).toString()) ?? 0,
      normalTarget: int.tryParse((json['normal_target'] ?? json['normalTarget'] ?? 700).toString()) ?? 700,
      overflowPoints: int.tryParse((json['overflow_points'] ?? json['overflowPoints'] ?? 0).toString()) ?? 0,
      roomLevel: int.tryParse((json['room_level'] ?? json['roomLevel'] ?? 1).toString()) ?? 1,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'gold_points': goldPoints,
      'gold_target': goldTarget,
      'normal_points': normalPoints,
      'normal_target': normalTarget,
      'overflow_points': overflowPoints,
      'room_level': roomLevel,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  RoomDualProgress copyWith({
    String? roomId,
    int? goldPoints,
    int? goldTarget,
    int? normalPoints,
    int? normalTarget,
    int? overflowPoints,
    int? roomLevel,
    DateTime? updatedAt,
  }) {
    return RoomDualProgress(
      roomId: roomId ?? this.roomId,
      goldPoints: goldPoints ?? this.goldPoints,
      goldTarget: goldTarget ?? this.goldTarget,
      normalPoints: normalPoints ?? this.normalPoints,
      normalTarget: normalTarget ?? this.normalTarget,
      overflowPoints: overflowPoints ?? this.overflowPoints,
      roomLevel: roomLevel ?? this.roomLevel,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
