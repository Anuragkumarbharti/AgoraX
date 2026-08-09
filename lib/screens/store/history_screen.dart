import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: context.scaffoldBackgroundColor,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 18),
            onPressed: () => Get.back(),
          ),
          Text(
            'TRANSACTION ARCHIVE',
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

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: context.textSecondary,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
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
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        itemCount: allOrders.length,
        itemBuilder: (context, index) {
          final o = allOrders[index];
          final isRefunded = o.status == 'Refunded' || o.status == 'Refund Requested';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      o.orderId,
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isRefunded ? Colors.redAccent.withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        o.status,
                        style: GoogleFonts.poppins(
                          color: isRefunded ? Colors.redAccent : const Color(0xFF10B981),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  o.name,
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${o.dateTime.day}/${o.dateTime.month}/${o.dateTime.year} via ${o.paymentMethod}',
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Divider(color: context.borderColor, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Charged (GST Inc.)', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 9.5)),
                        const SizedBox(height: 2),
                        Text('₹${o.finalAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: const Color(0xFFF4B400), fontSize: 15, fontWeight: FontWeight.bold)),
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
                          icon: Icon(Icons.receipt_long_rounded, color: context.textSecondary, size: 18),
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
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        itemCount: txs.length,
        itemBuilder: (context, index) {
          final tx = txs[index];
          final isCredit = tx.type == 'Purchased' || tx.type == 'Received' || tx.type == 'Refunded';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.description, style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.dateTime.day}/${tx.dateTime.month} • ${tx.type}',
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 10.5),
                    ),
                  ],
                ),
                Text(
                  '${isCredit ? "+" : "-"}${tx.amount} Coins',
                  style: GoogleFonts.poppins(
                    color: isCredit ? const Color(0xFF10B981) : Colors.redAccent,
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
        style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12.5),
      ),
    );
  }

  void _showInvoiceDialog(StoreOrderItem o) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: context.borderColor),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CREANIAA INVOICE', style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: Icon(Icons.close, color: context.textSecondary, size: 18), onPressed: () => Navigator.pop(context)),
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
            Divider(color: context.borderColor, height: 24),
            _invoiceLine('Product / Item', o.name),
            _invoiceLine('Price Charged', '₹${o.amount.toStringAsFixed(2)}'),
            if (o.discount > 0)
              _invoiceLine('Discount Deducted', '-₹${o.discount.toStringAsFixed(2)}'),
            _invoiceLine('GST (18% inclusive)', '₹${o.gst.toStringAsFixed(2)}'),
            Divider(color: context.borderColor, height: 24),
            _invoiceLine('Total Net Price', '₹${o.finalAmount.toStringAsFixed(2)}', highlight: true),
          ],
        ),
      ),
    );
  }

  Widget _invoiceLine(String key, String val, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11)),
          Text(val, style: GoogleFonts.poppins(color: highlight ? const Color(0xFFF4B400) : context.textPrimary, fontSize: 11.5, fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
