import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';
import '../../services/study_vault_controller.dart';
import '../../models/study_vault_model.dart';
import 'upload_book_screen.dart';
import '../../services/user_profile_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final StudyVaultController _controller = Get.find<StudyVaultController>();
  late TabController _tabController;

  final TextEditingController _withdrawAmountController = TextEditingController();
  final TextEditingController _withdrawUpiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _withdrawAmountController.dispose();
    _withdrawUpiController.dispose();
    super.dispose();
  }

  void _showWithdrawModal() {
    final wallet = _controller.sellerWallet.value;
    _withdrawAmountController.text = wallet.withdrawableBalance.toString();
    final uName = UserProfileCacheManager.currentUser?.username ?? Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'user';
    _withdrawUpiController.text = '$uName@upi';

    Get.dialog(
      Dialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REQUEST WITHDRAWAL',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Funds will be transferred to your UPI ID or bank account within 24 hours.',
                style: GoogleFonts.poppins(color: context.caption, fontSize: 11),
              ),
              SizedBox(height: 16),
              Text(
                'Withdrawable Balance: ₹${wallet.withdrawableBalance.toStringAsFixed(2)}',
                style: TextStyle(color: context.accentOrange, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _withdrawAmountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Withdrawal Amount (₹)',
                  labelStyle: TextStyle(color: context.caption, fontSize: 12),
                  fillColor: Colors.black.withOpacity(0.2),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _withdrawUpiController,
                style: TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'UPI ID or Bank Details',
                  labelStyle: TextStyle(color: context.caption, fontSize: 12),
                  fillColor: Colors.black.withOpacity(0.2),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel', style: GoogleFonts.poppins(color: context.caption)),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final double amt = double.tryParse(_withdrawAmountController.text) ?? 0.0;
                      final String upi = _withdrawUpiController.text.trim();
                      if (amt <= 0 || upi.isEmpty) {
                        Get.snackbar('Error ⚠️', 'Please enter a valid amount and payout details.');
                        return;
                      }

                      final success = _controller.requestWithdrawal(amt, upi);
                      if (success) {
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: context.primaryColor),
                    child: Text('Withdraw', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Seller Dashboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: context.secondaryBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: Colors.white),
            onPressed: () {
              Get.snackbar(
                'Seller Guide 📚',
                'Upload resource, set base price. Creania handles GST (18%), Platform (17%), Gateway (2%). Net payout (63%) is added directly to your Wallet.',
                duration: const Duration(seconds: 5),
              );
            },
          )
        ],
      ),
      body: Obx(() {
        // Find user uploaded items
        final sellerItems = _controller.items.where((item) => item.sellerId == 'me').toList();
        final approvedItems = sellerItems.where((item) => item.status == 'Approved').toList();
        final pendingItems = sellerItems.where((item) => item.status == 'Pending').toList();
        final rejectedItems = sellerItems.where((item) => item.status == 'Rejected').toList();

        final wallet = _controller.sellerWallet.value;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Seller Profile Summary Card
              _buildSellerProfileCard(),
              
              // 2. Financial Metrics overview
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _buildStatCard('Total Sales', '${wallet.totalSales}', Icons.shopping_bag_outlined, Color(0xFF6366F1)),
                    _buildStatCard('Total Earnings', '₹${wallet.totalEarnings.toStringAsFixed(0)}', Icons.monetization_on_outlined, Color(0xFF10B981)),
                    _buildStatCard('Profile Views', '8.4K', Icons.remove_red_eye_outlined, Color(0xFF06B6D4)),
                    _buildStatCard('Resource Downloads', '1.9K', Icons.cloud_download_outlined, Color(0xFFEC4899)),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // 3. Wallet details & withdrawal card
              _buildWalletDetailsCard(wallet),

              // 4. Transaction History
              _buildTransactionsList(),

              SizedBox(height: 24),
              // 5. Uploaded Content tab sections
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'YOUR CATALOG',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Get.to(() => const UploadBookScreen()),
                      icon: Icon(Icons.add, size: 14),
                      label: Text('Upload Resource', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primaryColor,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 12),

              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: context.secondaryBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: 'Approved (${approvedItems.length})'),
                    Tab(text: 'Pending (${pendingItems.length})'),
                    Tab(text: 'Rejected (${rejectedItems.length})'),
                  ],
                  indicatorColor: context.primaryColor,
                  labelColor: context.primaryColor,
                  unselectedLabelColor: context.caption,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),

              SizedBox(
                height: 300,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCatalogList(approvedItems, 'No approved resources yet.'),
                    _buildCatalogList(pendingItems, 'No pending approvals.'),
                    _buildCatalogList(rejectedItems, 'No rejected resources.'),
                  ],
                ),
              ),
              SizedBox(height: 30),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSellerProfileCard() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(UserProfileCacheManager.currentUser?.avatar ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          UserProfileCacheManager.currentUser?.username ?? Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'Seller',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.accentOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: context.accentOrange, size: 10),
                              SizedBox(width: 2),
                              Text('VERIFIED SELLER', style: TextStyle(color: context.accentOrange, fontSize: 8, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Joined: ${_controller.sellerJoinedDate.value}  |  Response Rate: ${_controller.responseRate.value}%',
                      style: TextStyle(color: context.caption, fontSize: 11),
                    )
                  ],
                ),
              )
            ],
          ),
          Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _profileStat('⭐ ${_controller.sellerRating.value}', 'Seller Rating'),
              _profileStat('👥 ${_controller.sellerFollowers.value}', 'Followers'),
              _profileStat('📝 ${_controller.items.where((i) => i.sellerId == 'me').length}', 'Resources'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(color: context.caption, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(color: context.caption, fontSize: 9.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletDetailsCard(VaultWallet wallet) {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 4, 20, 20),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFD700).withOpacity(0.03),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFFD700), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Seller Wallet',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showWithdrawModal,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Withdraw Funds',
                    style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WITHDRAWABLE BALANCE', style: TextStyle(color: context.caption, fontSize: 9)),
                    SizedBox(height: 4),
                    Text(
                      '₹${wallet.withdrawableBalance.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(color: context.accentOrange, fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white10),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PENDING BALANCE', style: TextStyle(color: context.caption, fontSize: 9)),
                    SizedBox(height: 4),
                    Text(
                      '₹${wallet.pendingBalance.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
            ],
          ),
          Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Revenue Earned: ₹${wallet.totalEarnings.toStringAsFixed(2)}', style: TextStyle(color: context.textSecondary, fontSize: 11)),
              Text('Refunds Processed: ₹${wallet.refunds.toStringAsFixed(2)}', style: TextStyle(color: context.errorColor, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSACTION HISTORY',
            style: GoogleFonts.outfit(
              color: Colors.white30,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 10),
          _controller.sellerTransactions.isEmpty
              ? Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text('No transaction logs found.', style: TextStyle(color: context.caption, fontSize: 12)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: min(3, _controller.sellerTransactions.length),
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final tx = _controller.sellerTransactions[i];
                    final isWithdrawal = tx.type == 'Withdrawal';
                    final isPending = tx.status == 'Pending';

                    return Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.bookTitle,
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${tx.type}  |  ${tx.dateTime.day}/${tx.dateTime.month} ${tx.dateTime.hour}:${tx.dateTime.minute}',
                                style: TextStyle(color: context.caption, fontSize: 10),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isWithdrawal ? "-" : "+"} ₹${tx.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isWithdrawal ? context.errorColor : context.accentOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isPending ? Colors.amber : (tx.status == 'Completed' ? Colors.green : Colors.red)).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tx.status.toUpperCase(),
                                  style: TextStyle(
                                    color: isPending ? Colors.amber : (tx.status == 'Completed' ? Colors.green : Colors.red),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildCatalogList(List<StudyVaultItem> list, String emptyMessage) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(emptyMessage, style: TextStyle(color: context.caption, fontSize: 13)),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final priceBreakdown = _controller.calculatePriceBreakdown(item.sellingPrice);

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(item.coverImage, width: 50, height: 70, fit: BoxFit.cover),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${item.fileType}  |  ${item.pages} Pages',
                      style: TextStyle(color: context.caption, fontSize: 10),
                    ),
                    SizedBox(height: 4),
                    Text(
                      item.sellingPrice == 0.0 ? 'FREE' : 'Buyer Price: ₹${priceBreakdown['buyerPays']!.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: item.sellingPrice == 0.0 ? context.accentOrange : Color(0xFFFFD700),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              if (item.status == 'Rejected' && item.adminComment != null)
                IconButton(
                  icon: Icon(Icons.comment_outlined, color: context.errorColor, size: 18),
                  onPressed: () {
                    Get.defaultDialog(
                      title: 'Rejection Reason ❌',
                      titleStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                      backgroundColor: context.secondaryBackgroundColor,
                      content: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text(
                          item.adminComment!,
                          style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                        ),
                      ),
                      cancel: TextButton(onPressed: () => Get.back(), child: Text('Close')),
                    );
                  },
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.purchasesCount} Sales',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (item.status == 'Approved'
                              ? Colors.green
                              : (item.status == 'Pending' ? Colors.amber : Colors.red))
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.status.toUpperCase(),
                      style: TextStyle(
                        color: item.status == 'Approved'
                            ? Colors.green
                            : (item.status == 'Pending' ? Colors.amber : Colors.red),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
