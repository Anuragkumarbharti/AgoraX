import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';
import '../../services/event_controller.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final EventController _controller = Get.find<EventController>();
  final _withdrawFormKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _upiController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void _showWithdrawDialog() {
    _amountController.clear();
    _upiController.clear();

    Get.dialog(
      AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: context.primaryColor, size: 24),
            const SizedBox(width: 10),
            Text(
              'Withdraw Cash (₹)',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Form(
          key: _withdrawFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Funds will be transferred to your UPI ID instantly.',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter amount';
                  final amt = double.tryParse(v);
                  if (amt == null || amt <= 0) return 'Invalid amount';
                  if (amt > _controller.cashBalance.value) return 'Insufficient cash balance';
                  return null;
                },
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Amount to Withdraw',
                  labelStyle: TextStyle(color: context.caption, fontSize: 12),
                  filled: true,
                  fillColor: context.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _upiController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'UPI ID required';
                  if (!v.contains('@')) return 'Invalid UPI format (e.g. user@upi)';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'UPI ID (e.g. mobile@upi)',
                  labelStyle: TextStyle(color: context.caption, fontSize: 12),
                  filled: true,
                  fillColor: context.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: context.caption)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (_withdrawFormKey.currentState!.validate()) {
                final amt = double.parse(_amountController.text);
                final upi = _upiController.text.trim();
                final success = await _controller.withdrawCash(amt, upi);
                Get.back();
                if (success) {
                  Get.snackbar(
                    'Withdrawal Initiated 💰',
                    '₹$amt is being transferred to $upi',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF10B981),
                    colorText: Colors.white,
                  );
                }
              }
            },
            child: const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _depositMockMoney() {
    _controller.depositCash(500.0);
    Get.snackbar(
      'Mock Deposit Success 💳',
      'Added ₹500.00 mock cash to your wallet!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: context.accentOrange,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090B12) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Wallet',
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: isDark ? Colors.white : const Color(0xFF374151)),
            onPressed: _depositMockMoney,
          ),
        ],
      ),
      body: Obx(() {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Royal Purple Gradient Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6D5DF6), Color(0xFF4C3CD2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D5DF6).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Balance',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF4B400),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '29,549',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // 3D Coin Stack Graphic
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars_rounded, color: Color(0xFFF4B400), size: 36),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Recharge Coins Button
                    ElevatedButton.icon(
                      onPressed: _showWithdrawDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4B400),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF111827), size: 18),
                      label: Text(
                        'Recharge Coins',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. 4-Across Quick Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWalletActionItem(Icons.receipt_long_rounded, 'Purchase\nHistory', isDark),
                  _buildWalletActionItem(Icons.swap_horiz_rounded, 'Transactions', isDark),
                  _buildWalletActionItem(Icons.qr_code_rounded, 'Redeem\nCode', isDark),
                  _buildWalletActionItem(Icons.card_giftcard_rounded, 'Free Coins', isDark),
                ],
              ),
              const SizedBox(height: 28),

              // 3. Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'See all >',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF6D5DF6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Sample & Real Transactions List
              _buildTransactionCard('Gift Sent to Neha', 'Today, 10:30 AM', '-500', isPositive: false, isDark: isDark),
              _buildTransactionCard('Room Gift Received', 'Today, 09:15 AM', '+1200', isPositive: true, isDark: isDark),
              _buildTransactionCard('Quiz Reward', 'Today, 08:45 AM', '+200', isPositive: true, isDark: isDark),
              _buildTransactionCard('Coins Purchase', 'Yesterday, 07:20 PM', '+5000', isPositive: true, isDark: isDark),
              _buildTransactionCard('Entry Effect Purchase', 'Yesterday, 06:10 PM', '-300', isPositive: false, isDark: isDark),

              const SizedBox(height: 24),

              // 5. Get More Coins Promo Banner Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4C3CD2), Color(0xFF6D5DF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Get More Coins',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Exclusive coins packages',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'View Packages',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF6D5DF6),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.monetization_on_rounded, color: Color(0xFFF4B400), size: 48),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildWalletActionItem(IconData icon, String label, bool isDark) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151923) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2D3645) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: isDark ? Colors.white : const Color(0xFF374151), size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(String title, String subtitle, String amount, {required bool isPositive, required bool isDark}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151923) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2D3645) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive ? Icons.call_received_rounded : Icons.call_made_rounded,
                  color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            amount,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}
