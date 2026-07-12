import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:creania/services/study_vault_controller.dart';
import 'package:creania/services/vip_controller.dart';
import 'package:creania/services/store_controller.dart';
import 'package:creania/services/novel_controller.dart';
import 'package:creania/models/study_vault_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late StudyVaultController controller;
  late VipController vipController;
  late StoreController storeController;
  late NovelController novelController;

  setUp(() {
    Get.reset();
    vipController = Get.put(VipController());
    storeController = Get.put(StoreController());
    novelController = Get.put(NovelController());
    controller = Get.put(StudyVaultController());
  });

  group('Study Vault Pricing Engine Tests', () {
    test('Standard Pricing without VIP Discount (Base: ₹100)', () {
      final breakdown = controller.calculatePriceBreakdown(100.0, vipLevel: 0);

      expect(breakdown['basePrice'], 100.0);
      expect(breakdown['discount'], 0.0);
      expect(breakdown['discountedBase'], 100.0);
      expect(breakdown['gst'], 18.0); // 18% of 100
      expect(breakdown['paymentGateway'], 2.0); // 2% of 100
      expect(breakdown['platformFee'], 17.0); // 17% of 100
      expect(breakdown['buyerPays'], 137.0); // 100 + 18 + 2 + 17 = 137
      expect(breakdown['sellerReceives'], 63.0); // 100 - 18 - 2 - 17 = 63
      expect(breakdown['platformReceives'], 74.0); // Platform receives: 137 - 63 = 74
    });

    test('Pricing with VIP 5 Discount (Base: ₹100, VIP 5: 25% off)', () {
      final breakdown = controller.calculatePriceBreakdown(100.0, vipLevel: 5);

      expect(breakdown['basePrice'], 100.0);
      expect(breakdown['discount'], 25.0); // 25% of 100
      expect(breakdown['discountedBase'], 75.0); // 100 - 25

      // Taxes/fees recalculated on discounted base (₹75)
      expect(breakdown['gst'], 75.0 * 0.18); // 13.5
      expect(breakdown['paymentGateway'], 75.0 * 0.02); // 1.5
      expect(breakdown['platformFee'], 75.0 * 0.17); // 12.75

      expect(breakdown['buyerPays'], 102.75); // 75.0 * 1.37
      expect(breakdown['sellerReceives'], 47.25); // 75.0 * 0.63
      expect(breakdown['platformReceives'], 55.5); // 102.75 - 47.25
    });

    test('Free Resource Calculations (Base: ₹0)', () {
      final breakdown = controller.calculatePriceBreakdown(0.0, vipLevel: 0);

      expect(breakdown['buyerPays'], 0.0);
      expect(breakdown['sellerReceives'], 0.0);
      expect(breakdown['platformReceives'], 0.0);
    });
  });

  group('Study Vault Access Logic Tests', () {
    test('User Uploaded Paid Book requires purchase', () {
      final paidBook = StudyVaultItem(
        id: 'test_paid_book',
        title: 'Paid Book',
        subtitle: '',
        description: '',
        coverImage: '',
        category: 'Coding',
        course: '',
        semester: '',
        branch: '',
        university: '',
        language: 'English',
        tags: [],
        authorName: '',
        publisher: '',
        edition: '',
        pages: 50,
        fileType: 'PDF',
        pdfUrl: '',
        thumbnail: '',
        previewPagesCount: 3,
        sellingPrice: 100.0,
        license: '',
        copyrightDeclaration: true,
        isOfficial: false,
        requiredVipLevel: 0,
        sellerId: 'other_seller',
        sellerName: '',
        sellerAvatar: '',
        createdAt: DateTime.now(),
      );

      // Reset membership levels to 0 to test purchase requirement
      vipController.vipLevel.value = 0;
      novelController.novelLevel.value = 0;

      // Initially locked
      expect(controller.isBookUnlocked(paidBook), false);

      // Unlock after adding to purchased list
      controller.purchasedBookIds.add(paidBook.id);
      expect(controller.isBookUnlocked(paidBook), true);
    });

    test('Official VIP3 Book requires VIP3 or above membership', () {
      final officialVip3Book = StudyVaultItem(
        id: 'official_vip3_book',
        title: 'Official VIP3 Book',
        subtitle: '',
        description: '',
        coverImage: '',
        category: 'Coding',
        course: '',
        semester: '',
        branch: '',
        university: '',
        language: 'English',
        tags: [],
        authorName: '',
        publisher: '',
        edition: '',
        pages: 50,
        fileType: 'PDF',
        pdfUrl: '',
        thumbnail: '',
        previewPagesCount: 3,
        sellingPrice: 0.0,
        license: '',
        copyrightDeclaration: true,
        isOfficial: true,
        requiredVipLevel: 3,
        sellerId: 'admin',
        sellerName: '',
        sellerAvatar: '',
        createdAt: DateTime.now(),
      );

      // VIP level is 3 (default seeded value in VipController is 3)
      vipController.vipLevel.value = 3;
      expect(controller.isBookUnlocked(officialVip3Book), true);

      // Downgrade to VIP2: Locks VIP3 book
      vipController.vipLevel.value = 2;
      expect(controller.isBookUnlocked(officialVip3Book), false);

      // Upgrade to VIP5: Unlocks VIP3 book
      vipController.vipLevel.value = 5;
      expect(controller.isBookUnlocked(officialVip3Book), true);
    });
  });

  group('Membership Daily Claims and Quota Limits Tests', () {
    test('VIP Daily Coin Claim 24-Hour Cooldown constraint', () async {
      vipController.vipLevel.value = 4;
      vipController.lastClaimTime.value = null;

      expect(vipController.canClaimDailyCoins(), true);
      expect(vipController.getDailyCoinsAmount(), 35);

      final initialCoins = storeController.coinsBalance.value;
      final success = await vipController.claimDailyCoins();
      expect(success, true);
      expect(storeController.coinsBalance.value, initialCoins + 35);
      expect(vipController.canClaimDailyCoins(), false); // blocked now
    });

    test('Novel Daily Coin Claim 24-Hour Cooldown constraint', () async {
      novelController.novelLevel.value = 3;
      novelController.lastClaimTime.value = null;

      expect(novelController.canClaimDailyCoins(), true);
      expect(novelController.getDailyCoinsAmount(), 70);

      final initialCoins = storeController.coinsBalance.value;
      final success = await novelController.claimDailyCoins();
      expect(success, true);
      expect(storeController.coinsBalance.value, initialCoins + 70);
      expect(novelController.canClaimDailyCoins(), false); // blocked now
    });

    test('Uploader Free Reads Quota Limits', () {
      final book1 = StudyVaultItem(
        id: 'member_book_1',
        title: 'Book 1',
        subtitle: '', description: '', coverImage: '', category: 'Coding', course: '', semester: '', branch: '', university: '', language: 'English', tags: [], authorName: '', publisher: '', edition: '', pages: 50, fileType: 'PDF', pdfUrl: '', thumbnail: '', previewPagesCount: 3,
        sellingPrice: 100.0,
        license: '', copyrightDeclaration: true, isOfficial: false, requiredVipLevel: 0, sellerId: 'other_seller', sellerName: '', sellerAvatar: '', createdAt: DateTime.now(),
      );

      final book2 = StudyVaultItem(
        id: 'member_book_2',
        title: 'Book 2',
        subtitle: '', description: '', coverImage: '', category: 'Coding', course: '', semester: '', branch: '', university: '', language: 'English', tags: [], authorName: '', publisher: '', edition: '', pages: 50, fileType: 'PDF', pdfUrl: '', thumbnail: '', previewPagesCount: 3,
        sellingPrice: 100.0,
        license: '', copyrightDeclaration: true, isOfficial: false, requiredVipLevel: 0, sellerId: 'other_seller', sellerName: '', sellerAvatar: '', createdAt: DateTime.now(),
      );

      // VIP 1-4 have 0 free reads quota
      vipController.vipLevel.value = 4;
      novelController.novelLevel.value = 0;
      expect(controller.isBookUnlocked(book1), false);

      // VIP 6 has 1 book/day free reads quota
      vipController.vipLevel.value = 6;
      vipController.vipFreeReadsToday.clear();
      expect(controller.isBookUnlocked(book1), true);

      // Read book 1 consumes quota
      expect(controller.checkMembershipReadingLimit(book1), true);
      expect(vipController.vipFreeReadsToday.contains(book1.id), true);

      // Try book 2 - should be blocked
      expect(controller.isBookUnlocked(book2), false);
      expect(controller.checkMembershipReadingLimit(book2), false);

      // Upgrade to VIP 7 (Allows 2 books/day)
      vipController.vipLevel.value = 7;
      vipController.vipFreeReadsToday.clear();
      vipController.vipFreeReadsToday.add(book1.id);
      expect(controller.isBookUnlocked(book2), true);
      expect(controller.checkMembershipReadingLimit(book2), true);
    });

    test('Seller receives ₹5.00 uploader payout upon first read visit today', () {
      final book = StudyVaultItem(
        id: 'member_book_visit',
        title: 'Book Visit Payout',
        subtitle: '', description: '', coverImage: '', category: 'Coding', course: '', semester: '', branch: '', university: '', language: 'English', tags: [], authorName: '', publisher: '', edition: '', pages: 50, fileType: 'PDF', pdfUrl: '', thumbnail: '', previewPagesCount: 3,
        sellingPrice: 100.0,
        license: '', copyrightDeclaration: true, isOfficial: false, requiredVipLevel: 0, sellerId: 'other_seller', sellerName: 'Other Seller', sellerAvatar: '', createdAt: DateTime.now(),
      );

      novelController.novelLevel.value = 0;
      vipController.vipLevel.value = 6;
      vipController.vipFreeReadsToday.clear();
      
      final initialBalance = controller.sellerWallet.value.currentBalance;

      // Start reading the book under membership
      expect(controller.checkMembershipReadingLimit(book), true);
      controller.startReadingSession(book, 1);
      controller.stopReadingSession();

      // Wallet balance should increase by ₹5.00
      expect(controller.sellerWallet.value.currentBalance, initialBalance + 5.0);

      // Transaction log should record it
      expect(controller.sellerTransactions.first.type, 'Read Visit Payout');
      expect(controller.sellerTransactions.first.amount, 5.0);
    });
  });
}
