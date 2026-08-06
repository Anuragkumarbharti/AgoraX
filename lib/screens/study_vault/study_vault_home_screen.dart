import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';
import '../../services/vault/study_vault_controller.dart';
import '../../services/memberships/vip_controller.dart';
import '../../models/vault/study_vault_model.dart';
import './book_details_screen.dart';
import './my_library_screen.dart';
import './seller_dashboard_screen.dart';
import './admin_vault_panel_screen.dart';
import '../coming_soon_screen.dart';

class StudyVaultHomeScreen extends StatefulWidget {
  const StudyVaultHomeScreen({Key? key}) : super(key: key);

  @override
  State<StudyVaultHomeScreen> createState() => _StudyVaultHomeScreenState();
}

class _StudyVaultHomeScreenState extends State<StudyVaultHomeScreen> {
  final StudyVaultController _controller = Get.find<StudyVaultController>();
  final VipController _vipCtrl = Get.find<VipController>();

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategoryFilter = 'All';

  // Filters State
  String _filterSortBy = 'Trending';
  String _filterPriceType = 'All'; // All, Free, Paid
  String _filterSourceType = 'All'; // All, Official, User Uploaded
  String _filterDocType = 'All'; // All, PDF, Notes, Books, Projects

  final List<String> _shortcutCategories = [
    'All', 'Coding', 'AI', 'GATE', 'UPSC', 'Engineering', 'Projects', 'Assignments', 'Research'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.secondaryBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return ListView(
              shrinkWrap: true,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Refine Search Filters',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _filterSortBy = 'Trending';
                          _filterPriceType = 'All';
                          _filterSourceType = 'All';
                          _filterDocType = 'All';
                        });
                        setState(() {});
                      },
                      child: Text('Reset', style: TextStyle(color: context.primaryColor)),
                    )
                  ],
                ),
                SizedBox(height: 12),
                
                // Sort By
                _filterHeader('Sort By'),
                Wrap(
                  spacing: 8,
                  children: ['Newest', 'Oldest', 'Trending', 'Best Selling', 'Highest Rated'].map((sort) {
                    final isSel = _filterSortBy == sort;
                    return ChoiceChip(
                      label: Text(sort, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11)),
                      selected: isSel,
                      selectedColor: Color(0xFFFFD700),
                      backgroundColor: context.scaffoldBackgroundColor,
                      onSelected: (selected) {
                        setModalState(() => _filterSortBy = sort);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 12),

                // Price Type
                _filterHeader('Pricing'),
                Wrap(
                  spacing: 8,
                  children: ['All', 'Free', 'Paid'].map((pt) {
                    final isSel = _filterPriceType == pt;
                    return ChoiceChip(
                      label: Text(pt, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11)),
                      selected: isSel,
                      selectedColor: Color(0xFFFFD700),
                      backgroundColor: context.scaffoldBackgroundColor,
                      onSelected: (selected) {
                        setModalState(() => _filterPriceType = pt);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 12),

                // Source Type
                _filterHeader('Creator Source'),
                Wrap(
                  spacing: 8,
                  children: ['All', 'Official', 'User Uploaded'].map((src) {
                    final isSel = _filterSourceType == src;
                    return ChoiceChip(
                      label: Text(src, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11)),
                      selected: isSel,
                      selectedColor: Color(0xFFFFD700),
                      backgroundColor: context.scaffoldBackgroundColor,
                      onSelected: (selected) {
                        setModalState(() => _filterSourceType = src);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 12),

                // Document Type
                _filterHeader('File Type'),
                Wrap(
                  spacing: 8,
                  children: ['All', 'PDF', 'Notes', 'Books', 'Projects', 'Lab Manuals'].map((doc) {
                    final isSel = _filterDocType == doc;
                    return ChoiceChip(
                      label: Text(doc, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11)),
                      selected: isSel,
                      selectedColor: Color(0xFFFFD700),
                      backgroundColor: context.scaffoldBackgroundColor,
                      onSelected: (selected) {
                        setModalState(() => _filterDocType = doc);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(backgroundColor: context.primaryColor),
                    child: Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterHeader(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0),
      child: Text(label, style: TextStyle(color: context.caption, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  List<StudyVaultItem> _getFilteredCatalog() {
    final query = _searchController.text.trim().toLowerCase();
    
    return _controller.items.where((book) {
      // 1. Text Search matching Book Name, Author, Seller, Subject, Tags
      if (query.isNotEmpty) {
        final matchTitle = book.title.toLowerCase().contains(query);
        final matchAuthor = book.authorName.toLowerCase().contains(query);
        final matchSeller = book.sellerName.toLowerCase().contains(query);
        final matchSubject = book.branch.toLowerCase().contains(query) || book.course.toLowerCase().contains(query);
        final matchTags = book.tags.any((t) => t.toLowerCase().contains(query));

        if (!matchTitle && !matchAuthor && !matchSeller && !matchSubject && !matchTags) {
          return false;
        }
      }

      // 2. Category Filter (from chip navigation)
      if (_selectedCategoryFilter != 'All' && book.category != _selectedCategoryFilter) {
        return false;
      }

      // 3. Price Filter
      if (_filterPriceType == 'Free' && book.sellingPrice > 0) return false;
      if (_filterPriceType == 'Paid' && book.sellingPrice == 0) return false;

      // 4. Source Filter
      if (_filterSourceType == 'Official' && !book.isOfficial) return false;
      if (_filterSourceType == 'User Uploaded' && book.isOfficial) return false;

      // 5. Doc Type Filter
      if (_filterDocType != 'All' && book.fileType != _filterDocType) return false;

      return book.status == 'Approved'; // Show only approved items in the catalog
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(title: 'Study Vault');
  }

  Widget _buildAppBarHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 16, 18, 8),
      color: context.scaffoldBackgroundColor,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
          Icon(Icons.auto_stories, color: context.primaryColor, size: 24),
          SizedBox(width: 10),
          Text(
            'Study Vault',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Profile shortcuts to Library & dashboards
          IconButton(
            icon: Icon(Icons.bookmark_outline, color: Colors.white, size: 20),
            onPressed: () => Get.to(() => const MyLibraryScreen()),
          ),
          IconButton(
            icon: Icon(Icons.dashboard_customize_outlined, color: Colors.white, size: 20),
            onPressed: () => Get.to(() => const SellerDashboardScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor, width: 0.8),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search, color: context.caption, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() {}),
                style: TextStyle(color: context.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search Books, Subjects, Authors, Sellers...',
                  hintStyle: TextStyle(color: context.caption, fontSize: 13),
                  filled: false,
                ),
              ),
            ),
            GestureDetector(
              onTap: _showFilterSheet,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded, color: context.primaryColor, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 18),
        physics: const BouncingScrollPhysics(),
        itemCount: _shortcutCategories.length,
        itemBuilder: (context, i) {
          final cat = _shortcutCategories[i];
          final isSel = _selectedCategoryFilter == cat;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSel,
              selectedColor: context.primaryColor,
              backgroundColor: context.surfaceColor,
              labelStyle: TextStyle(
                color: isSel ? Colors.white : context.textSecondary,
                fontSize: 12,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryFilter = cat;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return Container(
      margin: EdgeInsets.all(18),
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?w=800'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.85), Colors.black.withOpacity(0.2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('ACADEMIC SALE', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 6),
            Text(
              'Unlock 500+ Official Books',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text(
              'Subscribe to VIP and access GATE, UPSC, CSE & Coding Vaults.',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueReadingRail() {
    return Obx(() {
      final activeList = _controller.readingProgress.entries.toList();
      if (activeList.isEmpty) return SizedBox();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Text(
              'CONTINUE READING',
              style: GoogleFonts.outfit(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 18),
              physics: const BouncingScrollPhysics(),
              itemCount: activeList.length,
              itemBuilder: (context, i) {
                final entry = activeList[i];
                final book = _controller.items.firstWhereOrNull((item) => item.id == entry.key);
                if (book == null) return SizedBox();

                return GestureDetector(
                  onTap: () => Get.to(() => BookDetailsScreen(book: book)),
                  child: Container(
                    width: 250,
                    margin: EdgeInsets.only(right: 12),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(book.coverImage, width: 45, height: 60, fit: BoxFit.cover),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(book.title, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('Page ${entry.value.lastPageRead} of ${book.pages}', style: TextStyle(color: context.caption, fontSize: 10)),
                              SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: entry.value.readingProgress,
                                  minHeight: 4,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation(context.accentOrange),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      );
    });
  }

  Widget _buildFlashOffersBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFC084FC)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: Color(0xFFFFD700), size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FLASH OFFER: 25% OFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                Text('Upgrade to VIP 5 and receive full discounts on all premium notes.', style: TextStyle(color: Colors.white70, fontSize: 9.5)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBookshelfRail(String sectionTitle, List<StudyVaultItem> list) {
    if (list.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sectionTitle,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: context.caption, size: 12),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 18),
            physics: const BouncingScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final book = list[index];
              return _buildBookCard(book);
            },
          ),
        )
      ],
    );
  }

  Widget _buildBookCard(StudyVaultItem book) {
    final unlocked = _controller.isBookUnlocked(book);

    return GestureDetector(
      onTap: () => Get.to(() => BookDetailsScreen(book: book)),
      child: Container(
        width: 105,
        margin: EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Cover Art
                Container(
                  height: 135,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    ],
                    image: DecorationImage(
                      image: NetworkImage(book.coverImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Lock overlay if locked
                if (!unlocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 24),
                      ),
                    ),
                  ),
                // Badges
                Positioned(
                  top: 6,
                  left: 6,
                  child: _buildBadge(book),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              book.title,
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              book.authorName,
              style: TextStyle(color: context.caption, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(StudyVaultItem book) {
    if (book.isOfficial) {
      if (book.requiredVipLevel == 0) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: context.accentOrange, borderRadius: BorderRadius.circular(4)),
          child: Text('FREE', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
        );
      }
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: Color(0xFFFFD700), borderRadius: BorderRadius.circular(4)),
        child: Text('VIP ${book.requiredVipLevel}', style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold)),
      );
    } else {
      if (book.sellingPrice == 0.0) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(4)),
          child: Text('FREE', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
        );
      }
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: Color(0xFF6366F1), borderRadius: BorderRadius.circular(4)),
        child: Text('₹${book.sellingPrice.toStringAsFixed(0)}', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
      );
    }
  }

  Widget _buildSearchResultsGrid() {
    final list = _getFilteredCatalog();

    if (list.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Text('No matching study resources found.', style: TextStyle(color: context.caption)),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'SEARCH RESULTS (${list.length})',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
              childAspectRatio: 0.65,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              return _buildBookCard(list[i]);
            },
          ),
        ],
      ),
    );
  }
}
