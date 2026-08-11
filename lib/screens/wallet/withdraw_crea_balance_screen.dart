import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/wallet/creania_balance_model.dart';
import '../../services/wallet/creania_balance_controller.dart';

class WithdrawCreaBalanceScreen extends StatefulWidget {
  const WithdrawCreaBalanceScreen({Key? key}) : super(key: key);

  @override
  State<WithdrawCreaBalanceScreen> createState() => _WithdrawCreaBalanceScreenState();
}

class _WithdrawCreaBalanceScreenState extends State<WithdrawCreaBalanceScreen> {
  final CreaniaBalanceController _controller = CreaniaBalanceController.to;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _payoutMethod = 'razorpay_upi'; // 'razorpay_upi' or 'razorpay_bank'

  @override
  void initState() {
    super.initState();
    _amountController.text = '250000';
    final wallet = _controller.walletData.value;
    if (wallet != null) {
      if (wallet.upiId != null) _upiController.text = wallet.upiId!;
      if (wallet.bankAccountName != null) _nameController.text = wallet.bankAccountName!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Withdraw Creania Balance',
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        final wallet = _controller.walletData.value;
        final availableCb = wallet?.creaniaBalance ?? 0;
        final minCb = wallet?.config.minWithdrawalCb ?? 250000;
        final inputCb = int.tryParse(_amountController.text) ?? 0;
        final inrVal = CreaniaBalanceConverter.cbToInr(inputCb);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. AVAILABLE BALANCE CARD ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available For Withdrawal', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            '${NumberFormat('#,##,###').format(availableCb)} CB',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '≈ ${CreaniaBalanceConverter.formatInr(CreaniaBalanceConverter.cbToInr(availableCb))}',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 2. RAZORPAY PAYOUT DISBURSAL BANNER ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_on_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Razorpay Instant Disbursal Engine',
                              style: TextStyle(color: Color(0xFF1E40AF), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Instant direct transfer via Razorpay Payouts (Min ₹1,000 / 250,000 CB).',
                              style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Withdrawal Details',
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Amount Input (Min 250,000 CB = ₹1,000)
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter CB amount';
                    final val = int.tryParse(v);
                    if (val == null || val <= 0) return 'Invalid CB amount';
                    if (val < minCb) return 'Minimum withdrawal is ${NumberFormat('#,##,###').format(minCb)} CB (≈ ₹1,000.00)';
                    if (val > availableCb) return 'Exceeds available CB balance';
                    return null;
                  },
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Withdrawal Amount (CB)',
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    suffixText: '≈ ₹${inrVal.toStringAsFixed(2)}',
                    suffixStyle: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Razorpay Verified UPI ID Input
                TextFormField(
                  controller: _upiController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Razorpay UPI ID is required';
                    if (!v.contains('@')) return 'Invalid UPI format (e.g. mobile@upi)';
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Razorpay Disbursal UPI ID (e.g. 9876543210@paytm)',
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Account Name Input
                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Account Holder Name (Optional)',
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildRow('Requested CB', '${NumberFormat('#,##,###').format(inputCb)} CB'),
                      const Divider(color: Color(0xFFF1F5F9), height: 18),
                      _buildRow('Disbursal Amount', '₹${inrVal.toStringAsFixed(2)}'),
                      const Divider(color: Color(0xFFF1F5F9), height: 18),
                      _buildRow('Razorpay Processing Fee', '₹0.00 (Covered by Creania)'),
                      const Divider(color: Color(0xFFF1F5F9), height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Instant Disbursal', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('₹${inrVal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_controller.isProcessingAction.value || inputCb < minCb || inputCb > availableCb)
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              final amt = int.parse(_amountController.text);
                              final upi = _upiController.text.trim();
                              final name = _nameController.text.trim();

                              final success = await _controller.requestWithdrawal(
                                amountCb: amt,
                                upiId: upi,
                                accountName: name,
                              );
                              if (success) {
                                Get.back();
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _controller.isProcessingAction.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            inputCb < minCb
                                ? 'Minimum Withdrawal is ₹1,000 (250k CB)'
                                : 'Request Razorpay Instant Disbursal',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
