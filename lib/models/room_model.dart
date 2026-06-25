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
  };
}
