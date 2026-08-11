class HashtagModel {
  final String id;
  final String name;
  final String normalizedName;
  final int usageCount;
  final double trendScore;

  HashtagModel({
    required this.id,
    required this.name,
    required this.normalizedName,
    this.usageCount = 0,
    this.trendScore = 0.0,
  });

  factory HashtagModel.fromJson(Map<String, dynamic> json) {
    return HashtagModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      normalizedName: json['normalized_name']?.toString() ?? '',
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      trendScore: (json['trend_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'normalized_name': normalizedName,
      'usage_count': usageCount,
      'trend_score': trendScore,
    };
  }
}
