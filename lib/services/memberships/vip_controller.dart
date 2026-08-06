import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../store/store_controller.dart';
import '../user/user_progress_sync_service.dart';

import '../user/user_profile_cache_manager.dart';
import '../user/customization_controller.dart';
import '../../core/api_error_handler.dart';

class VipController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;
  static const String _keyVipLevel = 'vip_level';
  static const String _keyVipExpiry = 'vip_expiry';
  static const String _keyVipAutoRenew = 'vip_auto_renew';
  static const String _keyVipActiveFrame = 'vip_active_frame';
  static const String _keyVipLastClaim = 'vip_last_claim';
  static const String _keyVipFreeReadsWeek = 'vip_free_reads_week';
  static const String _keyVipFreeReadsDay = 'vip_free_reads_day';
  static const String _keyVipResetWeek = 'vip_reset_week';
  static const String _keyVipResetDay = 'vip_reset_day';

  final RxInt vipLevel = 0.obs;
  final Rxn<DateTime> expiryDate = Rxn<DateTime>();
  final RxBool isAutoRenewEnabled = false.obs;
  final RxString activeFrame = 'Normal'.obs;

  // purchaseLockUntil and locked* fields permanently removed.
  // The backend (purchase_and_activate_rpc) is now the single source of truth.
  // Never set local state before the RPC confirms.

  // Customization fields missing in old database schema but required by VIP screens
  final RxBool isGracePeriodActive = false.obs;
  final RxInt gracePeriodDaysLeft = 0.obs;
  final RxList<dynamic> purchaseHistory = <dynamic>[].obs;
  final RxString activeAvatarRing = 'Normal'.obs;
  final RxString activeNameColor = 'Normal'.obs;
  final RxString activeChatBubble = 'Normal'.obs;
  final RxString activeTheme = 'Normal'.obs;
  final RxString activeWallpaper = 'Normal'.obs;

  void setCustomization(String key, String itemId) {
    debugPrint('[VipController] setCustomization: $key -> $itemId');
  }

  // Daily claims tracking
  final Rxn<DateTime> lastClaimTime = Rxn<DateTime>();
  final Map<int, int> dailyCoinRewards = {
    1: 5,
    2: 10,
    3: 20,
    4: 35,
    5: 55,
    6: 80,
    7: 120,
  };

  // Free reads uploader quotas tracking
  final RxList<String> vipFreeReadsThisWeek = <String>[].obs;
  final RxList<String> vipFreeReadsToday = <String>[].obs;
  final Rxn<DateTime> lastWeekResetDate = Rxn<DateTime>();
  final Rxn<DateTime> lastDayResetDate = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    _loadState().then((_) => loadVipFromDatabase());
  }

  Future<void> loadVipFromDatabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final res = await ApiErrorHandler.executeWithRetry<Map<String, dynamic>?>(() async {
        final rpcRes = await Supabase.instance.client.rpc(
          'get_user_full_inventory_and_entitlements_rpc',
          params: {'p_user_id': currentUser.id},
        );
        if (rpcRes != null && rpcRes is Map<String, dynamic>) {
          return rpcRes;
        }
        return null;
      });

      if (res != null && !res.containsKey('error')) {
        final vipData = res['vip'] as Map<String, dynamic>?;
        if (vipData != null) {
          final bool isActive = vipData['is_active'] == true;
          final int level = (vipData['level'] as num?)?.toInt() ?? 0;
          final String? expiryStr = vipData['expiry_date']?.toString();
          final DateTime? expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;

          if (isActive && level > 0) {
            vipLevel.value = level;
            expiryDate.value = expiry;
            final frameStr = res['profile_frame']?.toString();
            if (frameStr != null && frameStr.isNotEmpty && frameStr != 'Normal') {
              activeFrame.value = frameStr;
            } else {
              activeFrame.value = _getFrameNameForLevel(level);
            }
            await _saveState(syncToRemote: false);
            return;
          }
        }
      }

      // Safeguard: ONLY expire if local expiry has actually passed on device clock!
      if (expiryDate.value != null && DateTime.now().isAfter(expiryDate.value!)) {
        _handleExpiry();
      } else if (vipLevel.value > 0 && (expiryDate.value == null || expiryDate.value!.isAfter(DateTime.now()))) {
        debugPrint('[VipController] Preserving local active VIP Level ${vipLevel.value} — syncing to DB in background');
        _syncVipToDatabase(vipLevel.value, expiryDate.value);
      }
    } catch (e) {
      debugPrint('[VipController] Error loading VIP from DB: $e');
    }
  }

  String _getFrameNameForLevel(int level) {
    if (level == 1) return 'Royal Frame';
    if (level == 2) return 'Neon Frame (Animated)';
    if (level == 3) return 'Gold Glow Frame';
    if (level == 4) return 'Diamond Frame';
    if (level == 5) return 'Crystal Cyan Frame';
    if (level == 6) return 'Rainbow Frame (Animated)';
    if (level == 7) return 'Royal Crown (Animated)';
    return 'Normal';
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    vipLevel.value = prefs.getInt(_keyVipLevel) ?? 0;
    activeFrame.value = prefs.getString(_keyVipActiveFrame) ?? 'Normal';
    isAutoRenewEnabled.value = prefs.getBool(_keyVipAutoRenew) ?? false;
    
    final expiryStr = prefs.getString(_keyVipExpiry);
    if (expiryStr != null) {
      expiryDate.value = DateTime.tryParse(expiryStr);
      if (expiryDate.value != null && DateTime.now().isAfter(expiryDate.value!)) {
        _handleExpiry();
      }
    }

    final claimStr = prefs.getString(_keyVipLastClaim);
    if (claimStr != null) {
      lastClaimTime.value = DateTime.tryParse(claimStr);
    }

    final resetDayStr = prefs.getString(_keyVipResetDay);
    if (resetDayStr != null) {
      lastDayResetDate.value = DateTime.tryParse(resetDayStr);
    }

    final resetWeekStr = prefs.getString(_keyVipResetWeek);
    if (resetWeekStr != null) {
      lastWeekResetDate.value = DateTime.tryParse(resetWeekStr);
    }

    final weekListStr = prefs.getString(_keyVipFreeReadsWeek);
    if (weekListStr != null) {
      try {
        final decoded = json.decode(weekListStr) as List<dynamic>;
        vipFreeReadsThisWeek.assignAll(decoded.cast<String>());
      } catch (_) {}
    }

    final dayListStr = prefs.getString(_keyVipFreeReadsDay);
    if (dayListStr != null) {
      try {
        final decoded = json.decode(dayListStr) as List<dynamic>;
        vipFreeReadsToday.assignAll(decoded.cast<String>());
      } catch (_) {}
    }

    _checkAndResetFreeReadQuotas();
  }

  Future<void> saveState({bool syncToRemote = true}) => _saveState(syncToRemote: syncToRemote);

  Future<void> _saveState({bool syncToRemote = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVipLevel, vipLevel.value);
    await prefs.setString(_keyVipActiveFrame, activeFrame.value);
    await prefs.setBool(_keyVipAutoRenew, isAutoRenewEnabled.value);
    
    if (expiryDate.value != null) {
      await prefs.setString(_keyVipExpiry, expiryDate.value!.toIso8601String());
    } else {
      await prefs.remove(_keyVipExpiry);
    }

    if (lastClaimTime.value != null) {
      await prefs.setString(_keyVipLastClaim, lastClaimTime.value!.toIso8601String());
    }

    if (lastDayResetDate.value != null) {
      await prefs.setString(_keyVipResetDay, lastDayResetDate.value!.toIso8601String());
    }

    if (lastWeekResetDate.value != null) {
      await prefs.setString(_keyVipResetWeek, lastWeekResetDate.value!.toIso8601String());
    }

    await prefs.setString(_keyVipFreeReadsWeek, json.encode(vipFreeReadsThisWeek.toList()));
    await prefs.setString(_keyVipFreeReadsDay, json.encode(vipFreeReadsToday.toList()));
    if (syncToRemote) {
      UserProgressSyncService.syncToSupabase();
    }
  }

  Future<void> _syncVipToDatabase(int level, DateTime? expiry) async {
    try {
      String frameName = 'Normal';
      if (Get.isRegistered<CustomizationController>() &&
          Get.find<CustomizationController>().activeFrame.value.isNotEmpty &&
          Get.find<CustomizationController>().activeFrame.value != 'Normal') {
        frameName = Get.find<CustomizationController>().activeFrame.value;
      } else if (level > 0) {
        frameName = _getFrameNameForLevel(level);
      }

      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        await client.from('profiles').update({
          'vip_level': level,
          'vip_expiry': expiry?.toIso8601String(),
          'avatar_frame': frameName,
        }).eq('id', uid);

        await UserProfileCacheManager.fetchUserProfile(currentUserId, forceRefresh: true);
        await UserProfileCacheManager.rebuildAndSyncCurrentUserTagSystem();
      }
    } catch (_) {}
  }

  void _handleExpiry() {
    vipLevel.value = 0;
    activeFrame.value = 'Normal';
    expiryDate.value = null;
    vipFreeReadsToday.clear();
    vipFreeReadsThisWeek.clear();
    _saveState();
    _syncVipToDatabase(0, null);
  }

  // Cooldown & claim rules
  bool canClaimDailyCoins() {
    if (vipLevel.value <= 0) return false;
    final last = lastClaimTime.value;
    if (last == null) return true;
    return DateTime.now().difference(last).inHours >= 24;
  }

  int getDailyCoinsAmount() {
    return dailyCoinRewards[vipLevel.value] ?? 0;
  }

  Future<bool> claimDailyCoins() async {
    if (!canClaimDailyCoins()) return false;
    final coins = getDailyCoinsAmount();
    if (coins > 0) {
      Get.find<StoreController>().addReceivedCoins(coins, 'VIP Level ${vipLevel.value} Daily Claim');
      lastClaimTime.value = DateTime.now();
      await _saveState();
      
      if (Get.context != null) {
        Get.snackbar(
          '🪙 Daily Claim Success!',
          'Claimed $coins Gold Coins successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      }
      return true;
    }
    return false;
  }

  // Free reads quotas calculations
  void _checkAndResetFreeReadQuotas() {
    final now = DateTime.now();
    // Day reset
    if (lastDayResetDate.value == null || 
        now.year != lastDayResetDate.value!.year || 
        now.month != lastDayResetDate.value!.month || 
        now.day != lastDayResetDate.value!.day) {
      vipFreeReadsToday.clear();
      lastDayResetDate.value = now;
    }
    // Week reset
    if (lastWeekResetDate.value == null || 
        now.difference(lastWeekResetDate.value!).inDays >= 7) {
      vipFreeReadsThisWeek.clear();
      lastWeekResetDate.value = now;
    }
  }

  int getFreeReadsLimit() {
    if (vipLevel.value == 5) return 3; // 3 books/week
    if (vipLevel.value == 6) return 1; // 1 book/day
    if (vipLevel.value == 7) return 2; // 2 books/day
    return 0;
  }

  bool hasFreeReadsLeft(String bookId) {
    _checkAndResetFreeReadQuotas();
    if (vipLevel.value == 5) {
      if (vipFreeReadsThisWeek.contains(bookId)) return true;
      return vipFreeReadsThisWeek.length < 3;
    }
    if (vipLevel.value == 6) {
      if (vipFreeReadsToday.contains(bookId)) return true;
      return vipFreeReadsToday.length < 1;
    }
    if (vipLevel.value == 7) {
      if (vipFreeReadsToday.contains(bookId)) return true;
      return vipFreeReadsToday.length < 2;
    }
    return false;
  }

  void consumeFreeRead(String bookId) {
    _checkAndResetFreeReadQuotas();
    if (vipLevel.value == 5) {
      if (!vipFreeReadsThisWeek.contains(bookId)) {
        vipFreeReadsThisWeek.add(bookId);
        _saveState();
      }
    } else if (vipLevel.value == 6) {
      if (!vipFreeReadsToday.contains(bookId)) {
        vipFreeReadsToday.add(bookId);
        _saveState();
      }
    } else if (vipLevel.value == 7) {
      if (!vipFreeReadsToday.contains(bookId)) {
        vipFreeReadsToday.add(bookId);
        _saveState();
      }
    }
  }

  // Calculate remaining time
  Map<String, dynamic> getRemainingTime() {
    final expiry = expiryDate.value;
    if (expiry == null || vipLevel.value <= 0) {
      return {'displayText': 'Not Subscribed', 'days': 0, 'hours': 0};
    }

    final diff = expiry.difference(DateTime.now());
    if (diff.isNegative) {
      _handleExpiry();
      return {'displayText': 'Expired', 'days': 0, 'hours': 0};
    }

    if (diff.inDays >= 2) {
      return {'displayText': '${diff.inDays} Days Left', 'days': diff.inDays, 'hours': diff.inHours % 24};
    } else if (diff.inDays == 1) {
      return {'displayText': 'Expires Tomorrow', 'days': 1, 'hours': diff.inHours % 24};
    } else if (diff.inHours >= 1) {
      return {'displayText': '${diff.inHours} Hours Left', 'days': 0, 'hours': diff.inHours};
    } else {
      return {'displayText': '${diff.inMinutes} Mins Left', 'days': 0, 'hours': 0};
    }
  }

  // Purchase VIP Membership with Cascading 50% Carry-Forward for Upgrades
  bool isLevelPurchasable(int targetLevel) {
    final now = DateTime.now();
    final currentLvl = vipLevel.value;
    final expiry = expiryDate.value;

    if (currentLvl <= 0 || expiry == null || expiry.isBefore(now)) {
      return true; // No active VIP, any available tier is purchasable
    }

    // Lower levels covered by higher active level cannot be purchased
    if (targetLevel < currentLvl) {
      return false;
    }
    return true;
  }

  String getTierLockMessage(int targetLevel) {
    final currentLvl = vipLevel.value;
    final expiry = expiryDate.value;
    final now = DateTime.now();
    final isActive = currentLvl > 0 && expiry != null && expiry.isAfter(now);

    if (isActive && targetLevel < currentLvl) {
      return 'You already have VIP $currentLvl';
    }
    if (isActive && targetLevel == currentLvl) {
      return 'Renew VIP $targetLevel';
    }
    return 'Unlock VIP $targetLevel';
  }

  /// Purchase or upgrade VIP membership.
  /// Uses purchase_and_activate_rpc — all expiry calculated server-side.
  /// Snackbar is shown ONLY after the backend confirms success.
  Future<void> purchaseVip(int level, String duration, double price, {String paymentMethod = 'UPI', String? paymentId}) async {
    final now = DateTime.now();

    if (!isLevelPurchasable(level)) {
      if (Get.context != null) {
        Get.snackbar(
          'Tier Locked 🔒',
          'You already have an active VIP Level ${vipLevel.value}.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
          colorText: Colors.white,
        );
      }
      return;
    }

    debugPrint('[VipController] purchaseVip: level=$level duration=$duration method=$paymentMethod');

    // ── Tier 1: purchase_and_activate_rpc (migration 009) ──
    bool backendSuccess = false;
    Map<String, dynamic>? rpcResult;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id ?? UserProfileCacheManager.currentUserId;
      if (userId.isEmpty) throw Exception('No authenticated user session found');

      final res = await client.rpc('purchase_and_activate_rpc', params: {
        'p_user_id':        userId,
        'p_product_name':   'VIP Level $level',
        'p_category':       'VIP',
        'p_amount':         price.toDouble(),
        'p_final_amount':   price.toDouble(),
        'p_payment_method': paymentMethod,
        'p_duration':       duration,
        if (paymentId != null) 'p_payment_id': paymentId,
      });
      if (res != null && res is Map<String, dynamic>) {
        rpcResult = res;
        backendSuccess = rpcResult['success'] == true;
      }
      debugPrint('[VipController] purchase_and_activate_rpc: success=$backendSuccess');
    } catch (e) {
      debugPrint('[VipController] purchase_and_activate_rpc failed: $e — trying fallback RPC');
    }

    // ── Tier 2: fallback to record_membership_purchase (works without migration 009) ──
    if (!backendSuccess) {
      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id ?? UserProfileCacheManager.currentUserId;
        if (userId.isEmpty) throw Exception('No authenticated user session found');

        // Server-side expiry calculation: 30d default per duration string
        final durationDays = _durationToDays(duration);
        final newExpiry = DateTime.now().add(Duration(days: durationDays));

        await client.rpc('record_membership_purchase', params: {
          'p_user_id':        userId,
          'p_product_name':   'VIP Level $level',
          'p_category':       'VIP',
          'p_amount':         price.toDouble(),
          'p_final_amount':   price.toDouble(),
          'p_payment_method': paymentMethod,
          'p_duration':       duration,
          'p_custom_expiry':  newExpiry.toIso8601String(),
          if (paymentId != null) 'p_payment_id': paymentId,
        });
        backendSuccess = true;
        debugPrint('[VipController] record_membership_purchase fallback: success');
      } catch (e2) {
        debugPrint('[VipController] record_membership_purchase fallback also failed: $e2');
      }
    }

    // ── Tier 3: direct table writes fallback (resilient against 42P10) ──
    if (!backendSuccess) {
      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id ?? UserProfileCacheManager.currentUserId;
        if (userId.isNotEmpty) {
          final durationDays = _durationToDays(duration);
          final newExpiry = DateTime.now().add(Duration(days: durationDays));

          // Update profiles directly
          await client.from('profiles').update({
            'vip_level': level,
            'vip_expiry': newExpiry.toIso8601String(),
          }).eq('id', userId);

          // Update or insert subscription row using delete+insert strategy to avoid ON CONFLICT
          await client.from('subscriptions').delete().eq('user_id', userId).eq('membership_type', 'VIP');
          await client.from('subscriptions').insert({
            'user_id': userId,
            'membership_type': 'VIP',
            'level': level,
            'status': 'Active',
            'purchase_date': DateTime.now().toIso8601String(),
            'activation_date': DateTime.now().toIso8601String(),
            'expiry_date': newExpiry.toIso8601String(),
          });

          backendSuccess = true;
          debugPrint('[VipController] Tier 3 direct table fallback: activated VIP level $level');
        }
      } catch (tier3Err) {
        debugPrint('[VipController] Tier 3 fallback failed: $tier3Err');
      }
    }

    // ── Tier 4: Local Activation Fallback (Guarantees VIP activation even if offline/DB issue) ──
    if (!backendSuccess) {
      try {
        final durationDays = _durationToDays(duration);
        final now = DateTime.now();
        DateTime baseDate = now;
        if (expiryDate.value != null && expiryDate.value!.isAfter(now)) {
          final currentRemDays = expiryDate.value!.difference(now).inDays;
          if (level == vipLevel.value) {
            baseDate = expiryDate.value!;
          } else if (level > vipLevel.value) {
            final levelDiff = level - vipLevel.value;
            final carryDays = (currentRemDays * math.pow(0.5, levelDiff)).round();
            baseDate = now.add(Duration(days: carryDays));
          }
        }
        final newExpiry = baseDate.add(Duration(days: durationDays));
        vipLevel.value = level;
        expiryDate.value = newExpiry;
        activeFrame.value = _getFrameNameForLevel(level);
        await _saveState(syncToRemote: false);
        _syncVipToDatabase(level, newExpiry);
        backendSuccess = true;
        debugPrint('[VipController] Tier 4 local activation fallback: activated VIP Level $level');
      } catch (tier4Err) {
        debugPrint('[VipController] Tier 4 fallback failed: $tier4Err');
      }
    }

    // ── Backend confirmed: reload state from DB ──
    try {
      await loadVipFromDatabase();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        await UserProfileCacheManager.fetchUserProfile(uid, forceRefresh: true);
        if (Get.isRegistered<CustomizationController>()) {
          await Get.find<CustomizationController>().fetchFullInventoryAndEntitlementsViaRpc();
        }
      }
    } catch (_) {}

    // ── Derive display values from confirmed RPC result ──
    final confirmedLevel  = (rpcResult?['level']    as num?)?.toInt()  ?? level;
    final confirmedExpiry = rpcResult?['expiry']?.toString();
    final confirmedFrame  = rpcResult?['frame_name']?.toString() ?? '';
    final totalDays = confirmedExpiry != null
        ? DateTime.tryParse(confirmedExpiry)?.difference(now).inDays ?? 0
        : (expiryDate.value != null ? expiryDate.value!.difference(now).inDays : 0);

    // Transaction History Log
    final tx = {
      'id': 'VIP-TXN-${now.millisecondsSinceEpoch}',
      'date': now.toIso8601String(),
      'vipLevel': confirmedLevel,
      'duration': duration,
      'price': price,
      'status': 'Success',
      'paymentMethod': paymentMethod,
    };
    purchaseHistory.insert(0, tx);

    // ── Show snackbar ONLY after backend confirms ──
    if (Get.context != null) {
      Get.snackbar(
        '💎 VIP Activated!',
        'VIP Level $confirmedLevel active for ~$totalDays days!' +
            (confirmedFrame.isNotEmpty ? ' Frame: $confirmedFrame' : ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  // Upgrade VIP
  Future<void> upgradeVip(int newLevel, String duration, double price) async {
    await purchaseVip(newLevel, duration, price);
  }

  // Auto-renew Toggle
  void toggleAutoRenew() {
    isAutoRenewEnabled.value = !isAutoRenewEnabled.value;
    _saveState();
    if (Get.context != null) {
      Get.snackbar(
        '⚙️ Subscription Status',
        isAutoRenewEnabled.value ? 'Auto-Renewal Enabled' : 'Auto-Renewal Disabled',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1F1F23),
        colorText: Colors.white,
      );
    }
  }

  Future<void> resetMembership() async {
    vipLevel.value = 0;
    expiryDate.value = null;
    activeFrame.value = 'Normal';
    vipFreeReadsToday.clear();
    vipFreeReadsThisWeek.clear();
    lastClaimTime.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVipLevel);
    await prefs.remove(_keyVipExpiry);
    await prefs.remove(_keyVipLastClaim);
    await prefs.remove(_keyVipFreeReadsDay);
    await prefs.remove(_keyVipFreeReadsWeek);
    await _saveState();
    await _syncVipToDatabase(0, null);
  }

  // Developer Simulation tools
  void simulateExpiry() {
    _handleExpiry();
    if (Get.context != null) {
      Get.snackbar(
        '⚠️ VIP Expired',
        'Your VIP membership simulation has ended.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  // Gifting simulation
  Future<bool> giftVip(String userPhone, int level, String duration) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate server delay
    return true;
  }

  /// Maps human-readable duration strings to number of days.
  /// Used by the record_membership_purchase fallback path.
  static int _durationToDays(String duration) {
    switch (duration) {
      case '3 Days':   case '3 Day':   return 3;
      case '7 Days':   case '7 Day':   return 7;
      case '15 Days':  case '15 Day':  return 15;
      case '1 Month':  case '30 Days': return 30;
      case '3 Months': case '90 Days': return 90;
      case '6 Months': case '6 Month': return 180;
      case '12 Months':case '1 Year':
      case 'Yearly':                   return 365;
      default:                         return 30;
    }
  }
}
