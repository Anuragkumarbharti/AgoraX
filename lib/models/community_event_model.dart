class CommunityEvent {
  final String id;
  final String communityId;
  final String name;
  final String? banner;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? hostId;
  final List<String> coHosts;
  final int maxParticipants;
  final String? rewards;
  final String? rules;
  final String status; // 'upcoming', 'live', 'completed', 'cancelled'

  CommunityEvent({
    required this.id,
    required this.communityId,
    required this.name,
    this.banner,
    this.description,
    required this.startTime,
    required this.endTime,
    this.hostId,
    this.coHosts = const [],
    this.maxParticipants = 0,
    this.rewards,
    this.rules,
    required this.status,
  });

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    return CommunityEvent(
      id: json['id'] ?? '',
      communityId: json['community_id'] ?? json['communityId'] ?? '',
      name: json['name'] ?? '',
      banner: json['banner'],
      description: json['description'],
      startTime: DateTime.parse(json['start_time'] ?? json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(json['end_time'] ?? json['endTime'] ?? DateTime.now().toIso8601String()),
      hostId: json['host_id'] ?? json['hostId'],
      coHosts: List<String>.from(json['co_hosts'] ?? json['coHosts'] ?? []),
      maxParticipants: json['max_participants'] ?? json['maxParticipants'] ?? 0,
      rewards: json['rewards'],
      rules: json['rules'],
      status: json['status'] ?? 'upcoming',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'community_id': communityId,
        'name': name,
        'banner': banner,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'host_id': hostId,
        'co_hosts': coHosts,
        'max_participants': maxParticipants,
        'rewards': rewards,
        'rules': rules,
        'status': status,
      };
}

class CommunityAnnouncement {
  final String id;
  final String communityId;
  final String title;
  final String content;
  final bool isPinned;
  final String? createdBy;
  final DateTime createdAt;

  CommunityAnnouncement({
    required this.id,
    required this.communityId,
    required this.title,
    required this.content,
    required this.isPinned,
    this.createdBy,
    required this.createdAt,
  });

  factory CommunityAnnouncement.fromJson(Map<String, dynamic> json) {
    return CommunityAnnouncement(
      id: json['id'] ?? '',
      communityId: json['community_id'] ?? json['communityId'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
      createdBy: json['created_by'] ?? json['createdBy'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'community_id': communityId,
        'title': title,
        'content': content,
        'is_pinned': isPinned,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };
}

class CommunityLog {
  final String id;
  final String communityId;
  final String? userId;
  final String actionType;
  final String description;
  final DateTime createdAt;

  CommunityLog({
    required this.id,
    required this.communityId,
    this.userId,
    required this.actionType,
    required this.description,
    required this.createdAt,
  });

  factory CommunityLog.fromJson(Map<String, dynamic> json) {
    return CommunityLog(
      id: json['id'] ?? '',
      communityId: json['community_id'] ?? json['communityId'] ?? '',
      userId: json['user_id'] ?? json['userId'],
      actionType: json['action_type'] ?? json['actionType'] ?? '',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'community_id': communityId,
        'user_id': userId,
        'action_type': actionType,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };
}
