import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VipController extends GetxController {
  static const String _keyVipLevel = 'vip_level';
  static const String _keyVipExpiry = 'vip_expiry';
  static const String _keyVipAutoRenew = 'vip_auto_renew';
  static const String _keyVipActiveFrame = 'vip_active_frame';

  final RxInt vipLevel = 0.obs;
  final Rxn<DateTime> expiryDate = Rxn<DateTime>();
  final RxBool isAutoRenewEnabled = false.obs;
  final RxString activeFrame = 'Normal'.obs;

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
      // Auto expire if time has passed
      if (expiryDate.value != null && DateTime.now().isAfter(expiryDate.value!)) {
        _handleExpiry();
      }
    } else {
      // Seed default VIP 3 expiring in 5 days for simulation
      vipLevel.value = 3;
      expiryDate.value = DateTime.now().add(const Duration(days: 5));
      activeFrame.value = 'VIP3';
      await _saveState();
    }
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
  }

  void _handleExpiry() {
    vipLevel.value = 0;
    activeFrame.value = 'Normal';
    expiryDate.value = null;
    _saveState();
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
      case '7 Days': days = 7; break;
      case '15 Days': days = 15; break;
      case '1 Month': days = 30; break;
      case '3 Months': days = 90; break;
      case '6 Months': days = 180; break;
      case '12 Months': days = 365; break;
    }

    expiryDate.value = DateTime.now().add(Duration(days: days));
    await _saveState();
    
    Get.snackbar(
      '💎 VIP Activated!',
      'Welcome to VIP Level $level Club for $duration!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
      colorText: Colors.white,
    );
  }

  // Upgrade VIP
  Future<void> upgradeVip(int newLevel, String duration, double price) async {
    await purchaseVip(newLevel, duration, price);
  }

  // Auto-renew Toggle
  void toggleAutoRenew() {
    isAutoRenewEnabled.value = !isAutoRenewEnabled.value;
    _saveState();
    Get.snackbar(
      '⚙️ Subscription Status',
      isAutoRenewEnabled.value ? 'Auto-Renewal Enabled' : 'Auto-Renewal Disabled',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF1F1F23),
      colorText: Colors.white,
    );
  }

  // Developer Simulation tools
  void simulateExpiry() {
    _handleExpiry();
    Get.snackbar(
      '⚠️ VIP Expired',
      'Your VIP membership simulation has ended.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
      colorText: Colors.white,
    );
  }

  // Gifting simulation
  Future<bool> giftVip(String userPhone, int level, String duration) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate server delay
    return true;
  }
}
