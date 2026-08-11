import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/wallet/creania_balance_model.dart';
import '../user/user_profile_cache_manager.dart';

class CreaniaBalanceController extends GetxController {
  static CreaniaBalanceController get to {
    if (!Get.isRegistered<CreaniaBalanceController>()) {
      return Get.put(CreaniaBalanceController(), permanent: true);
    }
    return Get.find<CreaniaBalanceController>();
  }

  final Rxn<CreaniaBalanceWallet> walletData = Rxn<CreaniaBalanceWallet>();
  final RxBool isLoading = false.obs;
  final RxBool isProcessingAction = false.obs;
  RealtimeChannel? _realtimeChannel;

  @override
  void onInit() {
    super.onInit();
    fetchWalletData();
    subscribeRealtimeWallet();
  }

  @override
  void onClose() {
    _realtimeChannel?.unsubscribe();
    super.onClose();
  }

  /// Subscribe to Supabase Realtime Postgres Changes on public.wallets table for instant CB balance updates
  void subscribeRealtimeWallet() {
    final user = UserProfileCacheManager.currentUser;
    final userId = user?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = Supabase.instance.client
          .channel('public:wallets:cb:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wallets',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('[CreaniaBalanceController] Realtime wallet event detected! Fetching fresh CB data...');
              fetchWalletData();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[CreaniaBalanceController] Error subscribing to wallet realtime channel: $e');
    }
  }

  Future<void> fetchWalletData() async {
    final user = UserProfileCacheManager.currentUser;
    final userId = user?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      isLoading.value = true;
      final res = await Supabase.instance.client.rpc(
        'get_cb_wallet_data',
        params: {'p_user_id': userId},
      );

      if (res != null && res is Map<String, dynamic> && res['success'] == true) {
        walletData.value = CreaniaBalanceWallet.fromJson(res);
      } else {
        debugPrint('[CreaniaBalanceController] Failed to fetch CB wallet data: $res');
      }
    } catch (e) {
      debugPrint('[CreaniaBalanceController] Error fetching CB wallet data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> exchangeCbCurrency({
    required int amountCb,
    String targetCurrency = 'gold',
  }) async {
    final user = UserProfileCacheManager.currentUser;
    final userId = user?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      Get.snackbar('Authentication Required', 'Please log in to exchange Creania Balance.');
      return false;
    }

    try {
      isProcessingAction.value = true;
      final res = await Supabase.instance.client.rpc(
        'exchange_cb_currency',
        params: {
          'p_user_id': userId,
          'p_amount_cb': amountCb,
          'p_target_currency': targetCurrency,
        },
      );

      if (res != null && res is Map<String, dynamic> && res['success'] == true) {
        final totalGained = res['total_amount'] ?? res['total_gold'] ?? 0;
        final bonusGained = res['bonus_amount'] ?? res['bonus_gold'] ?? 0;
        final targetName = targetCurrency.toLowerCase() == 'silver' ? 'Silver Coins 🥈' : 'Gold Coins 🪙';

        Get.snackbar(
          'Exchange Successful 🎉',
          'Exchanged ${CreaniaBalanceConverter.formatWithInr(amountCb)} for $totalGained $targetName! ${bonusGained > 0 ? "(Includes $bonusGained bonus)" : ""}',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );

        await fetchWalletData();
        return true;
      } else {
        final reason = res?['reason'] ?? 'Exchange failed.';
        Get.snackbar('Exchange Failed', reason, snackPosition: SnackPosition.TOP);
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred during exchange: $e', snackPosition: SnackPosition.TOP);
      return false;
    } finally {
      isProcessingAction.value = false;
    }
  }

  Future<bool> requestWithdrawal({
    required int amountCb,
    required String upiId,
    String? accountName,
  }) async {
    final user = UserProfileCacheManager.currentUser;
    final userId = user?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      Get.snackbar('Authentication Required', 'Please log in to request withdrawal.');
      return false;
    }

    try {
      isProcessingAction.value = true;
      final res = await Supabase.instance.client.rpc(
        'request_cb_withdrawal',
        params: {
          'p_user_id': userId,
          'p_amount_cb': amountCb,
          'p_upi_id': upiId,
          'p_account_name': accountName,
        },
      );

      if (res != null && res is Map<String, dynamic> && res['success'] == true) {
        final wdId = res['withdrawal_id'] ?? '';
        final netPayout = res['net_payout_inr'] ?? 0.0;

        Get.snackbar(
          'Withdrawal Requested 🚀',
          'Request $wdId submitted for ₹$netPayout to $upiId via Razorpay Instant Disbursal.',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 5),
        );

        await fetchWalletData();
        return true;
      } else {
        final reason = res?['reason'] ?? 'Withdrawal request failed.';
        Get.snackbar('Withdrawal Failed', reason, snackPosition: SnackPosition.TOP);
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred: $e', snackPosition: SnackPosition.TOP);
      return false;
    } finally {
      isProcessingAction.value = false;
    }
  }

  Future<bool> executeFamilySettlement(String familyId) async {
    try {
      isProcessingAction.value = true;
      final res = await Supabase.instance.client.rpc(
        'execute_weekend_family_settlement',
        params: {'p_family_id': familyId},
      );

      if (res != null && res is Map<String, dynamic> && res['success'] == true) {
        final settledCb = res['final_settled_cb'] ?? 0;
        Get.snackbar(
          'Settlement Completed 🏦',
          'Settled ${CreaniaBalanceConverter.formatWithInr(settledCb)} to Family Owner wallet.',
          snackPosition: SnackPosition.TOP,
        );
        await fetchWalletData();
        return true;
      } else {
        final reason = res?['reason'] ?? 'Settlement failed.';
        Get.snackbar('Settlement Failed', reason, snackPosition: SnackPosition.TOP);
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Settlement failed: $e');
      return false;
    } finally {
      isProcessingAction.value = false;
    }
  }
}
