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
  }) : username = username ?? ('@' + id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), ''));

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: (json['username'] ?? 'cm_' + (json['id'] ?? '').toString().replaceAll('CRN-CM-', '').toLowerCase()).toString().startsWith('@')
          ? (json['username'] ?? 'cm_' + (json['id'] ?? '').toString().replaceAll('CRN-CM-', '').toLowerCase()).toString()
          : '@${json['username'] ?? 'cm_' + (json['id'] ?? '').toString().replaceAll('CRN-CM-', '').toLowerCase()}',
      description: json['description'] ?? '',
      image: json['image'],
      banner: json['banner'],
      category: json['category'] ?? '',
      type: json['type'] ?? 'public',
      owner: json['owner'] ?? '',
      coOwnerIds: List<String>.from(json['coOwnerIds'] ?? []),
      admins: List<String>.from(json['admins'] ?? []),
      members: List<String>.from(json['members'] ?? []),
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
    );
  }
  final String id;
  final String name;
  final String username;
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
  bool get isPrivate => type == 'private';
  
  // Starmaker/Role attributes
  final int level;
  final int xp;
  final String creationType;
  final bool isApproved;
  final bool isLogoUnlocked;
  final List<CommunityTask> tasks;
  final String rules;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username.startsWith('@') ? username.substring(1) : username,
        'name': name,
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
      };

  Community copyWith({
    String? name,
    String? username,
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
  }) {
    return Community(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
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
    );
  }
}
