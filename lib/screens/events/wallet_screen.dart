import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
            Icon(Icons.account_balance_wallet,
                color: context.primaryColor, size: 24),
            SizedBox(width: 10),
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
              SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white, fontSize: 14),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter amount';
                  final amt = double.tryParse(v);
                  if (amt == null || amt <= 0) return 'Invalid amount';
                  if (amt > _controller.cashBalance.value)
                    return 'Insufficient cash balance';
                  return null;
                },
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Amount to Withdraw',
                  labelStyle: TextStyle(color: context.caption, fontSize: 12),
                  filled: true,
                  fillColor: context.scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _upiController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: Colors.white, fontSize: 14),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'UPI ID required';
                  if (!v.contains('@'))
                    return 'Invalid UPI format (e.g. user@upi)';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'UPI ID (e.g. mobile@upi)',
                  labelStyle: TextStyle(color: context.caption, fontSize: 12),
                  filled: true,
                  fillColor: context.scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
                    backgroundColor: Color(0xFF10B981),
                    colorText: Colors.white,
                  );
                }
              }
            },
            child: Text('Withdraw',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: context.iconPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Wallet & History',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_card_rounded, color: context.accentOrange),
            tooltip: 'Deposit Mock Money',
            onPressed: _depositMockMoney,
          ),
        ],
      ),
      body: Obx(() {
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Double Balance Card
              _buildBalanceCards(),
              SizedBox(height: 24),

              // 2. Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(Icons.account_balance_wallet_outlined,
                          color: Colors.white),
                      label: Text('Withdraw Cash',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      onPressed: _showWithdrawDialog,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 28),

              // 3. Transactions List Header
              Text(
                '📜 Transaction History',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),

              // 4. Transactions List
              Expanded(
                child: _controller.walletTransactions.isEmpty
                    ? Center(
                        child: Text(
                          'No transactions yet.',
                          style:
                              TextStyle(color: context.caption, fontSize: 13),
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF475569),
                  Color(0xFF1E293B).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🪙', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 6),
                    Text(
                      'Silver Coins',
                      style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  '${_controller.silverCoins.value}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'For hosting events & tools',
                  style: TextStyle(color: context.caption, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 10),
        // Cash Card
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1B4B),
                  Color(0xFF0F172A).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('💰', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text(
                      'Cash Balance',
                      style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  '₹${_controller.cashBalance.value.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: context.accentOrange,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'For entry fees & winnings',
                  style: TextStyle(color: context.caption, fontSize: 9),
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

    if (type.contains('Paid') ||
        type.contains('Fee') ||
        type.contains('Withdrawal')) {
      icon = Icons.arrow_outward_rounded;
      iconColor = Colors.redAccent;
    } else {
      icon = Icons.call_received_rounded;
      iconColor = Color(0xFF10B981);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.12),
            radius: 18,
            child: Icon(icon, color: iconColor, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                            color: iconColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      date,
                      style: TextStyle(color: context.caption, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}$amount',
            style: TextStyle(
              color: isCredit ? context.successColor : context.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
