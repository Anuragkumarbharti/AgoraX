import 'dart:async';
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

      final totalQuantity = count * comboCount;
      final totalCost = giftCost * totalQuantity * targetUserIds.length;

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

      // ── 2. INSTANT LOCAL EVENT, ANIMATION & CHAT DISPATCH (<10ms) ──
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

      final Map<String, dynamic> eventPayload = {
        'id': 'evt_${DateTime.now().microsecondsSinceEpoch}',
        'giftId': canonicalGiftUuid,
        'giftName': giftName,
        'giftIcon': giftIcon.isNotEmpty ? giftIcon : '🎁',
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

      // 🚀 Trigger instant zero-latency animation playback & WebSocket broadcast room-wide
      unawaited(GiftEventService.to.broadcastGiftEvent(roomId, eventPayload));

      // ⚡ Activate / Refresh Sender-Only Quick Repeat Session
      try {
        final qrCtrl = QuickRepeatController.to;
        if (!qrCtrl.isProcessing.value) {
          qrCtrl.activateQuickRepeat(
            originalGiftTransactionId: eventPayload['id'] as String,
            roomId: roomId,
            senderId: UserProfileCacheManager.currentUserId,
            giftId: canonicalGiftUuid,
            giftName: giftName,
            giftIcon: giftIcon.isNotEmpty ? giftIcon : '🎁',
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

      // ── 3. ASYNC BACKGROUND SERVER RPC SYNC & AP TASK REFRESH ──
      unawaited(Future(() async {
        try {
          final response = await Supabase.instance.client.rpc('send_star_gift', params: {
            'p_room_id': roomId,
            'p_receiver_ids': targetUserIds,
            'p_gift_id': canonicalGiftUuid,
            'p_quantity': count,
            'p_combo_count': comboCount,
            'p_seat_indices': seatIndices,
          });

          if (response != null && response['success'] == true) {
            final remaining = (response['remaining_balance'] as num).toInt();
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

            // Refresh Room AP Dual Progress bar & Progression
            if (Get.isRegistered<RoomDualProgressController>()) {
              unawaited(RoomDualProgressController.to.fetchDualProgress(roomId));
            }
            if (Get.isRegistered<RoomProgressionController>()) {
              final progCtrl = Get.find<RoomProgressionController>();
              unawaited(progCtrl.fetchRoomProgression(roomId, onUpdateSeats: (_) {}, onUpdateSeatGifts: (_) {}));
            }

            // Lucky reward notification check
            final luckyResult = response['lucky_result'];
            if (luckyResult != null && luckyResult is Map && luckyResult['is_lucky_gift'] == true) {
              if (Get.isRegistered<RoomChatController>()) {
                RoomChatController.to.addLuckyGiftMessage(roomId, Map<String, dynamic>.from(luckyResult));
              }
            }
          }
        } catch (e) {
          debugPrint('[GiftPipeline] Background RPC note: $e');
        }
      }));

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
}
