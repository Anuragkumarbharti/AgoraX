class User {
  User({
    required this.id,
    this.uid = '',
    required this.username,
    required this.email,
    this.phone,
    required this.displayName,
    this.fullName,
    this.avatar,
    this.coverPhoto,
    this.bio,
    this.dob,
    this.age = 0,
    this.gender,
    this.country,
    this.state,
    this.city,
    this.language = 'en',
    this.profession,
    this.education,
    this.website,
    this.instagram,
    this.youtube,
    this.twitter,
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
    this.vipLevel = 0,
    this.novelLevel = 0,
    this.careerLevel = 1,
    this.avatarFrame = 'Normal',
    this.diamonds = 0,
    this.friendsCount = 0,
    this.roomsJoined = 0,
    this.eventsJoined = 0,
    this.onlineStatus = false,
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
    this.emailVerified = false,
    this.verificationTimestamp,
    this.verificationMethod,
    this.lastVerificationDate,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final String parsedId = json['id'] ?? '';
    final String generatedSid = json['sid'] ?? (parsedId.hashCode.abs() % 900000 + 100000).toString();
    final String parsedUid = (json['uid'] ?? json['uid_numeric'] ?? generatedSid).toString();
    
    return User(
      id: parsedId,
      uid: parsedUid,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      displayName: json['displayName'] ?? json['display_name'] ?? json['username'] ?? 'User',
      fullName: json['fullName'] ?? json['full_name'],
      avatar: json['avatar'] ?? json['profile_photo'] ?? json['avatar_url'],
      coverPhoto: json['coverPhoto'] ?? json['cover_photo'],
      bio: json['bio'],
      dob: json['dob'] != null ? DateTime.tryParse(json['dob'].toString()) : null,
      age: json['age'] ?? 0,
      gender: json['gender'],
      country: json['country'],
      state: json['state'],
      city: json['city'],
      language: json['language'] ?? 'en',
      profession: json['profession'] ?? json['occupation'],
      education: json['education'] ?? json['school'] ?? json['college'] ?? json['company'],
      website: json['website'],
      instagram: json['instagram'],
      youtube: json['youtube'],
      twitter: json['twitter'] ?? json['x'],
      interests: List<String>.from(json['interests'] ?? []),
      communities: List<String>.from(json['communities'] ?? []),
      followers: json['followers_count'] ?? json['followers'] ?? 0,
      following: json['following_count'] ?? json['following'] ?? 0,
      isVerified: json['verified'] ?? json['isVerified'] ?? false,
      isPremium: json['isPremium'] ?? false,
      reputation: json['reputation'] ?? 0,
      sid: generatedSid,
      level: json['level'] ?? 1,
      xp: json['xp'] ?? json['experience'] ?? 0,
      totalXp: json['totalXp'] ?? 1000,
      totalPosts: json['totalPosts'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      badges: List<String>.from(json['badges'] ?? []),
      levelTitle: json['levelTitle'] ?? 'Newcomer',
      selectedStudyCategory: json['selected_study_category'] ?? json['selectedStudyCategory'],
      categoryLockExpiry: json['category_lock_expiry'] != null 
          ? DateTime.tryParse(json['category_lock_expiry'].toString())
          : (json['categoryLockExpiry'] != null ? DateTime.tryParse(json['categoryLockExpiry'].toString()) : null),
      silverCoins: json['silverCoins'] ?? json['coins'] ?? 0,
      learningStreak: json['learningStreak'] ?? 0,
      vipLevel: json['vip_level'] ?? json['vipLevel'] ?? 0,
      novelLevel: json['novel_level'] ?? json['novelLevel'] ?? 0,
      careerLevel: json['career_level'] ?? json['careerLevel'] ?? 1,
      avatarFrame: json['avatar_frame'] ?? json['avatarFrame'] ?? 'Normal',
      diamonds: json['diamonds'] ?? 0,
      friendsCount: json['friends_count'] ?? json['friendsCount'] ?? 0,
      roomsJoined: json['rooms_joined'] ?? json['roomsJoined'] ?? 0,
      eventsJoined: json['events_joined'] ?? json['eventsJoined'] ?? 0,
      onlineStatus: json['online_status'] ?? json['onlineStatus'] ?? false,
      lastSeen: json['last_seen'] != null ? DateTime.tryParse(json['last_seen']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      emailVerified: json['email_verified'] ?? json['emailVerified'] ?? false,
      verificationTimestamp: json['verification_timestamp'] != null ? DateTime.tryParse(json['verification_timestamp'].toString()) : null,
      verificationMethod: json['verification_method'] ?? json['verificationMethod'],
      lastVerificationDate: json['last_verification_date'] != null ? DateTime.tryParse(json['last_verification_date'].toString()) : null,
    );
  }

  final String id;
  final String uid; // Numeric UID
  final String username;
  final String email;
  final String? phone;
  final String displayName;
  final String? fullName;
  final String? avatar;
  final String? coverPhoto;
  final String? bio;
  final DateTime? dob;
  final int age;
  final String? gender;
  final String? country;
  final String? state;
  final String? city;
  final String language;
  final String? profession;
  final String? education;
  final String? website;
  final String? instagram;
  final String? youtube;
  final String? twitter;
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
  final int vipLevel;
  final int novelLevel;
  final int careerLevel;
  final String avatarFrame;

  // Additional prompt-specified attributes
  final int diamonds;
  final int friendsCount;
  final int roomsJoined;
  final int eventsJoined;
  final bool onlineStatus;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool emailVerified;
  final DateTime? verificationTimestamp;
  final String? verificationMethod;
  final DateTime? lastVerificationDate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'username': username,
        'email': email,
        'phone': phone,
        'displayName': displayName,
        'full_name': fullName,
        'avatar': avatar,
        'profile_photo': avatar,
        'avatar_url': avatar,
        'coverPhoto': coverPhoto,
        'cover_photo': coverPhoto,
        'bio': bio,
        'dob': dob?.toIso8601String(),
        'age': age,
        'gender': gender,
        'country': country,
        'state': state,
        'city': city,
        'language': language,
        'profession': profession,
        'education': education,
        'website': website,
        'instagram': instagram,
        'youtube': youtube,
        'twitter': twitter,
        'interests': interests,
        'communities': communities,
        'followers': followers,
        'followers_count': followers,
        'following': following,
        'following_count': following,
        'isVerified': isVerified,
        'verified': isVerified,
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
        'selected_study_category': selectedStudyCategory,
        'categoryLockExpiry': categoryLockExpiry?.toIso8601String(),
        'category_lock_expiry': categoryLockExpiry?.toIso8601String(),
        'silverCoins': silverCoins,
        'coins': silverCoins,
        'learningStreak': learningStreak,
        'vip_level': vipLevel,
        'novel_level': novelLevel,
        'career_level': careerLevel,
        'avatar_frame': avatarFrame,
        'diamonds': diamonds,
        'friends_count': friendsCount,
        'rooms_joined': roomsJoined,
        'events_joined': eventsJoined,
        'online_status': onlineStatus,
        'last_seen': lastSeen?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'email_verified': emailVerified,
        'verification_timestamp': verificationTimestamp?.toIso8601String(),
        'verification_method': verificationMethod,
        'last_verification_date': lastVerificationDate?.toIso8601String(),
      };
}
