import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/user_model.dart';
import 'dart:math' as math;

// Simple test helper to simulate the resolved entrance effect priority logic
String resolveEntranceEffect({
  required String effectStr,
  required int vipLvl,
  required int novelLvl,
}) {
  String targetEffect = 'None';
  final cleanEffect = effectStr.trim();
  if (cleanEffect.isNotEmpty && cleanEffect != 'null') {
    if (cleanEffect == 'Neon Gateway' || cleanEffect == 'VIP 2' || cleanEffect == 'VIP Level 2' || cleanEffect == 'VIP2') {
      targetEffect = 'VIP 2';
    } else if (cleanEffect == 'Royal Portal' || cleanEffect == 'VIP 1' || cleanEffect == 'VIP Level 1' || cleanEffect == 'VIP1') {
      targetEffect = 'VIP 1';
    } else if (cleanEffect.contains('Novel') || cleanEffect.contains('novel')) {
      targetEffect = 'Novel';
    } else if (cleanEffect == 'None') {
      targetEffect = 'None';
    } else {
      if (vipLvl >= 2) {
        targetEffect = 'VIP 2';
      } else if (vipLvl == 1) {
        targetEffect = 'VIP 1';
      } else if (novelLvl >= 1) {
        targetEffect = 'Novel';
      }
    }
  } else {
    if (vipLvl >= 2) {
      targetEffect = 'VIP 2';
    } else if (vipLvl == 1) {
      targetEffect = 'VIP 1';
    } else if (novelLvl >= 1) {
      targetEffect = 'Novel';
    }
  }
  return targetEffect;
}

// Simulates the backend signature verification & transaction commit
Future<Map<String, dynamic>> verifyAndCommitPayment({
  required String orderId,
  required String paymentId,
  required String signature,
  required String expectedSignature,
  required Set<String> processedPayments,
  required bool dbCommitSucceeds,
}) async {
  if (signature != expectedSignature) {
    return {'success': false, 'error': 'Signature Verification Failed'};
  }

  // Idempotency Check
  if (processedPayments.contains(paymentId)) {
    return {'success': true, 'message': 'Idempotent Success (Duplicate Callback)'};
  }

  if (!dbCommitSucceeds) {
    return {'success': false, 'error': 'Database Transaction Rollback'};
  }

  processedPayments.add(paymentId);
  return {'success': true, 'message': 'Committed Successfully'};
}

void main() {
  group('Membership System Serialization & Expiry Tests', () {
    test('Should parse membership_assets from JSON correctly', () {
      final json = {
        'id': 'test-user-id',
        'username': 'premium_student',
        'email': 'premium@creaniaa.com',
        'interests': [],
        'communities': [],
        'vip_level': 2,
        'novel_level': 1,
        'vip_expiry': '2026-08-16T12:00:00Z',
        'novel_expiry': '2026-09-16T12:00:00Z',
        'membership_assets': {
          'avatar_frame': 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_frame.webp',
          'chat_bubble': 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bubble.png',
          'name_glow': '#8B5CF6',
          'identity_tag': 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_2_tag.png',
          'profile_theme': 'amethyst_purple',
          'background_effect': 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bg.jpg'
        }
      };

      final user = User.fromJson(json);

      expect(user.vipLevel, 2);
      expect(user.novelLevel, 1);
      expect(user.vipExpiry, isNotNull);
      expect(user.vipExpiry!.year, 2026);
      expect(user.vipExpiry!.month, 8);
      expect(user.vipExpiry!.day, 16);

      expect(user.novelExpiry, isNotNull);
      expect(user.novelExpiry!.year, 2026);
      expect(user.novelExpiry!.month, 9);
      expect(user.novelExpiry!.day, 16);

      expect(user.membershipAssets, isNotNull);
      expect(user.membershipAssets['avatar_frame'], 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_frame.webp');
      expect(user.membershipAssets['chat_bubble'], 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bubble.png');
      expect(user.membershipAssets['name_glow'], '#8B5CF6');
      expect(user.membershipAssets['identity_tag'], 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/badges/vip_2_tag.png');
      expect(user.membershipAssets['profile_theme'], 'amethyst_purple');
      expect(user.membershipAssets['background_effect'], 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/frames/vip_2_bg.jpg');
    });

    test('Should copyWith membership_assets correctly', () {
      final user = User(
        id: 'user-1',
        username: 'alice',
        email: 'alice@creaniaa.com',
        interests: const [],
        communities: const [],
        followers: 0,
        following: 0,
        isVerified: false,
        isPremium: false,
        reputation: 0,
        sid: '123456',
        membershipAssets: const {
          'avatar_frame': 'frame_url_old',
        },
      );

      final updated = user.copyWith(
        membershipAssets: {
          'avatar_frame': 'frame_url_new',
          'chat_bubble': 'bubble_url_new',
        },
      );

      expect(updated.membershipAssets['avatar_frame'], 'frame_url_new');
      expect(updated.membershipAssets['chat_bubble'], 'bubble_url_new');
    });
  });

  group('Carry-Forward Stacking Calculation Tests', () {
    test('Same Level Renewal (100% days carry forward)', () {
      final now = DateTime.now();
      final currentExpiry = now.add(const Duration(days: 10)); // 10 days remaining
      const currentLevel = 2;
      const targetLevel = 2;
      const targetDays = 30;

      double totalDaysDouble = targetDays.toDouble();
      final double remainingDays = currentExpiry.difference(now).inSeconds / 86400.0;
      if (remainingDays > 0) {
        if (targetLevel == currentLevel) {
          totalDaysDouble = remainingDays + targetDays;
        }
      }

      final finalTotalDays = totalDaysDouble.round();
      expect(finalTotalDays, 40); // 10 remaining + 30 new
    });

    test('Higher Level Upgrade (Cascading 50% carry forward per step)', () {
      final now = DateTime.now();
      final currentExpiry = now.add(const Duration(days: 10)); // 10 days remaining
      const currentLevel = 1;
      const targetLevel = 2; // 1 step upgrade
      const targetDays = 30;

      double totalDaysDouble = targetDays.toDouble();
      final double remainingDays = currentExpiry.difference(now).inSeconds / 86400.0;
      if (remainingDays > 0) {
        if (targetLevel > currentLevel) {
          final int steps = targetLevel - currentLevel;
          final double carriedDays = remainingDays * math.pow(0.5, steps);
          totalDaysDouble = targetDays + carriedDays;
        }
      }

      final finalTotalDays = totalDaysDouble.round();
      expect(finalTotalDays, 35); // 30 new + (10 remaining * 50% = 5)
    });

    test('Multi-tier Upgrade (Cascading 50% carry forward for multiple steps)', () {
      final now = DateTime.now();
      final currentExpiry = now.add(const Duration(days: 20)); // 20 days remaining
      const currentLevel = 1;
      const targetLevel = 3; // 2 steps upgrade
      const targetDays = 30;

      double totalDaysDouble = targetDays.toDouble();
      final double remainingDays = currentExpiry.difference(now).inSeconds / 86400.0;
      if (remainingDays > 0) {
        if (targetLevel > currentLevel) {
          final int steps = targetLevel - currentLevel;
          final double carriedDays = remainingDays * math.pow(0.5, steps);
          totalDaysDouble = targetDays + carriedDays;
        }
      }

      final finalTotalDays = totalDaysDouble.round();
      expect(finalTotalDays, 35); // 30 new + (20 remaining * 25% = 5)
    });
  });

  group('Entry Effect Priority & Custom Choice Tests', () {
    test('Should prioritize VIP 2 when equipped even if user has other levels', () {
      final effect = resolveEntranceEffect(
        effectStr: 'Neon Gateway',
        vipLvl: 2,
        novelLvl: 1,
      );
      expect(effect, 'VIP 2');
    });

    test('Should prioritize VIP 1 when equipped', () {
      final effect = resolveEntranceEffect(
        effectStr: 'Royal Portal',
        vipLvl: 2,
        novelLvl: 1,
      );
      expect(effect, 'VIP 1');
    });

    test('Should prioritize Novel 1 when Novel 1 is selected explicitly by a VIP 2 user', () {
      final effect = resolveEntranceEffect(
        effectStr: 'Novel Level 1',
        vipLvl: 2,
        novelLvl: 1,
      );
      expect(effect, 'Novel');
    });

    test('Should play None if user equipped None explicitly', () {
      final effect = resolveEntranceEffect(
        effectStr: 'None',
        vipLvl: 2,
        novelLvl: 1,
      );
      expect(effect, 'None');
    });

    test('Should fall back to VIP 2 if effect is not specified and user is VIP 2', () {
      final effect = resolveEntranceEffect(
        effectStr: '',
        vipLvl: 2,
        novelLvl: 1,
      );
      expect(effect, 'VIP 2');
    });

    test('Should fall back to VIP 1 if effect is not specified and user is VIP 1', () {
      final effect = resolveEntranceEffect(
        effectStr: '',
        vipLvl: 1,
        novelLvl: 1,
      );
      expect(effect, 'VIP 1');
    });

    test('Should fall back to Novel if user is not VIP but Novel 1', () {
      final effect = resolveEntranceEffect(
        effectStr: '',
        vipLvl: 0,
        novelLvl: 1,
      );
      expect(effect, 'Novel');
    });
  });

  group('VIP Purchase Flow, Verification, and Lock Overlay Tests', () {
    test('Should verify payment and commit to DB in single transaction flow', () async {
      final res = await verifyAndCommitPayment(
        orderId: 'order_123',
        paymentId: 'pay_999',
        signature: 'valid_sig',
        expectedSignature: 'valid_sig',
        processedPayments: {},
        dbCommitSucceeds: true,
      );

      expect(res['success'], true);
      expect(res['message'], 'Committed Successfully');
    });

    test('Should fail activation if payment verification fails', () async {
      final res = await verifyAndCommitPayment(
        orderId: 'order_123',
        paymentId: 'pay_999',
        signature: 'invalid_sig',
        expectedSignature: 'valid_sig',
        processedPayments: {},
        dbCommitSucceeds: true,
      );

      expect(res['success'], false);
      expect(res['error'], 'Signature Verification Failed');
    });

    test('Should rollback activation if database commit fails', () async {
      final res = await verifyAndCommitPayment(
        orderId: 'order_123',
        paymentId: 'pay_999',
        signature: 'valid_sig',
        expectedSignature: 'valid_sig',
        processedPayments: {},
        dbCommitSucceeds: false,
      );

      expect(res['success'], false);
      expect(res['error'], 'Database Transaction Rollback');
    });

    test('Should make payment callback idempotent for duplicate IDs', () async {
      final Set<String> processed = {'pay_first_999'};
      
      final res = await verifyAndCommitPayment(
        orderId: 'order_123',
        paymentId: 'pay_first_999',
        signature: 'valid_sig',
        expectedSignature: 'valid_sig',
        processedPayments: processed,
        dbCommitSucceeds: true,
      );

      expect(res['success'], true);
      expect(res['message'], 'Idempotent Success (Duplicate Callback)');
    });

    test('Should overlay locked VIP level/expiry on profile fetch during lock duration', () {
      // Simulate User cache object
      final user = User(
        id: 'user_1',
        username: 'alice',
        email: 'alice@creaniaa.com',
        interests: const [],
        communities: const [],
        followers: 0,
        following: 0,
        isVerified: false,
        isPremium: false,
        reputation: 0,
        sid: '123456',
        vipLevel: 0, // database profile has level 0
        vipExpiry: null,
      );

      // Simulate lock details
      final DateTime lockUntil = DateTime.now().add(const Duration(seconds: 10));
      const int lockedVipLevel = 3;
      final DateTime lockedVipExpiry = DateTime.now().add(const Duration(days: 30));

      User resolvedUser = user;
      if (DateTime.now().isBefore(lockUntil)) {
        resolvedUser = user.copyWith(
          vipLevel: lockedVipLevel,
          vipExpiry: lockedVipExpiry,
        );
      }

      expect(resolvedUser.vipLevel, 3);
      expect(resolvedUser.vipExpiry, lockedVipExpiry);
    });
  });
}
