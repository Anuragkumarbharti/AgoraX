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

abstract class ArenaEventTypes {
  static const String roomEnter = 'ROOM_ENTER';
  static const String roomLeave = 'ROOM_LEAVE';
  static const String seatTaken = 'SEAT_TAKEN';
  static const String seatLeft = 'SEAT_LEFT';
  static const String seatChanged = 'SEAT_CHANGED';
  static const String hostSeatTaken = 'HOST_SEAT_TAKEN';
  static const String hostSeatLeft = 'HOST_SEAT_LEFT';
  static const String cohostSeatTaken = 'COHOST_SEAT_TAKEN';
  static const String cohostSeatLeft = 'COHOST_SEAT_LEFT';
  static const String luckyCoinWon = 'LUCKY_COIN_WON';
}

class ArenaEventFormatter {
  static String formatCanonicalSeatLabel(int seatIndex) {
    switch (seatIndex) {
      case 0:
        return 'Host';
      case 1:
        return 'Co-Host';
      case 2:
        return 'No.1';
      case 3:
        return 'No.2';
      case 4:
        return 'No.3';
      case 5:
        return 'No.4';
      case 6:
        return 'No.5';
      case 7:
        return 'No.6';
      case 8:
        return 'No.7';
      case 9:
        return 'No.8';
      default:
        return 'No.${seatIndex - 1}';
    }
  }

  static String formatSeatTakeMessage(String username, int seatIndex) {
    final label = formatCanonicalSeatLabel(seatIndex);
    return '$username joined $label';
  }

  static String formatSeatLeaveMessage(String username, int seatIndex) {
    final label = formatCanonicalSeatLabel(seatIndex);
    return '$username left $label';
  }

  static String formatSeatMoveMessage(String username, int fromSeatIndex, int toSeatIndex) {
    final fromLabel = formatCanonicalSeatLabel(fromSeatIndex);
    final toLabel = formatCanonicalSeatLabel(toSeatIndex);
    return '$username moved from $fromLabel to $toLabel';
  }

  static String formatRoomEnterMessage(String username) {
    return '$username has entered the room';
  }

  static String formatRoomLeaveMessage(String username) {
    return '$username left the room';
  }

  static String formatLuckyCoinWinMessage(String username, int amount) {
    final formattedAmount = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '🍀 $username won $formattedAmount Coins!';
  }
}

