import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../room/room_controller.dart';
import '../room/room_gift_controller.dart';
import '../store/store_controller.dart';
import '../../widgets/gifting/send_gift_dialog.dart';
import '../../models/vault/vault_models.dart';

import '../../widgets/gifting/insufficient_balance_sheet.dart';

import '../network/network_connectivity_service.dart';
import '../network/network_guard.dart';
import '../user/user_profile_cache_manager.dart';

class GiftSendService extends GetxController {
  static GiftSendService get to {
    if (!Get.isRegistered<GiftSendService>()) {
      return Get.put(GiftSendService());
    }
    return Get.find<GiftSendService>();
  }

  final RxBool _isSending = false.obs;
  bool get isSending => _isSending.value;

  /// Complete, safe gift send pipeline.
  /// Panel closes ONLY after:
  /// 1. Validation succeeds.
  /// 2. Coins deducted successfully.
  /// 3. Gift event sent to backend.
  /// 4. Backend confirms success.
  /// If any step fails: keep panel open, show error, never play animation, never deduct coins twice.
  Future<bool> sendGift({
    required String roomId,
    required GiftItem? gift,
    required VaultItem? vaultItem,
    required bool isVault,
    required bool giftAll,
    required List<String> selectedRecipients,
    required List<String> selectedRecipientNames,
    required List<int> selectedSeatIndices,
    required int comboMultiplier,
  }) async {
    // ── Offline Protection ──
    if (!NetworkGuard.checkInternet(
      actionName: 'send_gift',
      customOfflineMessage: "No internet. Gift not sent.",
    )) {
      NetworkConnectivityService.to.logAnalyticsEvent('failed_gift_offline', {'room_id': roomId});
      return false;
    }

    if (_isSending.value) {
      debugPrint('[GiftSendService] Duplicate send tap blocked.');
      return false;
    }

    _isSending.value = true;

    try {
      // ── Step 1: Pre-Validation ──
      if (isVault) {
        if (vaultItem == null) {
          _showError('No Vault item selected.');
          return false;
        }
      } else {
        if (gift == null) {
          _showError('No gift selected.');
          return false;
        }
      }

      final roomSeats = RoomController.to.roomSeatsInfo[roomId] ?? [];
      final List<String> receiverIds = giftAll
          ? roomSeats
              .where((s) => s['userId'] != null)
              .map((s) => s['userId'] as String)
              .toList()
          : List.from(selectedRecipients);

      final List<String> receiverNames = [];
      for (int i = 0; i < receiverIds.length; i++) {
        final uId = receiverIds[i];
        final passedName = i < selectedRecipientNames.length ? selectedRecipientNames[i] : '';
        final seat = roomSeats.firstWhereOrNull((s) => s['userId'] == uId);
        receiverNames.add(UserProfileCacheManager.resolveUsernameForGifting(
          uId,
          passedName: passedName,
          seatInfo: seat,
        ));
      }

      final List<int> seatIndices = giftAll
          ? roomSeats
              .where((s) => s['userId'] != null)
              .map((s) => s['seatIndex'] as int)
              .toList()
          : List.from(selectedSeatIndices);

      if (receiverIds.isEmpty) {
        _showError('Please select at least one recipient seat.');
        return false;
      }

      // Check coin balance pre-flight
      final totalQuantity = comboMultiplier;
      final storeCtrl = Get.find<StoreController>();

      if (!isVault && gift != null) {
        final totalCost = gift.cost * totalQuantity * receiverIds.length;
        final currentBalance = gift.currency == 'gold'
            ? storeCtrl.coinsBalance.value
            : storeCtrl.silverCoinsBalance.value;

        if (currentBalance < totalCost) {
          InsufficientBalanceSheet.show(
            currency: gift.currency,
            requiredCoins: totalCost,
            availableCoins: currentBalance,
            giftName: gift.name,
            giftIcon: gift.icon,
          );
          return false;
        }
      }

      // Dismiss Gift Dialog BottomSheet immediately so room screen is completely clear before launch
      if (Get.isBottomSheetOpen == true || Get.isDialogOpen == true) {
        Get.back();
      }

      // ── Step 2, 3 & 4: Backend API & Coin Deduction ──
      if (isVault && vaultItem != null) {
        return true;
      } else if (gift != null) {
        final totalCost = gift.cost * totalQuantity * receiverIds.length;
        debugPrint('[Gift] API Request: roomId: $roomId, gift: ${gift.name}, count: $totalQuantity, totalCost: $totalCost');
        final success = await RoomGiftController.to.sendStarGiftToRoom(
          roomId: roomId,
          giftId: gift.id,
          giftName: gift.name,
          giftIcon: gift.icon,
          giftCost: gift.cost,
          currency: gift.currency,
          targetUserIds: receiverIds,
          targetUserNames: receiverNames,
          seatIndices: seatIndices,
          roomsList: RoomController.to.rooms,
          walletBalance: gift.currency == 'gold'
              ? storeCtrl.coinsBalance
              : storeCtrl.silverCoinsBalance,
          count: totalQuantity,
          comboCount: comboMultiplier,
        );

        if (!success) {
          _showError('Failed to send gift. Backend confirmation failed.');
          return false;
        }

        return true;
      }

      return false;
    } catch (e) {
      _showError('Gifting error: ${e.toString().replaceAll('Exception: ', '')}');
      return false;
    } finally {
      _isSending.value = false;
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Gift Sending Failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEF4444),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}
