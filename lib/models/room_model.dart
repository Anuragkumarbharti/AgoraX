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
    
    // New Roles Hierarchy IDs
    this.founderId = 'uid_anurag_101',
    required this.managerIds,
    required this.moderatorIds,
    required this.hostIds,
    required this.mentorIds,
    required this.judgeIds,
    required this.performerIds,
    required this.eliteMemberIds,
    required this.vipMemberIds,
    required this.memberIds,
    required this.visitorIds,

    // New Room Settings
    this.bulletin = 'Welcome to VoxArena! Be respectful and have fun.',
    this.greetings = 'Hello! Welcome to our Arena.',
    this.roomTheme = 'Classic Dark',
    this.wordFilter = '',
    this.muteAll = false,
    required this.blockList,
    this.whoCanJoin = 'Everyone',
    this.whoCanSpeak = 'Everyone',
    this.seatPermissions = 'Everyone',
    this.invitePermissions = 'Everyone',
    this.giftSettings = 'Enabled',
    this.recommendationSettings = 'Enabled',
    this.musicSettings = 'Enabled',
    this.recordingSettings = 'Enabled',
    this.eventSettings = 'Enabled',
    this.autoModeration = 'Enabled',

    // New Special Mode State
    this.activeMode = 'Social', // Social, Debate, Study, Coaching, Family, Music, Gaming, Community, Event
    this.pinnedAnnouncement = 'Check out the active Poll in the menu!',
    this.currentDebateRound = 1,
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

      // New Roles Hierarchy
      founderId: json['founderId'] ?? 'uid_anurag_101',
      managerIds: List<String>.from(json['managerIds'] ?? []),
      moderatorIds: List<String>.from(json['moderatorIds'] ?? []),
      hostIds: List<String>.from(json['hostIds'] ?? []),
      mentorIds: List<String>.from(json['mentorIds'] ?? []),
      judgeIds: List<String>.from(json['judgeIds'] ?? []),
      performerIds: List<String>.from(json['performerIds'] ?? []),
      eliteMemberIds: List<String>.from(json['eliteMemberIds'] ?? []),
      vipMemberIds: List<String>.from(json['vipMemberIds'] ?? []),
      memberIds: List<String>.from(json['memberIds'] ?? []),
      visitorIds: List<String>.from(json['visitorIds'] ?? []),

      // Settings
      bulletin: json['bulletin'] ?? 'Welcome to VoxArena! Be respectful and have fun.',
      greetings: json['greetings'] ?? 'Hello! Welcome to our Arena.',
      roomTheme: json['roomTheme'] ?? 'Classic Dark',
      wordFilter: json['wordFilter'] ?? '',
      muteAll: json['muteAll'] ?? false,
      blockList: List<String>.from(json['blockList'] ?? []),
      whoCanJoin: json['whoCanJoin'] ?? 'Everyone',
      whoCanSpeak: json['whoCanSpeak'] ?? 'Everyone',
      seatPermissions: json['seatPermissions'] ?? 'Everyone',
      invitePermissions: json['invitePermissions'] ?? 'Everyone',
      giftSettings: json['giftSettings'] ?? 'Enabled',
      recommendationSettings: json['recommendationSettings'] ?? 'Enabled',
      musicSettings: json['musicSettings'] ?? 'Enabled',
      recordingSettings: json['recordingSettings'] ?? 'Enabled',
      eventSettings: json['eventSettings'] ?? 'Enabled',
      autoModeration: json['autoModeration'] ?? 'Enabled',

      // Special Mode State
      activeMode: json['activeMode'] ?? 'Social',
      pinnedAnnouncement: json['pinnedAnnouncement'] ?? 'Check out the active Poll in the menu!',
      currentDebateRound: json['currentDebateRound'] ?? 1,
    );
  }

  final String id;
  final String name;
  final String description;
  final String hostId;
  final String communityId;
  final String type; // Social Room, Debate Room, etc.
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

  // New Roles Hierarchy
  final String founderId;
  final List<String> managerIds;
  final List<String> moderatorIds;
  final List<String> hostIds;
  final List<String> mentorIds;
  final List<String> judgeIds;
  final List<String> performerIds;
  final List<String> eliteMemberIds;
  final List<String> vipMemberIds;
  final List<String> memberIds;
  final List<String> visitorIds;

  // New Room Settings
  final String bulletin;
  final String greetings;
  final String roomTheme;
  final String wordFilter;
  final bool muteAll;
  final List<String> blockList;
  final String whoCanJoin;
  final String whoCanSpeak;
  final String seatPermissions;
  final String invitePermissions;
  final String giftSettings;
  final String recommendationSettings;
  final String musicSettings;
  final String recordingSettings;
  final String eventSettings;
  final String autoModeration;

  // Special Mode State
  final String activeMode;
  final String pinnedAnnouncement;
  final int currentDebateRound;

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
    
    // New Roles Hierarchy
    'founderId': founderId,
    'managerIds': managerIds,
    'moderatorIds': moderatorIds,
    'hostIds': hostIds,
    'mentorIds': mentorIds,
    'judgeIds': judgeIds,
    'performerIds': performerIds,
    'eliteMemberIds': eliteMemberIds,
    'vipMemberIds': vipMemberIds,
    'memberIds': memberIds,
    'visitorIds': visitorIds,

    // Settings
    'bulletin': bulletin,
    'greetings': greetings,
    'roomTheme': roomTheme,
    'wordFilter': wordFilter,
    'muteAll': muteAll,
    'blockList': blockList,
    'whoCanJoin': whoCanJoin,
    'whoCanSpeak': whoCanSpeak,
    'seatPermissions': seatPermissions,
    'invitePermissions': invitePermissions,
    'giftSettings': giftSettings,
    'recommendationSettings': recommendationSettings,
    'musicSettings': musicSettings,
    'recordingSettings': recordingSettings,
    'eventSettings': eventSettings,
    'autoModeration': autoModeration,

    // Special Mode State
    'activeMode': activeMode,
    'pinnedAnnouncement': pinnedAnnouncement,
    'currentDebateRound': currentDebateRound,
  };
}
