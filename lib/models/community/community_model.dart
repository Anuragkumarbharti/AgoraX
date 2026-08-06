class CommunityTask {
  final String id;
  final String title;
  final String description;
  final int target;
  final int current;
  final bool isCompleted;

  CommunityTask({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    this.current = 0,
    this.isCompleted = false,
  });

  CommunityTask copyWith({
    int? current,
    bool? isCompleted,
  }) {
    return CommunityTask(
      id: id,
      title: title,
      description: description,
      target: target,
      current: current ?? this.current,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'target': target,
        'current': current,
        'isCompleted': isCompleted,
      };

  factory CommunityTask.fromJson(Map<String, dynamic> json) {
    return CommunityTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      target: json['target'] ?? 1,
      current: json['current'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class Community {
  Community({
    required this.id,
    required this.name,
    String? username,
    this.identityTag,
    required this.description,
    this.image,
    this.banner,
    required this.category,
    required this.type, // 'public', 'private', 'paid'
    required this.owner, // ownerId
    this.coOwnerIds = const [],
    required this.admins, // adminIds
    required this.members, // memberIds
    required this.memberCount,
    required this.isVerified,
    required this.createdAt,
    this.level = 1,
    this.xp = 0,
    this.creationType = 'coins', // 'coins' or 'apply'
    this.isApproved = true,
    this.isLogoUnlocked = true,
    this.tasks = const [],
    this.rules = 'Be respectful. No spamming or self-promotion.',
    this.isOfficial = false,
    this.joinMode = 'auto_join',
    this.language = 'en',
    this.country = 'IN',
    this.minIdLevel = 1,
    this.preferredLanguages = const [],
    this.preferredCountries = const [],
    this.preferredInterests = const [],
    this.tags = const [],
    this.visibility = 'public',
    this.lifetimeExp = 0,
    this.dailyExp = 0,
    this.weeklyExp = 0,
    this.monthlyExp = 0,
    this.activityScore = 0,
    this.coOwnerLimit = 2,
    this.adminLimit = 5,
  }) : username = username ?? ('@' + id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), ''));

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: (json['username'] ?? 'cm_' + (json['id'] ?? '').toString().replaceAll('CRN-CM-', '').toLowerCase()).toString().startsWith('@')
          ? (json['username'] ?? 'cm_' + (json['id'] ?? '').toString().replaceAll('CRN-CM-', '').toLowerCase()).toString()
          : '@${json['username'] ?? 'cm_' + (json['id'] ?? '').toString().replaceAll('CRN-CM-', '').toLowerCase()}',
      identityTag: json['identityTag'] ?? json['identity_tag'],
      description: json['description'] ?? '',
      image: json['image'],
      banner: json['banner'],
      category: json['category'] ?? '',
      type: json['type'] ?? 'public',
      owner: json['owner'] ?? '',
      coOwnerIds: List<String>.from(json['coOwnerIds'] ?? json['co_owner_ids'] ?? []),
      admins: List<String>.from(json['admins'] ?? json['admins'] ?? []),
      members: List<String>.from(json['members'] ?? json['members'] ?? []),
      memberCount: json['memberCount'] ?? json['member_count'] ?? 0,
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      creationType: json['creationType'] ?? 'coins',
      isApproved: json['isApproved'] ?? true,
      isLogoUnlocked: json['isLogoUnlocked'] ?? true,
      tasks: (json['tasks'] as List?)?.map((t) => CommunityTask.fromJson(t)).toList() ?? [],
      rules: json['rules'] ?? 'Be respectful. No spamming or self-promotion.',
      isOfficial: json['isOfficial'] ?? json['is_official'] ?? false,
      joinMode: json['joinMode'] ?? json['join_mode'] ?? 'auto_join',
      language: json['language'] ?? 'en',
      country: json['country'] ?? 'IN',
      minIdLevel: json['minIdLevel'] ?? json['min_id_level'] ?? 1,
      preferredLanguages: List<String>.from(json['preferredLanguages'] ?? json['preferred_languages'] ?? []),
      preferredCountries: List<String>.from(json['preferredCountries'] ?? json['preferred_countries'] ?? []),
      preferredInterests: List<String>.from(json['preferredInterests'] ?? json['preferred_interests'] ?? []),
      tags: List<String>.from(json['tags'] ?? json['tags'] ?? []),
      visibility: json['visibility'] ?? 'public',
      lifetimeExp: json['lifetimeExp'] ?? json['lifetime_exp'] ?? 0,
      dailyExp: json['dailyExp'] ?? json['daily_exp'] ?? 0,
      weeklyExp: json['weeklyExp'] ?? json['weekly_exp'] ?? 0,
      monthlyExp: json['monthlyExp'] ?? json['monthly_exp'] ?? 0,
      activityScore: json['activityScore'] ?? json['activity_score'] ?? 0,
      coOwnerLimit: json['coOwnerLimit'] ?? json['co_owner_limit'] ?? 2,
      adminLimit: json['adminLimit'] ?? json['admin_limit'] ?? 5,
    );
  }

  final String id;
  final String name;
  final String username;
  final String? identityTag;
  final String description;
  final String? image;
  final String? banner;
  final String category;
  final String type; 
  final String owner;
  final List<String> coOwnerIds;
  final List<String> admins;
  final List<String> members;
  final int memberCount;
  final bool isVerified;
  final DateTime createdAt;
  bool get isPrivate => type == 'private' || visibility == 'private';
  
  // Starmaker/Role attributes
  final int level;
  final int xp;
  final String creationType;
  final bool isApproved;
  final bool isLogoUnlocked;
  final List<CommunityTask> tasks;
  final String rules;

  final bool isOfficial;
  final String joinMode;
  final String language;
  final String country;
  final int minIdLevel;
  final List<String> preferredLanguages;
  final List<String> preferredCountries;
  final List<String> preferredInterests;
  final List<String> tags;
  final String visibility;

  // StarMaker Progression Stats
  final int lifetimeExp;
  final int dailyExp;
  final int weeklyExp;
  final int monthlyExp;
  final int activityScore;
  final int coOwnerLimit;
  final int adminLimit;

  int get requiredExpForNextLevel {
    switch (level) {
      case 1: return 150000;
      case 2: return 600000;
      case 3: return 1600000;
      case 4: return 3400000;
      case 5: return 5400000;
      case 6: return 7900000;
      default: return 0; // level 7 is max
    }
  }

  double get currentLevelProgress {
    if (level >= 7) return 1.0;
    final req = requiredExpForNextLevel;
    if (req <= 0) return 0.0;
    return (xp.toDouble() / req.toDouble()).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username.startsWith('@') ? username.substring(1) : username,
        'name': name,
        'identity_tag': identityTag,
        'description': description,
        'image': image,
        'banner': banner,
        'category': category,
        'type': type,
        'owner': owner,
        'coOwnerIds': coOwnerIds,
        'admins': admins,
        'members': members,
        'memberCount': memberCount,
        'isVerified': isVerified,
        'createdAt': createdAt.toIso8601String(),
        'level': level,
        'xp': xp,
        'creationType': creationType,
        'isApproved': isApproved,
        'isLogoUnlocked': isLogoUnlocked,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'rules': rules,
        'is_official': isOfficial,
        'join_mode': joinMode,
        'language': language,
        'country': country,
        'min_id_level': minIdLevel,
        'preferred_languages': preferredLanguages,
        'preferred_countries': preferredCountries,
        'preferred_interests': preferredInterests,
        'tags': tags,
        'visibility': visibility,
        'lifetime_exp': lifetimeExp,
        'daily_exp': dailyExp,
        'weekly_exp': weeklyExp,
        'monthly_exp': monthlyExp,
        'activity_score': activityScore,
        'co_owner_limit': coOwnerLimit,
        'admin_limit': adminLimit,
      };

  Community copyWith({
    String? name,
    String? username,
    String? identityTag,
    String? description,
    String? image,
    String? banner,
    String? category,
    String? type,
    String? owner,
    List<String>? coOwnerIds,
    List<String>? admins,
    List<String>? members,
    int? memberCount,
    bool? isVerified,
    int? level,
    int? xp,
    String? creationType,
    bool? isApproved,
    bool? isLogoUnlocked,
    List<CommunityTask>? tasks,
    String? rules,
    bool? isOfficial,
    String? joinMode,
    String? language,
    String? country,
    int? minIdLevel,
    List<String>? preferredLanguages,
    List<String>? preferredCountries,
    List<String>? preferredInterests,
    List<String>? tags,
    String? visibility,
    int? lifetimeExp,
    int? dailyExp,
    int? weeklyExp,
    int? monthlyExp,
    int? activityScore,
    int? coOwnerLimit,
    int? adminLimit,
  }) {
    return Community(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      identityTag: identityTag ?? this.identityTag,
      description: description ?? this.description,
      image: image ?? this.image,
      banner: banner ?? this.banner,
      category: category ?? this.category,
      type: type ?? this.type,
      owner: owner ?? this.owner,
      coOwnerIds: coOwnerIds ?? this.coOwnerIds,
      admins: admins ?? this.admins,
      members: members ?? this.members,
      memberCount: memberCount ?? this.memberCount,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      creationType: creationType ?? this.creationType,
      isApproved: isApproved ?? this.isApproved,
      isLogoUnlocked: isLogoUnlocked ?? this.isLogoUnlocked,
      tasks: tasks ?? this.tasks,
      rules: rules ?? this.rules,
      isOfficial: isOfficial ?? this.isOfficial,
      joinMode: joinMode ?? this.joinMode,
      language: language ?? this.language,
      country: country ?? this.country,
      minIdLevel: minIdLevel ?? this.minIdLevel,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      preferredCountries: preferredCountries ?? this.preferredCountries,
      preferredInterests: preferredInterests ?? this.preferredInterests,
      tags: tags ?? this.tags,
      visibility: visibility ?? this.visibility,
      lifetimeExp: lifetimeExp ?? this.lifetimeExp,
      dailyExp: dailyExp ?? this.dailyExp,
      weeklyExp: weeklyExp ?? this.weeklyExp,
      monthlyExp: monthlyExp ?? this.monthlyExp,
      activityScore: activityScore ?? this.activityScore,
      coOwnerLimit: coOwnerLimit ?? this.coOwnerLimit,
      adminLimit: adminLimit ?? this.adminLimit,
    );
  }
}

class CommunityMembership {
  final String id;
  final String communityId;
  final String userId;
  final String role; // 'owner', 'co_owner', 'admin', 'member'
  final DateTime joinedAt;
  final String joinedBy;
  final String joinMethod; // 'auto_join', 'approved', 'creator'
  final int contribution;
  final int expContribution;
  final int activityScore;
  final DateTime lastActiveAt;

  CommunityMembership({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.joinedBy,
    required this.joinMethod,
    required this.contribution,
    required this.expContribution,
    required this.activityScore,
    required this.lastActiveAt,
  });

  factory CommunityMembership.fromJson(Map<String, dynamic> json) {
    return CommunityMembership(
      id: json['id'] ?? '',
      communityId: json['community_id'] ?? json['communityId'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      role: json['role'] ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] ?? json['joinedAt'] ?? DateTime.now().toIso8601String()),
      joinedBy: json['joined_by'] ?? json['joinedBy'] ?? '',
      joinMethod: json['join_method'] ?? json['joinMethod'] ?? 'auto_join',
      contribution: json['contribution'] ?? 0,
      expContribution: json['exp_contribution'] ?? json['expContribution'] ?? 0,
      activityScore: json['activity_score'] ?? json['activityScore'] ?? 0,
      lastActiveAt: DateTime.parse(json['last_active_at'] ?? json['lastActiveAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'community_id': communityId,
        'user_id': userId,
        'role': role,
        'joined_at': joinedAt.toIso8601String(),
        'joined_by': joinedBy,
        'join_method': joinMethod,
        'contribution': contribution,
        'exp_contribution': expContribution,
        'activity_score': activityScore,
        'last_active_at': lastActiveAt.toIso8601String(),
      };
}

class CommunityApplication {
  final String id;
  final String communityId;
  final String userId;
  final String status; // 'pending', 'approved', 'rejected', 'blocked'
  final String? introduction;
  final String? reason;
  final String? preferredLanguage;
  final String? optionalMessage;
  final DateTime createdAt;

  CommunityApplication({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.status,
    this.introduction,
    this.reason,
    this.preferredLanguage,
    this.optionalMessage,
    required this.createdAt,
  });

  factory CommunityApplication.fromJson(Map<String, dynamic> json) {
    return CommunityApplication(
      id: json['id'] ?? '',
      communityId: json['community_id'] ?? json['communityId'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      status: json['status'] ?? 'pending',
      introduction: json['introduction'],
      reason: json['reason'],
      preferredLanguage: json['preferred_language'] ?? json['preferredLanguage'],
      optionalMessage: json['optional_message'] ?? json['optionalMessage'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'community_id': communityId,
        'user_id': userId,
        'status': status,
        'introduction': introduction,
        'reason': reason,
        'preferred_language': preferredLanguage,
        'optional_message': optionalMessage,
        'created_at': createdAt.toIso8601String(),
      };
}
