import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/user_profile_cache_manager.dart';
import '../store/store_controller.dart';
import '../room/room_controller.dart';
import '../room/room_gift_controller.dart';
import '../../widgets/gifting/insufficient_balance_sheet.dart';
import '../../models/gift/gift_animation_metadata.dart';
import 'arena_gift_recipient_manager.dart';

class QuickRepeatState {
  final String originalGiftTransactionId;
  final String roomId;
  final String senderId;
  final String giftId;
  final String giftName;
  final String giftIcon;

  /// Resolved GIF asset path from GiftMetadataRegistry.
  /// e.g. assets/GIFTS_SHOWCCASE/ROSE.gif
  final String giftImageAssetPath;

  final String currency;
  final int giftCost;
  final int originalMultiplier;
  final List<String> originalRecipientIds;
  final List<String> originalRecipientNames;
  final List<int> originalSeatIndices;
  final RxInt currentQuantity;
  final DateTime createdAt;

  QuickRepeatState({
    required this.originalGiftTransactionId,
    required this.roomId,
    required this.senderId,
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.giftImageAssetPath,
    required this.currency,
    required this.giftCost,
    required this.originalMultiplier,
    required this.originalRecipientIds,
    required this.originalRecipientNames,
    required this.originalSeatIndices,
    required int initialQuantity,
    DateTime? createdAt,
  })  : currentQuantity = initialQuantity.obs,
        createdAt = createdAt ?? DateTime.now();

  List<String> get recipientIds => originalRecipientIds;
  List<String> get recipientNames => originalRecipientNames;
  List<int> get seatIndices => originalSeatIndices;
}

/// Timer Logic Summary
/// ───────────────────────────────────────────────────────────────────────────
///
/// GLOBAL TIMER (10s) — drives arc ring, **never resets**:
///   • Starts when first gift is sent.
///   • Counts down from 10 → 0.
///   • At 0 → QuickRepeat is completely removed, no exceptions.
///
/// INACTIVITY TIMER (3s) — drives showcase animation, **only after 1st repeat**:
///   • Does NOT start on initial activation.
///   • Starts after the very first successful Repeat tap.
///   • Resets to 3s on every subsequent successful Repeat tap.
///   • At 0 (no tap for 3s) → fires [shouldTriggerShowcase] = true.
///   • Widget plays showcase animation; QR button stays visible.
///   • Showcase auto-restarts every 3s of inactivity until 10s global expiry.
///
/// Phase Summary:
///   No repeats yet  → Normal display, 10s countdown, no showcase.
///   ≥1 repeat done  → 3s inactivity timer active; showcase fires on expiry.
///   Global 10s done → QR hidden regardless of inactivity state.
/// ───────────────────────────────────────────────────────────────────────────
class QuickRepeatController extends GetxController {
  static QuickRepeatController get to {
    if (!Get.isRegistered<QuickRepeatController>()) {
      return Get.put(QuickRepeatController());
    }
    return Get.find<QuickRepeatController>();
  }

  // ── Timer Constants ────────────────────────────────────────────────────────
  /// Total lifetime of QuickRepeat. Global timer runs for exactly this long,
  /// never extends, hides QR at expiry.
  static const int totalWindowSeconds = 10;

  /// After each successful Repeat tap, inactivity timer resets to this value.
  /// Only active after the first repeat.
  static const int inactivityShowcaseSeconds = 3;

  // ── Observable State ───────────────────────────────────────────────────────
  final Rxn<QuickRepeatState> activeState = Rxn<QuickRepeatState>();

  /// Remaining global seconds (0–10). Drives arc ring visual progress.
  final RxInt remainingSeconds = totalWindowSeconds.obs;

  /// Global progress fraction (0.0–1.0). Drives arc ring fill.
  final RxDouble progress = 1.0.obs;

  final RxBool isProcessing = false.obs;

  /// Pulses true for 300ms after each successful repeat → drives scale animation.
  final RxBool tapPulse = false.obs;

  /// Fires true when 3s inactivity expires (only after ≥1 repeat).
  /// Resets to false when a new repeat tap resets the inactivity timer.
  /// Widget listens to this to trigger the showcase animation.
  final RxBool shouldTriggerShowcase = false.obs;

  // ── Internal State ─────────────────────────────────────────────────────────
  /// Whether the sender has done at least one successful repeat tap.
  bool _hasRepeated = false;

  // ── Internal Timers ────────────────────────────────────────────────────────
  /// Global 10s countdown — NEVER resets, drives arc ring, hides QR at 0.
  Timer? _globalTimer;
  int _globalTicksRemaining = totalWindowSeconds * 10;

  /// 3s inactivity countdown — starts/resets on each successful repeat.
  /// Only runs when [_hasRepeated] is true.
  Timer? _inactivityTimer;

  @override
  void onClose() {
    _globalTimer?.cancel();
    _inactivityTimer?.cancel();
    super.onClose();
  }

  // ── Activate ──────────────────────────────────────────────────────────────

  void activateQuickRepeat({
    required String originalGiftTransactionId,
    required String roomId,
    required String senderId,
    required String giftId,
    required String giftName,
    required String giftIcon,
    required String currency,
    required int giftCost,
    required List<String> recipientIds,
    required List<String> recipientNames,
    required List<int> seatIndices,
    required int initialQuantity,
    int? multiplier,
  }) {
    final currentUserId = UserProfileCacheManager.currentUserId;
    if (senderId.isEmpty || currentUserId.isEmpty || senderId != currentUserId) {
      debugPrint(
        '[QuickRepeat] Sender-only isolation: ignored for non-sender '
        '($senderId != $currentUserId)',
      );
      return;
    }

    // Resolve GIF asset path & icon from the gift metadata registry
    final meta = GiftMetadataRegistry.getMetadata(
      giftId.isNotEmpty ? giftId : giftName,
    );
    final assetPath = meta.resolvedGifAssetPath;
    final resolvedIcon = (giftIcon.isNotEmpty && giftIcon != '🎁') ? giftIcon : meta.giftIcon;

    final int effectiveMultiplier = (multiplier != null && multiplier > 0)
        ? multiplier
        : 1;

    final state = QuickRepeatState(
      originalGiftTransactionId: originalGiftTransactionId,
      roomId: roomId,
      senderId: senderId,
      giftId: giftId,
      giftName: giftName,
      giftIcon: resolvedIcon,
      giftImageAssetPath: assetPath,
      currency: currency,
      giftCost: giftCost,
      originalMultiplier: effectiveMultiplier,
      originalRecipientIds: List.from(recipientIds),
      originalRecipientNames: List.from(recipientNames),
      originalSeatIndices: List.from(seatIndices),
      initialQuantity: initialQuantity,
    );

    _hasRepeated = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    shouldTriggerShowcase.value = false;

    activeState.value = state;

    // Lock the current selected recipients into the Quick Gift session so
    // they remain protected even if they leave an Arena seat mid-session.
    if (Get.isRegistered<ArenaGiftRecipientManager>()) {
      ArenaGiftRecipientManager.to.startQuickGiftSession();
    }

    debugPrint(
      '[QuickRepeat] Activated: $giftName x$effectiveMultiplier → $assetPath with ${recipientIds.length} recipients.',
    );

    _startGlobalTimer();
    // NOTE: Inactivity timer does NOT start here. It starts after 1st repeat.
  }

  // ── Repeat Gift ────────────────────────────────────────────────────────────

  Future<bool> repeatGift(String roomId) async {
    final state = activeState.value;
    if (state == null) {
      debugPrint('[QuickRepeat] Repeat tap ignored: no active state.');
      return false;
    }
    if (state.roomId != roomId) {
      debugPrint('[QuickRepeat] Repeat tap ignored: room mismatch.');
      return false;
    }
    final currentUserId = UserProfileCacheManager.currentUserId;
    if (state.senderId != currentUserId) {
      debugPrint('[QuickRepeat] Repeat tap ignored: sender mismatch.');
      return false;
    }
    if (isProcessing.value) {
      debugPrint('[QuickRepeat] Mutex guard: tap ignored while processing.');
      return false;
    }

    isProcessing.value = true;

    try {
      // ── Recipient Resolution (Rules 3, 7, 9, 13) ──────────────────────────
      // Use ArenaGiftRecipientManager as the source of truth.
      // It preserves QG-protected users who left their seat and applies
      // Room Owner fallback if no valid seat recipient remains.
      List<String> validRecipientIds = [];
      List<String> validRecipientNames = [];
      List<int> validSeatIndices = [];

      if (Get.isRegistered<ArenaGiftRecipientManager>()) {
        final finalRecipients =
            ArenaGiftRecipientManager.to.validateAndGetFinalRecipients(state.roomId);
        for (final entry in finalRecipients) {
          validRecipientIds.add(entry.userId);
          validRecipientNames.add(entry.userName);
          validSeatIndices.add(entry.seatIndex);
        }
      } else {
        // Fallback: use the original recipients if manager is not registered.
        if (Get.isRegistered<RoomController>()) {
          final roomSeats = RoomController.to.roomSeatsInfo[state.roomId] ?? [];
          final currentOccupiedUserIds = roomSeats
              .where((s) => s['userId'] != null)
              .map((s) => s['userId'] as String)
              .toSet();
          for (int i = 0; i < state.originalRecipientIds.length; i++) {
            final uId = state.originalRecipientIds[i];
            if (currentOccupiedUserIds.contains(uId)) {
              final seat =
                  roomSeats.firstWhereOrNull((s) => s['userId'] == uId);
              final passedName = i < state.originalRecipientNames.length
                  ? state.originalRecipientNames[i]
                  : '';
              final resolvedName =
                  UserProfileCacheManager.resolveUsernameForGifting(
                uId,
                passedName: passedName,
                seatInfo: seat,
              );
              final seatIdx =
                  seat != null ? (seat['seatIndex'] as int? ?? -1) : -1;
              validRecipientIds.add(uId);
              validRecipientNames.add(resolvedName);
              validSeatIndices.add(seatIdx);
            }
          }
        } else {
          validRecipientIds = List.from(state.originalRecipientIds);
          validRecipientNames = List.from(state.originalRecipientNames);
          validSeatIndices = List.from(state.originalSeatIndices);
        }
      }

      if (validRecipientIds.isEmpty) {
        debugPrint(
          '[QuickRepeat] Repeat failed: no valid recipients '
          '(all left seats and no Room Owner fallback available).',
        );
        // No snackbar — silently clear the QR session since we have no one to send to.
        clearQuickRepeat();
        return false;
      }

      // Calculate effective multiplier for repeat action based on remaining valid recipients
      final int effectiveMultiplier = state.originalMultiplier > 0 ? state.originalMultiplier : 1;
      final int totalQuantity = validRecipientIds.length * effectiveMultiplier;
      final int totalCost = state.giftCost * totalQuantity;

      RxInt? walletBalance;
      if (Get.isRegistered<StoreController>()) {
        final storeCtrl = Get.find<StoreController>();
        walletBalance = state.currency == 'gold'
            ? storeCtrl.coinsBalance
            : storeCtrl.silverCoinsBalance;
      }

      final int currentBalance = walletBalance?.value ?? 0;
      if (currentBalance < totalCost) {
        debugPrint(
          '[QuickRepeat] Insufficient balance: '
          'need $totalCost ${state.currency}, have $currentBalance',
        );
        try {
          InsufficientBalanceSheet.show(
            currency: state.currency,
            requiredCoins: totalCost,
            availableCoins: currentBalance,
            giftName: state.giftName,
            giftIcon: state.giftIcon,
          );
        } catch (_) {}
        return false;
      }

      final success = await RoomGiftController.to.sendStarGiftToRoom(
        roomId: state.roomId,
        giftId: state.giftId,
        giftName: state.giftName,
        giftIcon: state.giftIcon,
        giftCost: state.giftCost,
        currency: state.currency,
        targetUserIds: validRecipientIds,
        targetUserNames: validRecipientNames,
        seatIndices: validSeatIndices,
        roomsList: [],
        walletBalance: walletBalance ?? 0.obs,
        count: 1,
        comboCount: effectiveMultiplier,
      );

      if (success) {
        state.currentQuantity.value += totalQuantity;

        if (!_hasRepeated) {
          _hasRepeated = true;
        }

        _startGlobalTimer();
        _resetInactivityTimer();
        _triggerTapPulse();

        debugPrint(
          '[QuickRepeat] Repeat SUCCESS: '
          '${state.giftName} multiplier=$effectiveMultiplier total=×${state.currentQuantity.value}',
        );
        return true;
      } else {
        debugPrint('[QuickRepeat] Repeat FAILED in RoomGiftController.');
        return false;
      }
    } catch (e) {
      debugPrint('[QuickRepeat] Repeat exception: $e');
      return false;
    } finally {
      isProcessing.value = false;
    }
  }

  // ── Timer Internals ────────────────────────────────────────────────────────

  /// 10-second global countdown.
  /// Drives the arc ring progress.
  /// Never resets. Hides QR at 0.
  void _startGlobalTimer() {
    _globalTimer?.cancel();
    _globalTicksRemaining = totalWindowSeconds * 10;
    remainingSeconds.value = totalWindowSeconds;
    progress.value = 1.0;

    _globalTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        _globalTicksRemaining--;
        remainingSeconds.value =
            (_globalTicksRemaining / 10).ceil().clamp(0, totalWindowSeconds);
        progress.value =
            (_globalTicksRemaining / (totalWindowSeconds * 10))
                .clamp(0.0, 1.0);

        if (_globalTicksRemaining <= 0) {
          timer.cancel();
          debugPrint(
            '[QuickRepeat] 10s global window expired → QR removed.',
          );
          clearQuickRepeat();
        }
      },
    );
  }

  /// 3-second inactivity countdown.
  /// Starts/resets after every successful repeat tap.
  /// NOT started on initial activation.
  /// At 0 → fires showcase animation signal; then auto-restarts for next cycle.
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    shouldTriggerShowcase.value = false;

    int ticks = inactivityShowcaseSeconds * 10;
    _inactivityTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        ticks--;
        if (ticks <= 0) {
          timer.cancel();
          // Only fire if global window still active
          if (remainingSeconds.value > 0 && activeState.value != null) {
            shouldTriggerShowcase.value = true;
            debugPrint(
              '[QuickRepeat] 3s inactivity → showcase triggered. '
              'QR still visible (${remainingSeconds.value}s global remaining).',
            );
          }
        }
      },
    );
  }

  Future<void> _triggerTapPulse() async {
    tapPulse.value = true;
    await Future.delayed(const Duration(milliseconds: 300));
    tapPulse.value = false;
  }

  // ── Clear ──────────────────────────────────────────────────────────────────

  void clearQuickRepeat() {
    _globalTimer?.cancel();
    _globalTimer = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _hasRepeated = false;
    activeState.value = null;
    remainingSeconds.value = 0;
    progress.value = 0.0;
    isProcessing.value = false;
    tapPulse.value = false;
    shouldTriggerShowcase.value = false;
    // End QG session so seat-left users are no longer protected
    if (Get.isRegistered<ArenaGiftRecipientManager>()) {
      ArenaGiftRecipientManager.to.endQuickGiftSession();
    }
    debugPrint('[QuickRepeat] Session cleared.');
  }

  // ── Visibility ─────────────────────────────────────────────────────────────

  bool isVisible(String roomId, String currentUserId) {
    final state = activeState.value;
    if (state == null) return false;
    return state.roomId == roomId &&
        state.senderId == currentUserId &&
        remainingSeconds.value > 0;
  }
}
