class Post {

  Post({
    required this.id,
    required this.userId,
    required this.communityId,
    required this.content,
    this.images,
    this.videos,
    this.pdfs,
    this.docUrls,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isLiked,
    required this.isBookmarked,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      communityId: json['communityId'] ?? '',
      content: json['content'] ?? '',
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      videos: json['videos'] != null ? List<String>.from(json['videos']) : null,
      pdfs: json['pdfs'] != null ? List<String>.from(json['pdfs']) : null,
      docUrls: json['docUrls'] != null ? List<String>.from(json['docUrls']) : null,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isBookmarked: json['isBookmarked'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
  final String id;
  final String userId;
  final String communityId;
  final String content;
  final List<String>? images;
  final List<String>? videos;
  final List<String>? pdfs;
  final List<String>? docUrls;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final bool isBookmarked;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'communityId': communityId,
    'content': content,
    'images': images,
    'videos': videos,
    'pdfs': pdfs,
    'docUrls': docUrls,
    'likes': likes,
    'comments': comments,
    'shares': shares,
    'isLiked': isLiked,
    'isBookmarked': isBookmarked,
    'createdAt': createdAt.toIso8601String(),
  };
}
