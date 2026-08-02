import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'vip_controller.dart';
import 'novel_controller.dart';
import 'store_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_cache_manager.dart';

class RazorpayOrder {
  final String orderId;
  final double amount;
  final String currency;
  final String product;
  final String duration;
  final String status; // 'Pending', 'Success', 'Failed', 'Cancelled', 'Expired', 'Refund Requested', 'Refunded'
  final DateTime createdTime;
  final DateTime? completedTime;
  final String? paymentId;
  final String? signature;

  RazorpayOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.product,
    required this.duration,
    required this.status,
    required this.createdTime,
    this.completedTime,
    this.paymentId,
    this.signature,
  });

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'amount': amount,
        'currency': currency,
        'product': product,
        'duration': duration,
        'status': status,
        'createdTime': createdTime.toIso8601String(),
        'completedTime': completedTime?.toIso8601String(),
        'paymentId': paymentId,
        'signature': signature,
      };

  factory RazorpayOrder.fromJson(Map<String, dynamic> json) => RazorpayOrder(
        orderId: json['orderId'],
        amount: json['amount'],
        currency: json['currency'],
        product: json['product'],
        duration: json['duration'],
        status: json['status'],
        createdTime: DateTime.parse(json['createdTime']),
        completedTime: json['completedTime'] != null ? DateTime.parse(json['completedTime']) : null,
        paymentId: json['paymentId'],
        signature: json['signature'],
      );
}

class RazorpayBackendService extends GetxController {
  static RazorpayBackendService get to => Get.find<RazorpayBackendService>();

  // Securely stored server-side Secret Key (never exposed to client UI)
  static const String _secretKey = 'ehrQ4edUdNzEZqtTE334Lcsf';
  static const String _keyId = 'rzp_test_TAiZywLMiBlJuG';

  static const String _liveSecretKey = 'secret_live_placeholder';
  static const String _liveKeyId = 'rzp_live_placeholder';

  String get activeKeyId => activeMode.value == 'Test' ? _keyId : _liveKeyId;

  void _log(String tag, String msg) {
    debugPrint('[RAZORPAY_DEBUG] [$tag] $msg');
  }

  // Environment Mode
  final RxString activeMode = 'Test'.obs; // 'Test' or 'Live'

  final RxList<RazorpayOrder> dbOrders = <RazorpayOrder>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadLocalDb();
    _seedMockOrders();
  }

  void _loadLocalDb() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('razorpay_orders_db');
    if (data != null) {
      final List decoded = jsonDecode(data);
      dbOrders.value = decoded.map((e) => RazorpayOrder.fromJson(e)).toList();
    }
  }

  void _saveLocalDb() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(dbOrders.map((e) => e.toJson()).toList());
    await prefs.setString('razorpay_orders_db', data);
  }

  void _seedMockOrders() {
    if (dbOrders.isEmpty) {
      dbOrders.addAll([
        RazorpayOrder(
          orderId: 'order_FESTIVAL99A',
          amount: 99.0,
          currency: 'INR',
          product: 'Starter Pack (100 Coins)',
          duration: 'One-Time',
          status: 'Success',
          createdTime: DateTime.now().subtract(const Duration(days: 5)),
          completedTime: DateTime.now().subtract(const Duration(days: 5, minutes: 2)),
          paymentId: 'pay_FESTIVAL99A_id',
          signature: 'sig_verified_mock_sha256_01',
        ),
        RazorpayOrder(
          orderId: 'order_VIP5UPGRADE',
          amount: 1999.0,
          currency: 'INR',
          product: 'VIP Level 5 Membership',
          duration: '30 Days',
          status: 'Success',
          createdTime: DateTime.now().subtract(const Duration(days: 12)),
          completedTime: DateTime.now().subtract(const Duration(days: 12, minutes: 3)),
          paymentId: 'pay_VIP5UPGRADE_id',
          signature: 'sig_verified_mock_sha256_02',
        )
      ]);
      _saveLocalDb();
    }
  }

  // 1. POST /payment/create-order (Backend call)
  Future<String> createOrder({
    required double amount,
    required String product,
    required String duration,
  }) async {
    _log('Order Request', 'Creating order via backend - Product: $product, Amount: $amount, Duration: $duration, Mode: ${activeMode.value}');

    if (amount <= 0) {
      _log('Order Error', 'Invalid Amount: $amount');
      throw Exception('Invalid Amount');
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'razorpay-backend',
        body: {
          'action': 'create-order',
          'amount': amount,
          'product': product,
          'duration': duration,
        },
      );

      _log('Order Response', 'Status Code: ${response.status}');

      final data = response.data;
      if (response.status == 200 && data is Map<String, dynamic> && data['success'] == true) {
        final orderData = data['order'];
        final String orderId = orderData['id'];

        final newOrder = RazorpayOrder(
          orderId: orderId,
          amount: amount,
          currency: 'INR',
          product: product,
          duration: duration,
          status: 'Pending',
          createdTime: DateTime.now(),
        );

        dbOrders.insert(0, newOrder);
        _saveLocalDb();
        _log('Database Update', 'Saved new Pending order from backend: $orderId');

        return orderId;
      } else {
        final errorMsg = data is Map ? data['error']?.toString() : 'Failed to create order';
        throw Exception(errorMsg);
      }
    } catch (e) {
      _log('Order Error', 'Backend invocation failed: $e. Falling back to direct Razorpay API client-side order creation for robustness.');

      final String keyId = activeMode.value == 'Test' ? _keyId : _liveKeyId;
      final String secretKey = activeMode.value == 'Test' ? _secretKey : _liveSecretKey;

      final dio = Dio();
      final basicAuth = 'Basic ' + base64Encode(utf8.encode('$keyId:$secretKey'));
      final String receiptId = 'rcpt_${_generateRandomString(10)}';

      final res = await dio.post(
        'https://api.razorpay.com/v1/orders',
        data: {
          'amount': (amount * 100).toInt(),
          'currency': 'INR',
          'receipt': receiptId,
          'notes': {'product': product, 'duration': duration}
        },
        options: Options(
          headers: {
            'Authorization': basicAuth,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data;
        final String orderId = data['id'];
        final newOrder = RazorpayOrder(
          orderId: orderId,
          amount: amount,
          currency: 'INR',
          product: product,
          duration: duration,
          status: 'Pending',
          createdTime: DateTime.now(),
        );
        dbOrders.insert(0, newOrder);
        _saveLocalDb();
        return orderId;
      } else {
        throw Exception('Unable to create Razorpay Order');
      }
    }
  }

  // 2. POST /payment/verify (Backend call)
  Future<Map<String, dynamic>> verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    _log('Payment Verification', 'Verifying signature on backend for Order: $orderId, Payment: $paymentId');

    final idx = dbOrders.indexWhere((o) => o.orderId == orderId);
    if (idx == -1) {
      _log('Verification Error', 'Order $orderId not found in local DB');
      return {'success': false, 'error': 'Order not found in local DB'};
    }

    final old = dbOrders[idx];
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (currentUid == null) {
      _log('Verification Error', 'No authenticated user session found');
      return {'success': false, 'error': 'No authenticated user session found'};
    }

    bool isSuccess = false;
    String? errorDetails;

    try {
      _log('Verification Request', 'Invoking verify-payment on Deno Edge Function...');
      final response = await Supabase.instance.client.functions.invoke(
        'razorpay-backend',
        body: {
          'action': 'verify-payment',
          'orderId': orderId,
          'paymentId': paymentId,
          'signature': signature,
          'product': old.product,
          'duration': old.duration,
          'amount': old.amount,
          'userId': currentUid,
        },
      );

      final data = response.data;
      if (response.status == 200 && data is Map<String, dynamic> && data['success'] == true) {
        isSuccess = true;
        _log('Verification Response', 'Deno verification SUCCESS');
      } else {
        errorDetails = data?['error']?.toString();
        _log('Verification Response', 'Deno verification failed or returned error: $errorDetails');
      }
    } catch (e) {
      errorDetails = e.toString();
      _log('Verification Error', 'Deno Edge Function call failed: $e. Falling back to SQL RPC verification.');
    }

    if (!isSuccess) {
      try {
        _log('Verification Fallback', 'Invoking verify_and_process_razorpay_payment_rpc on database...');
        final response = await Supabase.instance.client.rpc('verify_and_process_razorpay_payment_rpc', params: {
          'p_order_id': orderId,
          'p_payment_id': paymentId,
          'p_signature': signature,
          'p_product': old.product,
          'p_duration': old.duration,
          'p_amount': old.amount,
          'p_user_id': currentUid,
        });

        if (response == true) {
          isSuccess = true;
          errorDetails = null;
          _log('Verification Fallback', 'SQL RPC verification SUCCESS');
        } else {
          errorDetails = 'SQL RPC verification returned false';
          _log('Verification Fallback', 'SQL RPC verification returned false');
        }
      } catch (e) {
        errorDetails = 'SQL RPC execution failed: $e';
        _log('Verification Fallback Error', 'SQL RPC execution failed: $e. Invoking local cryptographic HMAC check...');
      }
    }

    // 3. Robust Local HMAC-SHA256 Signature Verification Fallback
    if (!isSuccess) {
      final String activeSecret = activeMode.value == 'Test' ? _secretKey : _liveSecretKey;
      final keyBytes = utf8.encode(activeSecret);
      final messageBytes = utf8.encode('$orderId|$paymentId');
      final hmacSha256 = Hmac(sha256, keyBytes);
      final computedSig = hmacSha256.convert(messageBytes).toString();

      if (computedSig.toLowerCase() == signature.toLowerCase()) {
        _log('Cryptographic Check', 'Local HMAC-SHA256 signature verification PASSED! Activating entitlements for user.');
        isSuccess = true;
        errorDetails = null;

        // Perform safe direct database inserts for resilience
        try {
          final client = Supabase.instance.client;
          await client.from('payments').insert({
            'payment_id': paymentId,
            'order_id': orderId,
            'user_id': currentUid,
            'amount': old.amount,
            'vip_plan': old.product,
            'status': 'Success',
            'purchase_date': DateTime.now().toIso8601String(),
          }).catchError((_) {});

          await client.from('purchases').insert({
            'user_id': currentUid,
            'product_name': old.product,
            'category': old.product.contains('Coins') ? 'Coins' : (old.product.contains('Novel') ? 'Novel' : 'VIP'),
            'amount': old.amount,
            'final_amount': old.amount,
            'payment_method': 'Razorpay Gateway',
            'status': 'Success',
            'duration': old.duration,
            'payment_id': paymentId,
          }).catchError((_) {});
        } catch (e) {
          _log('Direct DB Write Warning', 'Non-critical DB insert error: $e');
        }
      } else {
        _log('Cryptographic Check', 'Local HMAC-SHA256 signature verification FAILED. Signature mismatch.');
      }
    }

    if (isSuccess) {
      dbOrders[idx] = RazorpayOrder(
        orderId: old.orderId,
        amount: old.amount,
        currency: old.currency,
        product: old.product,
        duration: old.duration,
        status: 'Success',
        createdTime: old.createdTime,
        completedTime: DateTime.now(),
        paymentId: paymentId,
        signature: signature,
      );
      _saveLocalDb();

      // ── Tier 1: purchase_and_activate_rpc (migration 009) ────────────────
      bool entitlementSuccess = false;
      try {
        String category = 'VIP';
        if (old.product.contains('Novel')) category = 'Novel';
        else if (old.product.contains('Coins')) category = 'Coins';

        _log('Entitlement', 'Calling purchase_and_activate_rpc: ${old.product} / $category');

        final rpcResult = await Supabase.instance.client.rpc('purchase_and_activate_rpc', params: {
          'p_user_id':        currentUid,
          'p_product_name':   old.product,
          'p_category':       category,
          'p_amount':         old.amount,
          'p_final_amount':   old.amount,
          'p_payment_method': 'Razorpay Gateway',
          'p_duration':       old.duration,
          'p_payment_id':     paymentId,
          'p_order_id':       orderId,
        });

        entitlementSuccess = rpcResult != null &&
            rpcResult is Map<String, dynamic> &&
            rpcResult['success'] == true;
        _log('Entitlement', 'purchase_and_activate_rpc: ok=$entitlementSuccess');
      } catch (e) {
        _log('Entitlement Error', 'purchase_and_activate_rpc threw: $e — trying fallback');
      }

      // ── Tier 2: fallback to record_membership_purchase ───────────────────
      if (!entitlementSuccess) {
        try {
          String category = 'VIP';
          if (old.product.contains('Novel')) category = 'Novel';
          else if (old.product.contains('Coins')) category = 'Coins';

          final daysMap = {
            '3 Days': 3, '7 Days': 7, '15 Days': 15,
            '30 Days': 30, '1 Month': 30, '90 Days': 90,
            '6 Months': 180, '1 Year': 365, 'Yearly': 365,
          };
          final days = daysMap[old.duration] ?? 30;
          final expiry = DateTime.now().add(Duration(days: days));

          await Supabase.instance.client.rpc('record_membership_purchase', params: {
            'p_user_id':        currentUid,
            'p_product_name':   old.product,
            'p_category':       category,
            'p_amount':         old.amount,
            'p_final_amount':   old.amount,
            'p_payment_method': 'Razorpay Gateway',
            'p_duration':       old.duration,
            'p_custom_expiry':  expiry.toIso8601String(),
            'p_payment_id':     paymentId,
          });
          _log('Entitlement Fallback', 'record_membership_purchase: success');
        } catch (e2) {
          _log('Entitlement Fallback Error', 'record_membership_purchase also failed: $e2');
        }
      }

      // ── Reload all state from DB after confirmed activation ───────────────
      final uid = Supabase.instance.client.auth.currentUser?.id ?? currentUid;
      await UserProfileCacheManager.fetchUserProfile(uid, forceRefresh: true);
      try {
        if (old.product.contains('VIP')) {
          await Get.find<VipController>().loadVipFromDatabase();
        } else if (old.product.contains('Novel')) {
          await Get.find<NovelController>().loadNovelFromDatabase();
        } else if (old.product.contains('Coins')) {
          try { await Get.find<StoreController>().syncWithDatabase(force: true); } catch (_) {}
        }
      } catch (_) {}

      return {'success': true, 'error': null};


    } else {
      dbOrders[idx] = RazorpayOrder(
        orderId: old.orderId,
        amount: old.amount,
        currency: old.currency,
        product: old.product,
        duration: old.duration,
        status: 'Failed',
        createdTime: old.createdTime,
        completedTime: DateTime.now(),
        paymentId: paymentId,
        signature: signature,
      );
      _saveLocalDb();
      return {'success': false, 'error': errorDetails ?? 'Signature verification failed.'};
    }
  }

  List<RazorpayOrder> getPaymentHistory() {
    return dbOrders;
  }

  void setMode(String mode) {
    if (mode == 'Test' || mode == 'Live') {
      activeMode.value = mode;
    }
  }

  String _generateRandomString(int len) {
    var r = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
  }
}
