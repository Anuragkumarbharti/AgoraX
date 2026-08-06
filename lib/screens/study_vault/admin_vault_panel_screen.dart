import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';
import '../../services/vault/study_vault_controller.dart';
import '../../services/memberships/vip_controller.dart';
import '../../services/memberships/novel_controller.dart';
import '../../services/store/store_controller.dart';
import '../../models/vault/study_vault_model.dart';

class AdminVaultPanelScreen extends StatefulWidget {
  const AdminVaultPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminVaultPanelScreen> createState() => _AdminVaultPanelScreenState();
}

class _AdminVaultPanelScreenState extends State<AdminVaultPanelScreen>
    with SingleTickerProviderStateMixin {
  final StudyVaultController _controller = Get.find<StudyVaultController>();
  late TabController _tabController;

  // Official Upload Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _pagesController = TextEditingController(text: '150');
  
  String _selectedCategory = 'Coding';
  int _selectedVipLevel = 3; // Default VIP3
  String _coverImage = 'https://images.unsplash.com/photo-1516979187457-637abb4f9353?w=400';

  final List<String> _categories = ['Coding', 'Engineering', 'Medical', 'MBA', 'BCA', 'UPSC', 'GATE', 'AI', 'Cyber Security', 'Research'];
  final List<int> _vipLevels = [0, 1, 2, 3, 4, 5];

  final TextEditingController _rejectCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _subController.dispose();
    _descController.dispose();
    _pagesController.dispose();
    _rejectCommentController.dispose();
    super.dispose();
  }

  void _showRejectDialog(String bookId) {
    _rejectCommentController.clear();
    Get.dialog(
      Dialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REJECT STUDY RESOURCE',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _rejectCommentController,
                maxLines: 3,
                style: TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejection (e.g. low resolution scan, copyright logo found)...',
                  hintStyle: TextStyle(color: context.caption, fontSize: 12),
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
                      final comment = _rejectCommentController.text.trim();
                      if (comment.isEmpty) {
                        Get.snackbar('Error ⚠️', 'Please enter a rejection reason.');
                        return;
                      }
                      _controller.adminRejectBook(bookId, comment);
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
                    child: Text('Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _uploadOfficial() {
    if (_titleController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      Get.snackbar('Error ⚠️', 'Title and Description are required for official books.');
      return;
    }

    _controller.adminUploadOfficialBook(
      title: _titleController.text.trim(),
      subtitle: _subController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      vipLevel: _selectedVipLevel,
      pages: int.tryParse(_pagesController.text) ?? 150,
      coverUrl: _coverImage,
    );

    _titleController.clear();
    _subController.clear();
    _descController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Admin Panel (Study Vault)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: context.secondaryBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.rate_review_outlined), text: 'Reviews'),
            Tab(icon: Icon(Icons.cloud_upload_outlined), text: 'Official'),
            Tab(icon: Icon(Icons.payments_outlined), text: 'Payouts'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Settings'),
          ],
          indicatorColor: context.primaryColor,
          labelColor: context.primaryColor,
          unselectedLabelColor: context.caption,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
      body: Obx(() {
        final pendingApprovals = _controller.items.where((b) => b.status == 'Pending').toList();
        final pendingWithdrawals = _controller.sellerTransactions.where((tx) => tx.type == 'Withdrawal' && tx.status == 'Pending').toList();

        return TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Pending Approvals
            _buildApprovalsTab(pendingApprovals),

            // Tab 2: Upload Official Content
            _buildOfficialTab(),

            // Tab 3: Withdrawal requests & Piracy Reports
            _buildPayoutsTab(pendingWithdrawals),

            // Tab 4: General Settings
            _buildSettingsTab(),
          ],
        );
      }),
    );
  }

  Widget _buildApprovalsTab(List<StudyVaultItem> list) {
    if (list.isEmpty) {
      return Center(
        child: Text('No resources pending approval.', style: TextStyle(color: context.caption)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final book = list[i];
        final priceBreakdown = _controller.calculatePriceBreakdown(book.sellingPrice);

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          color: context.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(book.coverImage, width: 50, height: 75, fit: BoxFit.cover),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(book.fileType.toUpperCase(), style: TextStyle(color: context.primaryColor, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(height: 6),
                          Text(book.title, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('By ${book.authorName}  |  Seller: ${book.sellerName}', style: TextStyle(color: context.caption, fontSize: 11)),
                          SizedBox(height: 6),
                          Text(
                            book.sellingPrice == 0.0 ? 'FREE' : 'Price: ₹${priceBreakdown['buyerPays']!.toStringAsFixed(0)} (Seller gets: ₹${priceBreakdown['sellerReceives']!.toStringAsFixed(0)})',
                            style: TextStyle(
                              color: book.sellingPrice == 0.0 ? context.accentOrange : Color(0xFFFFD700),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  book.description,
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Divider(color: Colors.white10, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(book.id),
                      icon: Icon(Icons.close, size: 14, color: context.errorColor),
                      label: Text('Reject', style: TextStyle(color: context.errorColor, fontSize: 12)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: context.errorColor)),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _controller.adminApproveBook(book.id),
                      icon: Icon(Icons.check, size: 14),
                      label: Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: context.accentOrange),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfficialTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPLOAD OFFICIAL CREANIAA STUDY RESOURCE',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
          ),
          SizedBox(height: 14),
          _buildTextField(_titleController, 'Book Title', 'e.g. UPSC Prelims Civil Services Manual'),
          SizedBox(height: 12),
          _buildTextField(_subController, 'Subtitle', 'e.g. Complete Syllabus, visual diagrams, and 5-year past solve keys'),
          SizedBox(height: 12),
          _buildTextField(_descController, 'Description', 'Formal academic manual for members.', maxLines: 3),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  'Required Membership Level',
                  _selectedVipLevel,
                  _vipLevels,
                  (val) => setState(() => _selectedVipLevel = val!),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDropdownFieldString(
                  'Category Collection',
                  _selectedCategory,
                  _categories,
                  (val) => setState(() => _selectedCategory = val!),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField(_pagesController, 'Total Pages', 'e.g. 350', keyboardType: TextInputType.number)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cover Image Option', style: TextStyle(color: context.caption, fontSize: 11)),
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Text('Official Cover Locked', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              )
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _uploadOfficial,
              style: ElevatedButton.styleFrom(backgroundColor: context.primaryColor),
              child: Text('Upload Official Resource', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsTab(List<VaultTransaction> pendingWithdrawals) {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        Text(
          'PENDING WITHDRAWALS (${pendingWithdrawals.length})',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
        ),
        SizedBox(height: 10),
        pendingWithdrawals.isEmpty
            ? Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('No payouts pending approval.', style: TextStyle(color: context.caption, fontSize: 12))),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingWithdrawals.length,
                itemBuilder: (context, i) {
                  final tx = pendingWithdrawals[i];
                  return Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx.bookTitle, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Awaiting UPI Settlement  |  ₹${tx.amount.toStringAsFixed(2)}', style: TextStyle(color: context.caption, fontSize: 11)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => _controller.adminApproveWithdrawal(tx.id),
                          style: ElevatedButton.styleFrom(backgroundColor: context.accentOrange, padding: EdgeInsets.symmetric(horizontal: 14)),
                          child: Text('Approve Settlement', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  );
                },
              ),
        SizedBox(height: 24),
        Text(
          'COPYRIGHT & PIRACY COMPLAINTS (${_controller.piracyReports.length})',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
        ),
        SizedBox(height: 10),
        _controller.piracyReports.isEmpty
            ? Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('No piracy complaints logged.', style: TextStyle(color: context.caption, fontSize: 12))),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _controller.piracyReports.length,
                itemBuilder: (context, i) {
                  final rep = _controller.piracyReports[i];
                  return Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.errorColor.withOpacity(0.3), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(rep['bookTitle'], style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: context.errorColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                              child: Text('REPORTED', style: TextStyle(color: context.errorColor, fontSize: 8, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        SizedBox(height: 6),
                        Text('Reporter: ${rep['reporter']}', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                        Text('Reason: ${rep['reason']}', style: TextStyle(color: context.caption, fontSize: 11)),
                        Divider(color: Colors.white10, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                _controller.piracyReports.removeAt(i);
                                Get.snackbar('Dismissed ✅', 'Piracy complaint dismissed.');
                              },
                              child: Text('Dismiss', style: TextStyle(color: context.caption, fontSize: 11)),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final itemsList = _controller.items;
                                final itemIdx = itemsList.indexWhere((item) => item.title == rep['bookTitle']);
                                if (itemIdx != -1) {
                                  _controller.items.removeAt(itemIdx);
                                  _controller.piracyReports.removeAt(i);
                                  Get.snackbar('Resource Suspended ❌', 'Pirated document removed from Creaniaa servers.');
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: context.errorColor, padding: EdgeInsets.symmetric(horizontal: 14)),
                              child: Text('Delete Resource', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    final vipCtrl = Get.find<VipController>();
    final novelCtrl = Get.find<NovelController>();
    final storeCtrl = Get.find<StoreController>();

    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        Text(
          'DEVELOPER & TESTING ACTIONS 🧪',
          style: GoogleFonts.outfit(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
        ),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFFFFB800).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Simulate Account & Wallet states instantly to verify features.',
                style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11),
              ),
              SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await vipCtrl.resetMembership();
                      await novelCtrl.resetMembership();
                      Get.snackbar(
                        'Memberships Reset! 🧼',
                        'VIP and Novel levels reset to 0.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.blueAccent,
                        colorText: Colors.white,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Reset VIP/Novel to 0', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      storeCtrl.addCoins(500, 'Test Coins Grant');
                      Get.snackbar(
                        'Coins Granted! 🪙',
                        'Added 500 Gold Coins to your balance.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.orangeAccent,
                        colorText: Colors.white,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Add 500 Coins', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final testBook = _controller.items.firstWhereOrNull((b) => !b.isOfficial) ??
                          StudyVaultItem(
                            id: 'temp_visit_test',
                            title: 'Simulated Uploader Book',
                            subtitle: '', description: '', coverImage: '', category: 'Coding', course: '', semester: '', branch: '', university: '', language: 'English', tags: [], authorName: '', publisher: '', edition: '', pages: 10, fileType: 'PDF', pdfUrl: '', thumbnail: '', previewPagesCount: 1,
                            sellingPrice: 100.0,
                            license: '', copyrightDeclaration: true, isOfficial: false, requiredVipLevel: 0, sellerId: 'seller_test', sellerName: 'Test Seller', sellerAvatar: '', createdAt: DateTime.now(),
                          );
                      _controller.triggerReadVisitPayout(testBook);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Trigger ₹5 Payout', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        Text(
          'GLOBAL DEVICE SETTINGS',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
        ),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device Download Limit', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Maximum authorization count to cache PDFs locally on separate devices.', style: TextStyle(color: context.caption, fontSize: 11)),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _controller.downloadLimitPerDevice.value.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: context.primaryColor,
                      onChanged: (val) {
                        setState(() {
                          _controller.downloadLimitPerDevice.value = val.toInt();
                        });
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: context.secondaryBackgroundColor, borderRadius: BorderRadius.circular(8)),
                    child: Text('${_controller.downloadLimitPerDevice.value} devices', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              )
            ],
          ),
        ),
        SizedBox(height: 24),
        Text(
          'MEMBERSHIP DISCOUNTS (USER UPLOADS)',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
        ),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _discountRow('VIP 1 Member Discount', '5%'),
              Divider(color: Colors.white10),
              _discountRow('VIP 2 Member Discount', '10%'),
              Divider(color: Colors.white10),
              _discountRow('VIP 3 Member Discount', '15%'),
              Divider(color: Colors.white10),
              _discountRow('VIP 4 Member Discount', '20%'),
              Divider(color: Colors.white10),
              _discountRow('VIP 5 Member Discount', '25%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _discountRow(String tier, String discount) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tier, style: TextStyle(color: context.textSecondary, fontSize: 12)),
          Text(discount, style: TextStyle(color: context.accentOrange, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.caption, fontSize: 11)),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.caption, fontSize: 12),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, int value, List<int> items, void Function(int?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.caption, fontSize: 11)),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              dropdownColor: context.secondaryBackgroundColor,
              isExpanded: true,
              style: TextStyle(color: Colors.white, fontSize: 13),
              items: items.map((t) {
                return DropdownMenuItem<int>(
                  value: t,
                  child: Text(t == 0 ? 'FREE' : 'VIP $t'),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownFieldString(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.caption, fontSize: 11)),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: context.secondaryBackgroundColor,
              isExpanded: true,
              style: TextStyle(color: Colors.white, fontSize: 13),
              items: items.map((t) {
                return DropdownMenuItem<String>(
                  value: t,
                  child: Text(t),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
