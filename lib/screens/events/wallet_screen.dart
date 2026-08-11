import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:creania/core/theme.dart';
import '../../models/wallet/creania_balance_model.dart';
import '../../services/wallet/creania_balance_controller.dart';
import '../../services/store/store_controller.dart';
import '../wallet/exchange_crea_balance_screen.dart';
import '../wallet/withdraw_crea_balance_screen.dart';
import '../store/store_home_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late CreaniaBalanceController _cbController;
  late StoreController _storeController;

  @override
  void initState() {
    super.initState();
    _cbController = Get.isRegistered<CreaniaBalanceController>()
        ? Get.find<CreaniaBalanceController>()
        : Get.put(CreaniaBalanceController());
    _storeController = Get.isRegistered<StoreController>()
        ? Get.find<StoreController>()
        : Get.put(StoreController());
    _cbController.fetchWalletData();
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
          'Wallet & Balances',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.iconPrimary),
            onPressed: () => _cbController.fetchWalletData(),
          ),
        ],
      ),
      body: Obx(() {
        final wallet = _cbController.walletData.value;
        final goldCoins = _storeController.coinsBalance.value;
        final silverCoins = _storeController.silverCoinsBalance.value;
        final cbBalance = wallet?.creaniaBalance ?? 0;
        final pendingCb = wallet?.pendingCbBalance ?? 0;
        final inrVal = CreaniaBalanceConverter.cbToInr(cbBalance);

        return RefreshIndicator(
          onRefresh: () => _cbController.fetchWalletData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. MAIN CREANIA BALANCE CARD ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: const [
                                Text('💎', style: TextStyle(fontSize: 12)),
                                SizedBox(width: 6),
                                Text(
                                  'CREANIA BALANCE',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '500 CB = ₹2.00',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${NumberFormat('#,##,###').format(cbBalance)} CB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '≈ ${CreaniaBalanceConverter.formatInr(inrVal)} ${pendingCb > 0 ? "(Pending: ${NumberFormat('#,##,###').format(pendingCb)} CB)" : ""}',
                        style: TextStyle(
                          color: Colors.amber.shade300,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Get.to(() => const ExchangeCreaBalanceScreen()),
                              icon: const Icon(Icons.swap_horiz, color: Colors.black87, size: 16),
                              label: const Text('Exchange CB', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Get.to(() => const WithdrawCreaBalanceScreen()),
                              icon: const Icon(Icons.account_balance, color: Colors.white, size: 16),
                              label: const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.white24),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 2. GOLD & SILVER CURRENCY CARDS ──
                Row(
                  children: [
                    // Gold Coins Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Text('🪙', style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 4),
                                    Text('Gold Coins', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () => Get.to(() => const StoreHomeScreen()),
                                  child: const Text('+ Topup', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              NumberFormat('#,##,###').format(goldCoins),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            const Text('Spending Currency', style: TextStyle(color: Colors.white38, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Silver Coins Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Text('🥈', style: TextStyle(fontSize: 14)),
                                SizedBox(width: 4),
                                Text('Silver Coins', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              NumberFormat('#,##,###').format(silverCoins),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            const Text('Free Activity Coins', style: TextStyle(color: Colors.white38, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── 3. TRANSACTION HISTORY ──
                Text(
                  '📜 Creania Balance Audit History',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (wallet == null || wallet.transactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No transaction history found.', style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: wallet.transactions.length,
                    itemBuilder: (context, index) {
                      final tx = wallet.transactions[index];
                      final isCredit = tx.isCredit;
                      final color = isCredit ? const Color(0xFF10B981) : Colors.redAccent;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                color: color,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.displayTitle,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt),
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isCredit ? '+' : ''}${NumberFormat('#,##,###').format(tx.amountCb)} CB',
                                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '≈ ${CreaniaBalanceConverter.formatInr(tx.inrEquivalent.abs())}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
