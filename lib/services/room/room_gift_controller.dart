import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../../widgets/gifting/gift_animation_overlay.dart';
import '../../models/room/room_model.dart';
import '../user/user_profile_cache_manager.dart';
import '../store/store_controller.dart';
import 'room_seat_controller.dart';

class RoomGiftController extends GetxController {
  static RoomGiftController get to => Get.find<RoomGiftController>();

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
    try {
      final room = roomsList.firstWhereOrNull((r) => r.id == roomId);
      if (room == null) return false;

      final response =
          await Supabase.instance.client.rpc('send_star_gift', params: {
        'p_room_id': roomId,
        'p_receiver_ids': targetUserIds,
        'p_gift_id': giftId,
        'p_quantity': count,
        'p_combo_count': comboCount,
        'p_seat_indices': seatIndices,
      });

      if (response != null && response['success'] == true) {
        final remaining = (response['remaining_balance'] as num).toInt();
        walletBalance.value = remaining;
        try {
          if (Get.isRegistered<StoreController>()) {
            final StoreController storeCtrl = Get.find<StoreController>();
            if (currency == 'gold') {
              storeCtrl.coinsBalance.value = remaining;
            } else {
              storeCtrl.silverCoinsBalance.value = remaining;
            }
          }
        } catch (_) {}

        final magicResult = response['magic_result'];
        if (magicResult != null &&
            magicResult['payout_type'] != null &&
            magicResult['payout_type'] != 'nothing') {
          final String type = magicResult['payout_type'];
          final int coinsBack = magicResult['coins_back'] ?? 0;
          final int silverAmount = magicResult['silver_reward'] ?? 0;
          final String vaultName = magicResult['vault_item_name'] ?? '';

          String outcomeText = '';
          if (type == 'coin_back') {
            outcomeText = '🔮 Lucky Draw! You got $coinsBack Gold Coins Back!';
          } else if (type == 'silver_reward') {
            outcomeText = '🔮 Lucky Draw! You won $silverAmount Silver Coins!';
          } else if (type == 'vault_reward') {
            outcomeText = '🔮 Lucky Draw! You won a $vaultName!';
          }

          Get.snackbar(
            'Magic Gift Reward! 🔮',
            outcomeText,
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFF8B5CF6),
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending star gift: $e');
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
