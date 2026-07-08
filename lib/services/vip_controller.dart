import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/store_controller.dart';

class VipController extends GetxController {
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
    _loadState();
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
    } else {
      vipLevel.value = 0;
      activeFrame.value = 'Normal';
      expiryDate.value = null;
      await _saveState();
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

  Future<void> _saveState() async {
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
  }

  void _handleExpiry() {
    vipLevel.value = 0;
    activeFrame.value = 'Normal';
    expiryDate.value = null;
    vipFreeReadsToday.clear();
    vipFreeReadsThisWeek.clear();
    _saveState();
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

  // Purchase VIP Membership
  Future<void> purchaseVip(int level, String duration, double price) async {
    vipLevel.value = level;
    activeFrame.value = 'VIP$level';
    
    int days = 3;
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

    expiryDate.value = DateTime.now().add(Duration(days: days));
    await _saveState();
    
    if (Get.context != null) {
      Get.snackbar(
        '💎 VIP Activated!',
        'Welcome to VIP Level $level Club for $duration!',
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
}
