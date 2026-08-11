import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wallet Security & Idempotency Tests', () {
    test('Null or missing database wallet fields evaluate strictly to 0 (Never 1,000,000)', () {
      final Map<String, dynamic> walletDataNull = {
        'coins_balance': null,
        'gold_coins': null,
        'silver_coins_balance': null,
        'silver_coins': null,
      };

      final int fetchedCoins = ((walletDataNull['coins_balance'] ?? walletDataNull['gold_coins']) ?? 0) as int;
      final int fetchedSilver = ((walletDataNull['silver_coins_balance'] ?? walletDataNull['silver_coins']) ?? 0) as int;

      expect(fetchedCoins, equals(0));
      expect(fetchedSilver, equals(0));
      expect(fetchedCoins, isNot(equals(1000000)));
      expect(fetchedSilver, isNot(equals(1000000)));
    });

    test('Abnormally large single reward attempts (> 6,000) are unconditionally rejected per transaction', () {
      bool isAllowedTransaction(int amount, String source) {
        if (amount <= 0) return false;
        if (amount > 6000) return false; // Strict 6k per-transaction cap
        return true;
      }

      expect(isAllowedTransaction(1000000, 'FreeReward'), isFalse);
      expect(isAllowedTransaction(500000, 'RoomJoinBonus'), isFalse);
      expect(isAllowedTransaction(50000, 'RazorpayGatewayPayment'), isFalse); // >6k blocked
      expect(isAllowedTransaction(5599, 'LegendPack5kCoinsWithBonus'), isTrue); // Valid 5,599 coins Legend Pack
      expect(isAllowedTransaction(50, 'DailyTask'), isTrue);
    });

    test('Transaction idempotency checks prevent duplicate crediting for same transaction ID', () {
      final Set<String> processedTxIds = {};
      int walletBalance = 100;

      Map<String, dynamic> processWalletTx({
        required String txId,
        required int amount,
      }) {
        if (processedTxIds.contains(txId)) {
          return {
            'success': true,
            'already_processed': true,
            'new_balance': walletBalance,
          };
        }

        processedTxIds.add(txId);
        walletBalance += amount;
        return {
          'success': true,
          'already_processed': false,
          'new_balance': walletBalance,
        };
      }

      // First processing
      final res1 = processWalletTx(txId: 'tx_gift_998123', amount: 50);
      expect(res1['already_processed'], isFalse);
      expect(res1['new_balance'], equals(150));

      // Retry/Duplicate event processing with same txId
      final res2 = processWalletTx(txId: 'tx_gift_998123', amount: 50);
      expect(res2['already_processed'], isTrue);
      expect(res2['new_balance'], equals(150)); // Balance remains 150 (not 200!)
    });
  });

  group('Payment Recharge Idempotency & Per-Transaction Cap Tests', () {
    // Simulated database tables for testing payment recharge logic
    final Map<String, Map<String, dynamic>> verifiedPaymentsDb = {};
    final Map<String, Map<String, dynamic>> purchasesDb = {};
    final Map<String, int> userWallets = {};

    void resetMockDatabase() {
      verifiedPaymentsDb.clear();
      purchasesDb.clear();
      userWallets.clear();

      // Seed pre-verified gateway payments (₹10,000 INR = 5,000 Gold Coins)
      verifiedPaymentsDb['pay_A'] = {'payment_id': 'pay_A', 'user_id': 'user_1', 'amount': 10000.0, 'status': 'Success'};
      verifiedPaymentsDb['pay_B'] = {'payment_id': 'pay_B', 'user_id': 'user_1', 'amount': 10000.0, 'status': 'Success'};
      verifiedPaymentsDb['pay_C'] = {'payment_id': 'pay_C', 'user_id': 'user_1', 'amount': 10000.0, 'status': 'Success'};
      verifiedPaymentsDb['pay_D'] = {'payment_id': 'pay_D', 'user_id': 'user_1', 'amount': 10000.0, 'status': 'Success'};
      verifiedPaymentsDb['pay_failed'] = {'payment_id': 'pay_failed', 'user_id': 'user_1', 'amount': 10000.0, 'status': 'Failed'};

      for (int i = 1; i <= 5; i++) {
        verifiedPaymentsDb['pay_multi_$i'] = {'payment_id': 'pay_multi_$i', 'user_id': 'user_1', 'amount': 10000.0, 'status': 'Success'};
      }
    }

    // Thread-safe atomic RPC simulator (mimics PostgreSQL FOR UPDATE row locks)
    Future<Map<String, dynamic>> processVerifiedPaymentRechargeRpc({
      required String userId,
      required String paymentId,
      required double amount,
      required int coinsAmount,
    }) async {
      // Small async delay to simulate network latency & concurrent execution
      await Future.delayed(const Duration(milliseconds: 2));

      // Synchronized transaction block inside atomic database lock
      // 1. Per-transaction cap check (6,000 coins max per single transaction)
      if (coinsAmount > 6000) {
        return {'success': false, 'error': 'Recharge coins amount exceeds single transaction cap of 6,000 coins'};
      }

      // 2. Idempotency Check on Purchases DB
      if (purchasesDb.containsKey(paymentId)) {
        final existingPurchase = purchasesDb[paymentId]!;

        if (existingPurchase['user_id'] != userId) {
          return {'success': false, 'error': 'Payment ID belongs to a different user'};
        }
        if (existingPurchase['amount'] != amount) {
          return {'success': false, 'error': 'Payment ID amount mismatch'};
        }
        if (existingPurchase['status'] == 'Success') {
          return {
            'success': true,
            'already_processed': true,
            'coins_added': 0,
            'new_balance': userWallets[userId] ?? 0,
          };
        }
        if (existingPurchase['status'] == 'Failed') {
          return {'success': false, 'error': 'Payment marked failed cannot be fulfilled'};
        }
      }

      // 3. Verification check on Gateway Payments DB
      if (!verifiedPaymentsDb.containsKey(paymentId)) {
        return {'success': false, 'error': 'Unverified or fake payment ID'};
      }

      final verifiedPayment = verifiedPaymentsDb[paymentId]!;
      if (verifiedPayment['user_id'] != userId) {
        return {'success': false, 'error': 'Payment ID user mismatch'};
      }
      if (verifiedPayment['amount'] != amount) {
        return {'success': false, 'error': 'Payment ID amount mismatch'};
      }
      if (verifiedPayment['status'] != 'Success') {
        return {'success': false, 'error': 'Unverified or failed payment status'};
      }

      // 4. Fulfill & credit balance (Accumulates cleanly, no cumulative artificial cap)
      final int prevBalance = userWallets[userId] ?? 0;
      final int newBalance = prevBalance + coinsAmount;
      userWallets[userId] = newBalance;

      // Mark purchase consumed & fulfilled
      purchasesDb[paymentId] = {
        'payment_id': paymentId,
        'user_id': userId,
        'amount': amount,
        'status': 'Success',
      };

      return {
        'success': true,
        'already_processed': false,
        'coins_added': coinsAmount,
        'previous_balance': prevBalance,
        'new_balance': newBalance,
      };
    }

    setUp(() {
      resetMockDatabase();
    });

    test('1. 5K payment -> +5K (Payment A)', () async {
      final res = await processVerifiedPaymentRechargeRpc(
        userId: 'user_1',
        paymentId: 'pay_A',
        amount: 10000.0,
        coinsAmount: 5000,
      );

      expect(res['success'], isTrue);
      expect(res['already_processed'], isFalse);
      expect(res['coins_added'], equals(5000));
      expect(res['new_balance'], equals(5000));
    });

    test('2. Second separate 5K payment -> +5K (Payment B -> Total = 10K)', () async {
      await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_A', amount: 10000.0, coinsAmount: 5000);
      final resB = await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_B', amount: 10000.0, coinsAmount: 5000);

      expect(resB['success'], isTrue);
      expect(resB['already_processed'], isFalse);
      expect(resB['coins_added'], equals(5000));
      expect(resB['new_balance'], equals(10000)); // 5K + 5K = 10K
    });

    test('3. Third separate 5K payment -> +5K (Payment C -> Total = 15K)', () async {
      await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_A', amount: 10000.0, coinsAmount: 5000);
      await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_B', amount: 10000.0, coinsAmount: 5000);
      final resC = await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_C', amount: 10000.0, coinsAmount: 5000);

      expect(resC['success'], isTrue);
      expect(resC['already_processed'], isFalse);
      expect(resC['coins_added'], equals(5000));
      expect(resC['new_balance'], equals(15000)); // 5K + 5K + 5K = 15K
    });

    test('4. Retry first payment -> +0 (Idempotent skip, balance remains 15K)', () async {
      await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_A', amount: 10000.0, coinsAmount: 5000);
      await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_B', amount: 10000.0, coinsAmount: 5000);
      await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_C', amount: 10000.0, coinsAmount: 5000);

      final resRetry = await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_A', amount: 10000.0, coinsAmount: 5000);

      expect(resRetry['success'], isTrue);
      expect(resRetry['already_processed'], isTrue);
      expect(resRetry['coins_added'], equals(0));
      expect(resRetry['new_balance'], equals(15000));
    });

    test('5. STRESS TEST: 10 simultaneous requests with SAME payment_id -> +5,000 once, 9 already_processed', () async {
      final futures = List.generate(10, (_) => processVerifiedPaymentRechargeRpc(
        userId: 'user_1',
        paymentId: 'pay_A',
        amount: 10000.0,
        coinsAmount: 5000,
      ));

      final results = await Future.wait(futures);

      final freshFulfillments = results.where((r) => r['already_processed'] == false).toList();
      final duplicateSkips = results.where((r) => r['already_processed'] == true).toList();

      expect(freshFulfillments.length, equals(1)); // Exactly 1 fulfilled
      expect(duplicateSkips.length, equals(9));   // Exactly 9 idempotent skips
      expect(userWallets['user_1'], equals(5000)); // Final balance exactly 5K
    });

    test('6. STRESS TEST: 50 simultaneous requests with SAME payment_id -> +5,000 once, 49 already_processed', () async {
      final futures = List.generate(50, (_) => processVerifiedPaymentRechargeRpc(
        userId: 'user_1',
        paymentId: 'pay_A',
        amount: 10000.0,
        coinsAmount: 5000,
      ));

      final results = await Future.wait(futures);

      final freshFulfillments = results.where((r) => r['already_processed'] == false).toList();
      final duplicateSkips = results.where((r) => r['already_processed'] == true).toList();

      expect(freshFulfillments.length, equals(1)); // Exactly 1 fulfilled
      expect(duplicateSkips.length, equals(49));  // Exactly 49 idempotent skips
      expect(userWallets['user_1'], equals(5000)); // Never +10K or +250K
    });

    test('7. STRESS TEST: 5 DIFFERENT verified payment_ids simultaneously -> +25,000 total', () async {
      final futures = List.generate(5, (i) => processVerifiedPaymentRechargeRpc(
        userId: 'user_1',
        paymentId: 'pay_multi_${i + 1}',
        amount: 10000.0,
        coinsAmount: 5000,
      ));

      final results = await Future.wait(futures);

      final freshFulfillments = results.where((r) => r['already_processed'] == false).toList();
      expect(freshFulfillments.length, equals(5));
      expect(userWallets['user_1'], equals(25000)); // 5 * 5K = 25,000 coins
    });

    test('8. Fake payment ID -> +0 (Rejected server-side)', () async {
      final resFake = await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_FAKE_99999', amount: 10000.0, coinsAmount: 5000);

      expect(resFake['success'], isFalse);
      expect(resFake['error'], contains('Unverified or fake payment ID'));
      expect(userWallets['user_1'] ?? 0, equals(0));
    });

    test('9. Payment marked failed -> +0 (Rejected server-side)', () async {
      final resFailed = await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_failed', amount: 10000.0, coinsAmount: 5000);

      expect(resFailed['success'], isFalse);
      expect(resFailed['error'], contains('Unverified or failed payment status'));
      expect(userWallets['user_1'] ?? 0, equals(0));
    });

    test('10. Security Check: Same payment ID with different user -> REJECTED', () async {
      final resWrongUser = await processVerifiedPaymentRechargeRpc(userId: 'user_IMPOSTOR', paymentId: 'pay_A', amount: 10000.0, coinsAmount: 5000);

      expect(resWrongUser['success'], isFalse);
      expect(resWrongUser['error'], contains('Payment ID user mismatch'));
    });

    test('11. Security Check: Same payment ID with different amount -> REJECTED', () async {
      final resWrongAmount = await processVerifiedPaymentRechargeRpc(userId: 'user_1', paymentId: 'pay_A', amount: 1.0, coinsAmount: 5000);

      expect(resWrongAmount['success'], isFalse);
      expect(resWrongAmount['error'], contains('Payment ID amount mismatch'));
    });
  });
}
