// lib/models/auth/two_factor_models.dart

class TwoFactorStatus {
  final bool isEnabled;
  final String method;
  final bool hasTotpSecret;
  final int remainingRecoveryCodes;
  final DateTime? lastVerifiedAt;

  TwoFactorStatus({
    required this.isEnabled,
    this.method = 'totp',
    this.hasTotpSecret = false,
    this.remainingRecoveryCodes = 0,
    this.lastVerifiedAt,
  });

  factory TwoFactorStatus.fromJson(Map<String, dynamic> json) {
    return TwoFactorStatus(
      isEnabled: json['two_factor_enabled'] ?? json['isEnabled'] ?? false,
      method: json['two_factor_method'] ?? json['method'] ?? 'totp',
      hasTotpSecret: json['has_totp_secret'] ?? json['hasTotpSecret'] ?? false,
      remainingRecoveryCodes: json['recovery_codes_remaining'] ?? json['remainingRecoveryCodes'] ?? 0,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.tryParse(json['last_verified_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'two_factor_enabled': isEnabled,
        'two_factor_method': method,
        'has_totp_secret': hasTotpSecret,
        'recovery_codes_remaining': remainingRecoveryCodes,
        'last_verified_at': lastVerifiedAt?.toIso8601String(),
      };
}

class TwoFactorSetupData {
  final String secret;
  final String qrUri;
  final String setupKey;
  final List<String> recoveryCodes;
  final List<String> serverSecurityKeys;

  TwoFactorSetupData({
    required this.secret,
    required this.qrUri,
    required this.setupKey,
    required this.recoveryCodes,
    required this.serverSecurityKeys,
  });
}

class TrustedDeviceModel {
  final String id;
  final String deviceId;
  final String deviceName;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime expiresAt;
  final bool isCurrent;

  TrustedDeviceModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.createdAt,
    required this.lastUsedAt,
    required this.expiresAt,
    this.isCurrent = false,
  });

  factory TrustedDeviceModel.fromJson(Map<String, dynamic> json, {String currentDeviceId = ''}) {
    final devId = json['device_id'] ?? json['id'] ?? '';
    return TrustedDeviceModel(
      id: json['id'] ?? '',
      deviceId: devId,
      deviceName: json['device_name'] ?? 'Trusted Device',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'].toString())
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'].toString())
          : DateTime.now().add(const Duration(days: 30)),
      isCurrent: currentDeviceId.isNotEmpty && devId == currentDeviceId,
    );
  }
}
