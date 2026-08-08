import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/user_profile_cache_manager.dart';
import '../store/store_controller.dart';
import '../room/room_gift_controller.dart';
import '../../widgets/gifting/insufficient_balance_sheet.dart';
import '../../models/gift/gift_animation_metadata.dart';

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
  final List<String> recipientIds;
  final List<String> recipientNames;
  final List<int> seatIndices;
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
    required this.recipientIds,
    required this.recipientNames,
    required this.seatIndices,
    required int initialQuantity,
    DateTime? createdAt,
  })  : currentQuantity = initialQuantity.obs,
        createdAt = createdAt ?? DateTime.now();
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
      recipientIds: List.from(recipientIds),
      recipientNames: List.from(recipientNames),
      seatIndices: List.from(seatIndices),
      initialQuantity: initialQuantity,
    );

    _hasRepeated = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    shouldTriggerShowcase.value = false;

    activeState.value = state;

    debugPrint(
      '[QuickRepeat] Activated: $giftName x$initialQuantity → $assetPath. '
      'Phase 1: 10s global window, no showcase until first repeat.',
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
      final totalCost = state.giftCost * state.recipientIds.length;
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
        targetUserIds: state.recipientIds,
        targetUserNames: state.recipientNames,
        seatIndices: state.seatIndices,
        roomsList: [],
        walletBalance: walletBalance ?? 0.obs,
        count: 1,
        comboCount: 1,
      );

      if (success) {
        state.currentQuantity.value += 1;

        // ── Phase transition: first repeat ever ─────────────────────────────
        if (!_hasRepeated) {
          _hasRepeated = true;
          debugPrint(
            '[QuickRepeat] Phase 2 unlocked: first repeat done. '
            '3s inactivity showcase now active.',
          );
        }

        // Reset the 10-second global countdown timer back to 10s on every repeat tap
        _startGlobalTimer();

        // Reset / start inactivity timer on every successful repeat
        _resetInactivityTimer();

        // Brief pulse animation on the circle
        _triggerTapPulse();

        debugPrint(
          '[QuickRepeat] Repeat SUCCESS: '
          '${state.giftName} total=×${state.currentQuantity.value}',
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
