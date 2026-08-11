import 'post_type.dart';

class Post {
  final String id;
  final String userId;
  final String communityId;
  final String content;
  final PostType postType;
  final String caption;
  final String mediaUrl;
  final String thumbnailUrl;
  final double aspectRatio;
  final Map<String, dynamic> mediaMetadata;
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
  final String visibility;
  final bool commentsEnabled;
  final bool sharesEnabled;
  final String status;
  final McqData? mcqData;
  final PollData? pollData;
  final QuestionData? questionData;

  Post({
    required this.id,
    required this.userId,
    required this.communityId,
    required this.content,
    this.postType = PostType.text,
    this.caption = '',
    this.mediaUrl = '',
    this.thumbnailUrl = '',
    this.aspectRatio = 1.0,
    this.mediaMetadata = const {},
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
    this.visibility = 'public',
    this.commentsEnabled = true,
    this.sharesEnabled = true,
    this.status = 'published',
    this.mcqData,
    this.pollData,
    this.questionData,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] ?? json['author_profile'];
    final rawType = json['post_type'] ?? json['postType'];
    
    // Parse legacy arrays if present
    List<String>? parsedImages = json['images'] != null ? List<String>.from(json['images']) : null;
    List<String>? parsedVideos = json['videos'] != null ? List<String>.from(json['videos']) : null;
    List<String>? parsedPdfs = json['pdfs'] != null ? List<String>.from(json['pdfs']) : null;
    List<String>? parsedDocs = json['docUrls'] != null ? List<String>.from(json['docUrls']) : null;

    final mediaUrl = json['media_url'] ?? json['mediaUrl'] ?? '';
    final thumbnailUrl = json['thumbnail_url'] ?? json['thumbnailUrl'] ?? '';

    // If images is null but mediaUrl is present and type is photo, fallback
    PostType parsedType = PostType.fromString(rawType);
    if (parsedType == PostType.photo && (parsedImages == null || parsedImages.isEmpty) && mediaUrl.isNotEmpty) {
      parsedImages = [mediaUrl];
    }
    if (parsedType == PostType.video && (parsedVideos == null || parsedVideos.isEmpty) && mediaUrl.isNotEmpty) {
      parsedVideos = [mediaUrl];
    }
    if (parsedType == PostType.pdf && (parsedPdfs == null || parsedPdfs.isEmpty) && mediaUrl.isNotEmpty) {
      parsedPdfs = [mediaUrl];
    }

    double ratio = 1.0;
    if (json['aspect_ratio'] != null) {
      ratio = (json['aspect_ratio'] as num).toDouble();
    } else if (json['aspectRatio'] != null) {
      ratio = (json['aspectRatio'] as num).toDouble();
    }

    return Post(
      id: json['id'] ?? '',
      userId: json['userId'] ?? json['user_id'] ?? '',
      communityId: json['communityId'] ?? json['community_id'] ?? '',
      content: json['content'] ?? json['caption'] ?? '',
      postType: parsedType,
      caption: json['caption'] ?? json['content'] ?? '',
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      aspectRatio: ratio <= 0 ? 1.0 : ratio,
      mediaMetadata: json['media_metadata'] is Map ? Map<String, dynamic>.from(json['media_metadata']) : {},
      images: parsedImages,
      videos: parsedVideos,
      pdfs: parsedPdfs,
      docUrls: parsedDocs,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
      isLiked: json['isLiked'] ?? json['is_liked'] ?? false,
      isBookmarked: json['isBookmarked'] ?? json['is_bookmarked'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      authorUsername: profiles != null ? profiles['username'] : json['authorUsername'],
      authorAvatarUrl: profiles != null ? (profiles['avatar_url'] ?? profiles['profile_photo']) : (json['authorAvatarUrl'] ?? json['avatar_url']),
      visibility: json['visibility'] ?? 'public',
      commentsEnabled: json['comments_enabled'] ?? json['commentsEnabled'] ?? true,
      sharesEnabled: json['shares_enabled'] ?? json['sharesEnabled'] ?? true,
      status: json['status'] ?? 'published',
      mcqData: json['mcq_data'] != null ? McqData.fromJson(Map<String, dynamic>.from(json['mcq_data'])) : null,
      pollData: json['poll_data'] != null ? PollData.fromJson(Map<String, dynamic>.from(json['poll_data'])) : null,
      questionData: json['question_data'] != null ? QuestionData.fromJson(Map<String, dynamic>.from(json['question_data'])) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'community_id': communityId,
    'content': content,
    'post_type': postType.value,
    'caption': caption,
    'media_url': mediaUrl,
    'thumbnail_url': thumbnailUrl,
    'aspect_ratio': aspectRatio,
    'media_metadata': mediaMetadata,
    'images': images,
    'videos': videos,
    'pdfs': pdfs,
    'doc_urls': docUrls,
    'likes': likes,
    'comments': comments,
    'shares': shares,
    'is_liked': isLiked,
    'is_bookmarked': isBookmarked,
    'created_at': createdAt.toIso8601String(),
    'authorUsername': authorUsername,
    'authorAvatarUrl': authorAvatarUrl,
    'visibility': visibility,
    'comments_enabled': commentsEnabled,
    'shares_enabled': sharesEnabled,
    'status': status,
    'mcq_data': mcqData?.toJson(),
    'poll_data': pollData?.toJson(),
    'question_data': questionData?.toJson(),
  };

  Post copyWith({
    String? id,
    String? userId,
    String? communityId,
    String? content,
    PostType? postType,
    String? caption,
    String? mediaUrl,
    String? thumbnailUrl,
    double? aspectRatio,
    Map<String, dynamic>? mediaMetadata,
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
    String? visibility,
    bool? commentsEnabled,
    bool? sharesEnabled,
    String? status,
    McqData? mcqData,
    PollData? pollData,
    QuestionData? questionData,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      content: content ?? this.content,
      postType: postType ?? this.postType,
      caption: caption ?? this.caption,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      mediaMetadata: mediaMetadata ?? this.mediaMetadata,
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
      visibility: visibility ?? this.visibility,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      sharesEnabled: sharesEnabled ?? this.sharesEnabled,
      status: status ?? this.status,
      mcqData: mcqData ?? this.mcqData,
      pollData: pollData ?? this.pollData,
      questionData: questionData ?? this.questionData,
    );
  }
}

class McqOption {
  final String id;
  final String text;
  final bool isCorrect;

  McqOption({
    required this.id,
    required this.text,
    this.isCorrect = false,
  });

  factory McqOption.fromJson(Map<String, dynamic> json) {
    return McqOption(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      isCorrect: json['is_correct'] ?? json['isCorrect'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'is_correct': isCorrect,
  };
}

class McqData {
  final String question;
  final List<McqOption> options;
  final String explanation;
  final int timerSeconds;
  final String difficulty;
  final String category;
  final int xpReward;
  final String? userSelectedOptionId;

  McqData({
    required this.question,
    required this.options,
    this.explanation = '',
    this.timerSeconds = 0,
    this.difficulty = 'Medium',
    this.category = 'General',
    this.xpReward = 10,
    this.userSelectedOptionId,
  });

  factory McqData.fromJson(Map<String, dynamic> json) {
    final list = json['options'] is List ? (json['options'] as List) : [];
    return McqData(
      question: json['question'] ?? '',
      options: list.map((e) => McqOption.fromJson(Map<String, dynamic>.from(e))).toList(),
      explanation: json['explanation'] ?? '',
      timerSeconds: json['timer_seconds'] ?? json['timerSeconds'] ?? 0,
      difficulty: json['difficulty'] ?? 'Medium',
      category: json['category'] ?? 'General',
      xpReward: json['xp_reward'] ?? json['xpReward'] ?? 10,
      userSelectedOptionId: json['user_selected_option_id'] ?? json['userSelectedOptionId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options.map((e) => e.toJson()).toList(),
    'explanation': explanation,
    'timer_seconds': timerSeconds,
    'difficulty': difficulty,
    'category': category,
    'xp_reward': xpReward,
    'user_selected_option_id': userSelectedOptionId,
  };
}

class PollOption {
  final String id;
  final String text;

  PollOption({
    required this.id,
    required this.text,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
  };
}

class PollData {
  final String question;
  final List<PollOption> options;
  final int durationHours;
  final DateTime? expiresAt;
  final int totalVotes;
  final String? userSelectedOptionId;
  final Map<String, int> optionCounts;

  PollData({
    required this.question,
    required this.options,
    this.durationHours = 24,
    this.expiresAt,
    this.totalVotes = 0,
    this.userSelectedOptionId,
    this.optionCounts = const {},
  });

  factory PollData.fromJson(Map<String, dynamic> json) {
    final list = json['options'] is List ? (json['options'] as List) : [];
    Map<String, int> counts = {};
    if (json['option_counts'] is Map) {
      json['option_counts'].forEach((key, val) {
        counts[key.toString()] = (val as num).toInt();
      });
    }

    return PollData(
      question: json['question'] ?? '',
      options: list.map((e) => PollOption.fromJson(Map<String, dynamic>.from(e))).toList(),
      durationHours: json['duration_hours'] ?? json['durationHours'] ?? 24,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      totalVotes: json['total_votes'] ?? json['totalVotes'] ?? 0,
      userSelectedOptionId: json['user_selected_option_id'] ?? json['userSelectedOptionId'],
      optionCounts: counts,
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options.map((e) => e.toJson()).toList(),
    'duration_hours': durationHours,
    'expires_at': expiresAt?.toIso8601String(),
    'total_votes': totalVotes,
    'user_selected_option_id': userSelectedOptionId,
    'option_counts': optionCounts,
  };

  double getPercentage(String optionId) {
    if (totalVotes == 0) return 0.0;
    final cnt = optionCounts[optionId] ?? 0;
    return (cnt / totalVotes) * 100;
  }
}

class QuestionData {
  final String question;
  final String context;
  final String optionalMediaUrl;

  QuestionData({
    required this.question,
    this.context = '',
    this.optionalMediaUrl = '',
  });

  factory QuestionData.fromJson(Map<String, dynamic> json) {
    return QuestionData(
      question: json['question'] ?? '',
      context: json['context'] ?? '',
      optionalMediaUrl: json['optional_media_url'] ?? json['optionalMediaUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'context': context,
    'optional_media_url': optionalMediaUrl,
  };
}
