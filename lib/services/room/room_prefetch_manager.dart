import 'package:flutter/material.dart';
import '../../models/room/room_model.dart';

class FastPrefetchItem {
  final VoiceRoom room;
  final DateTime prefetchedAt;
  final String joinToken;
  final Map<String, dynamic>? preloadedPayload;

  FastPrefetchItem({
    required this.room,
    required this.prefetchedAt,
    required this.joinToken,
    this.preloadedPayload,
  });

  bool get isExpired => DateTime.now().difference(prefetchedAt).inSeconds > 60;
}

class RoomPrefetchManager {
  static final RoomPrefetchManager _instance = RoomPrefetchManager._internal();
  factory RoomPrefetchManager() => _instance;
  RoomPrefetchManager._internal();

  final Map<String, FastPrefetchItem> _cache = {};

  /// Prefetch room metadata, host avatar, cover image, and join token in background
  void prefetchRoom(VoiceRoom room, [BuildContext? context]) {
    if (_cache.containsKey(room.id) && !_cache[room.id]!.isExpired) {
      return;
    }

    try {
      final shortLivedToken = 'JOIN_TOK_${room.id.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';

      if (context != null) {
        if (room.avatar != null && room.avatar!.isNotEmpty) {
          precacheImage(NetworkImage(room.avatar!), context).catchError((_) {});
        }
        if (room.banner != null && room.banner!.isNotEmpty) {
          precacheImage(NetworkImage(room.banner!), context).catchError((_) {});
        }
      }

      _cache[room.id] = FastPrefetchItem(
        room: room,
        prefetchedAt: DateTime.now(),
        joinToken: shortLivedToken,
      );

      debugPrint('[RoomPrefetchManager] Prefetched room ${room.id} (${room.name}) with join token.');
    } catch (e) {
      debugPrint('[RoomPrefetchManager] Prefetch skipped: $e');
    }
  }

  /// Get prefetched item if available and valid
  FastPrefetchItem? getPrefetchedRoom(String roomId) {
    final item = _cache[roomId];
    if (item != null && !item.isExpired) {
      return item;
    }
    return null;
  }

  void clearCache() {
    _cache.clear();
  }
}
