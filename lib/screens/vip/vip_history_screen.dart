import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/vip_controller.dart';
import '../../widgets/vip_badge_widget.dart';

class VipHistoryScreen extends StatelessWidget {
  const VipHistoryScreen({Key? key}) : super(key: key);

  void _showInvoiceDialog(BuildContext context, Map<String, dynamic> txn) {
    final DateTime date = DateTime.tryParse(txn['date'] as String) ?? DateTime.now();
    final double rawPrice = txn['price'] as double;
    final int level = txn['vipLevel'] as int;
    final String duration = txn['duration'] as String;
    final String id = txn['id'] as String;
    final String paymentMethod = (txn['paymentMethod'] ?? 'UPI (Google Pay)') as String;
    final bool isGift = (txn['isGift'] ?? false) as bool;
    final String? friendName = txn['friend'] as String?;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Invoice Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AGORAX INVOICE',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),

                // Txn Info
                _buildInvoiceMetaRow('Invoice Number', id),
                _buildInvoiceMetaRow('Billing Date', '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'),
                _buildInvoiceMetaRow('Payment Status', 'PAID (Completed)', valueColor: const Color(0xFF10B981)),
                _buildInvoiceMetaRow('Payment Method', paymentMethod),
                
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),

                // Item description
                Text(
                  'BILLING ITEMS',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white60),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIP Level $level Membership',
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          isGift ? 'Gift subscription to @$friendName' : 'Personal subscription ($duration)',
                          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      '₹${rawPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),

                // Totals
                _buildTotalRow('Subtotal', '₹${(rawPrice / 1.18).toStringAsFixed(2)}'),
                _buildTotalRow('GST (18%)', '₹${(rawPrice - (rawPrice / 1.18)).toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildTotalRow(
                  'Grand Total',
                  '₹${rawPrice.toStringAsFixed(2)}',
                  isBold: true,
                  valueColor: const Color(0xFFD4AF37),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Get.snackbar('Mock PDF Generated', 'Invoice PDF downloaded to files.');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Download Invoice PDF', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceMetaRow(String label, String value, {Color valueColor = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
          Text(value, style: GoogleFonts.poppins(color: valueColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, Color valueColor = Colors.white}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: isBold ? Colors.white : Colors.white60,
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: valueColor,
            fontSize: isBold ? 18 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final VipController vipCtrl = Get.find<VipController>();

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: Text(
          'PURCHASE HISTORY',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        final history = vipCtrl.purchaseHistory;

        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🧾', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'No transactions found',
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final txn = history[index];
            final DateTime date = DateTime.tryParse(txn['date'] as String) ?? DateTime.now();
            final double price = txn['price'] as double;
            final int level = txn['vipLevel'] as int;
            final String duration = txn['duration'] as String;
            final bool isGift = (txn['isGift'] ?? false) as bool;
            final String? friendName = txn['friend'] as String?;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Text(
                      isGift ? 'Gifted VIP $level' : 'VIP $level Subscription',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    VipBadgeWidget(level: level, fontSize: 9, showIcon: false),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      isGift ? 'To: @$friendName | Duration: $duration' : 'Duration: $duration',
                      style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Date: ${date.day}/${date.month}/${date.year}',
                      style: GoogleFonts.poppins(color: Colors.white30, fontSize: 11),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _showInvoiceDialog(context, txn),
                      child: const Text(
                        'View Invoice',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 11, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
