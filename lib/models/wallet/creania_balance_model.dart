import 'package:intl/intl.dart';

/// Centralized Creania Balance Converter enforcing 500 CB = ₹2.00 (250 CB = ₹1.00)
class CreaniaBalanceConverter {
  static const double cbPerInr = 250.0;

  /// Convert Creania Balance (CB) to Approximate INR Value
  static double cbToInr(int cb) {
    if (cb <= 0) return 0.0;
    return cb / cbPerInr;
  }

  /// Format Creania Balance with explicit INR approximation: "125,000 CB (≈ ₹500.00)"
  static String formatWithInr(int cb, {bool compact = false}) {
    final numFormat = NumberFormat('#,##,###');
    final formattedCb = numFormat.format(cb);
    final inrVal = cbToInr(cb);
    if (compact && cb >= 1000) {
      final kVal = (cb / 1000.0).toStringAsFixed(cb % 1000 == 0 ? 0 : 1);
      return '$kVal k CB (≈ ₹${inrVal.toStringAsFixed(0)})';
    }
    return '$formattedCb CB (≈ ₹${inrVal.toStringAsFixed(2)})';
  }

  /// Format raw INR value to Indian currency string: "₹40.00"
  static String formatInr(double inr) {
    return '₹${inr.toStringAsFixed(2)}';
  }
}

class CbSystemConfig {
  final double cbPerInr;
  final double goldReceiverCbRatio;
  final double goldRoomOwnerCbRatio;
  final double goldCommunityCbRatio;
  final double goldFamilyCbRatio;
  final double silverGiftRewardRate;
  final double voltGiftRewardRate;
  final int minExchangeCb;
  final int minWithdrawalCb;
  final double withdrawalFeePercent;
  final double promotionalBonusPercent;

  CbSystemConfig({
    this.cbPerInr = 250.0,
    this.goldReceiverCbRatio = 50.0,
    this.goldRoomOwnerCbRatio = 25.0,
    this.goldCommunityCbRatio = 15.0,
    this.goldFamilyCbRatio = 10.0,
    this.silverGiftRewardRate = 0.05,
    this.voltGiftRewardRate = 0.10,
    this.minExchangeCb = 5000,
    this.minWithdrawalCb = 250000,
    this.withdrawalFeePercent = 0.0,
    this.promotionalBonusPercent = 5.0,
  });

  factory CbSystemConfig.fromJson(Map<String, dynamic> json) {
    return CbSystemConfig(
      cbPerInr: (json['cb_per_inr'] as num?)?.toDouble() ?? 250.0,
      goldReceiverCbRatio: (json['gold_receiver_cb_ratio'] as num?)?.toDouble() ?? 50.0,
      goldRoomOwnerCbRatio: (json['gold_room_owner_cb_ratio'] as num?)?.toDouble() ?? 25.0,
      goldCommunityCbRatio: (json['gold_community_cb_ratio'] as num?)?.toDouble() ?? 15.0,
      goldFamilyCbRatio: (json['gold_family_cb_ratio'] as num?)?.toDouble() ?? 10.0,
      silverGiftRewardRate: (json['silver_gift_reward_rate'] as num?)?.toDouble() ?? 0.05,
      voltGiftRewardRate: (json['volt_gift_reward_rate'] as num?)?.toDouble() ?? 0.10,
      minExchangeCb: (json['min_exchange_cb'] as num?)?.toInt() ?? 5000,
      minWithdrawalCb: (json['min_withdrawal_cb'] as num?)?.toInt() ?? 250000,
      withdrawalFeePercent: (json['withdrawal_fee_percent'] as num?)?.toDouble() ?? 0.0,
      promotionalBonusPercent: (json['promotional_bonus_percent'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

class CreaniaBalanceWallet {
  final int creaniaBalance;
  final int pendingCbBalance;
  final int lifetimeEarnedCb;
  final int lifetimeWithdrawnCb;
  final int giftEarningsCb;
  final int roomEarningsCb;
  final int communityEarningsCb;
  final int familyEarningsCb;
  final int familyPendingCb;
  final bool kycVerified;
  final String? upiId;
  final String? bankAccountName;
  final CbSystemConfig config;
  final List<CreaniaBalanceTransaction> transactions;
  final List<FamilySettlementRecord> familySettlements;
  final List<WithdrawalRecord> withdrawals;

  CreaniaBalanceWallet({
    required this.creaniaBalance,
    required this.pendingCbBalance,
    required this.lifetimeEarnedCb,
    required this.lifetimeWithdrawnCb,
    required this.giftEarningsCb,
    required this.roomEarningsCb,
    required this.communityEarningsCb,
    required this.familyEarningsCb,
    required this.familyPendingCb,
    required this.kycVerified,
    this.upiId,
    this.bankAccountName,
    required this.config,
    required this.transactions,
    required this.familySettlements,
    required this.withdrawals,
  });

  double get inrAvailable => CreaniaBalanceConverter.cbToInr(creaniaBalance);
  double get inrPending => CreaniaBalanceConverter.cbToInr(pendingCbBalance);
  double get inrLifetimeEarned => CreaniaBalanceConverter.cbToInr(lifetimeEarnedCb);
  double get inrLifetimeWithdrawn => CreaniaBalanceConverter.cbToInr(lifetimeWithdrawnCb);

  factory CreaniaBalanceWallet.fromJson(Map<String, dynamic> json) {
    final cfgJson = json['config'] as Map<String, dynamic>? ?? {};
    final txList = (json['transactions'] as List<dynamic>? ?? [])
        .map((e) => CreaniaBalanceTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
    final stList = (json['family_settlements'] as List<dynamic>? ?? [])
        .map((e) => FamilySettlementRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    final wdList = (json['withdrawals'] as List<dynamic>? ?? [])
        .map((e) => WithdrawalRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    return CreaniaBalanceWallet(
      creaniaBalance: (json['creania_balance'] as num?)?.toInt() ?? 0,
      pendingCbBalance: (json['pending_cb_balance'] as num?)?.toInt() ?? 0,
      lifetimeEarnedCb: (json['lifetime_earned_cb'] as num?)?.toInt() ?? 0,
      lifetimeWithdrawnCb: (json['lifetime_withdrawn_cb'] as num?)?.toInt() ?? 0,
      giftEarningsCb: (json['gift_earnings_cb'] as num?)?.toInt() ?? 0,
      roomEarningsCb: (json['room_earnings_cb'] as num?)?.toInt() ?? 0,
      communityEarningsCb: (json['community_earnings_cb'] as num?)?.toInt() ?? 0,
      familyEarningsCb: (json['family_earnings_cb'] as num?)?.toInt() ?? 0,
      familyPendingCb: (json['family_pending_cb'] as num?)?.toInt() ?? 0,
      kycVerified: json['kyc_verified'] as bool? ?? false,
      upiId: json['upi_id'] as String?,
      bankAccountName: json['bank_account_name'] as String?,
      config: CbSystemConfig.fromJson(cfgJson),
      transactions: txList,
      familySettlements: stList,
      withdrawals: wdList,
    );
  }
}

class CreaniaBalanceTransaction {
  final String id;
  final int amountCb;
  final double inrEquivalent;
  final String entryType;
  final String? referenceId;
  final String idempotencyKey;
  final String status;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  CreaniaBalanceTransaction({
    required this.id,
    required this.amountCb,
    required this.inrEquivalent,
    required this.entryType,
    this.referenceId,
    required this.idempotencyKey,
    required this.status,
    required this.details,
    required this.createdAt,
  });

  bool get isCredit => amountCb > 0;

  String get displayTitle {
    switch (entryType) {
      case 'GIFT_RECEIVER_REWARD':
        return 'Gift Earnings';
      case 'GIFT_ROOM_OWNER_REWARD':
        return 'Room Owner Royalty';
      case 'GIFT_COMMUNITY_REWARD':
        return 'Community Reward';
      case 'FAMILY_GIFT_REWARD':
        return 'Family Gift Reward';
      case 'WEEKEND_FAMILY_SETTLEMENT':
        return 'Weekend Family Settlement';
      case 'EXCHANGE':
        return 'Coin Exchange';
      case 'PROMOTIONAL_BONUS':
        return 'Promotional Bonus';
      case 'WITHDRAWAL_REQUEST':
        return 'Withdrawal Requested';
      case 'WITHDRAWAL_COMPLETED':
        return 'Withdrawal Disbursed';
      case 'WITHDRAWAL_REJECTED':
        return 'Withdrawal Refunded';
      case 'GIFT_REFUNDED':
        return 'Gift Refund Reversal';
      case 'FRAUD_REVERSAL':
        return 'Fraud Reversal';
      default:
        return entryType.replaceAll('_', ' ');
    }
  }

  factory CreaniaBalanceTransaction.fromJson(Map<String, dynamic> json) {
    return CreaniaBalanceTransaction(
      id: json['id'] as String? ?? '',
      amountCb: (json['amount_cb'] as num?)?.toInt() ?? 0,
      inrEquivalent: (json['inr_equivalent'] as num?)?.toDouble() ?? 0.0,
      entryType: json['entry_type'] as String? ?? 'UNKNOWN',
      referenceId: json['reference_id'] as String?,
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      status: json['status'] as String? ?? 'COMPLETED',
      details: json['details'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class FamilySettlementRecord {
  final String id;
  final String familyId;
  final int previousPendingCb;
  final int eligibleAddedCb;
  final int fraudAdjustmentCb;
  final int finalSettledCb;
  final double inrValue;
  final DateTime settledAt;
  final String status;

  FamilySettlementRecord({
    required this.id,
    required this.familyId,
    required this.previousPendingCb,
    required this.eligibleAddedCb,
    required this.fraudAdjustmentCb,
    required this.finalSettledCb,
    required this.inrValue,
    required this.settledAt,
    required this.status,
  });

  factory FamilySettlementRecord.fromJson(Map<String, dynamic> json) {
    return FamilySettlementRecord(
      id: json['id'] as String? ?? '',
      familyId: json['family_id'] as String? ?? '',
      previousPendingCb: (json['previous_pending_cb'] as num?)?.toInt() ?? 0,
      eligibleAddedCb: (json['eligible_added_cb'] as num?)?.toInt() ?? 0,
      fraudAdjustmentCb: (json['fraud_adjustment_cb'] as num?)?.toInt() ?? 0,
      finalSettledCb: (json['final_settled_cb'] as num?)?.toInt() ?? 0,
      inrValue: (json['inr_value'] as num?)?.toDouble() ?? 0.0,
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'COMPLETED',
    );
  }
}

class WithdrawalRecord {
  final String id;
  final int amountCb;
  final double inrValue;
  final double feeInr;
  final double netPayoutInr;
  final String upiId;
  final String? accountName;
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  WithdrawalRecord({
    required this.id,
    required this.amountCb,
    required this.inrValue,
    required this.feeInr,
    required this.netPayoutInr,
    required this.upiId,
    this.accountName,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WithdrawalRecord.fromJson(Map<String, dynamic> json) {
    return WithdrawalRecord(
      id: json['id'] as String? ?? '',
      amountCb: (json['amount_cb'] as num?)?.toInt() ?? 0,
      inrValue: (json['inr_value'] as num?)?.toDouble() ?? 0.0,
      feeInr: (json['fee_inr'] as num?)?.toDouble() ?? 0.0,
      netPayoutInr: (json['net_payout_inr'] as num?)?.toDouble() ?? 0.0,
      upiId: json['upi_id'] as String? ?? '',
      accountName: json['account_name'] as String?,
      status: json['status'] as String? ?? 'Withdrawal Requested',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
