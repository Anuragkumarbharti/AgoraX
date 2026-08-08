// lib/services/gifting/arena_gift_recipient_manager.dart
//
// ArenaGiftRecipientManager
// ─────────────────────────
// Single source of truth for Arena Room gift recipient state.
//
// KEY DESIGN: Seat occupancy and active gift recipients are TWO SEPARATE concepts.
//   • _currentOccupants  — users presently sitting on a seat (seat-source)
//   • _activeRecipients  — users actively selected to receive the next gift
//   • _quickGiftProtected — subset locked during an active Quick Gift window
//
// Seat changes update _currentOccupants but NEVER blindly overwrite _activeRecipients.
// Quick-Gift-protected users stay in _activeRecipients even after leaving a seat.
// Room Owner is the permanent fallback when no seat-occupant-derived recipient exists.

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../user/user_profile_cache_manager.dart';
import '../room/room_controller.dart';

// ─── Data Model ──────────────────────────────────────────────────────────────

class RecipientEntry {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final int seatIndex; // -1 if not on any seat (e.g. Room Owner fallback)
  final bool isRoomOwner;

  const RecipientEntry({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.seatIndex = -1,
    this.isRoomOwner = false,
  });

  RecipientEntry copyWith({
    String? userId,
    String? userName,
    String? avatarUrl,
    int? seatIndex,
    bool? isRoomOwner,
  }) {
    return RecipientEntry(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      seatIndex: seatIndex ?? this.seatIndex,
      isRoomOwner: isRoomOwner ?? this.isRoomOwner,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipientEntry &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      'RecipientEntry(id=$userId, name=$userName, seat=$seatIndex, owner=$isRoomOwner)';
}

// ─── Manager ─────────────────────────────────────────────────────────────────

class ArenaGiftRecipientManager extends GetxController {
  static ArenaGiftRecipientManager get to {
    if (!Get.isRegistered<ArenaGiftRecipientManager>()) {
      return Get.put(ArenaGiftRecipientManager());
    }
    return Get.find<ArenaGiftRecipientManager>();
  }

  // ── Internal State ──────────────────────────────────────────────────────────

  /// Users currently sitting on Arena seats (live source from RoomController).
  final Set<String> _currentOccupants = {};

  /// Users actively selected as gift recipients.
  /// Ordered by insertion time; duplicates are impossible.
  final Map<String, RecipientEntry> _activeRecipients = {};

  /// Users locked-in by the active Quick Gift session.
  /// They remain in _activeRecipients even if they leave a seat.
  final Set<String> _quickGiftProtected = {};

  /// Whether a Quick Gift session is currently active.
  bool _quickGiftActive = false;

  /// Room ID this manager was last initialised for.
  String _roomId = '';

  /// Room Owner fallback entry (always resolved when manager is initialised).
  RecipientEntry? _roomOwnerFallback;

  // ── Reactive State (UI-facing) ───────────────────────────────────────────────

  /// All users that should appear in the recipient selector strip.
  /// Includes: currently occupied seats + QG-protected users off-seat + Room Owner (always last).
  final RxList<RecipientEntry> displayableRecipients = <RecipientEntry>[].obs;

  /// Currently selected recipients (for UI ring / check indicator).
  final RxList<RecipientEntry> activeRecipients = <RecipientEntry>[].obs;

  /// Room Owner fallback entry (nullable while panel is closed).
  final Rxn<RecipientEntry> roomOwnerFallback = Rxn<RecipientEntry>();

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Call when the Gift panel opens for a specific room.
  /// Seeds default recipients from ALL occupied seats.
  /// If [targetUserId] is provided, only that user is pre-selected (tap-to-gift flow).
  /// Falls back to Room Owner if no seats are occupied (and no target specified).
  void initForRoom(
    String roomId, {
    String? targetUserId,
    String? targetUserName,
  }) {
    _roomId = roomId;
    _quickGiftActive = false;
    _quickGiftProtected.clear();
    _activeRecipients.clear();
    _currentOccupants.clear();

    // Resolve Room Owner fallback (permanent for this room)
    _roomOwnerFallback = _resolveRoomOwner(roomId);
    roomOwnerFallback.value = _roomOwnerFallback;

    final seats = _getSeats(roomId);

    // Update live occupant set regardless of which mode we use
    for (final seat in seats) {
      final uId = seat['userId'] as String?;
      if (uId == null || uId.isEmpty) continue;
      _currentOccupants.add(uId);
    }

    if (targetUserId != null && targetUserId.isNotEmpty) {
      // Tap-to-gift mode: pre-select only the tapped user.
      final seat =
          seats.firstWhereOrNull((s) => s['userId'] == targetUserId);
      final resolvedName = UserProfileCacheManager.resolveUsernameForGifting(
        targetUserId,
        passedName: targetUserName,
        seatInfo: seat,
      );
      _activeRecipients[targetUserId] = RecipientEntry(
        userId: targetUserId,
        userName: resolvedName,
        avatarUrl: seat?['avatar'] as String?,
        seatIndex: seat?['seatIndex'] as int? ?? -1,
      );
      debugPrint(
        '[ArenaGiftRecipient] initForRoom($roomId): tap-to-gift → $targetUserId.',
      );
    } else {
      // Auto-select-all mode: seed from all occupied seats.
      for (final seat in seats) {
        final uId = seat['userId'] as String?;
        if (uId == null || uId.isEmpty) continue;
        _activeRecipients[uId] = _entryFromSeat(seat);
      }

      // Rule 2: If no occupied seats, auto-select Room Owner as fallback
      if (_activeRecipients.isEmpty && _roomOwnerFallback != null) {
        _activeRecipients[_roomOwnerFallback!.userId] = _roomOwnerFallback!;
        debugPrint(
          '[ArenaGiftRecipient] No seats occupied → Room Owner fallback selected: '
          '${_roomOwnerFallback!.userName}',
        );
      }
    }

    _syncReactiveState();

    debugPrint(
      '[ArenaGiftRecipient] initForRoom($roomId): '
      '${_activeRecipients.length} recipients, '
      '${_currentOccupants.length} occupants.',
    );
  }

  /// Call when the Gift panel is closed / disposed.
  void disposeForRoom() {
    _quickGiftProtected.clear();
    _quickGiftActive = false;
    _activeRecipients.clear();
    _currentOccupants.clear();
    _roomId = '';
    _roomOwnerFallback = null;
    roomOwnerFallback.value = null;
    _syncReactiveState();
    debugPrint('[ArenaGiftRecipient] disposeForRoom() — state cleared.');
  }

  // ── Real-time Seat Change Handler ────────────────────────────────────────────

  /// Called whenever the real-time seat list changes.
  /// Updates _currentOccupants without blindly overwriting _activeRecipients.
  /// Rule 6, 11: Seat changes update display strip but never remove active recipients.
  void onSeatsChanged(String roomId, List<Map<String, dynamic>> newSeats) {
    if (roomId != _roomId) return;

    final newOccupantIds = <String>{};
    final newSeatEntries = <String, RecipientEntry>{};

    for (final seat in newSeats) {
      final uId = seat['userId'] as String?;
      if (uId == null || uId.isEmpty) continue;
      newOccupantIds.add(uId);
      newSeatEntries[uId] = _entryFromSeat(seat);
    }

    _currentOccupants
      ..clear()
      ..addAll(newOccupantIds);

    // Update seat indices for currently-active recipients who changed seats
    for (final uid in newSeatEntries.keys) {
      if (_activeRecipients.containsKey(uid)) {
        _activeRecipients[uid] = newSeatEntries[uid]!;
      }
    }

    // Rule 6: If all seats emptied and no active recipients remain (and no QG protection),
    // automatically fall back to Room Owner.
    final unprotectedEmpty = _activeRecipients.isEmpty ||
        (_activeRecipients.keys
            .every((uid) => !_quickGiftProtected.contains(uid) &&
                !newOccupantIds.contains(uid) &&
                uid != _roomOwnerFallback?.userId));

    if (newOccupantIds.isEmpty &&
        unprotectedEmpty &&
        !_quickGiftActive &&
        _roomOwnerFallback != null) {
      _activeRecipients.clear();
      _activeRecipients[_roomOwnerFallback!.userId] = _roomOwnerFallback!;
      debugPrint(
        '[ArenaGiftRecipient] All seats emptied → Room Owner fallback restored.',
      );
    }

    _syncReactiveState();
  }

  // ── Manual Recipient Control (Rules 4, 5) ────────────────────────────────────

  /// Manually selects a recipient.
  /// No-op if already selected. Deduplication guaranteed.
  void selectRecipient(RecipientEntry entry) {
    if (_activeRecipients.containsKey(entry.userId)) return;
    _activeRecipients[entry.userId] = entry;
    _syncReactiveState();
    debugPrint('[ArenaGiftRecipient] Selected: ${entry.userName}');
  }

  /// Manually unselects a recipient.
  /// If user is Quick-Gift-protected, the unselect is silently ignored.
  void unselectRecipient(String userId) {
    if (_quickGiftProtected.contains(userId)) {
      debugPrint(
        '[ArenaGiftRecipient] Cannot unselect $userId — Quick Gift protected.',
      );
      return;
    }
    _activeRecipients.remove(userId);
    _syncReactiveState();
    debugPrint('[ArenaGiftRecipient] Unselected: $userId');
  }

  /// Toggles selection for a user.
  /// If unselecting would result in zero recipients, Room Owner fallback is added.
  void toggleRecipient(RecipientEntry entry) {
    if (_activeRecipients.containsKey(entry.userId)) {
      unselectRecipient(entry.userId);
      // If we just unselected the last person and no QG protection, add Room Owner
      if (_activeRecipients.isEmpty &&
          !_quickGiftActive &&
          _roomOwnerFallback != null) {
        _activeRecipients[_roomOwnerFallback!.userId] = _roomOwnerFallback!;
        debugPrint(
          '[ArenaGiftRecipient] Last recipient removed → Room Owner fallback added.',
        );
        _syncReactiveState();
      }
    } else {
      selectRecipient(entry);
    }
  }

  // ── Quick Gift Session (Rules 3, 9) ──────────────────────────────────────────

  /// Locks the current active recipients for the Quick Gift window.
  /// While active: leaving a seat does NOT remove a recipient.
  void startQuickGiftSession() {
    _quickGiftActive = true;
    _quickGiftProtected
      ..clear()
      ..addAll(_activeRecipients.keys);
    debugPrint(
      '[ArenaGiftRecipient] QG session started. Protected: $_quickGiftProtected',
    );
  }

  /// Ends the Quick Gift session and clears protection.
  /// Re-validates active recipients against current occupants + Room Owner fallback.
  void endQuickGiftSession() {
    _quickGiftActive = false;
    _quickGiftProtected.clear();

    // Re-validate: keep only users who are still on a seat OR the Room Owner
    final toRemove = _activeRecipients.keys
        .where((uid) =>
            !_currentOccupants.contains(uid) &&
            uid != _roomOwnerFallback?.userId)
        .toList();
    for (final uid in toRemove) {
      _activeRecipients.remove(uid);
    }

    // If nobody remains, restore Room Owner fallback
    if (_activeRecipients.isEmpty && _roomOwnerFallback != null) {
      _activeRecipients[_roomOwnerFallback!.userId] = _roomOwnerFallback!;
    }

    _syncReactiveState();
    debugPrint('[ArenaGiftRecipient] QG session ended. Revalidated.');
  }

  // ── Pre-Send Validation (Rules 5, 7, 13) ─────────────────────────────────────

  /// Returns the final validated recipient list for sending.
  ///
  /// Priority:
  ///   1. Currently selected active recipients (seat occupants or QG-protected)
  ///   2. Room Owner fallback if list would otherwise be empty
  ///
  /// Never returns an empty list if a Room Owner is available.
  /// Removes stale/invalid recipients unless they are QG-protected.
  List<RecipientEntry> validateAndGetFinalRecipients(String roomId) {
    final seats = _getSeats(roomId);
    final currentOccupantIds = seats
        .where((s) => s['userId'] != null)
        .map((s) => s['userId'] as String)
        .toSet();

    final validRecipients = <RecipientEntry>[];

    for (final entry in _activeRecipients.values) {
      final isOnSeat = currentOccupantIds.contains(entry.userId);
      final isQGProtected = _quickGiftProtected.contains(entry.userId);
      final isRoomOwner = entry.userId == _roomOwnerFallback?.userId;

      if (isOnSeat || isQGProtected || isRoomOwner) {
        // Refresh seat info if user is on a seat
        if (isOnSeat) {
          final liveSeat = seats.firstWhereOrNull(
            (s) => s['userId'] == entry.userId,
          );
          if (liveSeat != null) {
            validRecipients.add(_entryFromSeat(liveSeat));
            continue;
          }
        }
        validRecipients.add(entry);
      }
    }

    // Rule 7 / 13: Never send with empty list
    if (validRecipients.isEmpty && _roomOwnerFallback != null) {
      debugPrint(
        '[ArenaGiftRecipient] validateAndGetFinalRecipients: '
        'no valid recipients → using Room Owner fallback.',
      );
      validRecipients.add(_roomOwnerFallback!);
    }

    // Deduplicate by userId (should be impossible, but guard anyway)
    final seen = <String>{};
    final deduplicated =
        validRecipients.where((e) => seen.add(e.userId)).toList();

    debugPrint(
      '[ArenaGiftRecipient] validateAndGetFinalRecipients: '
      '${deduplicated.length} final recipients.',
    );
    return deduplicated;
  }

  // ── Convenience Getters ──────────────────────────────────────────────────────

  bool isSelected(String userId) => _activeRecipients.containsKey(userId);

  bool isQuickGiftProtected(String userId) =>
      _quickGiftProtected.contains(userId);

  int get activeCount => _activeRecipients.length;

  RecipientEntry? get currentRoomOwner => _roomOwnerFallback;

  // ── Private Helpers ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _getSeats(String roomId) {
    if (!Get.isRegistered<RoomController>()) return [];
    return RoomController.to.roomSeatsInfo[roomId] ?? [];
  }

  RecipientEntry _entryFromSeat(Map<String, dynamic> seat) {
    final uid = seat['userId'] as String? ?? '';
    final rawName =
        seat['username'] as String? ?? seat['name'] as String? ?? '';
    final resolved = UserProfileCacheManager.resolveUsernameForGifting(
      uid,
      passedName: rawName,
      seatInfo: seat,
    );
    return RecipientEntry(
      userId: uid,
      userName: resolved,
      avatarUrl: seat['avatar'] as String?,
      seatIndex: seat['seatIndex'] as int? ?? -1,
    );
  }

  RecipientEntry? _resolveRoomOwner(String roomId) {
    if (!Get.isRegistered<RoomController>()) return null;
    final room = RoomController.to.rooms
        .firstWhereOrNull((r) => r.id == roomId);

    final String fallbackUid =
        UserProfileCacheManager.currentUserId.isNotEmpty
            ? UserProfileCacheManager.currentUserId
            : '00000000-0000-0000-0000-000000000000';

    final ownerId = (room?.hostId != null &&
            room!.hostId.isNotEmpty &&
            room.hostId != 'room_owner')
        ? room.hostId
        : fallbackUid;

    final ownerName = UserProfileCacheManager.resolveUsernameForGifting(
      ownerId,
      passedName: room?.ownerName,
    );

    // Try to get the owner's avatar from their seat (if they are on one)
    final seats = _getSeats(roomId);
    final ownerSeat = seats.firstWhereOrNull((s) => s['userId'] == ownerId);
    final avatar = ownerSeat != null ? ownerSeat['avatar'] as String? : null;

    return RecipientEntry(
      userId: ownerId,
      userName: ownerName,
      avatarUrl: avatar,
      seatIndex: ownerSeat != null ? (ownerSeat['seatIndex'] as int? ?? -1) : -1,
      isRoomOwner: true,
    );
  }

  /// Syncs the _activeRecipients and display strip into the Rx observable lists.
  void _syncReactiveState() {
    // Build display list:
    // 1. Currently occupied seat users (in seat-index order)
    // 2. QG-protected users who left their seat (no duplicate)
    // 3. Room Owner (if not already in the list)

    final seats = _getSeats(_roomId);
    final displayMap = <String, RecipientEntry>{};

    // Add all current seat occupants (whether selected or not)
    for (final seat in seats) {
      final uid = seat['userId'] as String?;
      if (uid == null || uid.isEmpty) continue;
      displayMap[uid] = _entryFromSeat(seat);
    }

    // Add QG-protected users who left their seat
    for (final uid in _quickGiftProtected) {
      if (!displayMap.containsKey(uid) && _activeRecipients.containsKey(uid)) {
        displayMap[uid] = _activeRecipients[uid]!;
      }
    }

    // Add Room Owner as last entry (if not already present and owner exists)
    if (_roomOwnerFallback != null &&
        !displayMap.containsKey(_roomOwnerFallback!.userId)) {
      displayMap[_roomOwnerFallback!.userId] = _roomOwnerFallback!;
    }

    displayableRecipients.value = displayMap.values.toList();
    activeRecipients.value = _activeRecipients.values.toList();
  }
}
