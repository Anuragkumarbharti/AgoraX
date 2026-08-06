import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/user/user_profile_cache_manager.dart';
import 'package:creania/core/theme.dart';
import '../../services/store/store_controller.dart';
import '../../services/store/razorpay_backend_service.dart';

class StoreHistoryScreen extends StatefulWidget {
  const StoreHistoryScreen({Key? key}) : super(key: key);

  @override
  State<StoreHistoryScreen> createState() => _StoreHistoryScreenState();
}

class _StoreHistoryScreenState extends State<StoreHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final StoreController _storeCtrl = Get.find<StoreController>();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF07070A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildOrdersList(),
                      _buildCoinTransactionsList(),
                    ],
                  ),
                ),
              ],
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
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Get.back(),
          ),
          Text(
            'TRANSACTION ARCHIVE',
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

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 44,
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: const [
          Tab(text: 'Orders & Receipts'),
          Tab(text: 'Coin Ledger'),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return Obx(() {
      final localOrders = _storeCtrl.orderHistory;
      final razorpayOrders = RazorpayBackendService.to.dbOrders;

      final List<StoreOrderItem> allOrders = [];
      for (var r in razorpayOrders) {
        allOrders.add(StoreOrderItem(
          orderId: r.orderId,
          name: r.product,
          category: 'Prestige Item',
          amount: r.amount / 1.18,
          discount: 0,
          gst: r.amount * 0.18 / 1.18,
          finalAmount: r.amount,
          paymentMethod: 'Razorpay Gateway',
          dateTime: r.createdTime,
          status: r.status,
          duration: r.duration,
        ));
      }
      for (var l in localOrders) {
        if (!allOrders.any((o) => o.orderId == l.orderId)) {
          allOrders.add(l);
        }
      }

      allOrders.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      if (allOrders.isEmpty) {
        return _buildEmptyState('No purchase records found.');
      }

      return ListView.builder(
        padding: EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        itemCount: allOrders.length,
        itemBuilder: (context, index) {
          final o = allOrders[index];
          final isRefunded = o.status == 'Refunded' || o.status == 'Refund Requested';

          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.03)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(o.orderId, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isRefunded ? Colors.redAccent.withOpacity(0.12) : Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        o.status,
                        style: GoogleFonts.poppins(
                          color: isRefunded ? Colors.redAccent : Color(0xFF34D399),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  o.name,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  '${o.dateTime.day}/${o.dateTime.month}/${o.dateTime.year} via ${o.paymentMethod}',
                  style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Charged (GST Inc.)', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)),
                        Text('₹${o.finalAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        if (o.category != 'Coins' && !isRefunded)
                          TextButton(
                            onPressed: () {
                              _storeCtrl.requestRefund(o.orderId);
                            },
                            child: Text('Request Refund', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        IconButton(
                          icon: Icon(Icons.receipt_long_rounded, color: Colors.white60, size: 18),
                          tooltip: 'View Invoice',
                          onPressed: () => _showInvoiceDialog(o),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildCoinTransactionsList() {
    return Obx(() {
      final txs = _storeCtrl.coinTransactions;
      if (txs.isEmpty) {
        return _buildEmptyState('No coin ledger details.');
      }

      return ListView.builder(
        padding: EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        itemCount: txs.length,
        itemBuilder: (context, index) {
          final tx = txs[index];
          final isCredit = tx.type == 'Purchased' || tx.type == 'Received' || tx.type == 'Refunded';

          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.02)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.description, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text(
                      '${tx.dateTime.day}/${tx.dateTime.month} • ${tx.type}',
                      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
                Text(
                  '${isCredit ? "+" : "-"}${tx.amount} Coins',
                  style: GoogleFonts.poppins(
                    color: isCredit ? Color(0xFF10B981) : Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Text(
        msg,
        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
      ),
    );
  }

  void _showInvoiceDialog(StoreOrderItem o) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white10),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CREANIAA INVOICE', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: Icon(Icons.close, color: Colors.white60, size: 18), onPressed: () => Navigator.pop(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _invoiceLine('Order Reference', o.orderId),
            _invoiceLine('Date & Time', '${o.dateTime.day}/${o.dateTime.month}/${o.dateTime.year}'),
            _invoiceLine('Billing Target', 'Me (${UserProfileCacheManager.currentUser?.username ?? Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'Student'})'),
            _invoiceLine('Payment Method', o.paymentMethod),
            Divider(color: Colors.white10, height: 24),
            _invoiceLine('Product / Item', o.name),
            _invoiceLine('Price Charged', '₹${o.amount.toStringAsFixed(2)}'),
            if (o.discount > 0)
              _invoiceLine('Discount Deducted', '-₹${o.discount.toStringAsFixed(2)}'),
            _invoiceLine('GST (18% inclusive)', '₹${o.gst.toStringAsFixed(2)}'),
            Divider(color: Colors.white10, height: 24),
            _invoiceLine('Total Net Price', '₹${o.finalAmount.toStringAsFixed(2)}', highlight: true),
          ],
        ),
      ),
    );
  }

  Widget _invoiceLine(String key, String val, {bool highlight = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
          Text(val, style: GoogleFonts.poppins(color: highlight ? Color(0xFFFFD700) : Colors.white70, fontSize: 11.5, fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
