import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';
import '../core/theme.dart';
import 'vip_controller.dart';
import 'novel_controller.dart';
import 'customization_controller.dart';

class CoinPack {
  final String id;
  final String name;
  final int coins;
  final int bonusCoins;
  final double price;
  final String? tag; // e.g., 'Popular', 'Best Value', 'Limited Offer'
  final bool isSpecial;

  CoinPack({
    required this.id,
    required this.name,
    required this.coins,
    required this.bonusCoins,
    required this.price,
    this.tag,
    this.isSpecial = false,
  });
}

class StoreOrderItem {
  final String orderId;
  final String name;
  final String category; // 'Coins', 'VIP', 'Novel', 'Frame', etc.
  final double amount;
  final double discount;
  final double gst;
  final double finalAmount;
  final DateTime dateTime;
  final String paymentMethod;
  final String status; // 'Completed', 'Failed', 'Refunded', 'Processing'
  final String duration; // '30 Days', '90 Days', '1 Year', 'One-Time'
  final String? refundStatus; // 'Requested', 'Approved', 'Rejected', null
  final String? couponApplied;

  StoreOrderItem({
    required this.orderId,
    required this.name,
    required this.category,
    required this.amount,
    required this.discount,
    required this.gst,
    required this.finalAmount,
    required this.dateTime,
    required this.paymentMethod,
    required this.status,
    required this.duration,
    this.refundStatus,
    this.couponApplied,
  });
}

class CoinTransaction {
  final String type; // 'Purchased', 'Used', 'Received', 'Gifted', 'Refunded'
  final int amount;
  final String description;
  final DateTime dateTime;

  CoinTransaction({
    required this.type,
    required this.amount,
    required this.description,
    required this.dateTime,
  });
}

class LuckyDrawReward {
  final String name;
  final String icon;
  final Color color;
  final String rewardType; // 'Coins', 'VIP', 'Novel', 'Frame', 'Coupon'
  final int value; // e.g. 50 coins, 3 days VIP

  LuckyDrawReward({
    required this.name,
    required this.icon,
    required this.color,
    required this.rewardType,
    required this.value,
  });
}

class StoreController extends GetxController {
  static StoreController get to => Get.find<StoreController>();

  final RxInt coinsBalance = 1500.obs;
  final RxInt silverCoinsBalance = 350000.obs; // seed enough silver to test
  final RxInt diamondsBalance = 1200.obs; // seed enough diamonds to test
  final RxDouble availableIncomeBalance = 250.00.obs;
  
  // Lists and Histories
  final RxList<StoreOrderItem> orderHistory = <StoreOrderItem>[].obs;
  final RxList<CoinTransaction> coinTransactions = <CoinTransaction>[].obs;
  final RxList<Map<String, dynamic>> luckySpinHistory = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> giftHistory = <Map<String, dynamic>>[].obs;

  // Coupon Database & Active Coupon State
  final RxMap<String, double> couponCodes = <String, double>{
    'FESTIVAL50': 0.50, // 50% discount
    'CREATOR10': 0.10,  // 10% discount
    'STUDENT20': 0.20,  // 20% discount
    'OFFICIAL30': 0.30, // 30% discount
    'VIPEXCLUSIVE': 0.15, // 15% discount
  }.obs;
  
  final RxString activeCouponCode = ''.obs;
  final RxDouble activeCouponDiscount = 0.0.obs;

  // Daily Deals State
  final RxString dailyDealItem = 'Ice Dragon Avatar Frame'.obs;
  final RxDouble dailyDealOriginalPrice = 500.0.obs;
  final RxDouble dailyDealDiscountedPrice = 199.0.obs;
  final RxInt dailyDealStockRemaining = 7.obs;
  final RxInt dailyDealTimeSeconds = (4 * 3600 + 15 * 60 + 30).obs; // 4h 15m 30s
  Timer? _dealTimer;

  // Lucky Draw Wheel Rewards
  final List<LuckyDrawReward> wheelRewards = [
    LuckyDrawReward(name: '50 Coins', icon: '🪙', color: const Color(0xFFFFD700), rewardType: 'Coins', value: 50),
    LuckyDrawReward(name: '3 Days VIP', icon: '👑', color: const Color(0xFF3B82F6), rewardType: 'VIP', value: 3),
    LuckyDrawReward(name: '7 Days Novel', icon: '📖', color: const Color(0xFFEF4444), rewardType: 'Novel', value: 7),
    LuckyDrawReward(name: 'Mystic Flame Frame', icon: '🖼️', color: const Color(0xFFA855F7), rewardType: 'Frame', value: 0),
    LuckyDrawReward(name: '200 Coins', icon: '🪙', color: const Color(0xFFFFA500), rewardType: 'Coins', value: 200),
    LuckyDrawReward(name: '15% Off Coupon', icon: '🏷️', color: const Color(0xFF10B981), rewardType: 'Coupon', value: 15),
    LuckyDrawReward(name: '1 Day VIP', icon: '👑', color: const Color(0xFF60A5FA), rewardType: 'VIP', value: 1),
    LuckyDrawReward(name: 'Super Aurora Effect', icon: '⚡', color: const Color(0xFFEC4899), rewardType: 'Effect', value: 0),
  ];

  // Admin Configuration & Controls
  final RxDouble priceModifier = 1.0.obs; // 1.0 = standard, 0.8 = 20% store-wide sale
  final RxBool isFlashSaleActive = false.obs;
  final RxDouble flashSaleDiscount = 0.35.obs; // 35% off
  final RxList<String> disabledProducts = <String>[].obs;
  final RxDouble totalRevenue = 143890.0.obs;
  final RxInt totalSalesCount = 824.obs;

  // Standard Coin Packs
  final List<CoinPack> coinPacks = [
    CoinPack(id: 'coins_starter', name: 'Starter Pack', coins: 50, bonusCoins: 0, price: 100, tag: 'Limited Offer'),
    CoinPack(id: 'coins_basic', name: 'Basic Pack', coins: 100, bonusCoins: 1, price: 200),
    CoinPack(id: 'coins_silver', name: 'Silver Pack', coins: 250, bonusCoins: 5, price: 500, tag: 'Popular'),
    CoinPack(id: 'coins_gold', name: 'Gold Pack', coins: 500, bonusCoins: 15, price: 1000),
    CoinPack(id: 'coins_diamond', name: 'Diamond Pack', coins: 2500, bonusCoins: 100, price: 5000, tag: 'Best Value'),
    CoinPack(id: 'coins_elite', name: 'Elite Pack', coins: 5000, bonusCoins: 225, price: 10000),
    CoinPack(id: 'coins_legend', name: 'Legend Pack', coins: 10000, bonusCoins: 480, price: 20000, tag: 'Limited Offer', isSpecial: true),
    CoinPack(id: 'coins_royal', name: 'Royal Pack', coins: 50000, bonusCoins: 2500, price: 100000, tag: 'Crown Value', isSpecial: true),
  ];

  @override
  void onInit() {
    super.onInit();
    _loadData();
    _startDailyDealsTimer();
    _seedMockHistory();
  }

  @override
  void onClose() {
    _dealTimer?.cancel();
    super.onClose();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    coinsBalance.value = prefs.getInt('store_coins_balance') ?? 2500;
    silverCoinsBalance.value = prefs.getInt('store_silver_balance') ?? 350000;
    diamondsBalance.value = prefs.getInt('store_diamonds_balance') ?? 1200;
    availableIncomeBalance.value = prefs.getDouble('store_income_balance') ?? 250.00;
  }

  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('store_coins_balance', coinsBalance.value);
    await prefs.setInt('store_silver_balance', silverCoinsBalance.value);
    await prefs.setInt('store_diamonds_balance', diamondsBalance.value);
    await prefs.setDouble('store_income_balance', availableIncomeBalance.value);
  }

  void _startDailyDealsTimer() {
    _dealTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (dailyDealTimeSeconds.value > 0) {
        dailyDealTimeSeconds.value--;
      } else {
        // Reset timer and randomize item
        dailyDealTimeSeconds.value = 24 * 3600; // 24 hours
        _randomizeDailyDeal();
      }
    });
  }

  void _randomizeDailyDeal() {
    final items = [
      'Celestial Phoenix Frame',
      'Cyberpunk Glowing Border',
      'Sakura Entrance Portal Effect',
      'VIP Golden Crown Seat',
      'Galaxy Wings Aura Decor',
      'Neon Echo Voice Effect'
    ];
    dailyDealItem.value = items[Random().nextInt(items.length)];
    dailyDealStockRemaining.value = Random().nextInt(15) + 3;
    dailyDealOriginalPrice.value = (Random().nextInt(6) + 3) * 100.0;
    dailyDealDiscountedPrice.value = dailyDealOriginalPrice.value * 0.40; // 60% off
  }

  void _seedMockHistory() {
    orderHistory.addAll([
      StoreOrderItem(
        orderId: 'AGX-98317-IND',
        name: 'Gold Pack (1,000 Coins)',
        category: 'Coins',
        amount: 799.0,
        discount: 0.0,
        gst: 143.82,
        finalAmount: 942.82,
        dateTime: DateTime.now().subtract(const Duration(days: 4, hours: 2)),
        paymentMethod: 'UPI (PhonePe)',
        status: 'Completed',
        duration: 'One-Time',
      ),
      StoreOrderItem(
        orderId: 'AGX-72541-VIP',
        name: 'VIP 5 Membership Upgrade',
        category: 'VIP',
        amount: 1999.0,
        discount: 399.80,
        gst: 287.82,
        finalAmount: 1887.02,
        dateTime: DateTime.now().subtract(const Duration(days: 12, hours: 5)),
        paymentMethod: 'Credit Card',
        status: 'Completed',
        duration: '30 Days',
        couponApplied: 'STUDENT20',
      ),
      StoreOrderItem(
        orderId: 'AGX-61102-NOV',
        name: 'Novel Level 3 Collectible',
        category: 'Novel',
        amount: 2999.0,
        discount: 1499.50,
        gst: 269.91,
        finalAmount: 1769.41,
        dateTime: DateTime.now().subtract(const Duration(days: 28)),
        paymentMethod: 'Google Pay',
        status: 'Refunded',
        duration: '90 Days',
        refundStatus: 'Approved',
        couponApplied: 'FESTIVAL50',
      )
    ]);

    coinTransactions.addAll([
      CoinTransaction(type: 'Purchased', amount: 1120, description: 'Gold Pack Purchase', dateTime: DateTime.now().subtract(const Duration(days: 4))),
      CoinTransaction(type: 'Used', amount: 300, description: 'Unlocked Nebula Chat Bubble', dateTime: DateTime.now().subtract(const Duration(days: 3))),
      CoinTransaction(type: 'Gifted', amount: 150, description: 'Gifted to @amit_kumar', dateTime: DateTime.now().subtract(const Duration(days: 2))),
      CoinTransaction(type: 'Received', amount: 500, description: 'Received gift from @moderator_roy', dateTime: DateTime.now().subtract(const Duration(days: 1))),
    ]);
  }

  // Coupon Operations
  bool applyCoupon(String code) {
    final cleanCode = code.toUpperCase().trim();
    if (couponCodes.containsKey(cleanCode)) {
      activeCouponCode.value = cleanCode;
      activeCouponDiscount.value = couponCodes[cleanCode]!;
      return true;
    }
    return false;
  }

  void removeCoupon() {
    activeCouponCode.value = '';
    activeCouponDiscount.value = 0.0;
  }

  // Coin Purchase / Gifting Operations
  void addCoins(int amount, String description) {
    coinsBalance.value += amount;
    coinTransactions.insert(0, CoinTransaction(
      type: 'Purchased',
      amount: amount,
      description: description,
      dateTime: DateTime.now(),
    ));
    _saveData();
  }

  void addReceivedCoins(int amount, String description) {
    coinsBalance.value += amount;
    coinTransactions.insert(0, CoinTransaction(
      type: 'Received',
      amount: amount,
      description: description,
      dateTime: DateTime.now(),
    ));
    _saveData();
  }

  bool deductCoins(int amount, String description) {
    if (coinsBalance.value >= amount) {
      coinsBalance.value -= amount;
      coinTransactions.insert(0, CoinTransaction(
        type: 'Used',
        amount: amount,
        description: description,
        dateTime: DateTime.now(),
      ));
      _saveData();
      return true;
    }
    return false;
  }

  // --- CURRENCY EXCHANGE DISABLED ---

  // --- GIFT CONVERSION ---
  
  // Whenever user receives Gold Gifts, Diamonds are automatically generated (100 Gold Gift = 7 Diamonds)
  void convertGoldGiftToDiamonds(int goldGiftAmount, String sender) {
    if (goldGiftAmount <= 0) return;
    int generatedDiamonds = (goldGiftAmount * 7) ~/ 100;
    
    diamondsBalance.value += generatedDiamonds;
    
    double rupeesAdded = generatedDiamonds.toDouble();
    availableIncomeBalance.value += rupeesAdded;
    
    giftHistory.insert(0, {
      'orderId': 'GFT-${Random().nextInt(90000) + 10000}-REC',
      'item': '$goldGiftAmount Gold Gift',
      'sender': sender,
      'diamonds': generatedDiamonds,
      'date': DateTime.now().toString(),
    });
    
    _saveData();
  }

  // --- WITHDRAWAL SYSTEM ---
  
  // Only Diamonds can be withdrawn. Minimum 1000 Diamonds.
  bool requestDiamondWithdrawal(int diamondAmount, String paymentMethod, String accountInfo) {
    if (diamondAmount < 1000) {
      Get.snackbar('Withdrawal Error ⚠️', 'Minimum withdrawal is 1000 Diamonds.', backgroundColor: const Color(0xFFEF4444), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (diamondsBalance.value >= diamondAmount) {
      diamondsBalance.value -= diamondAmount;
      double rupeesWithdrawn = diamondAmount.toDouble();
      
      availableIncomeBalance.value -= rupeesWithdrawn;
      
      final orderId = 'WD-${Random().nextInt(90000) + 10000}-PAY';
      orderHistory.insert(0, StoreOrderItem(
        orderId: orderId,
        name: 'Withdrawal of $diamondAmount Diamonds',
        category: 'Withdrawal',
        amount: rupeesWithdrawn,
        discount: 0,
        gst: 0,
        finalAmount: rupeesWithdrawn,
        dateTime: DateTime.now(),
        paymentMethod: paymentMethod,
        status: 'Completed',
        duration: 'One-Time',
      ));
      
      _saveData();
      return true;
    } else {
      Get.snackbar('Withdrawal Error ⚠️', 'Insufficient Diamonds balance.', backgroundColor: const Color(0xFFEF4444), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  // ₹100 = 50 Gold Coins
  void rechargeGoldCoins(double inrAmount, String paymentId) async {
    if (inrAmount <= 0) return;
    int coinsAdded = (inrAmount * 0.50).round();
    
    coinsBalance.value += coinsAdded;
    
    final orderId = 'RCG-${Random().nextInt(90000) + 10000}-PAY';
    orderHistory.insert(0, StoreOrderItem(
      orderId: orderId,
      name: 'Recharge $coinsAdded Coins',
      category: 'Coins',
      amount: inrAmount,
      discount: 0,
      gst: 0,
      finalAmount: inrAmount,
      dateTime: DateTime.now(),
      paymentMethod: 'UPI (Razorpay ID: $paymentId)',
      status: 'Completed',
      duration: 'One-Time',
    ));
    
    coinTransactions.insert(0, CoinTransaction(
      type: 'Purchased',
      amount: coinsAdded,
      description: 'Recharged ₹${inrAmount.toStringAsFixed(2)}',
      dateTime: DateTime.now(),
    ));

    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        await client.from('wallet_transactions').insert({
          'wallet_id': client.auth.currentUser!.id,
          'amount': inrAmount,
          'currency': 'INR',
          'type': 'Deposit',
          'status': 'Completed',
          'reference_id': paymentId,
          'details': 'Recharged $coinsAdded Coins',
        });
      }
    } catch (_) {}
    
    _saveData();
  }

  // Place Order / Mock Payments
  Future<bool> processPurchaseOrder({
    required String name,
    required String category,
    required double basePrice,
    required String duration,
    required String paymentMethod,
    bool giftToFriend = false,
    String? friendUsername,
    String? giftMessage,
    bool anonymous = false,
    DateTime? scheduledDate,
    String purchaseMethod = 'INR',
  }) async {
    if (category == 'Coins' && purchaseMethod == 'Gold') {
      Get.snackbar(
        'Purchase Failed ⚠️',
        'Coins cannot be purchased using other coins.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    await Future.delayed(const Duration(milliseconds: 1800)); // simulation latency

    final orderId = 'AGX-${Random().nextInt(90000) + 10000}-${category.toUpperCase().substring(0, min(3, category.length))}';
    final discount = basePrice * activeCouponDiscount.value + (isFlashSaleActive.value ? basePrice * flashSaleDiscount.value : 0.0);
    final finalBase = basePrice - discount;
    
    // In our new pricing system, displayed price is final (inclusive of taxes). GST is 0 in display breakdown.
    final finalAmount = finalBase;

    if (purchaseMethod == 'Gold') {
      // Proportional conversion: ₹100 = 50 Gold Coins.
      // So GoldPrice = INRPrice * 0.50
      int goldPrice = (finalAmount * 0.50).round();
      if (coinsBalance.value < goldPrice) {
        Get.snackbar(
          'Purchase Failed ⚠️',
          'Insufficient Gold Coins balance.',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      
      // Deduct coins
      coinsBalance.value -= goldPrice;
      
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentUser != null) {
          await client.from('wallet_transactions').insert({
            'wallet_id': client.auth.currentUser!.id,
            'amount': goldPrice.toDouble(),
            'currency': 'Coins',
            'type': 'Payout',
            'status': 'Completed',
            'details': 'Purchased $name',
          });

          await client.from('purchase_history').insert({
            'user_id': client.auth.currentUser!.id,
            'item_id': name,
            'item_type': category,
            'price': goldPrice.toDouble(),
            'currency': 'Coins',
            'duration': duration,
          });
        }
      } catch (_) {}

      coinTransactions.insert(0, CoinTransaction(
        type: 'Used',
        amount: goldPrice,
        description: 'Purchased $name',
        dateTime: DateTime.now(),
      ));
      _saveData();
    }

    final newOrder = StoreOrderItem(
      orderId: orderId,
      name: name,
      category: category,
      amount: purchaseMethod == 'Gold' ? (basePrice * 0.50).roundToDouble() : basePrice,
      discount: purchaseMethod == 'Gold' ? (discount * 0.50).roundToDouble() : discount,
      gst: 0.0, // Taxes are already included, hidden from breakdown
      finalAmount: purchaseMethod == 'Gold' ? (finalAmount * 0.50).roundToDouble() : finalAmount,
      dateTime: DateTime.now(),
      paymentMethod: purchaseMethod == 'Gold' ? 'Gold Coins Wallet' : paymentMethod,
      status: 'Completed',
      duration: duration,
      couponApplied: activeCouponCode.isNotEmpty ? activeCouponCode.value : null,
    );

    orderHistory.insert(0, newOrder);

    // Update Stats for Admin Panel
    if (purchaseMethod == 'INR') {
      totalRevenue.value += finalAmount;
      
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentUser != null) {
          await client.from('purchase_history').insert({
            'user_id': client.auth.currentUser!.id,
            'item_id': name,
            'item_type': category,
            'price': finalAmount,
            'currency': 'INR',
            'duration': duration,
          });
        }
      } catch (_) {}
    }
    totalSalesCount.value++;

    if (giftToFriend && friendUsername != null) {
      giftHistory.insert(0, {
        'orderId': orderId,
        'item': name,
        'recipient': friendUsername,
        'message': giftMessage ?? 'Enjoy your gift!',
        'anonymous': anonymous,
        'scheduled': scheduledDate != null ? scheduledDate.toString() : 'Immediate',
        'date': DateTime.now().toString(),
      });
      Get.snackbar(
        'Gift Sent Successfully! 🎁',
        anonymous ? 'Your anonymous gift was delivered.' : 'Gift sent to @$friendUsername.',
        backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      // Apply locally to active user
      if (category == 'VIP') {
        final vipLvl = int.tryParse(name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        final vipCtrl = Get.find<VipController>();
        vipCtrl.vipLevel.value = vipLvl;
        vipCtrl.activeFrame.value = 'VIP$vipLvl';
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
          case 'Yearly': days = 365; break;
        }
        vipCtrl.expiryDate.value = DateTime.now().add(Duration(days: days));
        vipCtrl.isAutoRenewEnabled.value = true;
      } else if (category == 'Novel') {
        final novelLvl = int.tryParse(name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        final novelCtrl = Get.find<NovelController>();
        novelCtrl.novelLevel.value = novelLvl;
        if (!novelCtrl.ownedNovels.contains(novelLvl)) {
          novelCtrl.ownedNovels.add(novelLvl);
        }
        novelCtrl.activeNovelStyle.value = novelLvl;
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
          case 'Yearly': days = 365; break;
        }
        novelCtrl.expiryDate.value = DateTime.now().add(Duration(days: days));
      } else if (category == 'Coins') {
        final coinMatch = RegExp(r'(\d+,?\d*) Coins').firstMatch(name);
        if (coinMatch != null) {
          final amt = int.parse(coinMatch.group(1)!.replaceAll(',', ''));
          addCoins(amt, 'Pack Purchase: $name');
        }
      } else if (category == 'Frame') {
        final cust = Get.find<CustomizationController>();
        cust.itemExpiries[name] = DateTime.now().add(const Duration(days: 30));
        cust.unlockedItems.add(name);
        cust.activeFrame.value = name;
      }
    }

    removeCoupon(); // Clear active coupon after purchase
    return true;
  }

  // Lucky Draw spin simulation
  int performLuckySpin() {
    final rewardIdx = Random().nextInt(wheelRewards.length);
    final reward = wheelRewards[rewardIdx];

    luckySpinHistory.insert(0, {
      'reward': reward.name,
      'icon': reward.icon,
      'date': DateTime.now().toString(),
    });

    if (reward.rewardType == 'Coins') {
      addCoins(reward.value, 'Lucky Spin Reward: ${reward.name}');
    } else if (reward.rewardType == 'VIP') {
      final vipCtrl = Get.find<VipController>();
      if (vipCtrl.vipLevel.value <= 0) vipCtrl.vipLevel.value = 1;
      final currentExpiry = vipCtrl.expiryDate.value ?? DateTime.now();
      vipCtrl.expiryDate.value = currentExpiry.add(Duration(days: reward.value));
    } else if (reward.rewardType == 'Novel') {
      final novelCtrl = Get.find<NovelController>();
      if (novelCtrl.novelLevel.value <= 0) novelCtrl.novelLevel.value = 1;
      final currentExpiry = novelCtrl.expiryDate.value ?? DateTime.now();
      novelCtrl.expiryDate.value = currentExpiry.add(Duration(days: reward.value));
    } else if (reward.rewardType == 'Frame') {
      final cust = Get.find<CustomizationController>();
      cust.itemExpiries[reward.name] = DateTime.now().add(const Duration(days: 7));
      cust.unlockedItems.add(reward.name);
      cust.activeFrame.value = reward.name;
    }

    return rewardIdx;
  }

  // Request Refund logic
  void requestRefund(String orderId) {
    final idx = orderHistory.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      final old = orderHistory[idx];
      orderHistory[idx] = StoreOrderItem(
        orderId: old.orderId,
        name: old.name,
        category: old.category,
        amount: old.amount,
        discount: old.discount,
        gst: old.gst,
        finalAmount: old.finalAmount,
        dateTime: old.dateTime,
        paymentMethod: old.paymentMethod,
        status: 'Refunded',
        duration: old.duration,
        refundStatus: 'Approved',
        couponApplied: old.couponApplied,
      );

      if (old.category == 'Coins') {
        final coinMatch = RegExp(r'(\d+,?\d*) Coins').firstMatch(old.name);
        if (coinMatch != null) {
          final amt = int.parse(coinMatch.group(1)!.replaceAll(',', ''));
          deductCoins(amt, 'Refund processed for ${old.orderId}');
        }
      }
      
      Get.snackbar(
        'Refund Approved! 💸',
        'Refund of ₹${old.finalAmount.toStringAsFixed(2)} was sent back to ${old.paymentMethod}.',
        backgroundColor: Colors.green.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Admin Config Updates
  void setPriceModifier(double value) {
    priceModifier.value = value;
  }

  void toggleFlashSale(bool active) {
    isFlashSaleActive.value = active;
  }

  void disableProduct(String prodName) {
    if (!disabledProducts.contains(prodName)) {
      disabledProducts.add(prodName);
    }
  }

  void enableProduct(String prodName) {
    disabledProducts.remove(prodName);
  }
}
