import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/store_controller.dart';

class NovelController extends GetxController {
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
    _loadState();
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
    } else {
      novelLevel.value = 0;
      activeNovelStyle.value = 0;
      ownedNovels.clear();
      expiryDate.value = null;
      await _saveState();
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

  Future<void> _saveState() async {
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
  }

  void _handleExpiry() {
    novelLevel.value = 0;
    activeNovelStyle.value = 0;
    ownedNovels.clear();
    novelFreeReadsToday.clear();
    novelFreeReadsThisWeek.clear();
    expiryDate.value = null;
    _saveState();
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

  // Purchase Novel Membership
  Future<void> purchaseNovel(int targetLevel, String duration, double rawPrice, {String? couponCode, String? friendUsername}) async {
    final now = DateTime.now();
    int days = 30;
    switch (duration) {
      case '3 Days': days = 3; break;
      case '3 Day': days = 3; break;
      case '7 Days': days = 7; break;
      case '7 Day': days = 7; break;
      case '15 Days': days = 15; break;
      case '15 Day': days = 15; break;
      case '1 Month': days = 30; break;
      case '6 Months': days = 180; break;
      case '6 Month': days = 180; break;
      case '12 Months': days = 365; break;
      case 'Yearly': days = 365; break;
    }

    // Apply Coupon
    double finalPrice = rawPrice;
    if (couponCode != null && couponDiscounts.containsKey(couponCode.toUpperCase())) {
      finalPrice = rawPrice * (1.0 - couponDiscounts[couponCode.toUpperCase()]!);
    }

    if (friendUsername != null && friendUsername.isNotEmpty) {
      // Gift Log
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
      _addNotification('Novel Gifted!', 'You gifted Novel Level $targetLevel ($duration) to @$friendUsername for ₹${finalPrice.toStringAsFixed(0)}.', 'gift');
      await _saveState();
      return;
    }

    // Set level and expiry
    novelLevel.value = targetLevel;
    expiryDate.value = now.add(Duration(days: days));
    
    // Add to owned novels collections
    if (!ownedNovels.contains(targetLevel)) {
      ownedNovels.add(targetLevel);
    }
    // Auto-equip the newly purchased Novel style
    activeNovelStyle.value = targetLevel;

    // Transaction History Log
    final tx = {
      'id': 'NV-TXN-${now.millisecondsSinceEpoch}',
      'date': now.toIso8601String(),
      'novelLevel': targetLevel,
      'duration': duration,
      'price': finalPrice,
      'status': 'Completed',
      'isGift': false,
      'paymentMethod': 'UPI (Google Pay)',
    };
    purchaseHistory.insert(0, tx);

    _addNotification(
      'Novel Unlocked! 🔮',
      'Congratulations! You have unlocked Novel Level $targetLevel ($duration). Explore your luxury customisations.',
      'unlock',
    );

    await _saveState();
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
}
