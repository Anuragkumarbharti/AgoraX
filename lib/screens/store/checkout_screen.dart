import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme.dart';
import '../../services/store_controller.dart';
import '../../services/razorpay_backend_service.dart';
import 'payment_status_screen.dart';

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
  
  String _selectedPaymentMethod = 'UPI QR Code (Scan & Pay) 📲';
  bool _autoRenew = true;
  bool _isProcessing = false;
  String _selectedPurchaseMethod = 'Gold';

  final List<String> paymentMethods = [
    'UPI QR Code (Scan & Pay) 📲', 'UPI (Google Pay / PhonePe)', 'Debit / Credit Card', 'Net Banking', 'Amazon Pay Wallet'
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
    debugPrint('[RAZORPAY_DEBUG] [Payment Success Callback] Payment ID: ${response.paymentId}, Order ID: ${response.orderId}, Signature: ${response.signature}');
    setState(() => _isProcessing = true);

    // Secure server-side signature verification
    final verified = await RazorpayBackendService.to.verifyPaymentSignature(
      orderId: response.orderId ?? '',
      paymentId: response.paymentId ?? '',
      signature: response.signature ?? '',
    );

    setState(() => _isProcessing = false);

    if (verified) {
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
        final coinMatch = RegExp(r'(\d+,?\d*) Coins').firstMatch(_tempName ?? '');
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
            errorMessage: 'Signature Verification Failed',
          ));
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('[RAZORPAY_DEBUG] [Payment Failure Callback] Code: ${response.code}, Message: ${response.message}');
    
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
      backgroundColor: const Color(0xFF07070A),
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
                    color: const Color(0xFF8B5CF6).withOpacity(0.08),
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
                    padding: const EdgeInsets.all(20.0),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductCard(name, category, duration, giftToFriend, friendUsername),
                        const SizedBox(height: 20),
                        _buildPurchaseMethodSelector(category),
                        const SizedBox(height: 20),
                        _buildCouponSection(),
                        const SizedBox(height: 20),
                        _buildPaymentMethodSection(),
                        const SizedBox(height: 20),
                        _buildAutoRenewToggle(category),
                        const SizedBox(height: 20),
                        _buildBillingBreakdown(basePrice),
                        const SizedBox(height: 30),
                        _buildBuyNowButton(name, category, basePrice, duration, giftToFriend, friendUsername, giftMessage, anonymous, scheduledDate),
                        const SizedBox(height: 40),
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
                    const SizedBox(height: 24),
                    Text(
                      'Securing gateway channel...',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verified by Razorpay & Fraud Prevention',
                      style: GoogleFonts.poppins(color: Colors.white30, fontSize: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Get.back(),
          ),
          Text(
            'SECURE CHECKOUT',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseMethodSelector(String category) {
    if (category == 'Coins') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT PURCHASE METHOD',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMethodTab('Gold Coins 🪙', 'Gold'),
              ),
              const SizedBox(width: 10),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF1E1B4B).withOpacity(0.4) : Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.04),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: isSel ? Colors.white : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(String name, String category, String duration, bool gift, String? friend) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
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
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  gift ? 'Gift to @$friend' : 'Duration: $duration',
                  style: GoogleFonts.poppins(color: gift ? const Color(0xFFFFB800) : Colors.white38, fontSize: 11),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111115),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hasCoupon ? const Color(0xFF10B981).withOpacity(0.3) : Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COUPON / PROMO CODES',
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            if (hasCoupon)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '$couponCode applied! (${(discountPct * 100).toInt()}% off)',
                        style: GoogleFonts.poppins(color: const Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _storeCtrl.removeCoupon(),
                    child: Text('Remove', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12)),
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
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter Coupon Code',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      final ok = _storeCtrl.applyCoupon(_couponCtrl.text);
                      if (ok) {
                        _couponCtrl.clear();
                        Get.snackbar('Applied! 🎉', 'Promo Coupon discount loaded.', backgroundColor: Colors.green.withOpacity(0.9), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                      } else {
                        Get.snackbar('Invalid Coupon ⚠️', 'Check the coupon code and try again.', backgroundColor: const Color(0xFFEF4444).withOpacity(0.9), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                    child: Text('Apply', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111115),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAY WITH WALLET',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Gold Coins Balance',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '$currentGold 🪙',
                      style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHOOSE PAYMENT METHOD',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
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
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF1E1B4B).withOpacity(0.3) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.02),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSel ? const Color(0xFF8B5CF6) : Colors.white30,
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        pm,
                        style: GoogleFonts.poppins(color: isSel ? Colors.white : Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
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
    if (category == 'Coins') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
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
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Renew automatically at the end of validity period.',
                  style: GoogleFonts.poppins(color: Colors.white30, fontSize: 9.5),
                ),
              ],
            ),
          ),
          Switch(
            value: _autoRenew,
            onChanged: (val) => setState(() => _autoRenew = val),
            activeColor: const Color(0xFF8B5CF6),
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
        int goldPrice = (basePrice * 0.49).round();
        int goldDiscount = (discount * 0.49).round();
        int finalGoldAmount = goldPrice - goldDiscount;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111115),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            children: [
              _billingRow('Product Base Price', '$goldPrice Gold Coins 🪙'),
              if (goldDiscount > 0)
                _billingRow('Coupon Discount', '-$goldDiscount Gold Coins 🪙', valueColor: const Color(0xFF10B981)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: Colors.white10, height: 1),
              ),
              _billingRow('Final Amount', '$finalGoldAmount Gold Coins 🪙', isHeader: true),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111115),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            children: [
              _billingRow('Product Base Price', '₹${basePrice.toStringAsFixed(2)}'),
              if (discount > 0)
                _billingRow('Coupon Discount', '-₹${discount.toStringAsFixed(2)}', valueColor: const Color(0xFF10B981)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: Colors.white10, height: 1),
              ),
              _billingRow('Final Pay Amount', '₹${finalBase.toStringAsFixed(2)}', isHeader: true),
            ],
          ),
        );
      }
    });
  }

  Widget _billingRow(String label, String value, {Color? valueColor, bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: isHeader ? Colors.white : Colors.white38, fontSize: isHeader ? 13 : 11.5, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: valueColor ?? (isHeader ? const Color(0xFFFFD700) : Colors.white),
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
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.security_rounded, size: 18),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () async {
          final discount = basePrice * _storeCtrl.activeCouponDiscount.value;
          final finalAmount = basePrice - discount;

          if (_selectedPurchaseMethod == 'Gold') {
            int goldPrice = (finalAmount * 0.49).round();
            if (_storeCtrl.coinsBalance.value < goldPrice) {
              Get.snackbar(
                'Insufficient Balance ⚠️',
                'You do not have enough Gold Coins. Please recharge or pay with Real Money.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFFEF4444),
                colorText: Colors.white,
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

            final success = await _storeCtrl.processPurchaseOrder(
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

            if (success) {
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
                errorMessage: 'Gold payment failed',
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
            debugPrint('[RAZORPAY_DEBUG] [Create Order] Requesting order ID from simulated backend...');
            orderId = await RazorpayBackendService.to.createOrder(
              amount: finalAmount,
              product: name,
              duration: duration,
            );
            debugPrint('[RAZORPAY_DEBUG] [Create Order] Successfully generated Order ID: $orderId');
          } catch (e) {
            setState(() => _isProcessing = false);
            String displayError = e.toString();
            if (displayError.contains('Exception:')) {
              displayError = displayError.substring(displayError.indexOf(':') + 1).trim();
            }
            Get.snackbar(
              'Payment Error',
              displayError,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFFEF4444),
              colorText: Colors.white,
            );
            return;
          }

          setState(() => _isProcessing = false);

          if (_selectedPaymentMethod.contains('QR Code')) {
            _showUpiQrPaymentDialog(orderId, name, finalAmount);
            return;
          }

          // 2. Launch Razorpay native Android/iOS checkout flow (exposing ONLY frontend Key ID)
          var options = {
            'key': RazorpayBackendService.to.activeKeyId,
            'amount': (finalAmount * 100).toInt(),
            'currency': 'INR',
            'order_id': orderId,
            'name': 'AgoraX',
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
              'contact': '9876543210',
              'email': 'anurag.bharti@agorax.com'
            },
            'config': {
              'display': {
                'blocks': {
                  'upi': {
                    'name': 'UPI & QR',
                    'instruments': [
                      {
                        'method': 'upi',
                        'flows': ['qr', 'intent', 'collect']
                      }
                    ]
                  }
                },
                'sequence': ['block.upi', 'block.other'],
                'preferences': {
                  'show_default_blocks': true
                }
              }
            },
            'notes': {
              'product': name,
              'duration': duration,
            }
          };

          try {
            debugPrint('[RAZORPAY_DEBUG] [Checkout Options] Opening checkout with: $options');
            _razorpay.open(options);
          } catch (e) {
            Get.snackbar(
              'Checkout Error',
              'Failed to open Razorpay payment interface: $e',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFFEF4444),
              colorText: Colors.white,
            );
          }
        },
        label: Text(
          _selectedPurchaseMethod == 'Gold' ? 'PURCHASE WITH GOLD 🪙' : 'SECURE CHECKOUT (INR) 🔒',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  void _showUpiQrPaymentDialog(String orderId, String name, double finalAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return UpiQrDialogWidget(
          amount: finalAmount,
          productName: name,
          orderId: orderId,
          onSuccess: (paymentId, signature) {
            Get.back(); // close dialog
            _onQrPaymentSuccess(orderId, paymentId, signature);
          },
          onFailure: (errorMsg) {
            Get.back(); // close dialog
            _onQrPaymentFailure(errorMsg);
          },
        );
      },
    );
  }

  void _onQrPaymentSuccess(String orderId, String paymentId, String signature) async {
    setState(() => _isProcessing = true);
    final verified = await RazorpayBackendService.to.verifyPaymentSignature(
      orderId: orderId,
      paymentId: paymentId,
      signature: signature,
    );
    setState(() => _isProcessing = false);

    if (verified) {
      _storeCtrl.orderHistory.insert(
        0,
        StoreOrderItem(
          orderId: orderId,
          name: _tempName ?? 'Premium Item',
          category: _tempCategory ?? 'Cosmetic',
          amount: _tempBasePrice ?? 0,
          discount: (_tempBasePrice ?? 0) - (_tempFinalPricePaid ?? 0),
          gst: (_tempFinalPricePaid ?? 0) * 0.18 / 1.18,
          finalAmount: _tempFinalPricePaid ?? 0,
          paymentMethod: 'UPI QR Code Scan',
          dateTime: DateTime.now(),
          status: 'Success',
          duration: _tempDuration ?? '30 Days',
        ),
      );

      if ((_tempName ?? '').contains('Coins')) {
        final coinMatch = RegExp(r'(\d+,?\d*) Coins').firstMatch(_tempName ?? '');
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
            errorMessage: 'Signature Verification Failed',
          ));
    }
  }

  void _onQrPaymentFailure(String errorMessage) {
    Get.off(() => PaymentStatusScreen(
          isSuccess: false,
          productName: _tempName ?? 'Premium Item',
          pricePaid: _tempFinalPricePaid ?? 0,
          errorMessage: errorMessage,
        ));
  }
}

class UpiQrDialogWidget extends StatefulWidget {
  final double amount;
  final String productName;
  final String orderId;
  final Function(String paymentId, String signature) onSuccess;
  final Function(String errorMsg) onFailure;

  const UpiQrDialogWidget({
    Key? key,
    required this.amount,
    required this.productName,
    required this.orderId,
    required this.onSuccess,
    required this.onFailure,
  }) : super(key: key);

  @override
  State<UpiQrDialogWidget> createState() => _UpiQrDialogWidgetState();
}

class _UpiQrDialogWidgetState extends State<UpiQrDialogWidget> {
  int _timeLeft = 300; // 5 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        widget.onFailure('Payment session expired');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final upiUrl = 'upi://pay?pa=agorax@okaxis&pn=AgoraX&am=${widget.amount.toStringAsFixed(2)}&cu=INR';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F13),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF312E81).withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFFFD700), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'UPI QR SCAN & PAY',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                  onPressed: () {
                    _timer?.cancel();
                    widget.onFailure('Payment cancelled by user');
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 20),
            
            // Subtitle
            Text(
              'Scan to pay for ${widget.productName}',
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11.5),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // QR Code Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                  )
                ],
              ),
              child: CustomPaint(
                size: const Size(180, 180),
                painter: UpiQrCodePainter(upiUrl),
              ),
            ),
            
            const SizedBox(height: 16),

            // Timer & Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AMOUNT TO PAY',
                      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${widget.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(color: const Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'EXPIRES IN',
                      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatTime(_timeLeft),
                      style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // UPI ID copy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'UPI ID: agorax@okaxis',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: 'agorax@okaxis'));
                      Get.snackbar(
                        'Copied! 📋',
                        'UPI ID copied to clipboard.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
                        colorText: Colors.white,
                      );
                    },
                    child: const Icon(Icons.copy_rounded, color: Color(0xFF8B5CF6), size: 16),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Simulation Dev Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1917),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚙️ SIMULATION CONTROLS',
                    style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            _timer?.cancel();
                            // Generate mock payment details
                            final mockPaymentId = 'pay_QR_${_generateRandomString(10)}';
                            final mockSignature = RazorpayBackendService.to.generateSignature(widget.orderId, mockPaymentId);
                            widget.onSuccess(mockPaymentId, mockSignature);
                          },
                          child: Text(
                            'Simulate Success ✅',
                            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            _timer?.cancel();
                            widget.onFailure('Transaction declined by simulator');
                          },
                          child: Text(
                            'Simulate Failure ❌',
                            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  String _generateRandomString(int len) {
    var r = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
  }
}

class UpiQrCodePainter extends CustomPainter {
  final String qrData;
  UpiQrCodePainter(this.qrData);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw white background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(12)),
      paint,
    );

    final qrPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final double cellSize = size.width / 21; // 21x21 grid for simple QR code

    // Draw Finder Patterns (Top-Left, Top-Right, Bottom-Left)
    _drawFinderPattern(canvas, 0, 0, cellSize, qrPaint);
    _drawFinderPattern(canvas, 14, 0, cellSize, qrPaint);
    _drawFinderPattern(canvas, 0, 14, cellSize, qrPaint);

    // Draw timing patterns
    for (int i = 8; i < 14; i++) {
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(6 * cellSize, i * cellSize, cellSize, cellSize), qrPaint);
        canvas.drawRect(Rect.fromLTWH(i * cellSize, 6 * cellSize, cellSize, cellSize), qrPaint);
      }
    }

    // Draw random-looking data bits using a pseudo-random generator based on data hash
    final hash = qrData.hashCode;
    final rand = Random(hash);

    for (int r = 0; r < 21; r++) {
      for (int c = 0; c < 21; c++) {
        // Skip finder pattern zones
        if ((r < 8 && c < 8) || (r < 8 && c >= 13) || (r >= 13 && c < 8)) {
          continue;
        }
        // Also skip timing pattern lines (row 6, col 6)
        if (r == 6 || c == 6) {
          continue;
        }

        // Draw random bits
        if (rand.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            qrPaint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(Canvas canvas, int col, int row, double cellSize, Paint paint) {
    final double left = col * cellSize;
    final double top = row * cellSize;

    // Outer 7x7 square
    canvas.drawRect(Rect.fromLTWH(left, top, cellSize * 7, cellSize * 7), paint);

    // Inner 5x5 white square
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(left + cellSize, top + cellSize, cellSize * 5, cellSize * 5), whitePaint);

    // Center 3x3 square
    canvas.drawRect(Rect.fromLTWH(left + cellSize * 2, top + cellSize * 2, cellSize * 3, cellSize * 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
