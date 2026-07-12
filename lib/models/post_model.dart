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
    this.authorUsername,
    this.authorAvatarUrl,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    // Check nested profiles from Supabase joins
    final profiles = json['profiles'];
    return Post(
      id: json['id'] ?? '',
      userId: json['userId'] ?? json['user_id'] ?? '',
      communityId: json['communityId'] ?? json['community_id'] ?? '',
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
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      authorUsername: profiles != null ? profiles['username'] : json['authorUsername'],
      authorAvatarUrl: profiles != null ? (profiles['avatar_url'] ?? profiles['profile_photo']) : (json['authorAvatarUrl'] ?? json['avatar_url']),
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
  final String? authorUsername;
  final String? authorAvatarUrl;

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
    'authorUsername': authorUsername,
    'authorAvatarUrl': authorAvatarUrl,
  };

  Post copyWith({
    String? id,
    String? userId,
    String? communityId,
    String? content,
    List<String>? images,
    List<String>? videos,
    List<String>? pdfs,
    List<String>? docUrls,
    int? likes,
    int? comments,
    int? shares,
    bool? isLiked,
    bool? isBookmarked,
    DateTime? createdAt,
    String? authorUsername,
    String? authorAvatarUrl,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      content: content ?? this.content,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      pdfs: pdfs ?? this.pdfs,
      docUrls: docUrls ?? this.docUrls,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      createdAt: createdAt ?? this.createdAt,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }
}
