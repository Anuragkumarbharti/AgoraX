import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/user_profile_cache_manager.dart';
import '../store/store_controller.dart';
import '../room/room_gift_controller.dart';
import '../../widgets/gifting/insufficient_balance_sheet.dart';

class QuickRepeatState {
  final String originalGiftTransactionId;
  final String roomId;
  final String senderId;
  final String giftId;
  final String giftName;
  final String giftIcon;
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

  static const int quickRepeatTimeoutSeconds = 12;

  final Rxn<QuickRepeatState> activeState = Rxn<QuickRepeatState>();
  final RxInt remainingSeconds = quickRepeatTimeoutSeconds.obs;
  final RxDouble progress = 1.0.obs;
  final RxBool isProcessing = false.obs;

  Timer? _timer;

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  /// Activates or replaces Quick Repeat session for sender.
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

    final state = QuickRepeatState(
      originalGiftTransactionId: originalGiftTransactionId,
      roomId: roomId,
      senderId: senderId,
      giftId: giftId,
      giftName: giftName,
      giftIcon: giftIcon,
      currency: currency,
      giftCost: giftCost,
      recipientIds: List.from(recipientIds),
      recipientNames: List.from(recipientNames),
      seatIndices: List.from(seatIndices),
      initialQuantity: initialQuantity,
    );

    activeState.value = state;
    debugPrint('[QuickRepeat] Activated: ${giftName} x$initialQuantity to ${recipientNames.join(", ")} (Timeout: 12s)');
    _startTimer();
  }

  /// Handles rapid repeat taps safely with pre-flight balance checks and sequential locks.
  Future<bool> repeatGift(String roomId) async {
    final state = activeState.value;
    if (state == null) {
      debugPrint('[QuickRepeat] Repeat tap ignored: No active quick repeat state.');
      return false;
    }

    if (state.roomId != roomId) {
      debugPrint('[QuickRepeat] Repeat tap ignored: Room mismatch (${state.roomId} != $roomId)');
      return false;
    }

    final currentUserId = UserProfileCacheManager.currentUserId;
    if (state.senderId != currentUserId) {
      debugPrint('[QuickRepeat] Repeat tap ignored: Sender mismatch (${state.senderId} != $currentUserId)');
      return false;
    }

    if (isProcessing.value) {
      debugPrint('[QuickRepeat] Mutex Guard: Tap ignored while previous repeat operation is processing.');
      return false;
    }

    isProcessing.value = true;

    try {
      // 1. Balance verification pre-flight
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
        debugPrint('[QuickRepeat] Insufficient balance for repeat: Required $totalCost ${state.currency}, available $currentBalance');
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

      // 2. Execute repeat gift transaction using production RoomGiftController pipeline
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
        debugPrint('[QuickRepeat] Repeat SUCCESS: ${state.giftName} effective total is now x${state.currentQuantity.value}');
        _startTimer(); // Reset 12-second inactivity timer on every successful repeat
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

  void _startTimer() {
    _timer?.cancel();
    remainingSeconds.value = quickRepeatTimeoutSeconds;
    progress.value = 1.0;

    int totalTicks = quickRepeatTimeoutSeconds * 10;
    int currentTick = 0;

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      currentTick++;
      final remaining = (quickRepeatTimeoutSeconds - (currentTick / 10.0)).ceil();
      remainingSeconds.value = remaining.clamp(0, quickRepeatTimeoutSeconds);
      progress.value = ((totalTicks - currentTick) / totalTicks).clamp(0.0, 1.0);

      if (currentTick >= totalTicks) {
        timer.cancel();
        clearQuickRepeat();
      }
    });
  }

  void clearQuickRepeat() {
    _timer?.cancel();
    _timer = null;
    activeState.value = null;
    remainingSeconds.value = 0;
    progress.value = 0.0;
    isProcessing.value = false;
    debugPrint('[QuickRepeat] Quick repeat session expired or cleared.');
  }

  bool isVisible(String roomId, String currentUserId) {
    final state = activeState.value;
    if (state == null) return false;
    return state.roomId == roomId && state.senderId == currentUserId && remainingSeconds.value > 0;
  }
}
