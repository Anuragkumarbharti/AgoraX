import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_vault_model.dart';
import 'vip_controller.dart';
import 'store_controller.dart';
import 'novel_controller.dart';

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
  final RxInt totalXp = 4250.obs;
  final RxInt readingStreak = 5.obs;
  final RxInt pagesRead = 1250.obs;
  final RxInt booksReadCount = 14.obs;
  final RxList<String> unlockedBadges = <String>[
    '📚 Bookworm',
    '🔥 Page Turner',
    '⚡ Academic Streak',
    '⭐ Top Reader'
  ].obs;

  // Seller Dashboard variables (simulated for current user as a seller)
  final Rx<VaultWallet> sellerWallet = VaultWallet().obs;
  final RxList<VaultTransaction> sellerTransactions = <VaultTransaction>[].obs;
  final RxInt sellerFollowers = 184.obs;
  final RxDouble sellerRating = 4.8.obs;
  final RxInt sellerTotalSales = 245.obs;
  final RxDouble responseRate = 98.0.obs;
  final RxString sellerJoinedDate = '12 Jan 2025'.obs;

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
    _seedMockData();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load purchased list
    final purchased = prefs.getStringList('vault_purchased_ids');
    if (purchased != null) {
      purchasedBookIds.assignAll(purchased);
    } else {
      // Seed default purchased books for simulation
      purchasedBookIds.assignAll(['book_notes_flutter_dsa', 'book_btech_project_guide']);
    }

    // Load wishlist list
    final wishlist = prefs.getStringList('vault_wishlist_ids');
    if (wishlist != null) {
      wishlistBookIds.assignAll(wishlist);
    } else {
      wishlistBookIds.assignAll(['book_upsc_history_notes']);
    }

    // Load membership read list and date
    final dailyReads = prefs.getStringList('vault_membership_reads_today');
    if (dailyReads != null) {
      membershipBooksReadToday.assignAll(dailyReads);
    }
    lastAccessDate.value = prefs.getString('vault_last_access_date') ?? '';

    // Load gamification stats
    totalXp.value = prefs.getInt('vault_user_xp') ?? 4250;
    readingStreak.value = prefs.getInt('vault_reading_streak') ?? 5;
    pagesRead.value = prefs.getInt('vault_pages_read') ?? 1250;
    booksReadCount.value = prefs.getInt('vault_books_read_count') ?? 14;

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
  }

  void _seedMockData() {
    // ── Clear and seed catalog items ──
    items.assignAll([
      // User Uploaded - Paid
      StudyVaultItem(
        id: 'book_notes_flutter_dsa',
        title: 'Flutter DSA Cheatsheet',
        subtitle: 'Crack Flutter technical interviews with visual algorithms and Dart code.',
        description: 'A comprehensive handbook containing 50+ solved Data Structures and Algorithms questions written entirely in Dart and tailored specifically for Flutter/Dart developer interviews. Covers lists, maps, trees, graphs, dynamic programming, and custom state controllers.',
        coverImage: 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=400',
        category: 'Coding',
        course: 'BTech',
        semester: '7th',
        branch: 'Computer Science',
        university: 'KTU',
        language: 'English',
        tags: ['Flutter', 'DSA', 'Interview', 'Dart'],
        authorName: 'Rohan Sharma',
        publisher: 'Self-Published',
        edition: '2nd Edition',
        isbn: '978-3-16-148410-0',
        pages: 120,
        fileType: 'Notes',
        pdfUrl: 'mock_flutter_dsa_handbook.pdf',
        thumbnail: 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=100',
        previewPagesCount: 5,
        sellingPrice: 150.0,
        license: 'Standard Commercial License',
        copyrightDeclaration: true,
        isOfficial: false,
        requiredVipLevel: 0,
        sellerId: 'seller_rohan',
        sellerName: 'Rohan Sharma',
        sellerAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        rating: 4.8,
        reviewsCount: 34,
        viewsCount: 1420,
        downloadsCount: 180,
        purchasesCount: 88,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isFeatured: true,
        status: 'Approved',
      ),
      StudyVaultItem(
        id: 'book_upsc_history_notes',
        title: 'Modern Indian History Visualized',
        subtitle: 'Handwritten timeline notes for UPSC CSE Prelims & Mains.',
        description: 'Complete Modern Indian History timeline simplified into diagrams, mind maps, and bullet points. Made by a verified UPSC mentor, this document has helped 500+ candidates clear historical MCQ sections with ease.',
        coverImage: 'https://images.unsplash.com/photo-1461360370896-922624d12aa1?w=400',
        category: 'UPSC',
        course: 'Civil Services',
        semester: 'N/A',
        branch: 'General Studies',
        university: 'N/A',
        language: 'Hindi / English',
        tags: ['UPSC', 'History', 'GS1', 'Handwritten'],
        authorName: 'IAS Guru Priya',
        publisher: 'Chanakya Academy',
        edition: '2026 Edition',
        pages: 250,
        fileType: 'Notes',
        pdfUrl: 'mock_upsc_history_notes.pdf',
        thumbnail: 'https://images.unsplash.com/photo-1461360370896-922624d12aa1?w=100',
        previewPagesCount: 10,
        sellingPrice: 250.0,
        license: 'Educational Use Only',
        copyrightDeclaration: true,
        isOfficial: false,
        requiredVipLevel: 0,
        sellerId: 'seller_priya',
        sellerName: 'Priya Mehta',
        sellerAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        rating: 4.9,
        reviewsCount: 112,
        viewsCount: 4500,
        downloadsCount: 820,
        purchasesCount: 420,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        isFeatured: true,
        status: 'Approved',
      ),
      StudyVaultItem(
        id: 'book_btech_project_guide',
        title: 'AI Smart Mirror Project Manual',
        subtitle: 'Complete BTech Capstone Project documentation, code, & hardware list.',
        description: 'Looking for a final year BTech project? This guide includes complete Raspberry Pi code, hardware assembly guide, wood working diagrams, UI design using Flutter web, and a 80-page formal seminar report ready to submit.',
        coverImage: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=400',
        category: 'Projects',
        course: 'BTech',
        semester: '8th',
        branch: 'ECE / CSE',
        university: 'VTU',
        language: 'English',
        tags: ['Project', 'Raspberry Pi', 'Smart Mirror', 'Capstone'],
        authorName: 'Innovator Arjun',
        publisher: 'Arjun Labs',
        edition: 'v1.4',
        pages: 90,
        fileType: 'Projects',
        pdfUrl: 'mock_smart_mirror_btech.pdf',
        thumbnail: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=100',
        previewPagesCount: 3,
        sellingPrice: 499.0,
        license: 'Developer Commons License',
        copyrightDeclaration: true,
        isOfficial: false,
        requiredVipLevel: 0,
        sellerId: 'seller_arjun',
        sellerName: 'Arjun Singh',
        sellerAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        rating: 4.6,
        reviewsCount: 15,
        viewsCount: 850,
        downloadsCount: 45,
        purchasesCount: 22,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        isFeatured: false,
        status: 'Approved',
      ),

      // User Uploaded - Free
      StudyVaultItem(
        id: 'book_engineering_physics_lab',
        title: 'First Year Physics Lab Manual Solved',
        subtitle: 'Fully written lab record with graphs, calculations, and viva questions.',
        description: 'Complete solved record book for Engineering Physics Practical Lab. Includes Torsional Pendulum, Spectrometer, Laser divergence, Solar cell characteristics, and Newton Rings. Zero errors, checked by college professor.',
        coverImage: 'https://images.unsplash.com/photo-1507668077129-56e32842fceb?w=400',
        category: 'Engineering',
        course: 'BTech / Diploma',
        semester: '1st & 2nd',
        branch: 'All Branches',
        university: 'Mumbai University',
        language: 'English',
        tags: ['Physics', 'Lab Record', 'Viva', 'Practical'],
        authorName: 'Kavya Nair',
        publisher: 'MU Student Union',
        edition: '2025 Edition',
        pages: 45,
        fileType: 'Lab Manuals',
        pdfUrl: 'mock_physics_lab_solved.pdf',
        thumbnail: 'https://images.unsplash.com/photo-1507668077129-56e32842fceb?w=100',
        previewPagesCount: 5,
        sellingPrice: 0.0, // Free resource
        license: 'Open Source',
        copyrightDeclaration: true,
        isOfficial: false,
        requiredVipLevel: 0,
        sellerId: 'seller_kavya',
        sellerName: 'Kavya Nair',
        sellerAvatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
        rating: 4.7,
        reviewsCount: 48,
        viewsCount: 3200,
        downloadsCount: 1100,
        purchasesCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        isFeatured: false,
        status: 'Approved',
      ),

      // Official AgoraX - VIP Locked
      StudyVaultItem(
        id: 'official_ai_summary',
        title: 'Deep Learning Mastery Guide',
        subtitle: 'Comprehensive lecture series, mathematical proofs, and notebook snippets.',
        description: 'Official AgoraX Educational Resource. Covers backpropagation math, transformer architectures, CNN filter designs, and reinforcement learning. Curated by DeepMind researchers and IIT professors.',
        coverImage: 'https://images.unsplash.com/photo-1501504905252-473c47e087f8?w=400',
        category: 'AI',
        course: 'MTech / Research',
        semester: 'N/A',
        branch: 'AI & Data Science',
        university: 'AgoraX Academy',
        language: 'English',
        tags: ['AI', 'Deep Learning', 'Transformers', 'Math'],
        authorName: 'AgoraX Board',
        publisher: 'AgoraX Press',
        edition: '1st Edition',
        pages: 320,
        fileType: 'Books',
        pdfUrl: 'official_deep_learning_mastery.pdf',
        thumbnail: 'https://images.unsplash.com/photo-1501504905252-473c47e087f8?w=100',
        previewPagesCount: 15,
        sellingPrice: 0.0, // Membership unlock only
        license: 'AgoraX Enterprise License',
        copyrightDeclaration: true,
        isOfficial: true,
        requiredVipLevel: 5, // VIP 5 ONLY
        sellerId: 'admin_agorax',
        sellerName: 'AgoraX Official',
        sellerAvatar: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=150',
        rating: 5.0,
        reviewsCount: 180,
        viewsCount: 9200,
        downloadsCount: 2300,
        purchasesCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        isFeatured: true,
        status: 'Approved',
      ),
      StudyVaultItem(
        id: 'official_gate_cse',
        title: 'GATE CSE Master Class Notes',
        subtitle: 'Official theory handbooks for GATE aspirants (CS & IT).',
        description: 'Official AgoraX study vaults for GATE Exam preparation. Contains core theory for Operating Systems, DBMS, Theory of Computation, Compiler Design, and Discrete Mathematics, with short tricks and formulas.',
        coverImage: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=400',
        category: 'GATE',
        course: 'GATE Prep',
        semester: 'N/A',
        branch: 'Computer Science',
        university: 'AgoraX Prep',
        language: 'English',
        tags: ['GATE', 'CSE', 'DBMS', 'OS'],
        authorName: 'AgoraX Exam Board',
        publisher: 'AgoraX Press',
        edition: '2026 Revision',
        pages: 410,
        fileType: 'Question Banks',
        pdfUrl: 'official_gate_cse_notes.pdf',
        thumbnail: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=100',
        previewPagesCount: 20,
        sellingPrice: 0.0,
        license: 'AgoraX Student License',
        copyrightDeclaration: true,
        isOfficial: true,
        requiredVipLevel: 3, // VIP 3 or above
        sellerId: 'admin_agorax',
        sellerName: 'AgoraX Official',
        sellerAvatar: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=150',
        rating: 4.8,
        reviewsCount: 92,
        viewsCount: 4120,
        downloadsCount: 980,
        purchasesCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 80)),
        isFeatured: true,
        status: 'Approved',
      ),
      StudyVaultItem(
        id: 'official_python_kids',
        title: 'Python Coding for Beginners',
        subtitle: 'Visual interactive workbook for school students and coding newbies.',
        description: 'Interactive introduction to Python programming. Ideal for K-12 students. Includes animations prompts, puzzle sheets, and mini game templates.',
        coverImage: 'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=400',
        category: 'Programming',
        course: 'School Coding',
        semester: 'Grade 6-10',
        branch: 'Coding',
        university: 'AgoraX Kids',
        language: 'English',
        tags: ['Python', 'Beginners', 'Kids', 'Coding'],
        authorName: 'AgoraX Kids Team',
        publisher: 'AgoraX Press',
        edition: 'v2.0',
        pages: 110,
        fileType: 'Books',
        pdfUrl: 'official_python_kids.pdf',
        thumbnail: 'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=100',
        previewPagesCount: 15,
        sellingPrice: 0.0,
        license: 'AgoraX Free Educational License',
        copyrightDeclaration: true,
        isOfficial: true,
        requiredVipLevel: 1, // VIP 1 or above
        sellerId: 'admin_agorax',
        sellerName: 'AgoraX Official',
        sellerAvatar: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=150',
        rating: 4.9,
        reviewsCount: 220,
        viewsCount: 11500,
        downloadsCount: 5200,
        purchasesCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
        isFeatured: false,
        status: 'Approved',
      ),

      // Pending Approvals for Simulation
      StudyVaultItem(
        id: 'pending_notes_web3',
        title: 'Solidity Smart Contracts Security Audit Notes',
        subtitle: 'Handwritten notes on flash loan attacks and reentrancy exploits.',
        description: 'Advanced Ethereum contract security guidelines. Contains real code snippets from famous exploits (DAO, Euler Finance) and remediation techniques.',
        coverImage: 'https://images.unsplash.com/photo-1639762681485-074b7f938ba0?w=400',
        category: 'Cyber Security',
        course: 'Security Auditor',
        semester: 'N/A',
        branch: 'Blockchain',
        university: 'Open Web',
        language: 'English',
        tags: ['Web3', 'Blockchain', 'Solidity', 'Security'],
        authorName: 'Web3 Guru Dev',
        publisher: 'DeFi Labs',
        edition: 'v1.0',
        pages: 68,
        fileType: 'Notes',
        pdfUrl: 'pending_web3_security.pdf',
        thumbnail: 'https://images.unsplash.com/photo-1639762681485-074b7f938ba0?w=100',
        previewPagesCount: 3,
        sellingPrice: 320.0,
        license: 'Commercial',
        copyrightDeclaration: true,
        isOfficial: false,
        requiredVipLevel: 0,
        sellerId: 'me', // Current user uploaded!
        sellerName: 'Anurag Kumar',
        sellerAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
        rating: 0.0,
        reviewsCount: 0,
        viewsCount: 0,
        downloadsCount: 0,
        purchasesCount: 0,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        isFeatured: false,
        status: 'Pending',
      ),
    ]);

    // Seed mock reviews
    reviews.assignAll([
      StudyReview(
        id: 'rev1',
        bookId: 'book_notes_flutter_dsa',
        userName: 'Aman Verma',
        userAvatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
        rating: 5,
        reviewText: 'Perfect handbook for interviews! The algorithmic explanations are extremely intuitive and having Dart code makes practicing directly in Flutter super easy. Highly recommended.',
        helpfulCount: 14,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      StudyReview(
        id: 'rev2',
        bookId: 'book_notes_flutter_dsa',
        userName: 'Kirti Sen',
        userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        rating: 4,
        reviewText: 'Excellent mind maps and clean code. Only minor issue is a few typos in chapter 4 but the algorithms are solid.',
        helpfulCount: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ]);

    // Seed default piracy reports
    piracyReports.assignAll([
      {
        'id': 'rep_001',
        'bookTitle': 'Modern Indian History Visualized',
        'reporter': 'Chanakya Academy Rep',
        'reason': 'Copyright Infringement - Uses our copyrighted notes diagrams directly.',
        'dateTime': DateTime.now().subtract(const Duration(days: 2)).toString(),
        'status': 'Open',
      }
    ]);

    // Seed Seller Wallet
    sellerWallet.value = VaultWallet(
      currentBalance: 15450.0,
      pendingBalance: 1200.0,
      withdrawableBalance: 14250.0,
      totalEarnings: 35800.0,
      totalSales: 245,
      refunds: 320.0,
    );

    // Seed Seller Transactions
    sellerTransactions.assignAll([
      VaultTransaction(
        id: 'TXN-9021',
        bookId: 'book_notes_flutter_dsa',
        bookTitle: 'Flutter DSA Cheatsheet',
        type: 'Sale',
        amount: 94.5, // Base 150 * 0.63
        status: 'Completed',
        dateTime: DateTime.now().subtract(const Duration(hours: 3)),
        details: 'Gold Coins purchase by @user_xyz',
      ),
      VaultTransaction(
        id: 'TXN-8812',
        bookId: 'N/A',
        bookTitle: 'Withdrawal to UPI (anurag@upi)',
        type: 'Withdrawal',
        amount: 5000.0,
        status: 'Completed',
        dateTime: DateTime.now().subtract(const Duration(days: 4)),
        details: 'Transferred to bank account',
      ),
      VaultTransaction(
        id: 'TXN-7734',
        bookId: 'book_btech_project_guide',
        bookTitle: 'AI Smart Mirror Project Manual',
        type: 'Sale',
        amount: 314.37, // Base 499 * 0.63
        status: 'Completed',
        dateTime: DateTime.now().subtract(const Duration(days: 8)),
        details: 'Purchase by @student_dev',
      ),
    ]);
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
          'wallet_id': client.auth.currentUser!.id,
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
          'wallet_id': client.auth.currentUser!.id,
          'amount': goldCoinsPrice.toDouble(),
          'currency': 'Coins',
          'type': 'Payout',
          'status': 'Completed',
          'reference_id': book.id,
          'details': 'Purchased Study Vault Book: ${book.title}',
        });

        await client.from('purchase_history').insert({
          'user_id': client.auth.currentUser!.id,
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
  void uploadBook({
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
  }) {
    final newBook = StudyVaultItem(
      id: 'book_user_${Random().nextInt(90000) + 10000}',
      title: title,
      subtitle: subtitle,
      description: description,
      coverImage: coverUrl,
      category: category,
      course: course,
      semester: semester,
      branch: branch,
      university: university,
      language: language,
      tags: tags,
      authorName: authorName,
      publisher: publisher,
      edition: edition,
      isbn: isbn,
      pages: pages,
      fileType: fileType,
      pdfUrl: pdfName,
      thumbnail: coverUrl,
      previewPagesCount: previewPages,
      sellingPrice: basePrice,
      license: 'Standard Digital License',
      copyrightDeclaration: true,
      isOfficial: false,
      requiredVipLevel: 0,
      sellerId: 'me', // Current user
      sellerName: 'Anurag Kumar',
      sellerAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
      rating: 0.0,
      reviewsCount: 0,
      createdAt: DateTime.now(),
      status: 'Pending', // Requires Admin approval
    );

    items.add(newBook);
    Get.snackbar(
      'Upload Submitted! 📚',
      'Your book has been sent to Admin queue for review.',
      backgroundColor: Colors.amber.withOpacity(0.9),
      colorText: Colors.black,
      snackPosition: SnackPosition.BOTTOM,
    );
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
      course: 'AgoraX Official Academy',
      semester: 'N/A',
      branch: 'All Sciences',
      university: 'AgoraX Board',
      language: 'English',
      tags: [category, 'Official', 'Membership'],
      authorName: 'AgoraX Authors',
      publisher: 'AgoraX Press',
      edition: '1st Edition',
      pages: pages,
      fileType: 'Books',
      pdfUrl: 'official_document.pdf',
      thumbnail: coverUrl,
      previewPagesCount: 10,
      sellingPrice: 0.0,
      license: 'AgoraX Enterprise License',
      copyrightDeclaration: true,
      isOfficial: true,
      requiredVipLevel: vipLevel,
      sellerId: 'admin_agorax',
      sellerName: 'AgoraX Official',
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
