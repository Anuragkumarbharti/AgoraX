import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../../widgets/gifting/gift_animation_overlay.dart';
import '../../models/room/room_model.dart';
import '../user/user_profile_cache_manager.dart';
import '../store/store_controller.dart';
import '../gifting/gift_animation_controller.dart';
import '../gifting/gift_event_service.dart';
import '../gifting/quick_repeat_controller.dart';
import 'room_seat_controller.dart';
import 'room_activity_controller.dart';
import 'room_controller.dart';
import 'room_realtime_controller.dart';
import 'room_dual_progress_controller.dart';
import 'room_progression_controller.dart';
import 'room_chat_controller.dart';
import '../../widgets/gifting/insufficient_balance_sheet.dart';

import '../network/network_connectivity_service.dart';
import '../network/network_guard.dart';

class RoomGiftController extends GetxController {
  static RoomGiftController get to {
    if (!Get.isRegistered<RoomGiftController>()) {
      return Get.put(RoomGiftController());
    }
    return Get.find<RoomGiftController>();
  }

  final Rxn<GiftAnimationEvent> activeGiftAnimation =
      Rxn<GiftAnimationEvent>();
  final Rxn<Map<String, dynamic>> activeGiftNotification =
      Rxn<Map<String, dynamic>>();

  void triggerGiftAnimation(GiftAnimationEvent event) {
    activeGiftAnimation.value = event;
  }

  Future<bool> sendStarGiftToRoom({
    required String roomId,
    required String giftId,
    required String giftName,
    String giftIcon = '🎁',
    required int giftCost,
    required String currency,
    required List<String> targetUserIds,
    required List<String> targetUserNames,
    required List<int> seatIndices,
    required List<VoiceRoom> roomsList,
    required RxInt walletBalance,
    int count = 1,
    int comboCount = 1,
  }) async {
    if (!NetworkGuard.checkInternet(
      actionName: 'send_gift',
      customOfflineMessage: 'No internet. Gift not sent.',
    )) {
      NetworkConnectivityService.to.logAnalyticsEvent('failed_gift_offline', {'room_id': roomId});
      return false;
    }
    try {
      if (roomId.isEmpty) {
        debugPrint('[GiftPipeline] FAILURE: Invalid room identifier.');
        Get.snackbar('Gifting Error', 'Invalid room identifier.');
        return false;
      }

      final int receiverCount = targetUserIds.length;
      if (receiverCount == 0) {
        debugPrint('[GiftPipeline] FAILURE: No recipients selected.');
        Get.snackbar('Gifting Error', 'Please select at least one recipient seat.');
        return false;
      }

      final int maxAllowed = receiverCount > 100 ? 100 : receiverCount;
      int effectiveMultiplier = comboCount;
      if (effectiveMultiplier <= 0 || effectiveMultiplier > maxAllowed) {
        effectiveMultiplier = maxAllowed;
      }

      final totalQuantity = effectiveMultiplier;
      final totalCost = giftCost * effectiveMultiplier;

      // ── 1. BALANCE CHECK & INSTANT OPTIMISTIC DEDUCTION (<1ms) ──
      if (walletBalance.value < totalCost) {
        debugPrint('[GiftPipeline] Insufficient balance: Required $totalCost coins. Balance: ${walletBalance.value}');
        try {
          InsufficientBalanceSheet.show(
            currency: currency,
            requiredCoins: totalCost,
            availableCoins: walletBalance.value,
            giftName: giftName,
            giftIcon: giftIcon,
          );
        } catch (_) {
          Get.snackbar('Insufficient Balance', 'Required $totalCost $currency coins.');
        }
        return false;
      }

      final int previousBalance = walletBalance.value;
      walletBalance.value = previousBalance - totalCost; // Optimistic deduction (<1ms)

      // Update StoreController balance reactively
      try {
        if (Get.isRegistered<StoreController>()) {
          final storeCtrl = Get.find<StoreController>();
          if (currency == 'gold') {
            storeCtrl.coinsBalance.value = walletBalance.value;
          } else {
            storeCtrl.silverCoinsBalance.value = walletBalance.value;
          }
        }
      } catch (_) {}

      // ── 2. PREPARE IDEMPOTENT TRANSACTION IDENTIFIER & PAYLOAD ──
      final user = UserProfileCacheManager.currentUser;
      final String uName = user?.username ?? '';
      final String fName = user?.fullName ?? '';
      final String senderName = (uName.isNotEmpty && uName != 'User')
          ? uName
          : (fName.isNotEmpty)
              ? fName
              : 'Member';
      final String? senderAvatar = user?.avatar;

      final roomSeats = RoomController.to.roomSeatsInfo[roomId] ?? [];
      final List<String> cleanTargetUserNames = [];
      for (int i = 0; i < targetUserIds.length; i++) {
        final uId = targetUserIds[i];
        final passedName = i < targetUserNames.length ? targetUserNames[i] : '';
        final seat = roomSeats.firstWhereOrNull((s) => s['userId'] == uId);
        cleanTargetUserNames.add(UserProfileCacheManager.resolveUsernameForGifting(
          uId,
          passedName: passedName,
          seatInfo: seat,
        ));
      }

      // Ensure valid 36-character UUID string for Supabase RPC
      final meta = GiftMetadataRegistry.getMetadata(giftId.isNotEmpty ? giftId : giftName);
      final String canonicalGiftUuid = meta.giftId;
      final String resolvedGiftIcon = (giftIcon.isNotEmpty && giftIcon != '🎁') ? giftIcon : meta.giftIcon;

      final String transactionId = 'tx_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';

      final Map<String, dynamic> eventPayload = {
        'id': transactionId,
        'giftId': canonicalGiftUuid,
        'giftName': giftName,
        'giftIcon': resolvedGiftIcon,
        'senderId': UserProfileCacheManager.currentUserId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'receiverIds': targetUserIds,
        'receiverNames': cleanTargetUserNames,
        'receiverSeats': seatIndices,
        'roomId': roomId,
        'giftType': currency,
        'giftValue': giftCost,
        'price': giftCost,
        'quantity': totalQuantity,
        'count': totalQuantity,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'messageText': '🎁 $senderName sent $giftName × $totalQuantity to ${cleanTargetUserNames.join(", ")}.',
      };

      // ── 3. SYNCHRONOUS SERVER-AUTHORITATIVE RPC TRANSACTION ──
      final List<String> sanitizedTargetUserIds = _sanitizeUuidList(targetUserIds);

      dynamic response;
      try {
        response = await Supabase.instance.client.rpc('send_star_gift', params: {
          'p_room_id': roomId,
          'p_receiver_ids': sanitizedTargetUserIds,
          'p_gift_id': canonicalGiftUuid,
          'p_quantity': count,
          'p_combo_count': comboCount,
          'p_seat_indices': seatIndices,
          'p_transaction_id': transactionId,
          'p_sender_id': UserProfileCacheManager.currentUserId,
        });
      } catch (rpcError) {
        final errStr = rpcError.toString();
        debugPrint('[GiftPipeline] Primary 8-param RPC Error: $errStr');

        // Check if 8-param signature is missing on DB, fallback to 6-param signature
        if (errStr.contains('PGRST202') ||
            errStr.contains('Could not find') ||
            errStr.contains('function') ||
            errStr.contains('schema cache')) {
          try {
            debugPrint('[GiftPipeline] Falling back to 6-parameter send_star_gift signature...');
            response = await Supabase.instance.client.rpc('send_star_gift', params: {
              'p_room_id': roomId,
              'p_receiver_ids': sanitizedTargetUserIds,
              'p_gift_id': canonicalGiftUuid,
              'p_quantity': count,
              'p_combo_count': comboCount,
              'p_seat_indices': seatIndices,
            });
          } catch (fallbackError) {
            debugPrint('[GiftPipeline] Fallback 6-param RPC Error: $fallbackError');
            _rollbackBalance(walletBalance, previousBalance, currency);
            _showGiftErrorSnackbar(fallbackError.toString());
            return false;
          }
        } else {
          _rollbackBalance(walletBalance, previousBalance, currency);
          _showGiftErrorSnackbar(errStr);
          return false;
        }
      }

      if (response == null || (response is Map && response['success'] != true)) {
        // Rollback optimistic balance on invalid server response
        walletBalance.value = previousBalance;
        try {
          if (Get.isRegistered<StoreController>()) {
            final storeCtrl = Get.find<StoreController>();
            if (currency == 'gold') {
              storeCtrl.coinsBalance.value = previousBalance;
            } else {
              storeCtrl.silverCoinsBalance.value = previousBalance;
            }
          }
        } catch (_) {}
        return false;
      }

      // ── 4. SERVER CONFIRMED SUCCESS: UPDATE AUTHORITATIVE STATE & DISPATCH ──
      final Map<String, dynamic> resMap = Map<String, dynamic>.from(response as Map);
      final int remaining = (resMap['remaining_balance'] as num).toInt();
      walletBalance.value = remaining;

      try {
        if (Get.isRegistered<StoreController>()) {
          final storeCtrl = Get.find<StoreController>();
          if (currency == 'gold') {
            storeCtrl.coinsBalance.value = remaining;
          } else {
            storeCtrl.silverCoinsBalance.value = remaining;
          }
        }
      } catch (_) {}

      // 🚀 Trigger instant animation playback & WebSocket broadcast room-wide
      unawaited(GiftEventService.to.broadcastGiftEvent(roomId, eventPayload));

      // ⚡ Activate / Refresh Sender-Only Quick Repeat Session
      try {
        final qrCtrl = QuickRepeatController.to;
        if (!qrCtrl.isProcessing.value) {
          qrCtrl.activateQuickRepeat(
            originalGiftTransactionId: transactionId,
            roomId: roomId,
            senderId: UserProfileCacheManager.currentUserId,
            giftId: canonicalGiftUuid,
            giftName: giftName,
            giftIcon: resolvedGiftIcon,
            currency: currency,
            giftCost: giftCost,
            recipientIds: targetUserIds,
            recipientNames: targetUserNames,
            seatIndices: seatIndices,
            initialQuantity: totalQuantity,
          );
        }
      } catch (e) {
        debugPrint('[QuickRepeat] Activation hook note: $e');
      }

      // Refresh Room AP Dual Progress bar & Progression
      if (Get.isRegistered<RoomDualProgressController>()) {
        unawaited(RoomDualProgressController.to.fetchDualProgress(roomId));
      }
      if (Get.isRegistered<RoomProgressionController>()) {
        final progCtrl = Get.find<RoomProgressionController>();
        unawaited(progCtrl.fetchRoomProgression(roomId, onUpdateSeats: (_) {}, onUpdateSeatGifts: (_) {}));
      }

      // Lucky reward notification check
      final luckyResult = resMap['lucky_result'];
      if (luckyResult != null && luckyResult is Map && luckyResult['is_lucky_gift'] == true) {
        if (Get.isRegistered<RoomChatController>()) {
          RoomChatController.to.addLuckyGiftMessage(roomId, Map<String, dynamic>.from(luckyResult));
        }
      }

      return true;
    } catch (e, stack) {
      debugPrint('[GiftPipeline] FAILURE: $e\n$stack');
      return false;
    }
  }


  Future<void> sendRoomGift(
    String roomId,
    int seatIndex,
    int amount,
    bool isGold, {
    required List<Map<String, dynamic>>? seats,
    required Function(String, String, int, String, Map<String, dynamic>) onEmitActivity,
    required Future<void> Function() onRefreshProgression,
  }) async {
    final currentUserId = UserProfileCacheManager.currentUserId;
    try {
      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creaniaa Student';

      await Supabase.instance.client.rpc('send_room_gift', params: {
        'p_room_id': roomId,
        'p_seat_index': seatIndex,
        'p_amount': amount,
        'p_is_gold': isGold,
      });

      final seatInfo =
          seats?.firstWhereOrNull((s) => s['seatIndex'] == seatIndex);
      final String receiverName = seatInfo?['name'] ?? RoomSeatController.getSeatName(seatIndex);

      final String message =
          '🎁 $uName sent $amount ${isGold ? 'Gold Coins' : 'Silver Coins'} to $receiverName.';

      await onEmitActivity(
        'gift_sent',
        currentUserId,
        seatIndex + 1,
        message,
        {
          'amount': amount,
          'is_gold': isGold,
          'receiver_name': receiverName,
        },
      );

      await onRefreshProgression();
    } catch (e) {
      Get.snackbar(
        'Gifting Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  void _rollbackBalance(RxInt walletBalance, int previousBalance, String currency) {
    walletBalance.value = previousBalance;
    try {
      if (Get.isRegistered<StoreController>()) {
        final storeCtrl = Get.find<StoreController>();
        if (currency == 'gold') {
          storeCtrl.coinsBalance.value = previousBalance;
        } else {
          storeCtrl.silverCoinsBalance.value = previousBalance;
        }
      }
    } catch (_) {}
  }

  void _showGiftErrorSnackbar(String errorMsg) {
    String friendlyError = errorMsg
        .replaceAll('Exception: ', '')
        .replaceAll('PostgrestException(', '')
        .replaceAll('message: ', '')
        .replaceAll(')', '')
        .trim();

    if (friendlyError.contains('<html') ||
        friendlyError.contains('SocketException') ||
        friendlyError.contains('Failed host lookup') ||
        friendlyError.contains('ClientException') ||
        friendlyError.contains('TimeoutException')) {
      friendlyError = 'Network/Server connection issue. Gift not sent.';
    }

    Get.snackbar(
      'Gift Sending Failed',
      friendlyError,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEF4444),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  List<String> _sanitizeUuidList(List<String> ids) {
    final RegExp uuidRegExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    final String currentUid = UserProfileCacheManager.currentUserId;
    final String validCurrentUid = (currentUid.isNotEmpty && uuidRegExp.hasMatch(currentUid))
        ? currentUid
        : '00000000-0000-0000-0000-000000000000';

    return ids.map((id) {
      if (uuidRegExp.hasMatch(id)) {
        return id;
      }
      return validCurrentUid;
    }).toList();
  }
}

