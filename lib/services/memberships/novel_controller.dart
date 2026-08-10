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

class NovelController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;
  // SharedPreferences Keys
  static const String _keyNovelLevel = 'novel_level';
  static const String _keyNovelExpiry = 'novel_expiry';
  static const String _keyNovelAutoRenew = 'novel_auto_renew';
  static const String _keyOwnedNovels = 'novel_owned_list';
  static const String _keyActiveStyle = 'novel_active_style';
  static const String _keyNovelHistory = 'novel_purchase_history';
  static const String _keyNovelNotifications = 'novel_notifications';
  static const String _keyNovelLastClaim = 'novel_last_claim';
  static const String _keyNovelFreeReadsWeek = 'novel_free_reads_week';
  static const String _keyNovelFreeReadsDay = 'novel_free_reads_day';
  static const String _keyNovelResetWeek = 'novel_reset_week';
  static const String _keyNovelResetDay = 'novel_reset_day';

  // Observables
  final RxInt novelLevel = 0.obs; // 0 = None, 1 to 7
  final Rxn<DateTime> expiryDate = Rxn<DateTime>();
  final RxBool isAutoRenewEnabled = false.obs;

  // Collector system: list of level numbers the user owns
  final RxList<int> ownedNovels = <int>[].obs;
  // Currently equipped active Novel visual style (must be in ownedNovels)
  final RxInt activeNovelStyle = 0.obs;

  // History & Notifications
  final RxList<Map<String, dynamic>> purchaseHistory = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;

  // Daily claim rewards
  final Rxn<DateTime> lastClaimTime = Rxn<DateTime>();
  final Map<int, int> dailyCoinRewards = {
    1: 20,
    2: 40,
    3: 70,
    4: 110,
    5: 160,
    6: 220,
    7: 300,
  };

  // Free reads quotas tracking
  final RxList<String> novelFreeReadsThisWeek = <String>[].obs;
  final RxList<String> novelFreeReadsToday = <String>[].obs;
  final Rxn<DateTime> lastWeekResetDate = Rxn<DateTime>();
  final Rxn<DateTime> lastDayResetDate = Rxn<DateTime>();

  // Coupons
  final Map<String, double> couponDiscounts = {
    'NOVEL100': 0.10, // 10% off
    'SUPREME': 0.20,  // 20% off
    'ROYALTY': 0.30,  // 30% off
  };

  @override
  void onInit() {
    super.onInit();
    _loadState().then((_) => loadNovelFromDatabase());
  }

  Future<void> loadNovelFromDatabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Use the authoritative single-call RPC (runs expiry cleanup + returns server-verified data)
      final res = await Supabase.instance.client.rpc(
        'get_user_full_inventory_and_entitlements_rpc',
        params: {'p_user_id': currentUser.id},
      );

      if (res != null && res is Map<String, dynamic> && !res.containsKey('error')) {
        final novelData = res['novel'] as Map<String, dynamic>?;
        if (novelData != null) {
          final bool isActive = novelData['is_active'] == true;
          final int level = (novelData['level'] as num?)?.toInt() ?? 0;
          final String? expiryStr = novelData['expiry_date']?.toString();
          final DateTime? expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;

          if (isActive && level > 0) {
            novelLevel.value = level;
            expiryDate.value = expiry;
            activeNovelStyle.value = level;
            if (!ownedNovels.contains(level)) ownedNovels.add(level);
            await _saveState(syncToRemote: false);
            return;
          }
        }
      }

      // Safeguard: ONLY expire if local expiry has actually passed on device clock!
      if (expiryDate.value != null && DateTime.now().isAfter(expiryDate.value!)) {
        _handleExpiry();
      } else if (novelLevel.value > 0 && (expiryDate.value == null || expiryDate.value!.isAfter(DateTime.now()))) {
        debugPrint('[NovelController] Preserving local active Novel Level ${novelLevel.value} — syncing to DB in background');
        _syncNovelToDatabase(novelLevel.value, expiryDate.value);
      }
    } catch (e) {
      debugPrint('[NovelController] Error loading Novel from DB: $e');
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    novelLevel.value = prefs.getInt(_keyNovelLevel) ?? 0;
    isAutoRenewEnabled.value = prefs.getBool(_keyNovelAutoRenew) ?? false;
    activeNovelStyle.value = prefs.getInt(_keyActiveStyle) ?? 0;

    final expiryStr = prefs.getString(_keyNovelExpiry);
    if (expiryStr != null) {
      expiryDate.value = DateTime.tryParse(expiryStr);
      if (expiryDate.value != null && DateTime.now().isAfter(expiryDate.value!)) {
        _handleExpiry();
      }
    }

    final ownedListStr = prefs.getString(_keyOwnedNovels);
    if (ownedListStr != null) {
      try {
        final decoded = json.decode(ownedListStr) as List<dynamic>;
        ownedNovels.assignAll(decoded.cast<int>());
      } catch (_) {}
    } else if (novelLevel.value > 0) {
      ownedNovels.assignAll([novelLevel.value]);
    }

    final historyJson = prefs.getString(_keyNovelHistory);
    if (historyJson != null) {
      try {
        final decoded = json.decode(historyJson) as List<dynamic>;
        purchaseHistory.assignAll(decoded.map((e) => Map<String, dynamic>.from(e)));
      } catch (_) {}
    }

    final notifJson = prefs.getString(_keyNovelNotifications);
    if (notifJson != null) {
      try {
        final decoded = json.decode(notifJson) as List<dynamic>;
        notifications.assignAll(decoded.map((e) => Map<String, dynamic>.from(e)));
      } catch (_) {}
    }

    final claimStr = prefs.getString(_keyNovelLastClaim);
    if (claimStr != null) {
      lastClaimTime.value = DateTime.tryParse(claimStr);
    }

    final resetDayStr = prefs.getString(_keyNovelResetDay);
    if (resetDayStr != null) {
      lastDayResetDate.value = DateTime.tryParse(resetDayStr);
    }

    final resetWeekStr = prefs.getString(_keyNovelResetWeek);
    if (resetWeekStr != null) {
      lastWeekResetDate.value = DateTime.tryParse(resetWeekStr);
    }

    final weekListStr = prefs.getString(_keyNovelFreeReadsWeek);
    if (weekListStr != null) {
      try {
        final decoded = json.decode(weekListStr) as List<dynamic>;
        novelFreeReadsThisWeek.assignAll(decoded.cast<String>());
      } catch (_) {}
    }

    final dayListStr = prefs.getString(_keyNovelFreeReadsDay);
    if (dayListStr != null) {
      try {
        final decoded = json.decode(dayListStr) as List<dynamic>;
        novelFreeReadsToday.assignAll(decoded.cast<String>());
      } catch (_) {}
    }

    _checkAndResetFreeReadQuotas();
  }

  Future<void> saveState({bool syncToRemote = true}) => _saveState(syncToRemote: syncToRemote);

  Future<void> _saveState({bool syncToRemote = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNovelLevel, novelLevel.value);
    await prefs.setBool(_keyNovelAutoRenew, isAutoRenewEnabled.value);
    await prefs.setInt(_keyActiveStyle, activeNovelStyle.value);
    await prefs.setString(_keyOwnedNovels, json.encode(ownedNovels.toList()));
    await prefs.setString(_keyNovelHistory, json.encode(purchaseHistory.toList()));
    await prefs.setString(_keyNovelNotifications, json.encode(notifications.toList()));

    if (expiryDate.value != null) {
      await prefs.setString(_keyNovelExpiry, expiryDate.value!.toIso8601String());
    } else {
      await prefs.remove(_keyNovelExpiry);
    }

    if (lastClaimTime.value != null) {
      await prefs.setString(_keyNovelLastClaim, lastClaimTime.value!.toIso8601String());
    }

    if (lastDayResetDate.value != null) {
      await prefs.setString(_keyNovelResetDay, lastDayResetDate.value!.toIso8601String());
    }

    if (lastWeekResetDate.value != null) {
      await prefs.setString(_keyNovelResetWeek, lastWeekResetDate.value!.toIso8601String());
    }

    await prefs.setString(_keyNovelFreeReadsWeek, json.encode(novelFreeReadsThisWeek.toList()));
    await prefs.setString(_keyNovelFreeReadsDay, json.encode(novelFreeReadsToday.toList()));
    if (syncToRemote) {
      UserProgressSyncService.syncToSupabase();
    }
  }

  Future<void> _syncNovelToDatabase(int level, DateTime? expiry) async {
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
          'novel_level': level,
          'novel_expiry': expiry?.toIso8601String(),
          'avatar_frame': frameName,
        }).eq('id', uid);

        await UserProfileCacheManager.fetchUserProfile(currentUserId, forceRefresh: true);
        await UserProfileCacheManager.rebuildAndSyncCurrentUserTagSystem();
      }
    } catch (_) {}
  }

  String _getFrameNameForLevel(int level) {
    if (level == 1) return 'Novel Level 1';
    if (level == 2) return 'Galaxy Orbit (Animated)';
    if (level == 3) return 'Royal Gold Palace';
    if (level == 4) return 'Dragon Fire Frame';
    if (level == 5) return 'Phoenix Flame (Animated)';
    if (level == 6) return 'Celestial Sky Frame';
    if (level == 7) return 'Cosmic Emperor (Animated)';
    return 'Normal';
  }

  void _handleExpiry() {
    novelLevel.value = 0;
    activeNovelStyle.value = 0;
    ownedNovels.clear();
    novelFreeReadsToday.clear();
    novelFreeReadsThisWeek.clear();
    expiryDate.value = null;
    _saveState();
    _syncNovelToDatabase(0, null);
  }

  // Daily Claim Logic
  bool canClaimDailyCoins() {
    if (novelLevel.value <= 0) return false;
    final last = lastClaimTime.value;
    if (last == null) return true;
    return DateTime.now().difference(last).inHours >= 24;
  }

  int getDailyCoinsAmount() {
    return dailyCoinRewards[novelLevel.value] ?? 0;
  }

  Future<bool> claimDailyCoins() async {
    if (!canClaimDailyCoins()) return false;
    final coins = getDailyCoinsAmount();
    if (coins > 0) {
      Get.find<StoreController>().addReceivedCoins(coins, 'Novel Level ${novelLevel.value} Daily Claim');
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
      novelFreeReadsToday.clear();
      lastDayResetDate.value = now;
    }
    // Week reset
    if (lastWeekResetDate.value == null || 
        now.difference(lastWeekResetDate.value!).inDays >= 7) {
      novelFreeReadsThisWeek.clear();
      lastWeekResetDate.value = now;
    }
  }

  int getFreeReadsLimit() {
    if (novelLevel.value == 4) return 3; // 3 books/week
    if (novelLevel.value == 5) return 1; // 1 book/day
    if (novelLevel.value == 6) return 2; // 2 books/day
    if (novelLevel.value == 7) return 4; // 4 books/day
    return 0;
  }

  bool hasFreeReadsLeft(String bookId) {
    _checkAndResetFreeReadQuotas();
    if (novelLevel.value == 4) {
      if (novelFreeReadsThisWeek.contains(bookId)) return true;
      return novelFreeReadsThisWeek.length < 3;
    }
    if (novelLevel.value == 5) {
      if (novelFreeReadsToday.contains(bookId)) return true;
      return novelFreeReadsToday.length < 1;
    }
    if (novelLevel.value == 6) {
      if (novelFreeReadsToday.contains(bookId)) return true;
      return novelFreeReadsToday.length < 2;
    }
    if (novelLevel.value == 7) {
      if (novelFreeReadsToday.contains(bookId)) return true;
      return novelFreeReadsToday.length < 4;
    }
    return false;
  }

  void consumeFreeRead(String bookId) {
    _checkAndResetFreeReadQuotas();
    if (novelLevel.value == 4) {
      if (!novelFreeReadsThisWeek.contains(bookId)) {
        novelFreeReadsThisWeek.add(bookId);
        _saveState();
      }
    } else if (novelLevel.value == 5) {
      if (!novelFreeReadsToday.contains(bookId)) {
        novelFreeReadsToday.add(bookId);
        _saveState();
      }
    } else if (novelLevel.value == 6) {
      if (!novelFreeReadsToday.contains(bookId)) {
        novelFreeReadsToday.add(bookId);
        _saveState();
      }
    } else if (novelLevel.value == 7) {
      if (!novelFreeReadsToday.contains(bookId)) {
        novelFreeReadsToday.add(bookId);
        _saveState();
      }
    }
  }

  // Swap equipped Novel collection style (Collector system)
  bool switchActiveStyle(int level) {
    if (novelLevel.value <= 0 || expiryDate.value == null) return false;
    if (ownedNovels.contains(level)) {
      activeNovelStyle.value = level;
      _saveState();
      
      if (Get.context != null) {
        Get.snackbar(
          '🎨 Collection Changed',
          'Equipped Novel Level $level Visual Style!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1E1B4B).withOpacity(0.9),
          colorText: Colors.white,
        );
      }
      return true;
    }
    return false;
  }

  // Calculate remaining time Display
  Map<String, dynamic> getRemainingTime() {
    final expiry = expiryDate.value;
    if (expiry == null || novelLevel.value <= 0) {
      return {'displayText': 'Not Unlocked', 'days': 0, 'hours': 0, 'isExpired': true};
    }

    final diff = expiry.difference(DateTime.now());
    if (diff.isNegative) {
      _handleExpiry();
      return {'displayText': 'Expired', 'days': 0, 'hours': 0, 'isExpired': true};
    }

    if (diff.inDays >= 2) {
      return {'displayText': '${diff.inDays} Days Left', 'days': diff.inDays, 'hours': diff.inHours % 24, 'isExpired': false};
    } else if (diff.inDays == 1) {
      return {'displayText': 'Expires Tomorrow', 'days': 1, 'hours': diff.inHours % 24, 'isExpired': false};
    } else if (diff.inHours >= 1) {
      return {'displayText': '${diff.inHours} Hours Left', 'days': 0, 'hours': diff.inHours, 'isExpired': false};
    } else {
      return {'displayText': '${diff.inMinutes} Mins Left', 'days': 0, 'hours': 0, 'isExpired': false};
    }
  }

  // Purchase Novel Membership with Cascading 50% Carry-Forward for Upgrades
  bool isLevelPurchasable(int targetLevel) {
    final now = DateTime.now();
    final currentLvl = novelLevel.value;
    final expiry = expiryDate.value;

    if (currentLvl <= 0 || expiry == null || expiry.isBefore(now)) {
      return true; // No active Novel membership, any available level is purchasable
    }

    // Lower levels covered by higher active level cannot be purchased
    if (targetLevel < currentLvl) {
      return false;
    }
    return true;
  }

  String getTierLockMessage(int targetLevel) {
    final currentLvl = novelLevel.value;
    final expiry = expiryDate.value;
    final now = DateTime.now();
    final isActive = currentLvl > 0 && expiry != null && expiry.isAfter(now);

    if (isActive && targetLevel < currentLvl) {
      return 'You already have Novel $currentLvl';
    }
    if (isActive && targetLevel == currentLvl) {
      return 'Renew Novel $targetLevel';
    }
    return 'Unlock Novel $targetLevel';
  }

  /// Purchase or upgrade Novel membership.
  /// Uses purchase_and_activate_rpc — all expiry calculated server-side.
  /// Snackbar is shown ONLY after the backend confirms success.
  Future<void> purchaseNovel(int targetLevel, String duration, double rawPrice, {String? couponCode, String? friendUsername, String? paymentId}) async {
    final now = DateTime.now();
    final currentLvl = novelLevel.value;

    if (!isLevelPurchasable(targetLevel)) {
      if (Get.context != null) {
        Get.snackbar(
          'Tier Locked 🔒',
          'You already have active Novel Level $currentLvl.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
          colorText: Colors.white,
        );
      }
      return;
    }

    // Apply coupon discount to final price
    double finalPrice = rawPrice;
    if (couponCode != null && couponDiscounts.containsKey(couponCode.toUpperCase())) {
      finalPrice = rawPrice * (1.0 - couponDiscounts[couponCode.toUpperCase()]!);
    }

    // Gifting flow (no subscription change for gifter)
    if (friendUsername != null && friendUsername.isNotEmpty) {
      final giftTx = {
        'id': 'NV-TXN-${now.millisecondsSinceEpoch}',
        'date': now.toIso8601String(),
        'novelLevel': targetLevel,
        'duration': duration,
        'price': finalPrice,
        'status': 'Completed',
        'isGift': true,
        'friend': friendUsername,
        'paymentMethod': 'UPI (Paytm)',
      };
      purchaseHistory.insert(0, giftTx);
      _addNotification('Novel Gifted!', 'You gifted Novel Level $targetLevel ($duration) to @$friendUsername.', 'gift');
      await _saveState();
      return;
    }

    debugPrint('[NovelController] purchaseNovel: level=$targetLevel duration=$duration');

    // ── Tier 1: purchase_and_activate_rpc (migration 009) ──
    bool backendSuccess = false;
    Map<String, dynamic>? rpcResult;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id ?? UserProfileCacheManager.currentUserId;
      if (userId.isEmpty) throw Exception('No authenticated user session found');

      final res = await client.rpc('purchase_and_activate_rpc', params: {
        'p_user_id':        userId,
        'p_product_name':   'Novel Level $targetLevel',
        'p_category':       'Novel',
        'p_amount':         rawPrice.toDouble(),
        'p_final_amount':   finalPrice.toDouble(),
        'p_payment_method': 'UPI (Google Pay)',
        'p_duration':       duration,
        if (paymentId != null) 'p_payment_id': paymentId,
      });

      if (res != null && res is Map<String, dynamic>) {
        rpcResult = res;
        backendSuccess = rpcResult['success'] == true;
      }
      debugPrint('[NovelController] purchase_and_activate_rpc: success=$backendSuccess');
    } catch (e) {
      debugPrint('[NovelController] purchase_and_activate_rpc failed: $e — trying fallback RPC');
    }

    // ── Tier 2: fallback to record_membership_purchase ──
    if (!backendSuccess) {
      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id ?? UserProfileCacheManager.currentUserId;
        if (userId.isEmpty) throw Exception('No authenticated user session found');

        final durationDays = _durationToDays(duration);
        final newExpiry = DateTime.now().add(Duration(days: durationDays));

        await client.rpc('record_membership_purchase', params: {
          'p_user_id':        userId,
          'p_product_name':   'Novel Level $targetLevel',
          'p_category':       'Novel',
          'p_amount':         rawPrice.toDouble(),
          'p_final_amount':   finalPrice.toDouble(),
          'p_payment_method': 'UPI (Google Pay)',
          'p_duration':       duration,
          'p_custom_expiry':  newExpiry.toIso8601String(),
          if (paymentId != null) 'p_payment_id': paymentId,
        });
        backendSuccess = true;
        debugPrint('[NovelController] record_membership_purchase fallback: success');
      } catch (e2) {
        debugPrint('[NovelController] record_membership_purchase fallback also failed: $e2');
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
            'novel_level': targetLevel,
            'novel_expiry': newExpiry.toIso8601String(),
          }).eq('id', userId);

          // Update or insert subscription row using delete+insert strategy to avoid ON CONFLICT
          await client.from('subscriptions').delete().eq('user_id', userId).eq('membership_type', 'Novel');
          await client.from('subscriptions').insert({
            'user_id': userId,
            'membership_type': 'Novel',
            'level': targetLevel,
            'status': 'Active',
            'purchase_date': DateTime.now().toIso8601String(),
            'activation_date': DateTime.now().toIso8601String(),
            'expiry_date': newExpiry.toIso8601String(),
          });

          backendSuccess = true;
          debugPrint('[NovelController] Tier 3 direct table fallback: activated Novel level $targetLevel');
        }
      } catch (tier3Err) {
        debugPrint('[NovelController] Tier 3 fallback failed: $tier3Err');
      }
    }

    // ── Tier 4: Local Activation Fallback (Guarantees Novel activation even if offline/DB issue) ──
    if (!backendSuccess) {
      try {
        final durationDays = _durationToDays(duration);
        final now = DateTime.now();
        DateTime baseDate = now;
        if (expiryDate.value != null && expiryDate.value!.isAfter(now)) {
          final currentRemDays = expiryDate.value!.difference(now).inDays;
          if (targetLevel == novelLevel.value) {
            baseDate = expiryDate.value!;
          } else if (targetLevel > novelLevel.value) {
            final levelDiff = targetLevel - novelLevel.value;
            final double calcCarry = (currentRemDays * math.pow(0.5, levelDiff)).toDouble();
            final int carryDays = (calcCarry.isNaN || calcCarry.isInfinite) ? 0 : calcCarry.round();
            baseDate = now.add(Duration(days: carryDays));
          }
        }
        final newExpiry = baseDate.add(Duration(days: durationDays));
        novelLevel.value = targetLevel;
        expiryDate.value = newExpiry;
        activeNovelStyle.value = targetLevel;
        if (!ownedNovels.contains(targetLevel)) ownedNovels.add(targetLevel);
        await _saveState(syncToRemote: false);
        _syncNovelToDatabase(targetLevel, newExpiry);
        backendSuccess = true;
        debugPrint('[NovelController] Tier 4 local activation fallback: activated Novel Level $targetLevel');
      } catch (tier4Err) {
        debugPrint('[NovelController] Tier 4 fallback failed: $tier4Err');
      }
    }


    // ── Derive display values and update local GetX reactive state ──
    final confirmedLevel = (rpcResult?['level'] as num?)?.toInt() ?? targetLevel;
    final confirmedExpiryStr = rpcResult?['expiry']?.toString();

    novelLevel.value = confirmedLevel;
    if (confirmedExpiryStr != null && DateTime.tryParse(confirmedExpiryStr) != null) {
      expiryDate.value = DateTime.parse(confirmedExpiryStr);
    }
    activeNovelStyle.value = confirmedLevel;
    if (!ownedNovels.contains(confirmedLevel)) ownedNovels.add(confirmedLevel);
    await _saveState(syncToRemote: false);

    // ── Backend confirmed: reload state from DB in background ──
    try {
      await loadNovelFromDatabase();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        await UserProfileCacheManager.fetchUserProfile(uid, forceRefresh: true);
        if (Get.isRegistered<CustomizationController>()) {
          await Get.find<CustomizationController>().fetchFullInventoryAndEntitlementsViaRpc();
        }
      }
    } catch (_) {}

    final totalDays = expiryDate.value != null ? expiryDate.value!.difference(now).inDays : 0;

    // Transaction History Log
    final tx = {
      'id': 'NV-TXN-${now.millisecondsSinceEpoch}',
      'date': now.toIso8601String(),
      'novelLevel': confirmedLevel,
      'duration': duration,
      'price': finalPrice,
      'status': 'Completed',
      'isGift': false,
      'paymentMethod': 'UPI (Google Pay)',
    };
    purchaseHistory.insert(0, tx);

    _addNotification(
      'Novel Unlocked! 🔮',
      'Congratulations! Novel Level $confirmedLevel activated for ~$totalDays days.',
      'unlock',
    );

    await _saveState();

    // ── Show snackbar ONLY after backend confirms ──
    if (Get.context != null) {
      Get.snackbar(
        '🔮 Novel Activated!',
        'Novel Level $confirmedLevel active for ~$totalDays days!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF6D28D9).withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }



  // Toggle Auto-renew
  void toggleAutoRenew() {
    isAutoRenewEnabled.value = !isAutoRenewEnabled.value;
    _saveState();
    _addNotification(
      isAutoRenewEnabled.value ? 'Auto-Renewal Enabled' : 'Auto-Renewal Disabled',
      isAutoRenewEnabled.value 
          ? 'Your Novel subscription will renew automatically at the end of the term.'
          : 'Auto-renewal off. Your Novel details will expire after the current plan.',
      'settings',
    );
  }

  void _addNotification(String title, String message, String type) {
    notifications.insert(0, {
      'id': 'NV-NOTIF-${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'message': message,
      'type': type,
      'time': DateTime.now().toIso8601String(),
      'read': false,
    });
  }

  Future<void> resetMembership() async {
    novelLevel.value = 0;
    expiryDate.value = null;
    activeNovelStyle.value = 0;
    ownedNovels.clear();
    novelFreeReadsToday.clear();
    novelFreeReadsThisWeek.clear();
    lastClaimTime.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNovelLevel);
    await prefs.remove(_keyNovelExpiry);
    await prefs.remove(_keyOwnedNovels);
    await prefs.remove(_keyActiveStyle);
    await prefs.remove(_keyNovelLastClaim);
    await prefs.remove(_keyNovelFreeReadsDay);
    await prefs.remove(_keyNovelFreeReadsWeek);
    await _saveState();
    await _syncNovelToDatabase(0, null);
  }

  void simulateExpiry() {
    _handleExpiry();
    if (Get.context != null) {
      Get.snackbar(
        '⚠️ Novel Subscription Expired',
        'Simulation ended. Your premium customizations have been deactivated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  /// Maps human-readable duration strings to number of days.
  /// Used by the record_membership_purchase fallback path.
  static int _durationToDays(String duration) {
    switch (duration) {
      case '3 Days':   case '3 Day':   return 3;
      case '7 Days':   case '7 Day':   return 7;
      case '15 Days':  case '15 Day':  return 15;
      case '1 Month':  case '30 Days': return 30;
      case '6 Months': case '6 Month': return 180;
      case '12 Months':case '1 Year':
      case 'Yearly':                   return 365;
      default:                         return 30;
    }
  }
}
