import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/gift/gift_animation_metadata.dart';
import './gift_media_manager.dart';

class GiftAnimationEventPayload {
  final String id;
  final String giftId;
  final String giftName;
  final String giftIcon;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final List<String> receiverIds;
  final List<String> receiverNames;
  final List<int> receiverSeats;
  final GiftTier tier;
  final String currency;
  final int price;
  final int count;
  final int timestamp;

  GiftAnimationEventPayload({
    required this.id,
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.receiverIds,
    required this.receiverNames,
    required this.receiverSeats,
    required this.tier,
    this.currency = 'gold',
    this.price = 10,
    this.count = 1,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'giftId': giftId,
        'giftName': giftName,
        'giftIcon': giftIcon,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'receiverIds': receiverIds,
        'receiverNames': receiverNames,
        'receiverSeats': receiverSeats,
        'tier': tier.name,
        'currency': currency,
        'price': price,
        'count': count,
        'timestamp': timestamp,
      };
}

class GiftAnimationController extends GetxController {
  static GiftAnimationController get to {
    if (!Get.isRegistered<GiftAnimationController>()) {
      return Get.put(GiftAnimationController());
    }
    return Get.find<GiftAnimationController>();
  }

  final RxList<GiftAnimationEventPayload> activeEvents =
      <GiftAnimationEventPayload>[].obs;
  final Set<String> _processedEventIds = {};

  // ── StarMaker-Style Combo Accumulator ─────────────────────────────────────
  /// Live accumulated combo count for the CURRENTLY playing animation.
  /// The engine widget listens to this and bumps ×N counter in-place WITHOUT
  /// restarting the animation. Resets each time a new (non-mergeable) animation starts.
  final ValueNotifier<int> activeComboCount = ValueNotifier<int>(1);

  /// Merge eligibility key: "giftId|senderId". Cleared when animation ends.
  String _activeComboKey = '';

  /// True ONLY while the active animation is in Stage 3 or Stage 4 (center showcase).
  /// Merge is ONLY allowed during this window.
  ///
  /// Lifecycle (per animation):
  ///   Stage 1/2  (seat → center, "come") → false → fresh animation forced
  ///   Stage 3/4  (center showcase)       → true  → merge window OPEN
  ///   Stage 5-10 (center → seat, "go")   → false → fresh animation forced
  bool _isInShowcasePhase = false;

  // ── Showcase Phase Gate ────────────────────────────────────────────────────

  /// Called by the animation engine on every build frame to report
  /// whether the animation is currently in Stage 3 or Stage 4.
  /// Opening/closing the gate controls when combo merges are allowed.
  void setShowcasePhase(bool active) {
    if (_isInShowcasePhase == active) return;
    _isInShowcasePhase = active;
    debugPrint(
      '[GiftCombo] Showcase gate: ${active ? 'OPEN ✔ (merge allowed)' : 'CLOSED ✘ (fresh animation)'}',
    );
  }

  // ── Merge Logic ────────────────────────────────────────────────────────────

  /// Attempts to merge [incomingCount] into the currently playing animation.
  ///
  /// Merge succeeds ONLY when ALL conditions are true:
  ///   • activeEvents is not empty (animation is running)
  ///   • _isInShowcasePhase == true (currently in Stage 3 or 4)
  ///   • Incoming giftId AND senderId match the active event
  ///
  /// On success → bumps [activeComboCount], returns true (no new event added).
  /// On failure → returns false → caller starts a fresh animation event.
  bool tryMergeIntoActive({
    required String giftId,
    required String senderId,
    required int incomingCount,
  }) {
    if (activeEvents.isEmpty) return false;

    // Showcase-phase gate: only merge while Stage 3/4 is visible
    if (!_isInShowcasePhase) {
      debugPrint(
        '[GiftCombo] Merge BLOCKED — not in showcase phase. Fresh animation.',
      );
      return false;
    }

    final comboKey = '$giftId|$senderId';
    if (_activeComboKey != comboKey) return false;

    // Same gift, same sender, showcase window open → bump counter only
    activeComboCount.value += incomingCount;
    debugPrint(
      '[GiftCombo] MERGED in showcase: $giftId ×${activeComboCount.value}',
    );
    return true;
  }

  /// Resets the combo counter and closes the showcase gate for a new animation.
  void _resetComboFor(GiftAnimationEventPayload payload) {
    _activeComboKey = '${payload.giftId}|${payload.senderId}';
    activeComboCount.value = payload.count;
    _isInShowcasePhase = false; // gate starts closed; engine opens at Stage 3
  }

  // ── Event Dispatch ─────────────────────────────────────────────────────────

  /// Dispatches a backend-broadcasted gift event payload to reconstruct animation locally.
  ///
  /// StarMaker merge rule:
  ///   • Same giftId + senderId while animation is active → merge (counter bump only, no restart).
  ///   • Different gift or sender → start fresh animation.
  void dispatchBroadcastGiftEvent(Map<String, dynamic> payload) {
    final String eventId = payload['id'] ??
        payload['timestamp']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();

    if (_processedEventIds.contains(eventId)) return;
    _processedEventIds.add(eventId);
    if (_processedEventIds.length > 200) {
      _processedEventIds.remove(_processedEventIds.first);
    }

    final String rawGiftId =
        (payload['gift_id'] ?? payload['giftId'] ?? '').toString().trim();
    final String rawGiftName =
        (payload['gift_name'] ?? payload['giftName'] ?? payload['name'] ?? '')
            .toString()
            .trim();

    final String lookupKey = (rawGiftId.isNotEmpty &&
            rawGiftId != 'gift_default' &&
            rawGiftId != 'gift')
        ? rawGiftId
        : (rawGiftName.isNotEmpty ? rawGiftName : 'Gift');

    final meta = GiftMetadataRegistry.getMetadata(lookupKey);

    final String giftId = (rawGiftId.isNotEmpty && rawGiftId != 'gift_default')
        ? rawGiftId
        : meta.giftId;
    final String giftName =
        (rawGiftName.isNotEmpty && rawGiftName.toLowerCase() != 'gift')
            ? rawGiftName
            : meta.giftName;

    final String rawIcon =
        payload['gift_icon'] ?? payload['giftIcon'] ?? payload['icon'] ?? '';
    final String giftIcon = rawIcon.isNotEmpty ? rawIcon : meta.giftIcon;

    final String senderId = payload['sender_id'] ??
        payload['senderId'] ??
        payload['user_id'] ??
        'sender';
    final String senderName = payload['sender_name'] ??
        payload['senderName'] ??
        payload['username'] ??
        'Member';

    final List<dynamic> rIdsRaw = payload['receiver_ids'] ??
        payload['receiverIds'] ??
        [payload['target_user_id'] ?? 'target'];
    final List<String> receiverIds = rIdsRaw.map((e) => e.toString()).toList();

    final List<dynamic> rNamesRaw = payload['receiver_names'] ??
        payload['receiverNames'] ??
        [payload['target_username'] ?? 'User'];
    final List<String> receiverNames =
        rNamesRaw.map((e) => e.toString()).toList();

    final List<dynamic> rSeatsRaw = payload['seat_indices'] ??
        payload['receiverSeats'] ??
        [payload['seat_number'] ?? 0];
    final List<int> receiverSeats =
        rSeatsRaw.map((e) => int.tryParse(e.toString()) ?? 0).toList();

    final int count =
        payload['count'] ?? payload['amount'] ?? payload['quantity'] ?? 1;

    // ── StarMaker Merge Check ─────────────────────────────────────────────
    // If animation is running and same gift+sender → bump counter, skip new event.
    if (tryMergeIntoActive(
      giftId: giftId,
      senderId: senderId,
      incomingCount: count,
    )) {
      return; // Merged into active animation — no restart needed
    }

    final eventPayload = GiftAnimationEventPayload(
      id: eventId,
      giftId: giftId,
      giftName: giftName,
      giftIcon: giftIcon,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: payload['sender_avatar'] ?? payload['senderAvatar'],
      receiverIds: receiverIds,
      receiverNames: receiverNames,
      receiverSeats: receiverSeats,
      tier: meta.tier,
      currency: meta.currency,
      price: meta.price,
      count: count,
      timestamp: payload['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );

    // Pre-warm asset in background via GiftMediaManager
    if (giftIcon.isNotEmpty && !giftIcon.startsWith('assets/')) {
      GiftMediaManager.instance.getOrFetchAnimationFile(giftIcon);
    }

    // Cap maximum active overlay events to 3 to avoid animation storms
    if (activeEvents.length >= 3) {
      activeEvents.removeAt(0);
      debugPrint('[Gift] Queue overflow: Evicted oldest active overlay event to maintain smooth 60 FPS.');
    }

    // Reset combo counter for this fresh animation
    _resetComboFor(eventPayload);

    debugPrint('[Gift] Queue Added: Gift event $eventId queued (×$count)');
    debugPrint('[Gift] Overlay Created: Rendering animation overlay layer');
    debugPrint('[Gift] Asset Loaded: $giftIcon');
    debugPrint('[Gift] Animation Started');

    activeEvents.add(eventPayload);
  }

  void removeEvent(String id) {
    activeEvents.removeWhere((e) => e.id == id);
    // Clear all combo state when animation finishes
    if (activeEvents.isEmpty) {
      _activeComboKey = '';
      activeComboCount.value = 1;
      _isInShowcasePhase = false; // close merge gate
    }
    debugPrint('[Gift] Animation Finished');
  }
}
