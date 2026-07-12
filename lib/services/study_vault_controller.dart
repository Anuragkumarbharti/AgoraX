import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_vault_model.dart';
import 'vip_controller.dart';
import 'store_controller.dart';
import 'novel_controller.dart';
import 'user_progress_sync_service.dart';
import 'user_profile_cache_manager.dart';

class StudyVaultController extends GetxController {
  static StudyVaultController get to => Get.find<StudyVaultController>();

  // Catalog collections
  final RxList<StudyVaultItem> items = <StudyVaultItem>[].obs;
  final RxList<StudyReview> reviews = <StudyReview>[].obs;

  // User Library and progress states
  final RxList<String> purchasedBookIds = <String>[].obs;
  final RxList<String> wishlistBookIds = <String>[].obs;
  final RxMap<String, ReadingHistory> readingProgress = <String, ReadingHistory>{}.obs;

  // Membership daily limits
  final RxList<String> membershipBooksReadToday = <String>[].obs;
  final RxString lastAccessDate = ''.obs;

  // Gamification stats
  final RxInt totalXp = 0.obs;
  final RxInt readingStreak = 0.obs;
  final RxInt pagesRead = 0.obs;
  final RxInt booksReadCount = 0.obs;
  final RxList<String> unlockedBadges = <String>[].obs;

  // Seller Dashboard variables (simulated for current user as a seller)
  final Rx<VaultWallet> sellerWallet = VaultWallet().obs;
  final RxList<VaultTransaction> sellerTransactions = <VaultTransaction>[].obs;
  final RxInt sellerFollowers = 0.obs;
  final RxDouble sellerRating = 0.0.obs;
  final RxInt sellerTotalSales = 0.obs;
  final RxDouble responseRate = 0.0.obs;
  final RxString sellerJoinedDate = ''.obs;

  // Admin Configuration parameters
  final RxInt downloadLimitPerDevice = 3.obs; // configurable by admin
  final RxList<Map<String, dynamic>> piracyReports = <Map<String, dynamic>>[].obs;

  // Active reading session variables
  Rxn<StudyVaultItem> activeReadingBook = Rxn<StudyVaultItem>();
  final RxInt activeBookPage = 1.obs;
  final RxDouble readingTimeSeconds = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadState();
    loadCatalogFromDatabase();
    loadPurchasedBooks();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load purchased list
    final purchased = prefs.getStringList('vault_purchased_ids');
    if (purchased != null) {
      purchasedBookIds.assignAll(purchased);
    } else {
      purchasedBookIds.clear();
    }

    // Load wishlist list
    final wishlist = prefs.getStringList('vault_wishlist_ids');
    if (wishlist != null) {
      wishlistBookIds.assignAll(wishlist);
    } else {
      wishlistBookIds.clear();
    }

    // Load membership read list and date
    final dailyReads = prefs.getStringList('vault_membership_reads_today');
    if (dailyReads != null) {
      membershipBooksReadToday.assignAll(dailyReads);
    }
    lastAccessDate.value = prefs.getString('vault_last_access_date') ?? '';

    // Load gamification stats
    totalXp.value = prefs.getInt('vault_user_xp') ?? 0;
    readingStreak.value = prefs.getInt('vault_reading_streak') ?? 0;
    pagesRead.value = prefs.getInt('vault_pages_read') ?? 0;
    booksReadCount.value = prefs.getInt('vault_books_read_count') ?? 0;

    _saveLocalState();
  }

  Future<void> _saveLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vault_purchased_ids', purchasedBookIds);
    await prefs.setStringList('vault_wishlist_ids', wishlistBookIds);
    await prefs.setStringList('vault_membership_reads_today', membershipBooksReadToday);
    await prefs.setString('vault_last_access_date', lastAccessDate.value);
    await prefs.setInt('vault_user_xp', totalXp.value);
    await prefs.setInt('vault_reading_streak', readingStreak.value);
    await prefs.setInt('vault_pages_read', pagesRead.value);
    await prefs.setInt('vault_books_read_count', booksReadCount.value);
    UserProgressSyncService.syncToSupabase();
  }

  StudyVaultItem _itemFromMap(Map<String, dynamic> m) {
    return StudyVaultItem(
      id: m['id'] ?? '',
      title: m['title'] ?? '',
      subtitle: m['subtitle'] ?? '',
      description: m['description'] ?? '',
      coverImage: m['cover_image'] ?? '',
      category: m['category'] ?? '',
      course: m['course'] ?? '',
      semester: m['semester'] ?? '',
      branch: m['branch'] ?? '',
      university: m['university'] ?? '',
      language: m['language'] ?? 'English',
      tags: List<String>.from(m['tags'] ?? []),
      authorName: m['author_name'] ?? '',
      publisher: m['publisher'] ?? '',
      edition: m['edition'] ?? '',
      isbn: m['isbn'],
      pages: m['pages'] ?? 10,
      fileType: m['file_type'] ?? 'PDF',
      pdfUrl: m['pdf_url'] ?? '',
      thumbnail: m['thumbnail'] ?? '',
      previewPagesCount: m['preview_pages_count'] ?? 3,
      sellingPrice: (m['selling_price'] as num?)?.toDouble() ?? 0.0,
      license: m['license'] ?? 'Standard Digital License',
      copyrightDeclaration: m['copyright_declaration'] ?? true,
      isOfficial: m['is_official'] ?? false,
      requiredVipLevel: m['required_vip_level'] ?? 0,
      sellerId: m['seller_id'] ?? '',
      sellerName: m['seller_name'] ?? '',
      sellerAvatar: m['seller_avatar'] ?? '',
      rating: (m['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: m['reviews_count'] ?? 0,
      viewsCount: m['views_count'] ?? 0,
      downloadsCount: m['downloads_count'] ?? 0,
      purchasesCount: m['purchases_count'] ?? 0,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at']) ?? DateTime.now() : DateTime.now(),
      watermarkText: m['watermark_text'] ?? 'Creania',
      isFeatured: m['is_featured'] ?? false,
      status: m['status'] ?? 'Pending',
      adminComment: m['admin_comment'],
    );
  }

  Future<void> loadCatalogFromDatabase() async {
    try {
      final List<dynamic> list = await Supabase.instance.client
          .from('study_vault_items')
          .select();

      final loadedItems = list.map((m) => _itemFromMap(m)).toList();
      items.assignAll(loadedItems);
    } catch (_) {}
  }

  Future<void> loadPurchasedBooks() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      
      final canonicalId = await UserProfileCacheManager.getOrFetchCanonicalId();
      final List<dynamic> list = await Supabase.instance.client
          .from('purchase_history')
          .select('item_id')
          .eq('user_id', canonicalId)
          .eq('item_type', 'Book');

      final ids = list.map((m) => m['item_id'].toString()).toList();
      purchasedBookIds.assignAll(ids);
      _saveLocalState();
    } catch (_) {}
  }

  void _seedMockData() {
    // Left empty for production backend loads
  }

  // ── Pricing Engine Calculations ──
  Map<String, double> calculatePriceBreakdown(double basePrice, {int vipLevel = 0, int novelLevel = 0}) {
    // 1. Calculate discount if applicable
    double vipDiscount = 0.0;
    if (vipLevel > 0) {
      if (vipLevel == 1) vipDiscount = 0.05;
      else if (vipLevel == 2) vipDiscount = 0.10;
      else if (vipLevel == 3) vipDiscount = 0.15;
      else if (vipLevel == 4) vipDiscount = 0.20;
      else if (vipLevel >= 5) vipDiscount = 0.25;
    }

    double novelDiscount = 0.0;
    if (novelLevel > 0) {
      if (novelLevel == 1) novelDiscount = 0.05;
      else if (novelLevel == 2) novelDiscount = 0.10;
      else if (novelLevel == 3) novelDiscount = 0.15;
      else if (novelLevel >= 4) novelDiscount = 0.25;
    }

    final double discountPercentage = max(vipDiscount, novelDiscount);
    final double discount = basePrice * discountPercentage;
    final double discountedBase = basePrice - discount;

    // 2. Taxes and Platform splits on final price
    final double gst = discountedBase * 0.18;
    final double gateway = discountedBase * 0.02;
    final double platformFee = discountedBase * 0.17;

    final double buyerPays = discountedBase + gst + gateway + platformFee;
    final double sellerReceives = discountedBase - gst - gateway - platformFee;
    final double platformReceives = buyerPays - sellerReceives;

    return {
      'basePrice': basePrice,
      'discount': discount,
      'discountedBase': discountedBase,
      'gst': gst,
      'paymentGateway': gateway,
      'platformFee': platformFee,
      'buyerPays': buyerPays,
      'sellerReceives': sellerReceives,
      'platformReceives': platformReceives,
    };
  }

  // ── Access Checks ──
  bool isBookUnlocked(StudyVaultItem book) {
    if (book.sellingPrice == 0 && !book.isOfficial) {
      return true; // Free user-uploaded resources are unlocked
    }

    if (book.isOfficial) {
      if (book.requiredVipLevel == 0) return true; // FREE official collections
      final vipCtrl = Get.find<VipController>();
      return vipCtrl.vipLevel.value >= book.requiredVipLevel;
    } else {
      // User uploaded paid content
      if (purchasedBookIds.contains(book.id) || book.sellerId == 'me') {
        return true;
      }
      final vipCtrl = Get.find<VipController>();
      final novelCtrl = Get.find<NovelController>();
      
      // VIP 5+ or Novel 4+ can unlock via free reads quota
      if (vipCtrl.vipLevel.value >= 5 && vipCtrl.hasFreeReadsLeft(book.id)) {
        return true;
      }
      if (novelCtrl.novelLevel.value >= 4 && novelCtrl.hasFreeReadsLeft(book.id)) {
        return true;
      }
      return false; // locked otherwise
    }
  }

  bool isBookAccessedViaMembership(StudyVaultItem book) {
    if (book.sellingPrice == 0) return false; // Free books are not membership-based
    if (purchasedBookIds.contains(book.id) || book.sellerId == 'me') return false; // Purchased or owned books are not accessed via membership
    if (book.isOfficial) return false; // Official books are not uploader free reads

    final vipCtrl = Get.find<VipController>();
    final novelCtrl = Get.find<NovelController>();
    
    return vipCtrl.vipLevel.value >= 5 || novelCtrl.novelLevel.value >= 4;
  }

  void _checkAndResetDailyLimit() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (lastAccessDate.value != today) {
      lastAccessDate.value = today;
      membershipBooksReadToday.clear();
      _saveLocalState();
    }
  }

  int getDailyMembershipLimit() {
    final vipCtrl = Get.find<VipController>();
    final novelCtrl = Get.find<NovelController>();
    return max(vipCtrl.getFreeReadsLimit(), novelCtrl.getFreeReadsLimit());
  }

  bool canReadMembershipBook(StudyVaultItem book) {
    _checkAndResetDailyLimit();
    if (!isBookAccessedViaMembership(book)) return true;

    final vipCtrl = Get.find<VipController>();
    final novelCtrl = Get.find<NovelController>();

    if (vipCtrl.vipLevel.value >= 5 && vipCtrl.hasFreeReadsLeft(book.id)) {
      return true;
    }
    if (novelCtrl.novelLevel.value >= 4 && novelCtrl.hasFreeReadsLeft(book.id)) {
      return true;
    }
    return false;
  }

  bool checkMembershipReadingLimit(StudyVaultItem book) {
    _checkAndResetDailyLimit();

    if (purchasedBookIds.contains(book.id) || book.sellerId == 'me') return true;

    if (book.isOfficial) {
      final vipCtrl = Get.find<VipController>();
      if (vipCtrl.vipLevel.value >= book.requiredVipLevel) {
        return true;
      } else {
        Get.snackbar('Access Denied 🔒', 'Please purchase this book or upgrade your VIP membership.');
        return false;
      }
    }

    // Paid uploader book access check
    final vipCtrl = Get.find<VipController>();
    final novelCtrl = Get.find<NovelController>();

    if (vipCtrl.vipLevel.value >= 5) {
      if (vipCtrl.hasFreeReadsLeft(book.id)) {
        vipCtrl.consumeFreeRead(book.id);
        return true;
      } else {
        _showLimitDialog("VIP 5+ free reads quota exceeded. Upgrade or purchase to read permanently.");
        return false;
      }
    }

    if (novelCtrl.novelLevel.value >= 4) {
      if (novelCtrl.hasFreeReadsLeft(book.id)) {
        novelCtrl.consumeFreeRead(book.id);
        return true;
      } else {
        _showLimitDialog("Novel 4+ free reads quota exceeded. Upgrade or purchase to read permanently.");
        return false;
      }
    }

    Get.snackbar('Access Denied 🔒', 'Please purchase this book or upgrade your VIP/Novel membership.');
    return false;
  }

  void _showLimitDialog(String message) {
    if (Get.context != null) {
      Get.defaultDialog(
        title: 'Quota Limit Reached 🔒',
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        backgroundColor: const Color(0xFF13131A),
        content: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        confirm: ElevatedButton(
          onPressed: () {
            Get.back();
            Get.toNamed('/membership_center');
          },
          child: const Text('Upgrade Plan'),
        ),
        cancel: TextButton(
          onPressed: () => Get.back(),
          child: const Text('Close', style: TextStyle(color: Colors.white38)),
        ),
      );
    }
  }

  void _payoutSellerForReadVisit(StudyVaultItem book) {
    final double payout = 5.0;
    
    // Credit seller's wallet
    final wallet = sellerWallet.value;
    sellerWallet.value = wallet.copyWith(
      currentBalance: wallet.currentBalance + payout,
      withdrawableBalance: wallet.withdrawableBalance + payout,
    );

    // Try logging transaction to Supabase
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        client.from('wallet_transactions').insert({
          'wallet_id': UserProfileCacheManager.currentUserId,
          'amount': payout,
          'currency': 'INR',
          'type': 'Payout',
          'status': 'Completed',
          'reference_id': book.id,
          'details': 'Earned ₹5.00 for membership read visit of "${book.title}".',
        }).then((_) {});
      }
    } catch (_) {}

    // Create payout transaction log
    final newTx = VaultTransaction(
      id: 'TXN-VISIT-${Random().nextInt(90000) + 10000}',
      bookId: book.id,
      bookTitle: book.title,
      type: 'Read Visit Payout',
      amount: payout,
      status: 'Completed',
      dateTime: DateTime.now(),
      details: 'Earned ₹5.00 for membership read visit of "${book.title}".',
    );

    sellerTransactions.insert(0, newTx);
    sellerTotalSales.value += 1;

    if (Get.context != null) {
      Get.snackbar(
        'Creator Payout Earned! 💸',
        '₹5.00 credited to ${book.sellerName} for membership read visit.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void triggerReadVisitPayout(StudyVaultItem book) {
    _payoutSellerForReadVisit(book);
  }

  // ── Purchase flow ──
  Future<bool> purchaseBook(StudyVaultItem book, String paymentMethod) async {
    if (purchasedBookIds.contains(book.id)) return true;

    final vipCtrl = Get.find<VipController>();
    final storeCtrl = Get.find<StoreController>();
    final breakdown = calculatePriceBreakdown(book.sellingPrice, vipLevel: vipCtrl.vipLevel.value);
    
    // Proportional conversion: ₹100 = 50 Gold Coins.
    int goldCoinsPrice = (breakdown['buyerPays']! * 0.50).round();

    if (storeCtrl.coinsBalance.value < goldCoinsPrice) {
      Get.snackbar(
        'Insufficient Balance 🪙',
        'You need $goldCoinsPrice Gold Coins. Please recharge.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withOpacity(0.9),
        colorText: Colors.white,
      );
      return false;
    }

    // Deduct coins from store balance
    storeCtrl.coinsBalance.value -= goldCoinsPrice;
    
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        await client.from('wallet_transactions').insert({
          'wallet_id': UserProfileCacheManager.currentUserId,
          'amount': goldCoinsPrice.toDouble(),
          'currency': 'Coins',
          'type': 'Payout',
          'status': 'Completed',
          'reference_id': book.id,
          'details': 'Purchased Study Vault Book: ${book.title}',
        });

        await client.from('purchase_history').insert({
          'user_id': UserProfileCacheManager.currentUserId,
          'item_id': book.id,
          'item_type': 'Book',
          'price': goldCoinsPrice.toDouble(),
          'currency': 'Coins',
          'duration': 'One-Time',
        });
      }
    } catch (_) {}

    storeCtrl.coinTransactions.insert(0, CoinTransaction(
      type: 'Used',
      amount: goldCoinsPrice,
      description: 'Purchased Study Vault Book: ${book.title}',
      dateTime: DateTime.now(),
    ));

    // Register purchase in library
    purchasedBookIds.add(book.id);
    await _saveLocalState();

    // Trigger Gamification: Add Study XP for purchase!
    addStudyXp(20, 'Purchased a study resource!');

    Get.snackbar(
      'Purchase Successful! 🎉',
      '"${book.title}" added to My Library.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
    );

    return true;
  }

  // ── Wishlist management ──
  void toggleWishlist(String bookId) {
    if (wishlistBookIds.contains(bookId)) {
      wishlistBookIds.remove(bookId);
      Get.snackbar('Removed from Wishlist 📁', 'Resource removed from your wishlist.');
    } else {
      wishlistBookIds.add(bookId);
      Get.snackbar('Added to Wishlist 📁', 'We will notify you on price drops!',
        backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
        colorText: Colors.white,
      );
    }
    _saveLocalState();
  }

  // ── Seller Upload system ──
  Future<void> uploadBook({
    required String title,
    required String subtitle,
    required String description,
    required String category,
    required String course,
    required String semester,
    required String branch,
    required String university,
    required String language,
    required List<String> tags,
    required String authorName,
    required String publisher,
    required String edition,
    String? isbn,
    required int pages,
    required String fileType,
    required double basePrice,
    required int previewPages,
    required String pdfName,
    required String coverUrl,
  }) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      Get.snackbar('Upload Failed ⚠️', 'User is not logged in.');
      return;
    }

    final newBookMap = {
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'cover_image': coverUrl,
      'category': category,
      'course': course,
      'semester': semester,
      'branch': branch,
      'university': university,
      'language': language,
      'tags': tags,
      'author_name': authorName,
      'publisher': publisher,
      'edition': edition,
      'isbn': isbn,
      'pages': pages,
      'file_type': fileType,
      'pdf_url': pdfName,
      'thumbnail': coverUrl,
      'preview_pages_count': previewPages,
      'selling_price': basePrice,
      'license': 'Standard Digital License',
      'copyright_declaration': true,
      'is_official': false,
      'required_vip_level': 0,
      'seller_id': UserProfileCacheManager.currentUserId,
      'seller_name': 'Me',
      'seller_avatar': '',
      'status': 'Pending',
    };

    try {
      final inserted = await Supabase.instance.client
          .from('study_vault_items')
          .insert(newBookMap)
          .select()
          .single();

      final newBook = _itemFromMap(inserted);
      items.add(newBook);
      
      Get.snackbar(
        'Upload Submitted! 📚',
        'Your book has been sent to Admin queue for review.',
        backgroundColor: Colors.amber.withOpacity(0.9),
        colorText: Colors.black,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Upload Failed ⚠️', 'Error uploading: $e');
    }
  }

  // ── Wallet / Withdrawal Flow ──
  bool requestWithdrawal(double amount, String upiOrBankInfo) {
    final wallet = sellerWallet.value;
    if (amount <= 0 || amount > wallet.withdrawableBalance) {
      Get.snackbar('Withdrawal Failed ⚠️', 'Invalid amount or insufficient withdrawable balance.');
      return false;
    }

    // Process withdrawal simulation
    final newWithdrawable = wallet.withdrawableBalance - amount;
    final newPending = wallet.pendingBalance + amount;
    final newCurrent = wallet.currentBalance - amount;

    sellerWallet.value = wallet.copyWith(
      withdrawableBalance: newWithdrawable,
      pendingBalance: newPending,
      currentBalance: newCurrent,
    );

    // Create withdrawal transaction
    final newTx = VaultTransaction(
      id: 'TXN-${Random().nextInt(9000) + 1000}',
      bookId: 'N/A',
      bookTitle: 'Withdrawal to $upiOrBankInfo',
      type: 'Withdrawal',
      amount: amount,
      status: 'Pending', // Admin needs to approve
      dateTime: DateTime.now(),
      details: 'Awaiting Bank Settlement.',
    );

    sellerTransactions.insert(0, newTx);

    Get.snackbar(
      'Withdrawal Requested 💸',
      '₹${amount.toStringAsFixed(2)} is pending approval. Will settle in 24 hours.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF6366F1),
      colorText: Colors.white,
    );

    return true;
  }

  // ── Admin Panel controls ──
  void adminApproveBook(String id) {
    final idx = items.indexWhere((b) => b.id == id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(status: 'Approved');
      items.refresh();
      Get.snackbar('Approved ✅', 'Book is now live in the Study Vault marketplace.');
    }
  }

  void adminRejectBook(String id, String comment) {
    final idx = items.indexWhere((b) => b.id == id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(status: 'Rejected', adminComment: comment);
      items.refresh();
      Get.snackbar('Rejected ❌', 'Book rejected. Seller will be notified with comment.');
    }
  }

  void adminUploadOfficialBook({
    required String title,
    required String subtitle,
    required String description,
    required String category,
    required int vipLevel,
    required int pages,
    required String coverUrl,
  }) {
    final newOfficial = StudyVaultItem(
      id: 'official_${Random().nextInt(90000) + 10000}',
      title: title,
      subtitle: subtitle,
      description: description,
      coverImage: coverUrl,
      category: category,
      course: 'Creania Official Academy',
      semester: 'N/A',
      branch: 'All Sciences',
      university: 'Creania Board',
      language: 'English',
      tags: [category, 'Official', 'Membership'],
      authorName: 'Creania Authors',
      publisher: 'Creania Press',
      edition: '1st Edition',
      pages: pages,
      fileType: 'Books',
      pdfUrl: 'official_document.pdf',
      thumbnail: coverUrl,
      previewPagesCount: 10,
      sellingPrice: 0.0,
      license: 'Creania Enterprise License',
      copyrightDeclaration: true,
      isOfficial: true,
      requiredVipLevel: vipLevel,
      sellerId: 'admin_creania',
      sellerName: 'Creania Official',
      sellerAvatar: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=150',
      rating: 5.0,
      createdAt: DateTime.now(),
      status: 'Approved',
    );

    items.add(newOfficial);
    Get.snackbar(
      'Official Book Uploaded! 👑',
      'Unlocked for VIP $vipLevel members.',
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
    );
  }

  void adminApproveWithdrawal(String txId) {
    final txIdx = sellerTransactions.indexWhere((tx) => tx.id == txId);
    if (txIdx != -1) {
      final oldTx = sellerTransactions[txIdx];
      sellerTransactions[txIdx] = VaultTransaction(
        id: oldTx.id,
        bookId: oldTx.bookId,
        bookTitle: oldTx.bookTitle,
        type: oldTx.type,
        amount: oldTx.amount,
        status: 'Completed',
        dateTime: oldTx.dateTime,
        details: 'Settled by Admin.',
      );
      sellerTransactions.refresh();

      // Deduct pending balance from wallet
      final wallet = sellerWallet.value;
      sellerWallet.value = wallet.copyWith(
        pendingBalance: max(0.0, wallet.pendingBalance - oldTx.amount),
      );

      Get.snackbar('Withdrawal Settled 💳', 'Funds transferred to seller account.');
    }
  }

  // ── Gamification Engine ──
  void addStudyXp(int amount, String reason) {
    totalXp.value += amount;
    // Check level up (for every 1000 XP)
    _saveLocalState();
    Get.snackbar(
      '+$amount Study XP! ⚡',
      reason,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFFD700),
      colorText: Colors.black,
      duration: const Duration(milliseconds: 1500),
    );
  }

  // ── Reading history & progress tracking ──
  void startReadingSession(StudyVaultItem book, int page, {bool isPreview = false}) {
    _checkAndResetDailyLimit();

    if (!isPreview && isBookAccessedViaMembership(book)) {
      if (!membershipBooksReadToday.contains(book.id)) {
        membershipBooksReadToday.add(book.id);
        _saveLocalState();
        _payoutSellerForReadVisit(book);
      }
    }

    activeReadingBook.value = book;
    activeBookPage.value = page;
    readingTimeSeconds.value = 0.0;
  }

  void stopReadingSession() {
    final book = activeReadingBook.value;
    if (book == null) return;

    final currentHistory = readingProgress[book.id] ?? ReadingHistory(
      bookId: book.id,
      lastReadTime: DateTime.now(),
    );

    final updated = currentHistory.copyWith(
      lastPageRead: activeBookPage.value,
      readingProgress: min(1.0, activeBookPage.value / book.pages),
      lastReadTime: DateTime.now(),
      totalReadingDurationSeconds: currentHistory.totalReadingDurationSeconds + readingTimeSeconds.value,
    );

    readingProgress[book.id] = updated;

    // Track pages read
    final pagesAdded = max(0, activeBookPage.value - currentHistory.lastPageRead);
    pagesRead.value += pagesAdded;

    // Earn Study XP for reading! (1 XP per minute read + 2 XP per page read)
    int xpEarned = (readingTimeSeconds.value / 60).floor() + (pagesAdded * 2);
    if (xpEarned > 0) {
      addStudyXp(xpEarned, 'Read ${pagesAdded} pages!');
    }

    activeReadingBook.value = null;
    _saveLocalState();
  }

  void toggleBookmarkPage(String bookId, int page) {
    final history = readingProgress[bookId] ?? ReadingHistory(
      bookId: bookId,
      lastReadTime: DateTime.now(),
    );

    final bookmarks = Set<int>.from(history.bookmarkedPages);
    if (bookmarks.contains(page)) {
      bookmarks.remove(page);
    } else {
      bookmarks.add(page);
    }

    readingProgress[bookId] = history.copyWith(bookmarkedPages: bookmarks);
  }

  void saveHighlight(String bookId, int page, String text) {
    final history = readingProgress[bookId] ?? ReadingHistory(
      bookId: bookId,
      lastReadTime: DateTime.now(),
    );

    final highlights = Map<int, String>.from(history.highlights);
    highlights[page] = text;

    readingProgress[bookId] = history.copyWith(highlights: highlights);
    addStudyXp(5, 'Highlighted text on Page $page');
  }

  void saveNote(String bookId, int page, String note) {
    final history = readingProgress[bookId] ?? ReadingHistory(
      bookId: bookId,
      lastReadTime: DateTime.now(),
    );

    final notes = Map<int, String>.from(history.personalNotes);
    notes[page] = note;

    readingProgress[bookId] = history.copyWith(personalNotes: notes);
    addStudyXp(10, 'Created a study note on Page $page');
  }

  // ── AI Simulator Features ──
  String generateAISummary(String bookId) {
    return '📌 Key Summary Points:\n'
        '1. Introduces core frameworks, structural models, and practical application parameters.\n'
        '2. Breaks down mathematical derivations and optimization algorithms step-by-step.\n'
        '3. Evaluates real-world case studies detailing design flaws and troubleshooting steps.\n'
        '4. Suggests custom exercises, cheat sheets, and code templates for final exams.';
  }

  List<Map<String, String>> generateAIFlashcards(String bookId) {
    return [
      {'question': 'What is the primary optimization objective?', 'answer': 'Minimizing memory overhead and execution latency.'},
      {'question': 'How is validation error calculated?', 'answer': 'Using Mean Squared Error (MSE) across the holdout validation subset.'},
      {'question': 'What architectural model is used for state updates?', 'answer': 'An autonomous reactive controller with transaction logging.'},
    ];
  }

  List<Map<String, dynamic>> generateAIQuiz(String bookId) {
    return [
      {
        'question': 'Which complexity class does the main algorithm belong to?',
        'options': ['O(1)', 'O(log N)', 'O(N)', 'O(N^2)'],
        'answerIndex': 1,
        'explanation': 'Because it binary divides search partitions at each iterative execution step.',
      },
      {
        'question': 'What is the primary design pattern leveraged here?',
        'options': ['Singleton', 'Observer', 'Factory', 'Command'],
        'answerIndex': 1,
        'explanation': 'It handles reactive updates via pub-sub listeners and state notifications.',
      }
    ];
  }

  String solveAIDoubt(String bookId, String question) {
    return '🤖 AI Tutor:\n\n'
        'Based on the contents of this resource, your question "$question" can be answered by looking at the fundamental components. '
        'Specifically, we resolve this by optimizing resource bindings and utilizing asynchronous background handlers to keep the main execution thread non-blocking. '
        'Let me know if you would like me to draft a Dart code template demonstrating this!';
  }
}
