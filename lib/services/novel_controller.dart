import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NovelController extends GetxController {
  // SharedPreferences Keys
  static const String _keyNovelLevel = 'novel_level';
  static const String _keyNovelExpiry = 'novel_expiry';
  static const String _keyNovelAutoRenew = 'novel_auto_renew';
  static const String _keyOwnedNovels = 'novel_owned_list';
  static const String _keyActiveStyle = 'novel_active_style';
  static const String _keyNovelHistory = 'novel_purchase_history';
  static const String _keyNovelNotifications = 'novel_notifications';

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
      // Auto expire if time has passed
      if (expiryDate.value != null && DateTime.now().isAfter(expiryDate.value!)) {
        _handleExpiry();
      }
    } else {
      // Seed default Novel 4 expiring in 4 days for simulation
      novelLevel.value = 4;
      expiryDate.value = DateTime.now().add(const Duration(days: 4));
      activeNovelStyle.value = 4;
      ownedNovels.assignAll([1, 2, 3, 4]);
      await _saveState();
    }

    final ownedListStr = prefs.getString(_keyOwnedNovels);
    if (ownedListStr != null) {
      try {
        final decoded = json.decode(ownedListStr) as List<dynamic>;
        ownedNovels.assignAll(decoded.cast<int>());
      } catch (_) {}
    } else if (novelLevel.value > 0) {
      // Fallback
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
  }

  void _handleExpiry() {
    novelLevel.value = 0;
    activeNovelStyle.value = 0;
    ownedNovels.clear();
    expiryDate.value = null;
    _saveState();
  }

  // Swap equipped Novel collection style (Collector system)
  bool switchActiveStyle(int level) {
    if (novelLevel.value <= 0 || expiryDate.value == null) return false;
    if (ownedNovels.contains(level)) {
      activeNovelStyle.value = level;
      _saveState();
      
      Get.snackbar(
        '🎨 Collection Changed',
        'Equipped Novel Level $level Visual Style!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E1B4B).withOpacity(0.9),
        colorText: Colors.white,
      );
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
      case '7 Days': days = 7; break;
      case '15 Days': days = 15; break;
      case '1 Month': days = 30; break;
      case '3 Months': days = 90; break;
      case '6 Months': days = 180; break;
      case '12 Months': days = 365; break;
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

  void simulateExpiry() {
    _handleExpiry();
    Get.snackbar(
      '⚠️ Novel Subscription Expired',
      'Simulation ended. Your premium customizations have been deactivated.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
      colorText: Colors.white,
    );
  }
}
