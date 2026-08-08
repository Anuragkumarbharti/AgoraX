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
  /// Resolved GIF asset path: assets/GIFTS_SHOWCCASE/ROSE.gif etc.
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

class QuickRepeatController extends GetxController {
  static QuickRepeatController get to {
    if (!Get.isRegistered<QuickRepeatController>()) {
      return Get.put(QuickRepeatController());
    }
    return Get.find<QuickRepeatController>();
  }

  // ── Timer Constants ───────────────────────────────────────────────────────
  /// Total 10-second global window. Quick Repeat hides when this expires.
  static const int totalWindowSeconds = 10;

  /// After each successful Repeat tap, inactivity timer resets to this value.
  static const int tapResetSeconds = 3;

  /// On first activation, showcase fires after 2s of inactivity.
  static const int inactivityShowcaseSeconds = 2;

  // ── Observable State ──────────────────────────────────────────────────────
  final Rxn<QuickRepeatState> activeState = Rxn<QuickRepeatState>();
  final RxInt remainingSeconds = totalWindowSeconds.obs;
  final RxDouble progress = 1.0.obs;
  final RxBool isProcessing = false.obs;

  /// Pulses true briefly on each successful repeat, used for tap-pulse animation.
  final RxBool tapPulse = false.obs;

  /// Fires true when inactivity threshold expires → overlay should play showcase animation.
  /// Resets to false immediately on the next Repeat tap.
  final RxBool shouldTriggerShowcase = false.obs;

  // ── Internal Timers ───────────────────────────────────────────────────────
  /// Global 10-second countdown — never resets, hides QR at expiry.
  Timer? _globalTimer;
  int _globalTicksRemaining = totalWindowSeconds * 10;

  /// Inactivity timer — 2s on activation, 3s after each Repeat tap.
  Timer? _inactivityTimer;

  @override
  void onClose() {
    _globalTimer?.cancel();
    _inactivityTimer?.cancel();
    super.onClose();
  }

  // ── Activate ─────────────────────────────────────────────────────────────

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
      debugPrint('[QuickRepeat] Sender-only isolation: QuickRepeat ignored for non-sender ($senderId != $currentUserId)');
      return;
    }

    // Resolve GIF asset path from the gift metadata registry
    final meta = GiftMetadataRegistry.getMetadata(giftId.isNotEmpty ? giftId : giftName);
    final assetPath = meta.resolvedGifAssetPath;

    final state = QuickRepeatState(
      originalGiftTransactionId: originalGiftTransactionId,
      roomId: roomId,
      senderId: senderId,
      giftId: giftId,
      giftName: giftName,
      giftIcon: giftIcon,
      giftImageAssetPath: assetPath,
      currency: currency,
      giftCost: giftCost,
      recipientIds: List.from(recipientIds),
      recipientNames: List.from(recipientNames),
      seatIndices: List.from(seatIndices),
      initialQuantity: initialQuantity,
    );

    activeState.value = state;
    debugPrint('[QuickRepeat] Activated: $giftName x$initialQuantity → $assetPath. 10s total window, 2s inactivity showcase.');
    _startGlobalTimer();
    _startInactivityTimer(seconds: inactivityShowcaseSeconds);
  }

  // ── Repeat Gift ───────────────────────────────────────────────────────────

  Future<bool> repeatGift(String roomId) async {
    final state = activeState.value;
    if (state == null) {
      debugPrint('[QuickRepeat] Repeat tap ignored: No active quick repeat state.');
      return false;
    }
    if (state.roomId != roomId) {
      debugPrint('[QuickRepeat] Repeat tap ignored: Room mismatch.');
      return false;
    }
    final currentUserId = UserProfileCacheManager.currentUserId;
    if (state.senderId != currentUserId) {
      debugPrint('[QuickRepeat] Repeat tap ignored: Sender mismatch.');
      return false;
    }
    if (isProcessing.value) {
      debugPrint('[QuickRepeat] Mutex Guard: Tap ignored while processing.');
      return false;
    }

    isProcessing.value = true;

    try {
      final totalCost = state.giftCost * 1 * state.recipientIds.length;
      RxInt? walletBalance;
      if (Get.isRegistered<StoreController>()) {
        final storeCtrl = Get.find<StoreController>();
        walletBalance = state.currency == 'gold'
            ? storeCtrl.coinsBalance
            : storeCtrl.silverCoinsBalance;
      }

      final int currentBalance = walletBalance?.value ?? 0;
      if (currentBalance < totalCost) {
        debugPrint('[QuickRepeat] Insufficient balance: Required $totalCost ${state.currency}, available $currentBalance');
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
        debugPrint('[QuickRepeat] Repeat SUCCESS: total=x${state.currentQuantity.value}');
        // Reset inactivity timer to 3s (global 10s window continues unchanged)
        _startInactivityTimer(seconds: tapResetSeconds);
        // Trigger pulse animation
        _triggerTapPulse();
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

  // ── Timer Internals ───────────────────────────────────────────────────────

  /// 10-second global countdown. Drives the arc ring progress indicator.
  /// Hides QR completely when it reaches 0. Never resets.
  void _startGlobalTimer() {
    _globalTimer?.cancel();
    _globalTicksRemaining = totalWindowSeconds * 10;
    remainingSeconds.value = totalWindowSeconds;
    progress.value = 1.0;

    _globalTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _globalTicksRemaining--;
      final secs = (_globalTicksRemaining / 10).ceil().clamp(0, totalWindowSeconds);
      remainingSeconds.value = secs;
      progress.value = (_globalTicksRemaining / (totalWindowSeconds * 10)).clamp(0.0, 1.0);

      if (_globalTicksRemaining <= 0) {
        timer.cancel();
        debugPrint('[QuickRepeat] 10s global window expired → hiding Quick Repeat.');
        clearQuickRepeat();
      }
    });
  }

  /// Inactivity timer — fires showcase trigger after [seconds] of no tap.
  /// [seconds]: 2s on activation, 3s after each Repeat tap.
  /// Quick Repeat widget remains visible — only animation starts.
  void _startInactivityTimer({required int seconds}) {
    _inactivityTimer?.cancel();
    shouldTriggerShowcase.value = false;

    int ticks = seconds * 10;
    _inactivityTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      ticks--;
      if (ticks <= 0) {
        timer.cancel();
        shouldTriggerShowcase.value = true;
        debugPrint('[QuickRepeat] ${seconds}s inactivity → showcase animation triggered. QR still visible.');
      }
    });
  }

  void _triggerTapPulse() async {
    tapPulse.value = true;
    await Future.delayed(const Duration(milliseconds: 300));
    tapPulse.value = false;
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  void clearQuickRepeat() {
    _globalTimer?.cancel();
    _globalTimer = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    activeState.value = null;
    remainingSeconds.value = 0;
    progress.value = 0.0;
    isProcessing.value = false;
    tapPulse.value = false;
    shouldTriggerShowcase.value = false;
    debugPrint('[QuickRepeat] Quick repeat session expired or cleared.');
  }

  // ── Visibility ────────────────────────────────────────────────────────────

  bool isVisible(String roomId, String currentUserId) {
    final state = activeState.value;
    if (state == null) return false;
    return state.roomId == roomId &&
        state.senderId == currentUserId &&
        remainingSeconds.value > 0;
  }
}
