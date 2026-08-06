import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../user/user_progress_sync_service.dart';
import '../user/user_profile_cache_manager.dart';
import '../storage/fcm_notification_service.dart';
import 'dart:math';
import 'dart:async';
import '../../core/theme.dart';
import '../memberships/vip_controller.dart';
import '../memberships/novel_controller.dart';
import '../user/customization_controller.dart';

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

class StoreController extends GetxController with WidgetsBindingObserver {
  static StoreController get to => Get.find<StoreController>();

  final RxInt coinsBalance = 0.obs;
  final RxInt silverCoinsBalance = 0.obs;
  final RxInt diamondsBalance = 0.obs;
  final RxDouble availableIncomeBalance = 0.00.obs;
  
  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _syncDebounceDuration = Duration(milliseconds: 500);

  // Lists and Histories
  final RxList<StoreOrderItem> orderHistory = <StoreOrderItem>[].obs;
  final RxList<CoinTransaction> coinTransactions = <CoinTransaction>[].obs;
  final RxList<Map<String, dynamic>> luckySpinHistory = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> giftHistory = <Map<String, dynamic>>[].obs;

  // Coupon Database & Active Coupon State
  final RxMap<String, double> couponCodes = <String, double>{
    'FESTIVAL50': 0.50,
    'CREATOR10': 0.10,
    'STUDENT20': 0.20,
    'OFFICIAL30': 0.30,
    'VIPEXCLUSIVE': 0.15,
  }.obs;
  
  final RxString activeCouponCode = ''.obs;
  final RxDouble activeCouponDiscount = 0.0.obs;

  // Daily Deals State
  final RxString dailyDealItem = 'Ice Dragon Avatar Frame'.obs;
  final RxDouble dailyDealOriginalPrice = 500.0.obs;
  final RxDouble dailyDealDiscountedPrice = 199.0.obs;
  final RxInt dailyDealStockRemaining = 7.obs;
  final RxInt dailyDealTimeSeconds = (4 * 3600 + 15 * 60 + 30).obs;
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
  final RxDouble priceModifier = 1.0.obs;
  final RxBool isFlashSaleActive = false.obs;
  final RxDouble flashSaleDiscount = 0.35.obs;
  final RxList<String> disabledProducts = <String>[].obs;
  final RxDouble totalRevenue = 0.0.obs;
  final RxInt totalSalesCount = 0.obs;

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
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    syncWithDatabase(force: true);
    _startDailyDealsTimer();

    // Auto-save local display cache whenever balances change
    ever(coinsBalance, (_) => _saveDataLocalOnly());
    ever(silverCoinsBalance, (_) => _saveDataLocalOnly());
    ever(diamondsBalance, (_) => _saveDataLocalOnly());
    ever(availableIncomeBalance, (_) => _saveDataLocalOnly());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncWithDatabase(force: true);
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _dealTimer?.cancel();
    super.onClose();
  }

  /// Server-authoritative fetch for wallet balance from Supabase database
  Future<void> syncWithDatabase({bool force = false}) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastSyncTime) < _syncDebounceDuration) return;
    _lastSyncTime = now;

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      
      final canonicalId = await UserProfileCacheManager.getOrFetchCanonicalId();
      if (canonicalId.isEmpty) return;

      final walletData = await Supabase.instance.client
          .from('wallets')
          .select('coins_balance, gold_coins, silver_coins, withdrawable_balance')
          .eq('id', canonicalId)
          .maybeSingle();

      if (walletData != null) {
        final int fetchedCoins = (walletData['coins_balance'] ?? walletData['gold_coins'] ?? 0) as int;
        final int fetchedSilver = (walletData['silver_coins'] ?? 0) as int;
        final double fetchedIncome = ((walletData['withdrawable_balance'] ?? 0.0) as num).toDouble();

        coinsBalance.value = fetchedCoins;
        silverCoinsBalance.value = fetchedSilver;
        availableIncomeBalance.value = fetchedIncome;
        await _saveDataLocalOnly();
      }
    } catch (e) {
      debugPrint('[StoreController] Balance sync error: $e');
    }
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    coinsBalance.value = prefs.getInt('store_coins_balance') ?? 0;
    silverCoinsBalance.value = prefs.getInt('store_silver_balance') ?? 0;
    diamondsBalance.value = prefs.getInt('store_diamonds_balance') ?? 0;
    availableIncomeBalance.value = prefs.getDouble('store_income_balance') ?? 0.00;
  }

  Future<void> _saveDataLocalOnly() async {
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
    // Left empty for production backend loads
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
    debugPrint('[StoreController] Requesting server balance sync after addCoins ($description)');
    syncWithDatabase(force: true);
  }

  void addReceivedCoins(int amount, String description) {
    coinsBalance.value += amount;
    coinTransactions.insert(0, CoinTransaction(
      type: 'Received',
      amount: amount,
      description: description,
      dateTime: DateTime.now(),
    ));
    _saveDataLocalOnly();
    debugPrint('[StoreController] Requesting server balance sync after addReceivedCoins ($description)');
    syncWithDatabase(force: true);
  }

  bool deductCoins(int amount, String description) {
    if (coinsBalance.value >= amount) {
      coinTransactions.insert(0, CoinTransaction(
        type: 'Used',
        amount: amount,
        description: description,
        dateTime: DateTime.now(),
      ));
      _saveDataLocalOnly();
      syncWithDatabase(force: true);
      return true;
    }
    return false;
  }

  /// Rule 7 & Rule 9 & Rule 20: Atomic and Idempotent Store Purchase RPC
  Future<bool> buyStoreItemViaRpc({
    required String itemId,
    required String itemName,
    required String category,
    required int coinPrice,
  }) async {
    try {
      final String txId = 'tx_store_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
      final String sessionId = UserProfileCacheManager.currentSessionId;

      final res = await Supabase.instance.client.rpc('buy_store_item', params: {
        'p_item_id': itemId,
        'p_item_name': itemName,
        'p_category': category,
        'p_coin_price': coinPrice,
        'p_session_id': sessionId,
        'p_transaction_id': txId,
      });

      if (res != null && res['success'] == true) {
        if (res['remaining_coins'] != null) {
          coinsBalance.value = (res['remaining_coins'] as num).toInt();
        }
        await syncWithDatabase(force: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[StoreController] buyStoreItemViaRpc error: $e');
      Get.snackbar(
        'Purchase Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }
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
    
    _saveDataLocalOnly();
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
      
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentUser != null) {
          client.from('wallet_transactions').insert({
            'wallet_id': UserProfileCacheManager.currentUserId,
            'amount': rupeesWithdrawn,
            'currency': 'INR',
            'type': 'Withdrawal',
            'status': 'Completed',
            'reference_id': orderId,
            'details': 'Withdrawal of $diamondAmount Diamonds',
          }).then((_) {}).catchError((_) {});
        }
      } catch (_) {}

      _saveDataLocalOnly();
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
    
    syncWithDatabase(force: true);
    
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
          'wallet_id': UserProfileCacheManager.currentUserId,
          'amount': inrAmount,
          'currency': 'INR',
          'type': 'Recharge',
          'status': 'Completed',
          'reference_id': paymentId,
          'details': 'Recharged $coinsAdded Coins',
        });
      }
    } catch (_) {}
    
    _saveDataLocalOnly();
  }

  // Place Order / Gold Coins Payments
  Future<Map<String, dynamic>> processPurchaseOrder({
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
    if (purchaseMethod != 'Gold') {
      Get.snackbar(
        'Purchase Failed ⚠️',
        'Real-money purchases must proceed via Razorpay Secure Gateway.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return {'success': false, 'error': 'Real-money purchases must proceed via Razorpay Secure Gateway.'};
    }

    if (category == 'Coins') {
      Get.snackbar(
        'Purchase Failed ⚠️',
        'Coins cannot be purchased using other coins.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return {'success': false, 'error': 'Coins cannot be purchased using other coins.'};
    }

    final discount = basePrice * activeCouponDiscount.value + (isFlashSaleActive.value ? basePrice * flashSaleDiscount.value : 0.0);
    final finalAmount = basePrice - discount;

    // Proportional conversion: ₹100 = 50 Gold Coins.
    int goldPrice = (finalAmount * 0.50).round();
    if (coinsBalance.value < goldPrice) {
      Get.snackbar(
        'Purchase Failed ⚠️',
        'Insufficient Gold Coins balance.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return {'success': false, 'error': 'Insufficient Gold Coins balance.'};
    }

    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        // Execute atomic purchase and balance check on database
        final response = await client.rpc('purchase_item_with_coins_rpc', params: {
          'p_user_id': uid,
          'p_item_name': name,
          'p_item_type': category,
          'p_coin_amount': goldPrice,
          'p_duration': duration,
        });

        if (response != true) {
          throw Exception('Database purchase function returned false');
        }
      } else {
        throw Exception('No authenticated user session found');
      }
    } catch (e) {
      debugPrint('[StoreController] purchase_item_with_coins_rpc failed: $e');
      if (e.toString().contains('Insufficient')) {
        Get.snackbar(
          'Purchase Failed ⚠️',
          'Insufficient Gold Coins balance.',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return {'success': false, 'error': 'Insufficient Gold Coins balance.'};
      }

      // Resilient local fallback if RPC fails on unmigrated remote database
      try {
        if (coinsBalance.value >= goldPrice) {
          debugPrint('[StoreController] Executing local fallback for coin purchase: $name ($category)');
          if (category == 'VIP') {
            final match = RegExp(r'(\d+)').firstMatch(name);
            final lvl = match != null ? (int.tryParse(match.group(1)!) ?? 1) : 1;
            await Get.find<VipController>().purchaseVip(lvl, duration, goldPrice.toDouble(), paymentMethod: 'Gold Coins');
          } else if (category == 'Novel') {
            final match = RegExp(r'(\d+)').firstMatch(name);
            final lvl = match != null ? (int.tryParse(match.group(1)!) ?? 1) : 1;
            await Get.find<NovelController>().purchaseNovel(lvl, duration, goldPrice.toDouble(), paymentId: 'coin_pay_${DateTime.now().millisecondsSinceEpoch}');
          } else {
            // Cosmetic or Frame fallback purchase
            final uid = Supabase.instance.client.auth.currentUser?.id;
            if (uid != null) {
              await Supabase.instance.client.from('user_customizations').delete().eq('user_id', uid).eq('type', category).eq('name', name);
              await Supabase.instance.client.from('user_customizations').insert({
                'user_id': uid,
                'type': category == 'Frame' ? 'Avatar Frame' : category,
                'name': name,
                'is_equipped': false,
              });
              if (Get.isRegistered<CustomizationController>()) {
                Get.find<CustomizationController>().unlockedItems.add(name);
              }
            }
          }

          await syncWithDatabase(force: true);
          return {'success': true, 'error': null};
        }
      } catch (fallbackErr) {
        debugPrint('[StoreController] Local fallback error: $fallbackErr');
      }

      Get.snackbar(
        'Purchase Failed ⚠️',
        'Purchase failed. Please try again.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return {'success': false, 'error': 'Purchase failed. Please try again.'};
    }

    // Sync authoritative balance from server database
    await syncWithDatabase(force: true);

    // Log transaction locally
    coinTransactions.insert(0, CoinTransaction(
      type: 'Used',
      amount: goldPrice,
      description: 'Purchased $name',
      dateTime: DateTime.now(),
    ));

    final orderId = 'AGX-${Random().nextInt(90000) + 10000}-${category.toUpperCase().substring(0, min(3, category.length))}';
    final newOrder = StoreOrderItem(
      orderId: orderId,
      name: name,
      category: category,
      amount: goldPrice.toDouble(),
      discount: (discount * 0.50).roundToDouble(),
      gst: 0.0,
      finalAmount: goldPrice.toDouble(),
      dateTime: DateTime.now(),
      paymentMethod: 'Gold Coins Wallet',
      status: 'Completed',
      duration: duration,
      couponApplied: activeCouponCode.isNotEmpty ? activeCouponCode.value : null,
    );

    orderHistory.insert(0, newOrder);
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
      if (category == 'VIP' || category == 'Novel') {
        // Gold Coins purchase: delegate to VipController / NovelController
        // which have the full two-tier fallback (purchase_and_activate_rpc → record_membership_purchase)
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          if (category == 'VIP') {
            try {
              final vipCtrl = Get.find<VipController>();
              final vipLevel = int.tryParse(name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
              await vipCtrl.purchaseVip(
                vipLevel, duration, goldPrice.toDouble(),
                paymentMethod: 'Gold Coins Wallet',
              );
            } catch (e) {
              debugPrint('[StoreController] VIP Gold Coins purchase failed: $e');
            }
          } else {
            try {
              final novelCtrl = Get.find<NovelController>();
              final novelLevel = int.tryParse(name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
              await novelCtrl.purchaseNovel(
                novelLevel, duration, goldPrice.toDouble(),
              );
            } catch (e) {
              debugPrint('[StoreController] Novel Gold Coins purchase failed: $e');
            }
          }
        }

      } else if (category == 'Frame') {
        try {
          final cust = Get.find<CustomizationController>();
          cust.unlockedItems.add(name);
        } catch (_) {}
      }
    }


    removeCoupon();
    return {'success': true, 'error': null};
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
