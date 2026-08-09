import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:creania/services/store/store_controller.dart';
import 'package:creania/services/memberships/vip_controller.dart';
import 'package:creania/services/memberships/novel_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Purchase Fulfillment Unit Tests', () {
    late StoreController storeCtrl;
    late VipController vipCtrl;
    late NovelController novelCtrl;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();

      storeCtrl = Get.put(StoreController());
      vipCtrl = Get.put(VipController());
      novelCtrl = Get.put(NovelController());
    });

    tearDown(() {
      Get.reset();
    });

    test('Coin Pack recharge credits coin balance and logs transaction', () async {
      expect(storeCtrl.coinsBalance.value, 0);

      // Simulate purchasing Starter Pack (50 coins for 100 INR)
      await storeCtrl.rechargeGoldCoins(100.0, paymentId: 'pay_test_coin_100', totalCoins: 50);

      expect(storeCtrl.coinsBalance.value, 50);
      expect(storeCtrl.coinTransactions.isNotEmpty, true);
      expect(storeCtrl.coinTransactions.first.amount, 50);
      expect(storeCtrl.coinTransactions.first.type, 'Purchased');
    });

    test('VIP purchase updates vipLevel and activates status', () async {
      expect(vipCtrl.vipLevel.value, 0);

      await vipCtrl.purchaseVip(1, '30 Days', 199.0, paymentMethod: 'Razorpay Gateway', paymentId: 'pay_test_vip');

      expect(vipCtrl.vipLevel.value, 1);
      expect(vipCtrl.expiryDate.value, isNotNull);
      expect(vipCtrl.activeFrame.value, 'Royal Frame');
    });

    test('Novel purchase updates novelLevel and activates status', () async {
      expect(novelCtrl.novelLevel.value, 0);

      await novelCtrl.purchaseNovel(2, '30 Days', 299.0, paymentId: 'pay_test_novel');

      expect(novelCtrl.novelLevel.value, 2);
      expect(novelCtrl.expiryDate.value, isNotNull);
      expect(novelCtrl.ownedNovels.contains(2), true);
    });
  });
}
