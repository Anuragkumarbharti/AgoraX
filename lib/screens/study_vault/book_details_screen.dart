import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/study_vault_controller.dart';
import '../../services/vip_controller.dart';
import '../../services/store_controller.dart';
import '../../models/study_vault_model.dart';
import 'study_vault_reader_screen.dart';

class BookDetailsScreen extends StatefulWidget {
  final StudyVaultItem book;
  const BookDetailsScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  final StudyVaultController _controller = Get.find<StudyVaultController>();
  final VipController _vipCtrl = Get.find<VipController>();
  final StoreController _storeCtrl = Get.find<StoreController>();

  void _showPriceBreakdownSheet() {
    final breakdown = _controller.calculatePriceBreakdown(widget.book.sellingPrice, vipLevel: _vipCtrl.vipLevel.value);
    final goldCoinsPrice = (breakdown['buyerPays']! * 0.50).round();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Pricing & Tax Breakdown',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _breakdownRow('Base Selling Price', '₹${breakdown['basePrice']!.toStringAsFixed(2)}'),
            if (breakdown['discount']! > 0)
              _breakdownRow('VIP ${_vipCtrl.vipLevel.value} Discount', '- ₹${breakdown['discount']!.toStringAsFixed(2)}', highlightColor: AppTheme.accentColor),
            const Divider(color: Colors.white10),
            _breakdownRow('GST (18%)', '+ ₹${breakdown['gst']!.toStringAsFixed(2)}'),
            _breakdownRow('Payment Gateway (2%)', '+ ₹${breakdown['paymentGateway']!.toStringAsFixed(2)}'),
            _breakdownRow('Platform Service Fee (17%)', '+ ₹${breakdown['platformFee']!.toStringAsFixed(2)}'),
            const Divider(color: Colors.white10),
            _breakdownRow('Total Buyer Pays (INR)', '₹${breakdown['buyerPays']!.toStringAsFixed(2)}', isHeader: true),
            _breakdownRow('Total Buyer Pays (Gold Coins)', '🪙 $goldCoinsPrice Coins', isHeader: true, highlightColor: const Color(0xFFFFD700)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.textTertiary, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The seller receives ₹${breakdown['sellerReceives']!.toStringAsFixed(2)} (63% net of discounted base). Platforms fee and taxes are auto-calculated.',
                      style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  _handlePurchase();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: Text('Confirm & Buy (🪙 $goldCoinsPrice Coins)', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {bool isHeader = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isHeader ? Colors.white : AppTheme.textTertiary,
              fontSize: isHeader ? 13 : 12,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlightColor ?? (isHeader ? Colors.white : AppTheme.textSecondary),
              fontSize: isHeader ? 13 : 12,
              fontWeight: (isHeader || highlightColor != null) ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _handlePurchase() async {
    final success = await _controller.purchaseBook(widget.book, 'Gold Coins');
    if (success) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Obx(() {
        final book = _controller.items.firstWhereOrNull((b) => b.id == widget.book.id) ?? widget.book;
        final unlocked = _controller.isBookUnlocked(book);
        final inWishlist = _controller.wishlistBookIds.contains(book.id);

        final breakdown = _controller.calculatePriceBreakdown(book.sellingPrice, vipLevel: _vipCtrl.vipLevel.value);
        final goldCoinsPrice = (breakdown['buyerPays']! * 0.50).round();

        return Stack(
          children: [
            // Scrollable Content
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(book, inWishlist),
                SliverList(
                  delegate: SliverChildListDelegate([
                    // Title and Basic Meta
                    _buildBookInfoSection(book, breakdown, unlocked),
                    
                    // Purchase Info or Unlock Info
                    _buildPricingActionCard(book, breakdown, goldCoinsPrice, unlocked),

                    // Security & Antipiracy warning
                    _buildSecurityBanner(),

                    // Seller details
                    _buildSellerProfileSnippet(book),

                    // Reviews Section
                    _buildReviewsSection(book),
                    
                    const SizedBox(height: 100),
                  ]),
                ),
              ],
            ),

            // Sticky Bottom CTA Buttons
            _buildStickyBottomCTAs(book, goldCoinsPrice, unlocked),
          ],
        );
      }),
    );
  }

  Widget _buildSliverAppBar(StudyVaultItem book, bool inWishlist) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppTheme.bgDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      actions: [
        IconButton(
          icon: Icon(
            inWishlist ? Icons.favorite : Icons.favorite_border_rounded,
            color: inWishlist ? Colors.redAccent : Colors.white,
          ),
          onPressed: () => _controller.toggleWishlist(book.id),
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {
            Get.snackbar('Link Copied 🔗', 'Study Vault book link copied to clipboard.');
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            // Blurred background cover
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(image: NetworkImage(book.coverImage), fit: BoxFit.cover),
              ),
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
            // Floating Cover Art
            Container(
              height: 180,
              width: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 12, spreadRadius: 2, offset: const Offset(0, 4))
                ],
                image: DecorationImage(image: NetworkImage(book.coverImage), fit: BoxFit.cover),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBookInfoSection(StudyVaultItem book, Map<String, double> breakdown, bool unlocked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: book.isOfficial ? const Color(0xFFFFD700) : AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  book.isOfficial ? 'OFFICIAL' : 'USER UPLOAD',
                  style: TextStyle(color: book.isOfficial ? Colors.black : Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(
                  book.fileType.toUpperCase(),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            book.title,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            book.subtitle,
            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          
          // Pages, Ratings, Language Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoTile('Pages', '${book.pages} pgs', Icons.menu_book),
              _infoTile('Rating', '${book.rating} (${book.reviewsCount} reviews)', Icons.star, iconColor: const Color(0xFFFFD700)),
              _infoTile('Language', book.language, Icons.translate),
            ],
          ),
          const Divider(color: Colors.white10, height: 28),
          
          // Subject taxonomy
          Text('TAXONOMY & INDEX', style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          _taxonomyRow('Category Collection', book.category),
          _taxonomyRow('Academic Path', '${book.course}  ·  Sem ${book.semester}'),
          _taxonomyRow('Branch / Subject', book.branch),
          _taxonomyRow('University Bound', book.university),
          _taxonomyRow('Publisher / License', '${book.publisher} (${book.edition})'),

          const Divider(color: Colors.white10, height: 28),
          Text('DESCRIPTION', style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Text(
            book.description,
            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const Divider(color: Colors.white10, height: 28),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? AppTheme.textTertiary, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _taxonomyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPricingActionCard(StudyVaultItem book, Map<String, double> breakdown, int goldCoins, bool unlocked) {
    final isPurchasedOrOwned = _controller.purchasedBookIds.contains(book.id) || book.sellerId == 'me';
    final isOfficialUnlocked = book.isOfficial && unlocked;

    if (isPurchasedOrOwned || isOfficialUnlocked) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentColor, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resource Unlocked', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    book.isOfficial 
                        ? 'Unlocked through your active VIP Membership.' 
                        : 'Permanent lifetime access unlocked.',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            )
          ],
        ),
      );
    }

    if (book.isOfficial) {
      // Locked official book
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFFFFD700), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VIP Locked Official Resource', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Unlocked exclusively for VIP ${book.requiredVipLevel} and above. Upgrade your membership in the Vip Club.',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            )
          ],
        ),
      );
    }

    // Locked user uploaded paid book
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (breakdown['discount']! > 0)
                    Text('Original Price: ₹${book.sellingPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10, decoration: TextDecoration.lineThrough)),
                  Text(
                    '₹${breakdown['buyerPays']!.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '🪙 $goldCoins Gold Coins',
                    style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold),
                  )
                ],
              ),
              if (_vipCtrl.vipLevel.value > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'VIP ${_vipCtrl.vipLevel.value} Discount Active',
                    style: const TextStyle(color: AppTheme.accentColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                )
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          GestureDetector(
            onTap: _showPriceBreakdownSheet,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('View GST & platform fee splits', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryColor, size: 10),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.12)),
      ),
      child: const Row(
        children: [
          Icon(Icons.security, color: AppTheme.errorColor, size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'AgoraX Anti-Piracy Active: This document features non-removable invisible buyer watermarks. Distribution is legally tracked.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.4),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSellerProfileSnippet(StudyVaultItem book) {
    if (book.isOfficial) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RESOURCE CREATOR', style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(image: NetworkImage(book.sellerAvatar), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(book.sellerName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: AppTheme.accentColor, size: 13),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Rating: 4.8  ·  Joined 2025  ·  Verified publisher', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildReviewsSection(StudyVaultItem book) {
    // filter reviews matching this book
    final bookReviews = _controller.reviews.where((r) => r.bookId == book.id).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STUDENT REVIEWS', style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              Text('${book.rating} / 5 (${book.reviewsCount} reviews)', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          bookReviews.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: const Center(child: Text('No reviews for this book yet.', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bookReviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final rev = bookReviews[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(image: NetworkImage(rev.userAvatar), fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(rev.userName, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(color: AppTheme.accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('VERIFIED BUYER', style: TextStyle(color: AppTheme.accentColor, fontSize: 6, fontWeight: FontWeight.bold)),
                                        )
                                      ],
                                    ),
                                    Row(
                                      children: List.generate(5, (starIdx) => Icon(Icons.star, color: starIdx < rev.rating ? const Color(0xFFFFD700) : Colors.white10, size: 10)),
                                    )
                                  ],
                                ),
                              ),
                              Text('${rev.createdAt.day}/${rev.createdAt.month}/${rev.createdAt.year}', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rev.reviewText,
                            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.4),
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

  Widget _buildStickyBottomCTAs(StudyVaultItem book, int goldCoins, bool unlocked) {
    final isPurchasedOrOwned = _controller.purchasedBookIds.contains(book.id) || book.sellerId == 'me';
    final isOfficialUnlocked = book.isOfficial && unlocked;
    final isQuotaAccess = !isOfficialUnlocked && unlocked && !isPurchasedOrOwned && book.sellingPrice > 0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: isQuotaAccess
                    ? ElevatedButton(
                        onPressed: () {
                          if (_controller.checkMembershipReadingLimit(book)) {
                            Get.to(() => StudyVaultReaderScreen(book: book, isPreview: false));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                        ),
                        child: const Text('Read Free', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      )
                    : OutlinedButton(
                        onPressed: () {
                          Get.to(() => StudyVaultReaderScreen(book: book, isPreview: true));
                        },
                        child: const Text('Read Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: (isPurchasedOrOwned || isOfficialUnlocked)
                      ? () {
                          Get.to(() => StudyVaultReaderScreen(book: book, isPreview: false));
                        }
                      : isQuotaAccess
                          ? () {
                              _showPriceBreakdownSheet();
                            }
                          : () {
                              if (book.isOfficial) {
                                Get.snackbar(
                                  'Upgrade Required 👑',
                                  'Please upgrade your membership to VIP ${book.requiredVipLevel} in the VIP tab to access this official book.',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              } else {
                                _showPriceBreakdownSheet();
                              }
                            },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (isPurchasedOrOwned || isOfficialUnlocked)
                        ? AppTheme.accentColor
                        : AppTheme.primaryColor,
                  ),
                  child: Text(
                    (isPurchasedOrOwned || isOfficialUnlocked)
                        ? 'Read Full Book'
                        : (book.isOfficial ? 'Unlock (VIP)' : 'Buy Now (🪙 $goldCoins)'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
