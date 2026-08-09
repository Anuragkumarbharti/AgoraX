import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:creania/core/theme.dart';
import '../../services/store/store_controller.dart';
import '../../services/memberships/vip_controller.dart';
import '../../services/memberships/novel_controller.dart';
import '../../services/store/razorpay_backend_service.dart';
import '../../widgets/gifting/insufficient_balance_sheet.dart';
import './payment_status_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final String productName;
  final String category;
  final double basePrice;
  final String duration;
  final bool giftToFriend;
  final String? friendUsername;
  final String? giftMessage;
  final bool anonymous;
  final DateTime? scheduledDate;

  const CheckoutScreen({
    Key? key,
    required this.productName,
    required this.category,
    required this.basePrice,
    required this.duration,
    this.giftToFriend = false,
    this.friendUsername,
    this.giftMessage,
    this.anonymous = false,
    this.scheduledDate,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final StoreController _storeCtrl = Get.find<StoreController>();
  final TextEditingController _couponCtrl = TextEditingController();

  String _selectedPaymentMethod = 'UPI (Google Pay / PhonePe)';
  bool _autoRenew = true;
  bool _isProcessing = false;
  String _selectedPurchaseMethod = 'Gold';

  final List<String> paymentMethods = [
    'UPI (Google Pay / PhonePe)',
    'Debit / Credit Card',
    'Net Banking',
    'Amazon Pay Wallet'
  ];

  late Razorpay _razorpay;

  // Temporary checkout session state
  String? _tempName;
  String? _tempCategory;
  double? _tempBasePrice;
  double? _tempFinalPricePaid;
  String? _tempDuration;
  bool? _tempGift;
  String? _tempFriend;
  String? _tempMsg;
  bool? _tempAnonymous;
  DateTime? _tempDate;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    final args = Get.arguments as Map<String, dynamic>?;
    final category = args?['category'] ?? widget.category;
    if (category == 'Coins') {
      _selectedPurchaseMethod = 'INR';
    } else {
      _selectedPurchaseMethod = 'Gold';
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint(
        '[RAZORPAY_DEBUG] [Payment Success Callback] Payment ID: ${response.paymentId}, Order ID: ${response.orderId}, Signature: ${response.signature}');
    setState(() => _isProcessing = true);

    // Secure server-side signature verification
    final result = await RazorpayBackendService.to.verifyPaymentSignature(
      orderId: response.orderId ?? '',
      paymentId: response.paymentId ?? '',
      signature: response.signature ?? '',
    );

    setState(() => _isProcessing = false);

    if (result['success'] == true) {
      // Record transaction history record
      _storeCtrl.orderHistory.insert(
        0,
        StoreOrderItem(
          orderId: response.orderId ?? 'order_unknown',
          name: _tempName ?? 'Premium Item',
          category: _tempCategory ?? 'Cosmetic',
          amount: _tempBasePrice ?? 0,
          discount: (_tempBasePrice ?? 0) - (_tempFinalPricePaid ?? 0),
          gst: (_tempFinalPricePaid ?? 0) * 0.18 / 1.18,
          finalAmount: _tempFinalPricePaid ?? 0,
          paymentMethod: 'Razorpay Gateway',
          dateTime: DateTime.now(),
          status: 'Success',
          duration: _tempDuration ?? '30 Days',
        ),
      );

      // Record coin ledger entry if coins package
      if ((_tempName ?? '').contains('Coins')) {
        final coinMatch =
            RegExp(r'(\d+,?\d*) Coins').firstMatch(_tempName ?? '');
        if (coinMatch != null) {
          final amt = int.parse(coinMatch.group(1)!.replaceAll(',', ''));
          _storeCtrl.coinTransactions.insert(
            0,
            CoinTransaction(
              amount: amt,
              type: 'Purchased',
              description: 'Bought $_tempName',
              dateTime: DateTime.now(),
            ),
          );
        }
      }

      await _activateMembershipBenefits(
        _tempCategory ?? widget.category,
        _tempName ?? widget.productName,
        _tempDuration ?? widget.duration,
        _tempFinalPricePaid ?? widget.basePrice,
        paymentId: response.paymentId,
      );

      Get.off(() => PaymentStatusScreen(
            isSuccess: true,
            productName: _tempName ?? 'Premium Item',
            pricePaid: _tempFinalPricePaid ?? 0,
          ));
    } else {
      Get.off(() => PaymentStatusScreen(
            isSuccess: false,
            productName: _tempName ?? 'Premium Item',
            pricePaid: _tempFinalPricePaid ?? 0,
            errorMessage: 'Purchase failed. Please try again.',
          ));
    }
  }

  Future<void> _activateMembershipBenefits(
      String category, String productName, String duration, double price,
      {String? paymentId}) async {
    final cleanCategory = category.trim();
    final cleanName = productName.trim();
    debugPrint(
        '[CheckoutScreen] Granting benefits for: $cleanCategory - $cleanName ($duration)');

    final match = RegExp(r'(\d+)').firstMatch(cleanName);
    int level = 1;
    if (match != null) {
      level = int.tryParse(match.group(1)!) ?? 1;
    }

    if (cleanCategory.toUpperCase() == 'VIP' ||
        cleanName.toUpperCase().contains('VIP')) {
      try {
        final vipCtrl = Get.find<VipController>();
        await vipCtrl.purchaseVip(level, duration, price, paymentId: paymentId);
      } catch (e) {
        debugPrint('[CheckoutScreen] Error activating VIP: $e');
      }
    } else if (cleanCategory.toUpperCase() == 'NOVEL' ||
        cleanName.toUpperCase().contains('NOVEL')) {
      try {
        final novelCtrl = Get.find<NovelController>();
        await novelCtrl.purchaseNovel(level, duration, price,
            paymentId: paymentId);
      } catch (e) {
        debugPrint('[CheckoutScreen] Error activating Novel: $e');
      }
    } else if (cleanCategory.toUpperCase() == 'COINS' ||
        cleanName.toUpperCase().contains('COIN') ||
        cleanName.toUpperCase().contains('PACK') ||
        cleanName.toUpperCase().contains('RECHARGE')) {
      try {
        final storeCtrl = Get.find<StoreController>();
        final packMatch = storeCtrl.coinPacks.firstWhereOrNull(
          (p) => p.name.toUpperCase() == cleanName.toUpperCase() || cleanName.toUpperCase().contains(p.name.toUpperCase()),
        );
        final totalCoins = packMatch != null ? (packMatch.coins + packMatch.bonusCoins) : (price * 0.50).round();
        await storeCtrl.rechargeGoldCoins(price, paymentId: paymentId, totalCoins: totalCoins);
      } catch (e) {
        debugPrint('[CheckoutScreen] Error activating Coins: $e');
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint(
        '[RAZORPAY_DEBUG] [Payment Failure Callback] Code: ${response.code}, Message: ${response.message}');

    String errorMsg = 'Payment Failed';
    if (response.message != null && response.message!.isNotEmpty) {
      if (response.message!.toLowerCase().contains('cancel')) {
        errorMsg = 'Payment Cancelled';
      } else {
        errorMsg = response.message!;
      }
    } else {
      switch (response.code) {
        case 2: // Network Error code
          errorMsg = 'Network Error';
          break;
        case 1: // Invalid Options code
          errorMsg = 'Invalid Checkout Options';
          break;
        default:
          errorMsg = 'Payment Failed (Error Code ${response.code})';
      }
    }

    Get.off(() => PaymentStatusScreen(
          isSuccess: false,
          productName: _tempName ?? 'Premium Item',
          pricePaid: _tempFinalPricePaid ?? 0,
          errorMessage: errorMsg,
        ));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Get.snackbar('External Wallet Selected', response.walletName ?? 'Wallet');
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if redirect arguments exist
    final args = Get.arguments as Map<String, dynamic>?;
    final name = args?['name'] ?? widget.productName;
    final category = args?['category'] ?? widget.category;
    final basePrice = args?['basePrice'] ?? widget.basePrice;
    final duration = args?['duration'] ?? widget.duration;
    final giftToFriend = args?['giftToFriend'] ?? widget.giftToFriend;
    final friendUsername = args?['friendUsername'] ?? widget.friendUsername;
    final giftMessage = args?['giftMessage'] ?? widget.giftMessage;
    final anonymous = args?['anonymous'] ?? widget.anonymous;
    final scheduledDate = args?['scheduledDate'] ?? widget.scheduledDate;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient Glow
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF8B5CF6).withOpacity(0.08),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20.0),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductCard(name, category, duration,
                            giftToFriend, friendUsername),
                        SizedBox(height: 20),
                        _buildPurchaseMethodSelector(category),
                        SizedBox(height: 20),
                        _buildCouponSection(),
                        SizedBox(height: 20),
                        _buildPaymentMethodSection(),
                        SizedBox(height: 20),
                        _buildAutoRenewToggle(category),
                        SizedBox(height: 20),
                        _buildBillingBreakdown(basePrice),
                        SizedBox(height: 30),
                        _buildBuyNowButton(
                            name,
                            category,
                            basePrice,
                            duration,
                            giftToFriend,
                            friendUsername,
                            giftMessage,
                            anonymous,
                            scheduledDate),
                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFFFD700)),
                    SizedBox(height: 24),
                    Text(
                      'Securing gateway channel...',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Verified by Razorpay & Fraud Prevention',
                      style: GoogleFonts.poppins(
                          color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: context.textPrimary, size: 18),
            onPressed: () => Get.back(),
          ),
          Text(
            'SECURE CHECKOUT',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 2,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseMethodSelector(String category) {
    if (category == 'Coins') return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT PURCHASE METHOD',
            style: GoogleFonts.outfit(
                color: context.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMethodTab('Gold Coins 🪙', 'Gold'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _buildMethodTab('Real Money (INR) 💵', 'INR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTab(String label, String method) {
    final isSel = _selectedPurchaseMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedPurchaseMethod = method),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSel
              ? context.primaryColor.withOpacity(0.12)
              : context.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? context.primaryColor : context.borderColor,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: isSel ? context.primaryColor : context.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(String name, String category, String duration,
      bool gift, String? friend) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: context.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                category == 'Coins'
                    ? '🪙'
                    : category == 'VIP'
                        ? '💎'
                        : category == 'Novel'
                            ? '📖'
                            : '🖼️',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  gift ? 'Gift to @$friend' : 'Duration: $duration',
                  style: GoogleFonts.poppins(
                      color: gift ? Color(0xFFFFB800) : context.textSecondary,
                      fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    return Obx(() {
      final hasCoupon = _storeCtrl.activeCouponCode.isNotEmpty;
      final couponCode = _storeCtrl.activeCouponCode.value;
      final discountPct = _storeCtrl.activeCouponDiscount.value;

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: hasCoupon
                  ? Color(0xFF10B981)
                  : context.borderColor,
              width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COUPON / PROMO CODES',
              style: GoogleFonts.outfit(
                  color: context.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            SizedBox(height: 10),
            if (hasCoupon)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          color: Color(0xFF10B981), size: 16),
                      SizedBox(width: 6),
                      Text(
                        '$couponCode applied! (${(discountPct * 100).toInt()}% off)',
                        style: GoogleFonts.poppins(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _storeCtrl.removeCoupon(),
                    child: Text('Remove',
                        style: GoogleFonts.poppins(
                            color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _couponCtrl,
                        style: TextStyle(color: context.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter Coupon Code',
                          hintStyle: TextStyle(color: context.caption),
                          filled: true,
                          fillColor: context.scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      final ok = _storeCtrl.applyCoupon(_couponCtrl.text);
                      if (ok) {
                        _couponCtrl.clear();
                        Get.snackbar(
                            'Applied! 🎉', 'Promo Coupon discount loaded.',
                            backgroundColor: Colors.green.withOpacity(0.9),
                            colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM);
                      } else {
                        Get.snackbar('Invalid Coupon ⚠️',
                            'Check the coupon code and try again.',
                            backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
                            colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                    child: Text('Apply',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
          ],
        ),
      );
    });
  }

  Widget _buildPaymentMethodSection() {
    if (_selectedPurchaseMethod == 'Gold') {
      return Obx(() {
        final currentGold = _storeCtrl.coinsBalance.value;
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAY WITH WALLET',
                style: GoogleFonts.outfit(
                    color: context.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Gold Coins Balance',
                      style: GoogleFonts.poppins(
                          color: context.textSecondary, fontSize: 12),
                    ),
                    Text(
                      '$currentGold 🪙',
                      style: GoogleFonts.poppins(
                          color: Color(0xFFF4B400),
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      });
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHOOSE PAYMENT METHOD',
            style: GoogleFonts.outfit(
                color: context.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
          ),
          SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paymentMethods.length,
            itemBuilder: (context, index) {
              final pm = paymentMethods[index];
              final isSel = _selectedPaymentMethod == pm;
              return GestureDetector(
                onTap: () => setState(() => _selectedPaymentMethod = pm),
                child: Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel
                        ? context.primaryColor.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel
                          ? context.primaryColor
                          : context.borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSel
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSel ? context.primaryColor : context.caption,
                        size: 16,
                      ),
                      SizedBox(width: 12),
                      Text(
                        pm,
                        style: GoogleFonts.poppins(
                            color: isSel ? context.textPrimary : context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAutoRenewToggle(String category) {
    if (category == 'Coins') return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AUTO RENEWAL',
                  style: GoogleFonts.poppins(
                      color: context.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Renew automatically at the end of validity period.',
                  style:
                      GoogleFonts.poppins(color: context.textSecondary, fontSize: 9.5),
                ),
              ],
            ),
          ),
          Switch(
            value: _autoRenew,
            onChanged: (val) => setState(() => _autoRenew = val),
            activeColor: context.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBillingBreakdown(double basePrice) {
    return Obx(() {
      final discount = basePrice * _storeCtrl.activeCouponDiscount.value;
      final finalBase = basePrice - discount;

      if (_selectedPurchaseMethod == 'Gold') {
        int goldPrice = (basePrice * 0.50).round();
        int goldDiscount = (discount * 0.50).round();
        int finalGoldAmount = goldPrice - goldDiscount;

        return Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor, width: 0.5),
          ),
          child: Column(
            children: [
              _billingRow('Product Base Price', '$goldPrice Gold Coins 🪙'),
              if (goldDiscount > 0)
                _billingRow('Coupon Discount', '-$goldDiscount Gold Coins 🪙',
                    valueColor: Color(0xFF10B981)),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: context.borderColor, height: 1),
              ),
              _billingRow('Final Amount', '$finalGoldAmount Gold Coins 🪙',
                  isHeader: true),
            ],
          ),
        );
      } else {
        return Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor, width: 0.5),
          ),
          child: Column(
            children: [
              _billingRow(
                  'Product Base Price', '₹${basePrice.toStringAsFixed(2)}'),
              if (discount > 0)
                _billingRow(
                    'Coupon Discount', '-₹${discount.toStringAsFixed(2)}',
                    valueColor: Color(0xFF10B981)),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: context.borderColor, height: 1),
              ),
              _billingRow(
                  'Final Pay Amount', '₹${finalBase.toStringAsFixed(2)}',
                  isHeader: true),
            ],
          ),
        );
      }
    });
  }

  Widget _billingRow(String label, String value,
      {Color? valueColor, bool isHeader = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
                color: isHeader ? context.textPrimary : context.textSecondary,
                fontSize: isHeader ? 13 : 11.5,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color:
                  valueColor ?? (isHeader ? Color(0xFFF4B400) : context.textPrimary),
              fontSize: isHeader ? 15 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyNowButton(
    String name,
    String category,
    double basePrice,
    String duration,
    bool gift,
    String? friend,
    String? msg,
    bool anonymous,
    DateTime? date,
  ) {
    final discount = basePrice * _storeCtrl.activeCouponDiscount.value;
    final payAmount = basePrice - discount;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.security_rounded, size: 18, color: Colors.white),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () async {
          final finalAmount = payAmount;

          if (_selectedPurchaseMethod == 'Gold') {
            int goldPrice = (finalAmount * 0.50).round();
            if (_storeCtrl.coinsBalance.value < goldPrice) {
              InsufficientBalanceSheet.show(
                currency: 'gold',
                requiredCoins: goldPrice,
                availableCoins: _storeCtrl.coinsBalance.value,
                giftName: name,
              );
              return;
            }

            setState(() => _isProcessing = true);

            _tempName = name;
            _tempCategory = category;
            _tempBasePrice = basePrice;
            _tempFinalPricePaid = finalAmount;
            _tempDuration = duration;
            _tempGift = gift;
            _tempFriend = friend;
            _tempMsg = msg;
            _tempAnonymous = anonymous;
            _tempDate = date;

            final result = await _storeCtrl.processPurchaseOrder(
              name: name,
              category: category,
              basePrice: basePrice,
              duration: duration,
              paymentMethod: 'Gold Coins Wallet',
              purchaseMethod: 'Gold',
              giftToFriend: gift,
              friendUsername: friend,
              giftMessage: msg,
              anonymous: anonymous,
              scheduledDate: date,
            );

            setState(() => _isProcessing = false);

            if (result['success'] == true) {
              await _activateMembershipBenefits(
                  category, name, duration, goldPrice.toDouble());

              Get.off(() => PaymentStatusScreen(
                    isSuccess: true,
                    productName: name,
                    pricePaid: goldPrice.toDouble(),
                  ));
            } else {
              Get.off(() => PaymentStatusScreen(
                    isSuccess: false,
                    productName: name,
                    pricePaid: goldPrice.toDouble(),
                    errorMessage: result['error'] ?? 'Gold payment failed',
                  ));
            }
            return;
          }

          // INR payment gateway flow
          setState(() => _isProcessing = true);

          _tempName = name;
          _tempCategory = category;
          _tempBasePrice = basePrice;
          _tempFinalPricePaid = finalAmount;
          _tempDuration = duration;
          _tempGift = gift;
          _tempFriend = friend;
          _tempMsg = msg;
          _tempAnonymous = anonymous;
          _tempDate = date;

          String orderId;
          try {
            debugPrint(
                '[RAZORPAY_DEBUG] [Create Order] Requesting order ID from backend...');
            orderId = await RazorpayBackendService.to.createOrder(
              amount: finalAmount,
              product: name,
              duration: duration,
            );
            debugPrint(
                '[RAZORPAY_DEBUG] [Create Order] Successfully generated Order ID: $orderId');
          } catch (e) {
            setState(() => _isProcessing = false);
            debugPrint('[RAZORPAY_ERROR] [Create Order Exception] $e');
            Get.snackbar(
              'Purchase Failed',
              'Purchase failed. Please try again.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFFEF4444),
              colorText: Colors.white,
            );
            return;
          }

          setState(() => _isProcessing = false);

          // 2. Launch Razorpay native Android/iOS checkout flow (exposing ONLY frontend Key ID)
          var options = {
            'key': RazorpayBackendService.to.activeKeyId,
            'amount': (finalAmount * 100).toInt(),
            'currency': 'INR',
            'order_id': orderId,
            'name': 'Creaniaa',
            'description': name,
            'timeout': 300,
            'theme': {
              'color': '#6366F1',
            },
            'retry': {
              'enabled': true,
              'max_count': 4,
            },
            'prefill': {
              'email': Supabase.instance.client.auth.currentUser?.email ??
                  'student@creaniaa.com'
            },
            'notes': {
              'product': name,
              'duration': duration,
            }
          };

          try {
            debugPrint(
                '[RAZORPAY_DEBUG] [Checkout Options] Opening checkout with: $options');
            _razorpay.open(options);
          } catch (e) {
            debugPrint('[RAZORPAY_ERROR] [Open Checkout Exception] $e');
            Get.snackbar(
              'Purchase Failed',
              'Purchase failed. Please try again.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFFEF4444),
              colorText: Colors.white,
            );
          }
        },
        label: Text(
          _selectedPurchaseMethod == 'Gold'
              ? 'PURCHASE WITH GOLD 🪙'
              : 'PAY ₹${payAmount.toStringAsFixed(2)} NOW 🔒',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
      ),
    );
  }
}
