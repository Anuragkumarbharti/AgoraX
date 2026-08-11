import 'audio_track_model.dart';
import '../community/post_type.dart';

class UnifiedContentItem {
  final String id;
  final String userId;
  final String? communityId;
  final String content;
  final PostType postType;
  final String caption;
  final String title;
  final String description;
  final String mediaUrl;
  final String thumbnailUrl;
  final double aspectRatio;
  final Map<String, dynamic> mediaMetadata;
  final String? categoryId;
  final List<String> hashtags;
  final List<String> mentions;
  final int likes;
  final int comments;
  final int shares;
  final DateTime createdAt;
  final double trendScore;
  final String visibility;
  final bool commentsEnabled;
  final bool sharesEnabled;
  final String status;
  final String authorName;
  final String authorDisplayName;
  final String authorAvatarUrl;
  final AudioTrack? audioTrack;
  final bool isLiked;
  final bool isSaved;
  final Map<String, dynamic>? mcqData;
  final Map<String, dynamic>? pollData;
  final Map<String, dynamic>? questionData;

  UnifiedContentItem({
    required this.id,
    required this.userId,
    this.communityId,
    required this.content,
    required this.postType,
    this.caption = '',
    this.title = '',
    this.description = '',
    this.mediaUrl = '',
    this.thumbnailUrl = '',
    this.aspectRatio = 1.0,
    this.mediaMetadata = const {},
    this.categoryId = 'general',
    this.hashtags = const [],
    this.mentions = const [],
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    required this.createdAt,
    this.trendScore = 0.0,
    this.visibility = 'public',
    this.commentsEnabled = true,
    this.sharesEnabled = true,
    this.status = 'published',
    this.authorName = 'Anonymous',
    this.authorDisplayName = 'User',
    this.authorAvatarUrl = '',
    this.audioTrack,
    this.isLiked = false,
    this.isSaved = false,
    this.mcqData,
    this.pollData,
    this.questionData,
  });

  factory UnifiedContentItem.fromJson(Map<String, dynamic> json) {
    PostType parsedType = PostType.text;
    final typeStr = json['post_type']?.toString().toLowerCase() ?? 'text';
    switch (typeStr) {
      case 'photo': parsedType = PostType.photo; break;
      case 'video': parsedType = PostType.video; break;
      case 'reel': parsedType = PostType.reel; break;
      case 'audio': parsedType = PostType.audio; break;
      case 'pdf': parsedType = PostType.pdf; break;
      case 'question': parsedType = PostType.question; break;
      case 'mcq': parsedType = PostType.mcq; break;
      case 'poll': parsedType = PostType.poll; break;
      case 'link': parsedType = PostType.link; break;
      default: parsedType = PostType.text;
    }

    final authorProf = json['author_profile'] as Map<String, dynamic>? ?? {};

    return UnifiedContentItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      communityId: json['community_id']?.toString(),
      content: json['content']?.toString() ?? '',
      postType: parsedType,
      caption: json['caption']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
      mediaMetadata: json['media_metadata'] as Map<String, dynamic>? ?? {},
      categoryId: json['category_id']?.toString() ?? 'general',
      hashtags: (json['hashtags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      mentions: (json['mentions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      comments: (json['comments'] as num?)?.toInt() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      trendScore: (json['trend_score'] as num?)?.toDouble() ?? 0.0,
      visibility: json['visibility']?.toString() ?? 'public',
      commentsEnabled: json['comments_enabled'] ?? true,
      sharesEnabled: json['shares_enabled'] ?? true,
      status: json['status']?.toString() ?? 'published',
      authorName: authorProf['username']?.toString() ?? 'Anonymous',
      authorDisplayName: authorProf['display_name']?.toString() ?? authorProf['username']?.toString() ?? 'User',
      authorAvatarUrl: authorProf['avatar_url']?.toString() ?? '',
      audioTrack: json['audio_track'] != null ? AudioTrack.fromJson(json['audio_track']) : null,
      isLiked: json['is_liked'] == true,
      isSaved: json['is_saved'] == true,
      mcqData: json['mcq_data'] as Map<String, dynamic>?,
      pollData: json['poll_data'] as Map<String, dynamic>?,
      questionData: json['question_data'] as Map<String, dynamic>?,
    );
  }
}
