import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
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
        backgroundColor: AppTheme.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor, size: 24),
            SizedBox(width: 10),
            Text(
              'Withdraw Cash (₹)',
              style: TextStyle(
                color: AppTheme.textPrimary,
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
              const Text(
                'Funds will be transferred to your UPI ID instantly.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                  labelStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.bgDark,
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
                  labelStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (_withdrawFormKey.currentState!.validate()) {
                final amt = double.parse(_amountController.text);
                final upi = _upiController.text.trim();
                final success = _controller.withdrawCash(amt, upi);
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
      backgroundColor: AppTheme.accentColor,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Wallet & History',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card_rounded, color: AppTheme.accentColor),
            tooltip: 'Deposit Mock Money',
            onPressed: _depositMockMoney,
          ),
        ],
      ),
      body: Obx(() {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Double Balance Card
              _buildBalanceCards(),
              const SizedBox(height: 24),

              // 2. Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
                      label: const Text('Withdraw Cash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: _showWithdrawDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 3. Transactions List Header
              const Text(
                '📜 Transaction History',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // 4. Transactions List
              Expanded(
                child: _controller.walletTransactions.isEmpty
                    ? const Center(
                        child: Text(
                          'No transactions yet.',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _controller.walletTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = _controller.walletTransactions[index];
                          return _buildTransactionRow(tx);
                        },
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBalanceCards() {
    return Row(
      children: [
        // Silver Coins Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF475569),
                  const Color(0xFF1E293B).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🪙', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 6),
                    Text(
                      'Silver Coins',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_controller.silverCoins.value}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'For hosting events & tools',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Cash Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E1B4B),
                  const Color(0xFF0F172A).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('💰', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text(
                      'Cash Balance',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '₹${_controller.cashBalance.value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'For entry fees & winnings',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(Map<String, dynamic> tx) {
    final bool isCredit = tx['isCredit'] as bool;
    final String amount = tx['amount'] as String;
    final String type = tx['type'] as String;
    final String title = tx['title'] as String;
    final String date = tx['date'] as String;
    
    IconData icon;
    Color iconColor;

    if (type.contains('Paid') || type.contains('Fee') || type.contains('Withdrawal')) {
      icon = Icons.arrow_outward_rounded;
      iconColor = Colors.redAccent;
    } else {
      icon = Icons.call_received_rounded;
      iconColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.12),
            radius: 18,
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bgDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(color: iconColor, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}$amount',
            style: TextStyle(
              color: isCredit ? const Color(0xFF10B981) : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
