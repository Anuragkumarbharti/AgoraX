class User {
  User({
    required this.id,
    this.uid = '',
    required this.username,
    required this.email,
    this.phone,
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
    this.tagLights = const [],
    this.rTags = const [],
    this.showcasedBadges = const [],
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
    this.totalStarsReceived = 0,
    this.totalStarsGifted = 0,
    this.vipExpiry,
    this.novelExpiry,
    this.tagSystem,
    String? displayName,
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
      profession: json['profession'],
      education: json['education'],
      website: json['website'],
      instagram: json['instagram'],
      youtube: json['youtube'],
      twitter: json['twitter'],
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
      tagLights: List<String>.from(json['tag_lights'] ?? []),
      rTags: List<String>.from(json['r_tags'] ?? []),
      showcasedBadges: List<String>.from(json['showcased_badges'] ?? []),
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
      totalStarsReceived: json['total_stars_received'] ?? json['totalStarsReceived'] ?? 0,
      totalStarsGifted: json['total_stars_gifted'] ?? json['totalStarsGifted'] ?? 0,
      vipExpiry: json['vip_expiry'] != null ? DateTime.tryParse(json['vip_expiry'].toString()) : null,
      novelExpiry: json['novel_expiry'] != null ? DateTime.tryParse(json['novel_expiry'].toString()) : null,
      tagSystem: json['tag_system'] != null ? TagSystem.fromJson(json['tag_system'] as Map<String, dynamic>) : null,
    );
  }

  final String id;
  final String uid; // Numeric UID
  final String username;
  final String email;
  final String? phone;
  String get displayName => username;
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
  final List<String> tagLights;
  final List<String> rTags;
  final List<String> showcasedBadges;
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
  final int totalStarsReceived;
  final int totalStarsGifted;
  final DateTime? vipExpiry;
  final DateTime? novelExpiry;
  final TagSystem? tagSystem;

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
        'tag_lights': tagLights,
        'r_tags': rTags,
        'showcased_badges': showcasedBadges,
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
        'total_stars_received': totalStarsReceived,
        'total_stars_gifted': totalStarsGifted,
        'vip_expiry': vipExpiry?.toIso8601String(),
        'novel_expiry': novelExpiry?.toIso8601String(),
        'tag_system': tagSystem?.toJson(),
      };

  User copyWith({
    String? id,
    String? uid,
    String? username,
    String? email,
    String? phone,
    String? displayName,
    String? fullName,
    String? avatar,
    String? coverPhoto,
    String? bio,
    DateTime? dob,
    int? age,
    String? gender,
    String? country,
    String? state,
    String? city,
    String? language,
    String? profession,
    String? education,
    String? website,
    String? instagram,
    String? youtube,
    String? twitter,
    List<String>? interests,
    List<String>? communities,
    int? followers,
    int? following,
    bool? isVerified,
    bool? isPremium,
    int? reputation,
    String? sid,
    int? level,
    int? xp,
    int? totalXp,
    int? totalPosts,
    int? totalQuestions,
    List<String>? badges,
    List<String>? tagLights,
    List<String>? rTags,
    List<String>? showcasedBadges,
    String? levelTitle,
    String? selectedStudyCategory,
    DateTime? categoryLockExpiry,
    int? silverCoins,
    int? learningStreak,
    int? vipLevel,
    int? novelLevel,
    int? careerLevel,
    String? avatarFrame,
    int? diamonds,
    int? friendsCount,
    int? roomsJoined,
    int? eventsJoined,
    bool? onlineStatus,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? emailVerified,
    DateTime? verificationTimestamp,
    String? verificationMethod,
    DateTime? lastVerificationDate,
    int? totalStarsReceived,
    int? totalStarsGifted,
    DateTime? vipExpiry,
    DateTime? novelExpiry,
    TagSystem? tagSystem,
  }) {
    return User(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      avatar: avatar ?? this.avatar,
      coverPhoto: coverPhoto ?? this.coverPhoto,
      bio: bio ?? this.bio,
      dob: dob ?? this.dob,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      language: language ?? this.language,
      profession: profession ?? this.profession,
      education: education ?? this.education,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      youtube: youtube ?? this.youtube,
      twitter: twitter ?? this.twitter,
      interests: interests ?? this.interests,
      communities: communities ?? this.communities,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      reputation: reputation ?? this.reputation,
      sid: sid ?? this.sid,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      totalXp: totalXp ?? this.totalXp,
      totalPosts: totalPosts ?? this.totalPosts,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      badges: badges ?? this.badges,
      tagLights: tagLights ?? this.tagLights,
      rTags: rTags ?? this.rTags,
      showcasedBadges: showcasedBadges ?? this.showcasedBadges,
      levelTitle: levelTitle ?? this.levelTitle,
      selectedStudyCategory: selectedStudyCategory ?? this.selectedStudyCategory,
      categoryLockExpiry: categoryLockExpiry ?? this.categoryLockExpiry,
      silverCoins: silverCoins ?? this.silverCoins,
      learningStreak: learningStreak ?? this.learningStreak,
      vipLevel: vipLevel ?? this.vipLevel,
      novelLevel: novelLevel ?? this.novelLevel,
      careerLevel: careerLevel ?? this.careerLevel,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      diamonds: diamonds ?? this.diamonds,
      friendsCount: friendsCount ?? this.friendsCount,
      roomsJoined: roomsJoined ?? this.roomsJoined,
      eventsJoined: eventsJoined ?? this.eventsJoined,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      emailVerified: emailVerified ?? this.emailVerified,
      verificationTimestamp: verificationTimestamp ?? this.verificationTimestamp,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      lastVerificationDate: lastVerificationDate ?? this.lastVerificationDate,
      totalStarsReceived: totalStarsReceived ?? this.totalStarsReceived,
      totalStarsGifted: totalStarsGifted ?? this.totalStarsGifted,
      vipExpiry: vipExpiry ?? this.vipExpiry,
      novelExpiry: novelExpiry ?? this.novelExpiry,
      tagSystem: tagSystem ?? this.tagSystem,
    );
  }
}

class TagSystem {
  final List<IdentityTag> identityTagBar;
  final OfficialStatus officialStatus;
  final List<String> profileShowcase;

  TagSystem({
    required this.identityTagBar,
    required this.officialStatus,
    required this.profileShowcase,
  });

  factory TagSystem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> tagBarList = json['identityTagBar'] ?? [];
    final Map<String, dynamic> statusMap = json['officialStatus'] ?? {};
    final List<dynamic> showcaseList = json['profileShowcase'] ?? [];

    return TagSystem(
      identityTagBar: tagBarList.map((e) => IdentityTag.fromJson(Map<String, dynamic>.from(e))).toList(),
      officialStatus: OfficialStatus.fromJson(statusMap),
      profileShowcase: List<String>.from(showcaseList),
    );
  }

  Map<String, dynamic> toJson() => {
    'identityTagBar': identityTagBar.map((e) => e.toJson()).toList(),
    'officialStatus': officialStatus.toJson(),
    'profileShowcase': profileShowcase,
  };
}

class IdentityTag {
  final String type;
  final String value;

  IdentityTag({required this.type, required this.value});

  factory IdentityTag.fromJson(Map<String, dynamic> json) {
    return IdentityTag(
      type: json['type'] ?? '',
      value: json['value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
  };
}

class OfficialStatus {
  final String? verifiedTag;
  final String? roleTag;

  OfficialStatus({this.verifiedTag, this.roleTag});

  factory OfficialStatus.fromJson(Map<String, dynamic> json) {
    return OfficialStatus(
      verifiedTag: json['verifiedTag'],
      roleTag: json['roleTag'],
    );
  }

  Map<String, dynamic> toJson() => {
    'verifiedTag': verifiedTag,
    'roleTag': roleTag,
  };
}
