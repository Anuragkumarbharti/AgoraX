import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/wallet/creania_balance_model.dart';
import '../../services/wallet/creania_balance_controller.dart';

class ExchangeCreaBalanceScreen extends StatefulWidget {
  const ExchangeCreaBalanceScreen({Key? key}) : super(key: key);

  @override
  State<ExchangeCreaBalanceScreen> createState() => _ExchangeCreaBalanceScreenState();
}

class _ExchangeCreaBalanceScreenState extends State<ExchangeCreaBalanceScreen> {
  final CreaniaBalanceController _controller = CreaniaBalanceController.to;
  int _selectedCb = 10000;
  String _targetCurrency = 'gold'; // 'gold' or 'silver'

  // Predefined Recharge-Style Exchange Packages (500 CB = 1 Gold / 200 Silver)
  final List<Map<String, dynamic>> _exchangePackages = [
    {
      'cb': 5000,
      'goldBase': 10,
      'goldBonus': 0,
      'silverBase': 2000,
      'silverBonus': 0,
      'tag': '⭐ MINIMUM STARTS HERE (10 GOLD)',
    },
    {
      'cb': 10000,
      'goldBase': 20,
      'goldBonus': 9,
      'silverBase': 4000,
      'silverBonus': 1800,
      'tag': '✨ 9 BONUS COINS (₹40)',
    },
    {
      'cb': 25000,
      'goldBase': 50,
      'goldBonus': 25,
      'silverBase': 10000,
      'silverBonus': 5000,
      'tag': '🔥 POPULAR (25 BONUS GOLD)',
    },
    {
      'cb': 50000,
      'goldBase': 100,
      'goldBonus': 60,
      'silverBase': 20000,
      'silverBonus': 12000,
      'tag': '⚡ BEST VALUE (60 BONUS GOLD)',
    },
    {
      'cb': 100000,
      'goldBase': 200,
      'goldBonus': 150,
      'silverBase': 40000,
      'silverBonus': 30000,
      'tag': '👑 MEGA PACK (150 BONUS GOLD)',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isGold = _targetCurrency == 'gold';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Pure Light Theme Background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Exchange Creania Balance',
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        final wallet = _controller.walletData.value;
        final availableCb = wallet?.creaniaBalance ?? 0;
        final selectedPkg = _exchangePackages.firstWhere(
          (p) => p['cb'] == _selectedCb,
          orElse: () => _exchangePackages[1],
        );

        final int cbCost = selectedPkg['cb'];
        final double inrVal = CreaniaBalanceConverter.cbToInr(cbCost);
        final int baseOutput = isGold ? selectedPkg['goldBase'] : selectedPkg['silverBase'];
        final int bonusOutput = isGold ? selectedPkg['goldBonus'] : selectedPkg['silverBonus'];
        final int totalOutput = baseOutput + bonusOutput;
        final String currencySymbol = isGold ? '🪙' : '🥈';
        final String currencyLabel = isGold ? 'Gold Coins' : 'Silver Coins';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. LIGHT THEME AVAILABLE BALANCE CARD ──
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
                        const Text(
                          'Available Creania Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${NumberFormat('#,##,###').format(availableCb)} CB',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
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

              const SizedBox(height: 20),

              // ── 2. LIGHT THEME CURRENCY TOGGLE TABS ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _targetCurrency = 'gold'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isGold ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isGold
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('🪙', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Text(
                                'Exchange to Gold',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _targetCurrency = 'silver'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isGold ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !isGold
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('🥈', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Text(
                                'Exchange to Silver',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 3. RECHARGE PACKAGES GRID ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select $currencyLabel Package',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Bonus starts at ₹40',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exchangePackages.length,
                itemBuilder: (context, index) {
                  final pkg = _exchangePackages[index];
                  final bool isSelected = _selectedCb == pkg['cb'];
                  final int pBase = isGold ? pkg['goldBase'] : pkg['silverBase'];
                  final int pBonus = isGold ? pkg['goldBonus'] : pkg['silverBonus'];
                  final int pTotal = pBase + pBonus;
                  final String? pTag = pkg['tag'];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCb = pkg['cb'];
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0xFF10B981).withOpacity(0.12)
                                : Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Currency Icon
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: isGold ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(currencySymbol, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Package Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (pTag != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      pTag,
                                      style: const TextStyle(color: Color(0xFF059669), fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                Text(
                                  '${NumberFormat('#,##,###').format(pTotal)} $currencyLabel',
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                if (pBonus > 0) ...[
                                  Text(
                                    'Includes ${NumberFormat('#,##,###').format(pBonus)} Bonus $currencyLabel',
                                    style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Price Chip (CB Cost Only - INR subtext removed as requested)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${NumberFormat('#,##,###').format(pkg['cb'])} CB',
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── 4. CONFIRMATION SUMMARY CARD ──
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Exchanging', '${NumberFormat('#,##,###').format(cbCost)} CB (≈ ₹${inrVal.toStringAsFixed(2)})'),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildSummaryRow('Base $currencyLabel', NumberFormat('#,##,###').format(baseOutput)),
                    if (bonusOutput > 0) ...[
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildSummaryRow('Bonus Coins', '+${NumberFormat('#,##,###').format(bonusOutput)}', highlightColor: const Color(0xFFD97706)),
                    ],
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'You Receive Total',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${NumberFormat('#,##,###').format(totalOutput)} $currencyLabel',
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 5. CONFIRM EXCHANGE BUTTON ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_controller.isProcessingAction.value || cbCost > availableCb)
                      ? null
                      : () => _confirmExchange(cbCost, totalOutput, currencyLabel),
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
                          cbCost > availableCb ? 'Insufficient CB Balance' : 'Confirm Exchange Now',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color highlightColor = const Color(0xFF0F172A)}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value, style: TextStyle(color: highlightColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _confirmExchange(int cbCost, int totalOutput, String currencyLabel) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Exchange',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to exchange ${NumberFormat('#,##,###').format(cbCost)} CB for ${NumberFormat('#,##,###').format(totalOutput)} $currencyLabel?',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Get.back();
              final success = await _controller.exchangeCbCurrency(
                amountCb: cbCost,
                targetCurrency: _targetCurrency,
              );
              if (success) Get.back();
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
