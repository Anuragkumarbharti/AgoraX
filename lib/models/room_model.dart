class VoiceRoom {

  VoiceRoom({
    required this.id,
    required this.name,
    required this.description,
    required this.hostId,
    required this.communityId,
    required this.type,
    required this.isLive,
    required this.participantCount,
    required this.maxParticipants,
    required this.speakerIds,
    required this.listenerIds,
    this.recordingUrl,
    required this.allowRecording,
    required this.allowScreenShare,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    // Expanded fields
    this.avatar,
    this.banner,
    required this.ownerName,
    required this.category,
    required this.country,
    required this.language,
    required this.tags,
    required this.rules,
    this.level = 1,
    this.xp = 0,
    this.badges = 1,
    this.totalMembers = 0,
    this.totalFollowers = 0,
    this.totalGiftsReceived = 0,
    this.isPermanent = false,
    this.entryPermission = 'everyone',
    required this.coOwnerIds,
    required this.adminIds,
    required this.starMemberIds,
    this.extraCoOwnerSlots = 0,
    this.extraAdminSlots = 0,
    this.extraStarMemberSlots = 0,
  });

  factory VoiceRoom.fromJson(Map<String, dynamic> json) {
    return VoiceRoom(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      hostId: json['hostId'] ?? '',
      communityId: json['communityId'] ?? '',
      type: json['type'] ?? 'discussion',
      isLive: json['isLive'] ?? false,
      participantCount: json['participantCount'] ?? 0,
      maxParticipants: json['maxParticipants'] ?? 500,
      speakerIds: List<String>.from(json['speakerIds'] ?? []),
      listenerIds: List<String>.from(json['listenerIds'] ?? []),
      recordingUrl: json['recordingUrl'] != null ? List<String>.from(json['recordingUrl']) : null,
      allowRecording: json['allowRecording'] ?? true,
      allowScreenShare: json['allowScreenShare'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
      // Expanded fields
      avatar: json['avatar'],
      banner: json['banner'],
      ownerName: json['ownerName'] ?? 'Anurag Kumar Bharti',
      category: json['category'] ?? 'Education',
      country: json['country'] ?? 'India',
      language: json['language'] ?? 'English',
      tags: List<String>.from(json['tags'] ?? []),
      rules: List<String>.from(json['rules'] ?? []),
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      badges: json['badges'] ?? 1,
      totalMembers: json['totalMembers'] ?? 0,
      totalFollowers: json['totalFollowers'] ?? 0,
      totalGiftsReceived: json['totalGiftsReceived'] ?? 0,
      isPermanent: json['isPermanent'] ?? false,
      entryPermission: json['entryPermission'] ?? 'everyone',
      coOwnerIds: List<String>.from(json['coOwnerIds'] ?? []),
      adminIds: List<String>.from(json['adminIds'] ?? []),
      starMemberIds: List<String>.from(json['starMemberIds'] ?? []),
      extraCoOwnerSlots: json['extraCoOwnerSlots'] ?? 0,
      extraAdminSlots: json['extraAdminSlots'] ?? 0,
      extraStarMemberSlots: json['extraStarMemberSlots'] ?? 0,
    );
  }

  final String id;
  final String name;
  final String description;
  final String hostId;
  final String communityId;
  final String type; // discussion, study, debate, hangout, event
  final bool isLive;
  final int participantCount;
  final int maxParticipants;
  final List<String> speakerIds;
  final List<String> listenerIds;
  final List<String>? recordingUrl;
  final bool allowRecording;
  final bool allowScreenShare;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  // Expanded fields
  final String? avatar;
  final String? banner;
  final String ownerName;
  final String category;
  final String country;
  final String language;
  final List<String> tags;
  final List<String> rules;
  final int level;
  final int xp;
  final int badges;
  final int totalMembers;
  final int totalFollowers;
  final int totalGiftsReceived;
  final bool isPermanent;
  final String entryPermission;
  final List<String> coOwnerIds;
  final List<String> adminIds;
  final List<String> starMemberIds;
  final int extraCoOwnerSlots;
  final int extraAdminSlots;
  final int extraStarMemberSlots;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'hostId': hostId,
    'communityId': communityId,
    'type': type,
    'isLive': isLive,
    'participantCount': participantCount,
    'maxParticipants': maxParticipants,
    'speakerIds': speakerIds,
    'listenerIds': listenerIds,
    'recordingUrl': recordingUrl,
    'allowRecording': allowRecording,
    'allowScreenShare': allowScreenShare,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    // Expanded fields
    'avatar': avatar,
    'banner': banner,
    'ownerName': ownerName,
    'category': category,
    'country': country,
    'language': language,
    'tags': tags,
    'rules': rules,
    'level': level,
    'xp': xp,
    'badges': badges,
    'totalMembers': totalMembers,
    'totalFollowers': totalFollowers,
    'totalGiftsReceived': totalGiftsReceived,
    'isPermanent': isPermanent,
    'entryPermission': entryPermission,
    'coOwnerIds': coOwnerIds,
    'adminIds': adminIds,
    'starMemberIds': starMemberIds,
    'extraCoOwnerSlots': extraCoOwnerSlots,
    'extraAdminSlots': extraAdminSlots,
    'extraStarMemberSlots': extraStarMemberSlots,
  };
}
