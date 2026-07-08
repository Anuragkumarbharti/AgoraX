class User {
  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatar,
    this.coverPhoto,
    this.bio,
    required this.interests,
    required this.communities,
    required this.followers,
    required this.following,
    required this.isVerified,
    required this.isPremium,
    required this.reputation,
    required this.sid,
    this.level = 1,
    this.xp = 0,
    this.totalXp = 1000,
    this.totalPosts = 0,
    this.totalQuestions = 0,
    this.badges = const [],
    this.levelTitle = 'Newcomer',
    this.selectedStudyCategory,
    this.categoryLockExpiry,
    this.silverCoins = 0,
    this.learningStreak = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final String parsedId = json['id'] ?? '';
    final String generatedSid = json['sid'] ?? (parsedId.hashCode.abs() % 900000 + 100000).toString();
    return User(
      id: parsedId,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      avatar: json['avatar'],
      coverPhoto: json['coverPhoto'],
      bio: json['bio'],
      interests: List<String>.from(json['interests'] ?? []),
      communities: List<String>.from(json['communities'] ?? []),
      followers: json['followers'] ?? 0,
      following: json['following'] ?? 0,
      isVerified: json['isVerified'] ?? false,
      isPremium: json['isPremium'] ?? false,
      reputation: json['reputation'] ?? 0,
      sid: generatedSid,
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      totalXp: json['totalXp'] ?? 1000,
      totalPosts: json['totalPosts'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      badges: List<String>.from(json['badges'] ?? []),
      levelTitle: json['levelTitle'] ?? 'Newcomer',
      selectedStudyCategory: json['selectedStudyCategory'],
      categoryLockExpiry: json['categoryLockExpiry'] != null ? DateTime.tryParse(json['categoryLockExpiry']) : null,
      silverCoins: json['silverCoins'] ?? 0,
      learningStreak: json['learningStreak'] ?? 0,
    );
  }

  final String id;
  final String username;
  final String email;
  final String displayName;
  final String? avatar;
  final String? coverPhoto;
  final String? bio;
  final List<String> interests;
  final List<String> communities;
  final int followers;
  final int following;
  final bool isVerified;
  final bool isPremium;
  final int reputation;
  final String sid;
  // Gamification
  final int level;
  final int xp;
  final int totalXp;
  final int totalPosts;
  final int totalQuestions;
  final List<String> badges;
  final String levelTitle;

  // Study Category & Learning Mission
  final String? selectedStudyCategory;
  final DateTime? categoryLockExpiry;
  final int silverCoins;
  final int learningStreak;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'displayName': displayName,
        'avatar': avatar,
        'coverPhoto': coverPhoto,
        'bio': bio,
        'interests': interests,
        'communities': communities,
        'followers': followers,
        'following': following,
        'isVerified': isVerified,
        'isPremium': isPremium,
        'reputation': reputation,
        'sid': sid,
        'level': level,
        'xp': xp,
        'totalXp': totalXp,
        'totalPosts': totalPosts,
        'totalQuestions': totalQuestions,
        'badges': badges,
        'levelTitle': levelTitle,
        'selectedStudyCategory': selectedStudyCategory,
        'categoryLockExpiry': categoryLockExpiry?.toIso8601String(),
        'silverCoins': silverCoins,
        'learningStreak': learningStreak,
      };
}
