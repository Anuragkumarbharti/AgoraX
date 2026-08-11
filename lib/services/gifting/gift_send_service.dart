import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../room/room_controller.dart';
import '../room/room_gift_controller.dart';
import '../store/store_controller.dart';
import '../../widgets/gifting/send_gift_dialog.dart';
import '../../models/vault/vault_models.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../../widgets/gifting/insufficient_balance_sheet.dart';
import '../network/network_connectivity_service.dart';
import '../network/network_guard.dart';
import '../user/user_profile_cache_manager.dart';
import '../vault/vault_controller.dart';
import '../room/room_dual_progress_controller.dart';
import '../room/room_progression_controller.dart';
import 'arena_gift_recipient_manager.dart';
import 'gift_event_service.dart';

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
  /// 2. Coins/Vault deducted successfully.
  /// 3. Gift event sent to backend.
  /// 4. Backend confirms success.
  /// If any step fails: keep panel open, show error, never play animation, never deduct twice.
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

      List<String> receiverIds = giftAll
          ? roomSeats
              .where((s) => s['userId'] != null)
              .map((s) => s['userId'] as String)
              .toList()
          : List.from(selectedRecipients);

      List<String> receiverNames = [];
      List<int> seatIndices = giftAll
          ? roomSeats
              .where((s) => s['userId'] != null)
              .map((s) => s['seatIndex'] as int)
              .toList()
          : List.from(selectedSeatIndices);

      if (receiverIds.isEmpty) {
        if (Get.isRegistered<ArenaGiftRecipientManager>()) {
          final fallbacks =
              ArenaGiftRecipientManager.to.validateAndGetFinalRecipients(roomId);
          if (fallbacks.isNotEmpty) {
            receiverIds = fallbacks.map((e) => e.userId).toList();
            seatIndices = fallbacks.map((e) => e.seatIndex).toList();
            debugPrint(
              '[GiftSendService] Empty recipient list — using manager fallback: '
              '${receiverIds.length} recipient(s).',
            );
          }
        }
      }

      if (receiverIds.isEmpty) {
        _showError('Please select at least one recipient seat.');
        return false;
      }

      for (int i = 0; i < receiverIds.length; i++) {
        final uId = receiverIds[i];
        final passedName = i < selectedRecipientNames.length
            ? selectedRecipientNames[i]
            : '';
        final seat = roomSeats.firstWhereOrNull((s) => s['userId'] == uId);
        receiverNames.add(UserProfileCacheManager.resolveUsernameForGifting(
          uId,
          passedName: passedName,
          seatInfo: seat,
        ));
      }

      final int receiverCount = receiverIds.length;
      int effectiveMultiplier = comboMultiplier;
      if (effectiveMultiplier < 1) effectiveMultiplier = 1;
      if (effectiveMultiplier > 100) effectiveMultiplier = 100;

      final int totalGifts = receiverCount * effectiveMultiplier;
      final storeCtrl = Get.find<StoreController>();

      if (!isVault && gift != null) {
        final totalCost = gift.cost * totalGifts;
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

      // ── Step 2, 3 & 4: Backend API & Vault/Coin Deduction ──
      if (isVault && vaultItem != null) {
        if (vaultItem.quantity < totalGifts) {
          _showError('Insufficient quantity of ${vaultItem.displayName} in Vault. (Have: ${vaultItem.quantity}, Need: $totalGifts)');
          return false;
        }

        final vaultCtrl = Get.isRegistered<VaultController>()
            ? VaultController.to
            : Get.put(VaultController());

        for (final rId in receiverIds) {
          for (int i = 0; i < effectiveMultiplier; i++) {
            await vaultCtrl.giftItem(vaultItem, rId);
          }
        }

        final user = UserProfileCacheManager.currentUser;
        final String uName = user?.username ?? '';
        final String fName = user?.fullName ?? '';
        final String senderName = (uName.isNotEmpty && uName != 'User')
            ? uName
            : (fName.isNotEmpty)
                ? fName
                : 'Member';
        final String? senderAvatar = user?.avatar;

        final String transactionId =
            'tx_vault_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
        final meta = GiftMetadataRegistry.getMetadata(vaultItem.displayName);

        final Map<String, dynamic> eventPayload = {
          'id': transactionId,
          'giftId': meta.giftId,
          'giftName': vaultItem.displayName,
          'giftIcon': vaultItem.category == 'Premium' ? '👑' : '🎒',
          'senderId': UserProfileCacheManager.currentUserId,
          'senderName': senderName,
          'senderAvatar': senderAvatar,
          'receiverIds': receiverIds,
          'receiverNames': receiverNames,
          'receiverSeats': seatIndices,
          'roomId': roomId,
          'giftType': 'volt',
          'currency': 'volt',
          'giftValue': 100,
          'price': 0,
          'quantity': totalGifts,
          'count': totalGifts,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'messageText':
              '🎁 $senderName sent ${vaultItem.displayName} × $totalGifts from Vault to ${receiverNames.join(", ")}.',
        };

        unawaited(GiftEventService.to.broadcastGiftEvent(roomId, eventPayload));

        // Process Free Activity / Normal Task progress (Volt gifts DO NOT fill Gold task)
        try {
          await Supabase.instance.client.rpc('process_room_dual_progress', params: {
            'p_room_id': roomId,
            'p_user_id': UserProfileCacheManager.currentUserId,
            'p_points': totalGifts * 100,
            'p_source': 'volt_gift',
          });
        } catch (e) {
          debugPrint('[GiftSendService] Vault dual progress call note: $e');
        }

        if (Get.isRegistered<RoomDualProgressController>()) {
          unawaited(RoomDualProgressController.to.fetchDualProgress(roomId));
        }
        if (Get.isRegistered<RoomProgressionController>()) {
          final progCtrl = Get.find<RoomProgressionController>();
          unawaited(progCtrl.fetchRoomProgression(roomId,
              onUpdateSeats: (_) {}, onUpdateSeatGifts: (_) {}));
        }

        return true;
      } else if (gift != null) {
        final totalCost = gift.cost * totalGifts;
        debugPrint('[Gift] API Request: roomId: $roomId, gift: ${gift.name}, multiplier: $effectiveMultiplier, totalGifts: $totalGifts, totalCost: $totalCost, currency: ${gift.currency}');
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
          count: 1,
          comboCount: effectiveMultiplier,
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
    String friendlyMsg = message;
    if (message.contains('<html') ||
        message.contains('<HTML') ||
        message.contains('SocketException') ||
        message.contains('ClientException') ||
        message.contains('Failed host lookup') ||
        message.contains('Connection refused') ||
        message.contains('TimeoutException') ||
        message.contains('HandshakeException')) {
      friendlyMsg = 'Network connection issue. Please check your connection and try again later.';
    }
    Get.snackbar(
      'Gift Sending Failed',
      friendlyMsg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEF4444),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }
}
