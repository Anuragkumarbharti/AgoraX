import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/study_vault_controller.dart';
import '../../services/vip_controller.dart';
import '../../models/study_vault_model.dart';
import 'book_details_screen.dart';
import 'study_vault_reader_screen.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen>
    with SingleTickerProviderStateMixin {
  final StudyVaultController _controller = Get.find<StudyVaultController>();
  final VipController _vipCtrl = Get.find<VipController>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(
          'My Library',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.bgLight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Purchased'),
            Tab(text: 'Official (VIP)'),
            Tab(text: 'Wishlist'),
            Tab(text: 'Progress'),
            Tab(text: 'Downloaded'),
          ],
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textTertiary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      body: Obx(() {
        // Purchased user uploads
        final purchasedBooks = _controller.items.where((b) => _controller.purchasedBookIds.contains(b.id)).toList();
        
        // Official Books matching VIP level
        final isVipActive = _vipCtrl.vipLevel.value > 0;
        final officialBooks = _controller.items.where((b) => b.isOfficial).toList();

        // Wishlist Books
        final wishlistBooks = _controller.items.where((b) => _controller.wishlistBookIds.contains(b.id)).toList();

        // History progress
        final progressEntries = _controller.readingProgress.entries.toList();

        // Downloaded items (simulation matches purchased and free items downloaded)
        final downloadedBooks = _controller.items.where((b) => _controller.purchasedBookIds.contains(b.id) || b.sellingPrice == 0.0).toList();

        return Column(
          children: [
            // VIP status header card
            _buildVipMembershipBanner(isVipActive),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Purchased Items
                  _buildBookShelfGrid(purchasedBooks, 'You haven\'t purchased any study resources yet.'),

                  // Tab 2: Official VIP items
                  _buildOfficialLibrary(officialBooks, isVipActive),

                  // Tab 3: Wishlist
                  _buildBookShelfGrid(wishlistBooks, 'Your wishlist is empty.'),

                  // Tab 4: Continue Reading progress
                  _buildProgressList(progressEntries),

                  // Tab 5: Downloaded Offline Cache
                  _buildDownloadedList(downloadedBooks),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildVipMembershipBanner(bool isVipActive) {
    final vipLevel = _vipCtrl.vipLevel.value;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isVipActive ? const Color(0xFFFFD700).withOpacity(0.08) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isVipActive ? const Color(0xFFFFD700).withOpacity(0.3) : AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isVipActive ? Icons.workspace_premium_rounded : Icons.info_outline_rounded,
            color: isVipActive ? const Color(0xFFFFD700) : AppTheme.textTertiary,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVipActive ? 'VIP $vipLevel Membership Active' : 'Membership Expired',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  isVipActive
                      ? 'Official AgoraX books unlocked matching Level $vipLevel. Expired memberships automatically lock content.'
                      : 'Subscribe to VIP to unlock official AgoraX study collections.',
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBookShelfGrid(List<StudyVaultItem> list, String emptyMsg) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(emptyMsg, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textTertiary)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.65,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final book = list[i];
        return GestureDetector(
          onTap: () => Get.to(() => BookDetailsScreen(book: book)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                  image: DecorationImage(image: NetworkImage(book.coverImage), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                book.title,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                book.authorName,
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfficialLibrary(List<StudyVaultItem> list, bool isVipActive) {
    if (list.isEmpty) {
      return const Center(child: Text('No official resources found.', style: TextStyle(color: AppTheme.textTertiary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final book = list[index];
        final userVipLevel = _vipCtrl.vipLevel.value;
        final isUnlocked = isVipActive && userVipLevel >= book.requiredVipLevel;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnlocked 
                  ? AppTheme.accentColor.withOpacity(0.3) 
                  : AppTheme.borderColor.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(book.coverImage, width: 44, height: 60, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : Colors.white30, 
                        fontSize: 13, 
                        fontWeight: FontWeight.bold,
                        decoration: isUnlocked ? TextDecoration.none : TextDecoration.lineThrough,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Official AgoraX Board  |  ${book.pages} Pages',
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isUnlocked ? AppTheme.accentColor.withOpacity(0.12) : AppTheme.errorColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isUnlocked ? 'UNLOCKED' : 'LOCKED (REQUIRES VIP ${book.requiredVipLevel})',
                        style: TextStyle(
                          color: isUnlocked ? AppTheme.accentColor : AppTheme.errorColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Get.to(() => BookDetailsScreen(book: book)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUnlocked ? AppTheme.primaryColor : Colors.white10,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(isUnlocked ? 'Read' : 'View', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressList(List<MapEntry<String, ReadingHistory>> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('No reading progress logged. Start reading!', style: TextStyle(color: AppTheme.textTertiary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final book = _controller.items.firstWhereOrNull((item) => item.id == entry.key);
        if (book == null) return const SizedBox();

        final history = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(book.coverImage, width: 44, height: 60, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Page ${history.lastPageRead} of ${book.pages}  |  ${(history.totalReadingDurationSeconds ~/ 60)} mins read',
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: history.readingProgress,
                        minHeight: 4,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textTertiary, size: 16),
                onPressed: () => Get.to(() => BookDetailsScreen(book: book)),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadedList(List<StudyVaultItem> list) {
    if (list.isEmpty) {
      return const Center(child: Text('No offline books downloaded.', style: TextStyle(color: AppTheme.textTertiary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final book = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Authorized offline device cache  |  Size: 4.8 MB', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  if (_controller.checkMembershipReadingLimit(book)) {
                    Get.to(() => StudyVaultReaderScreen(book: book, isPreview: false));
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  side: const BorderSide(color: AppTheme.accentColor),
                ),
                child: const Text('Read Offline', style: TextStyle(color: AppTheme.accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
