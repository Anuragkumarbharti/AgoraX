import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:creania/core/theme.dart';
import '../../models/wallet/creania_balance_model.dart';
import '../../services/wallet/creania_balance_controller.dart';
import 'exchange_crea_balance_screen.dart';
import 'withdraw_crea_balance_screen.dart';

class CreaniaBalanceWalletScreen extends StatefulWidget {
  const CreaniaBalanceWalletScreen({Key? key}) : super(key: key);

  @override
  State<CreaniaBalanceWalletScreen> createState() => _CreaniaBalanceWalletScreenState();
}

class _CreaniaBalanceWalletScreenState extends State<CreaniaBalanceWalletScreen> with SingleTickerProviderStateMixin {
  final CreaniaBalanceController _controller = CreaniaBalanceController.to;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _controller.fetchWalletData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Creania Balance Wallet',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => _controller.fetchWalletData(),
          ),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.walletData.value == null) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        }

        final wallet = _controller.walletData.value;
        final cb = wallet?.creaniaBalance ?? 0;
        final pendingCb = wallet?.pendingCbBalance ?? 0;
        final lifetimeEarned = wallet?.lifetimeEarnedCb ?? 0;
        final lifetimeWithdrawn = wallet?.lifetimeWithdrawnCb ?? 0;

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () => _controller.fetchWalletData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. MAIN BALANCE CAROUSEL CARD ──
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
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
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
                                Icon(Icons.account_balance_wallet, color: Colors.amber, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'CREANIA BALANCE',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '500 CB = ₹2.00',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        NumberFormat('#,##,###').format(cb) + ' CB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '≈ ${CreaniaBalanceConverter.formatInr(CreaniaBalanceConverter.cbToInr(cb))}',
                        style: TextStyle(
                          color: Colors.amber.shade300,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons: Exchange & Withdraw
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Get.to(() => const ExchangeCreaBalanceScreen()),
                              icon: const Icon(Icons.swap_horiz, color: Colors.black87, size: 18),
                              label: const Text(
                                'Exchange CB',
                                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Get.to(() => const WithdrawCreaBalanceScreen()),
                              icon: const Icon(Icons.account_balance, color: Colors.white, size: 18),
                              label: const Text(
                                'Withdraw',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
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

                // ── 2. METRIC STAT CARDS ──
                Row(
                  children: [
                    _buildStatMiniCard(
                      title: 'Pending Settlement',
                      cbValue: pendingCb + (wallet?.familyPendingCb ?? 0),
                      icon: Icons.hourglass_top,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 12),
                    _buildStatMiniCard(
                      title: 'Lifetime Earned',
                      cbValue: lifetimeEarned,
                      icon: Icons.trending_up,
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatMiniCard(
                      title: 'Lifetime Withdrawn',
                      cbValue: lifetimeWithdrawn,
                      icon: Icons.outbox,
                      color: Colors.lightBlueAccent,
                    ),
                    const SizedBox(width: 12),
                    _buildStatMiniCard(
                      title: 'KYC Status',
                      customText: (wallet?.kycVerified ?? false) ? 'Verified ✓' : 'Unverified',
                      icon: Icons.verified_user,
                      color: (wallet?.kycVerified ?? false) ? const Color(0xFF10B981) : Colors.redAccent,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── 3. EARNINGS BREAKDOWN ──
                const Text(
                  'Earnings Breakdown',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    _buildBreakdownTile('Gift Earnings', wallet?.giftEarningsCb ?? 0, Icons.card_giftcard, const Color(0xFFEC4899)),
                    _buildBreakdownTile('Room Earnings', wallet?.roomEarningsCb ?? 0, Icons.mic, const Color(0xFF8B5CF6)),
                    _buildBreakdownTile('Community Earnings', wallet?.communityEarningsCb ?? 0, Icons.groups, const Color(0xFF3B82F6)),
                    _buildBreakdownTile('Family Earnings', wallet?.familyEarningsCb ?? 0, Icons.shield, const Color(0xFFF59E0B)),
                  ],
                ),

                const SizedBox(height: 24),

                // ── 4. TABBED HISTORY & AUDIT LOG ──
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF10B981),
                  labelColor: const Color(0xFF10B981),
                  unselectedLabelColor: Colors.white60,
                  tabs: const [
                    Tab(text: 'Ledger History'),
                    Tab(text: 'Withdrawals'),
                    Tab(text: 'Family Settlements'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 380,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLedgerList(wallet?.transactions ?? []),
                      _buildWithdrawalsList(wallet?.withdrawals ?? []),
                      _buildFamilySettlementsList(wallet?.familySettlements ?? []),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatMiniCard({
    required String title,
    int? cbValue,
    String? customText,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (customText != null)
              Text(
                customText,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
              )
            else ...[
              Text(
                '${NumberFormat('#,##,###').format(cbValue ?? 0)} CB',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                '≈ ${CreaniaBalanceConverter.formatInr(CreaniaBalanceConverter.cbToInr(cbValue ?? 0))}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownTile(String label, int cb, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${NumberFormat('#,##,###').format(cb)} CB',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  '≈ ${CreaniaBalanceConverter.formatInr(CreaniaBalanceConverter.cbToInr(cb))}',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerList(List<CreaniaBalanceTransaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text('No transaction history found.', style: TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
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
    );
  }

  Widget _buildWithdrawalsList(List<WithdrawalRecord> withdrawals) {
    if (withdrawals.isEmpty) {
      return const Center(
        child: Text('No withdrawal requests yet.', style: TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }

    return ListView.builder(
      itemCount: withdrawals.length,
      itemBuilder: (context, index) {
        final wd = withdrawals[index];
        Color statusColor = Colors.orangeAccent;
        if (wd.status == 'Completed') statusColor = const Color(0xFF10B981);
        if (wd.status == 'Rejected' || wd.status == 'Reversed') statusColor = Colors.redAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.outbox, color: statusColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wd.id,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'UPI: ${wd.upiId}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(wd.createdAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${wd.netPayoutInr.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      wd.status,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFamilySettlementsList(List<FamilySettlementRecord> settlements) {
    if (settlements.isEmpty) {
      return const Center(
        child: Text('No weekend family settlements recorded.', style: TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }

    return ListView.builder(
      itemCount: settlements.length,
      itemBuilder: (context, index) {
        final st = settlements[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield, color: Colors.amber, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      st.id,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Settled: ${NumberFormat('#,##,###').format(st.finalSettledCb)} CB',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(st.settledAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Text(
                '≈ ₹${st.inrValue.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}
