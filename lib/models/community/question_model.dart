class Question {

  Question({
    required this.id,
    required this.userId,
    required this.communityId,
    required this.title,
    required this.description,
    required this.tags,
    this.images,
    required this.views,
    required this.answers,
    required this.upvotes,
    required this.isUpvoted,
    required this.isBookmarked,
    required this.isAnonymous,
    required this.isAnswered,
    this.acceptedAnswerId,
    required this.createdAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      communityId: json['communityId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      views: json['views'] ?? 0,
      answers: json['answers'] ?? 0,
      upvotes: json['upvotes'] ?? 0,
      isUpvoted: json['isUpvoted'] ?? false,
      isBookmarked: json['isBookmarked'] ?? false,
      isAnonymous: json['isAnonymous'] ?? false,
      isAnswered: json['isAnswered'] ?? false,
      acceptedAnswerId: json['acceptedAnswerId'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
  final String id;
  final String userId;
  final String communityId;
  final String title;
  final String description;
  final List<String> tags;
  final List<String>? images;
  final int views;
  final int answers;
  final int upvotes;
  final bool isUpvoted;
  final bool isBookmarked;
  final bool isAnonymous;
  final bool isAnswered;
  final String? acceptedAnswerId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'communityId': communityId,
    'title': title,
    'description': description,
    'tags': tags,
    'images': images,
    'views': views,
    'answers': answers,
    'upvotes': upvotes,
    'isUpvoted': isUpvoted,
    'isBookmarked': isBookmarked,
    'isAnonymous': isAnonymous,
    'isAnswered': isAnswered,
    'acceptedAnswerId': acceptedAnswerId,
    'createdAt': createdAt.toIso8601String(),
  };

  Question copyWith({
    String? id,
    String? userId,
    String? communityId,
    String? title,
    String? description,
    List<String>? tags,
    List<String>? images,
    int? views,
    int? answers,
    int? upvotes,
    bool? isUpvoted,
    bool? isBookmarked,
    bool? isAnonymous,
    bool? isAnswered,
    String? acceptedAnswerId,
    DateTime? createdAt,
  }) {
    return Question(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      views: views ?? this.views,
      answers: answers ?? this.answers,
      upvotes: upvotes ?? this.upvotes,
      isUpvoted: isUpvoted ?? this.isUpvoted,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isAnswered: isAnswered ?? this.isAnswered,
      acceptedAnswerId: acceptedAnswerId ?? this.acceptedAnswerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
