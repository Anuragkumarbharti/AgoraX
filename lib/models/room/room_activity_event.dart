class RoomActivityEvent {
  final String eventId;
  final String roomId;
  final String eventType;
  final String? userId;
  final String? username;
  final int? seatNumber;
  final String? targetUserId;
  final String? targetUsername;
  final String message;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  RoomActivityEvent({
    required this.eventId,
    required this.roomId,
    required this.eventType,
    this.userId,
    this.username,
    this.seatNumber,
    this.targetUserId,
    this.targetUsername,
    required this.message,
    required this.metadata,
    required this.createdAt,
  });

  factory RoomActivityEvent.fromJson(Map<String, dynamic> json) {
    return RoomActivityEvent(
      eventId: json['event_id'] ?? json['eventId'] ?? '',
      roomId: json['room_id'] ?? json['roomId'] ?? '',
      eventType: json['event_type'] ?? json['eventType'] ?? '',
      userId: json['user_id'] ?? json['userId'],
      username: json['username'],
      seatNumber: json['seat_number'] != null ? int.tryParse(json['seat_number'].toString()) : null,
      targetUserId: json['target_user_id'] ?? json['targetUserId'],
      targetUsername: json['target_username'] ?? json['targetUsername'],
      message: json['message'] ?? '',
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : {},
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'room_id': roomId,
      'event_type': eventType,
      'user_id': userId,
      'username': username,
      'seat_number': seatNumber,
      'target_user_id': targetUserId,
      'target_username': targetUsername,
      'message': message,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
