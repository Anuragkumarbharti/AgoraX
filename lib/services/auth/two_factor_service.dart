// lib/services/auth/two_factor_service.dart
// Centralized 2FA & Security Service for Creania.

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import '../../models/auth/two_factor_models.dart';
import '../../services/user/user_profile_cache_manager.dart';
import './totp_helper.dart';

class TwoFactorService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _trustedTokenKeyPrefix = 'creania_2fa_trusted_token_';
  
  static DateTime? _recentSecurityVerification;

  /// Checks if recent 2FA / Security check was completed within the last 10 minutes.
  static bool isRecentlyVerified() {
    if (_recentSecurityVerification == null) return false;
    final diff = DateTime.now().difference(_recentSecurityVerification!);
    return diff.inMinutes < 10;
  }

  /// Marks security verification completed for sensitive actions.
  static void markRecentlyVerified() {
    _recentSecurityVerification = DateTime.now();
  }

  /// Fetches real 2FA status from Supabase RPC.
  static Future<TwoFactorStatus> fetchStatus({String? userId}) async {
    final uid = userId ?? UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) {
      return TwoFactorStatus(isEnabled: false);
    }

    try {
      final res = await _supabase.rpc('get_2fa_status', params: {'p_user_id': uid});
      if (res != null && res['success'] == true) {
        return TwoFactorStatus.fromJson(res);
      }
    } catch (e) {
      debugPrint('[TwoFactorService] fetchStatus error: $e');
    }

    // Fallback profile check
    final profileUser = UserProfileCacheManager.currentUser;
    return TwoFactorStatus(isEnabled: profileUser?.twoFactorEnabled ?? false);
  }

  /// Initiates 2FA setup by generating or retrieving secret key.
  static Future<TwoFactorSetupData?> initiateSetup({required String email}) async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return null;

    try {
      final res = await _supabase.rpc('generate_totp_setup_secret', params: {'p_user_id': uid});
      if (res != null && res['success'] == true) {
        final String secret = res['secret'] ?? '';
        if (secret.isEmpty) return null;

        final qrUri = TotpHelper.buildOtpauthUri(secret: secret, email: email);
        final recoveryCodes = TotpHelper.generateRecoveryCodes(count: 10);
        final serverSecurityKeys = TotpHelper.generateServerSecurityKeys(count: 4);

        return TwoFactorSetupData(
          secret: secret,
          qrUri: qrUri,
          setupKey: secret,
          recoveryCodes: recoveryCodes,
          serverSecurityKeys: serverSecurityKeys,
        );
      }
    } catch (e) {
      debugPrint('[TwoFactorService] initiateSetup error: $e');
    }
    return null;
  }

  /// Verifies setup code and enables 2FA in backend with hashed recovery codes and 64-bit server keys.
  static Future<Map<String, dynamic>> verifyAndEnable2FA({
    required String secret,
    required String code,
    required List<String> recoveryCodes,
    List<String> serverSecurityKeys = const [],
  }) async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) {
      return {'success': false, 'error': 'User session not found.'};
    }

    // 1. Verify TOTP code client-side
    final isValid = TotpHelper.verifyTotpCode(secret, code);
    if (!isValid) {
      return {'success': false, 'error': 'Invalid verification code. Please try again.'};
    }

    // 2. Compute SHA-256 hashes of recovery codes & server keys
    final List<String> codeHashes = recoveryCodes
        .map((c) => TotpHelper.hashCodeString(c))
        .toList();

    final List<String> serverKeyHashes = serverSecurityKeys
        .map((k) => TotpHelper.hashCodeString(k))
        .toList();

    // 3. Enable in backend
    try {
      final res = await _supabase.rpc('verify_and_enable_2fa', params: {
        'p_user_id': uid,
        'p_totp_secret': secret,
        'p_recovery_code_hashes': codeHashes,
      });

      if (res != null && res['success'] == true) {
        if (serverKeyHashes.isNotEmpty) {
          await _supabase.rpc('save_server_security_key_hashes', params: {
            'p_user_id': uid,
            'p_key_hashes': serverKeyHashes,
          });
        }

        markRecentlyVerified();

        // Update local User cache
        final user = UserProfileCacheManager.currentUser;
        if (user != null) {
          final updated = user.copyWith(twoFactorEnabled: true);
          UserProfileCacheManager.setCurrentUser(updated);
        }

        return {'success': true};
      } else {
        return {'success': false, 'error': res?['error'] ?? 'Failed to enable 2FA'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Server verification failed: $e'};
    }
  }

  /// Checks if 2FA login is required for current user & device.
  static Future<bool> checkLogin2FARequired(String userId) async {
    if (userId.isEmpty) return false;

    // 1. Check if 2FA is enabled for user
    final status = await fetchStatus(userId: userId);
    if (!status.isEnabled) return false;

    // 2. Check if device has a valid trusted device token
    final isTrusted = await isDeviceTrusted(userId);
    if (isTrusted) {
      return false; // Trusted device skips login 2FA
    }

    return true; // 2FA is required
  }

  /// Verifies TOTP code during login.
  static Future<Map<String, dynamic>> verify2FALogin({
    required String userId,
    required String secret,
    required String code,
    bool trustDevice = false,
    String deviceId = '',
    String deviceName = '',
  }) async {
    // 1. Validate TOTP code
    final isValid = TotpHelper.verifyTotpCode(secret, code);
    if (!isValid) {
      return {'success': false, 'error': 'Invalid verification code. Please try again.'};
    }

    // 2. Generate trusted device token if trust requested
    String? deviceTokenHash;
    String? rawDeviceToken;
    if (trustDevice) {
      rawDeviceToken = _generateSecureToken();
      deviceTokenHash = TotpHelper.hashCodeString(rawDeviceToken);
    }

    try {
      final res = await _supabase.rpc('record_successful_totp_login', params: {
        'p_user_id': userId,
        'p_device_id': deviceId,
        'p_device_name': deviceName,
        'p_trust_device': trustDevice,
        'p_device_token_hash': deviceTokenHash,
      });

      if (res != null && res['success'] == true) {
        markRecentlyVerified();

        if (trustDevice && rawDeviceToken != null) {
          await _saveTrustedDeviceToken(userId, rawDeviceToken);
        }

        return {'success': true};
      } else {
        return {'success': false, 'error': res?['error'] ?? 'Verification failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Verification error: $e'};
    }
  }

  /// Verifies recovery code during login.
  static Future<Map<String, dynamic>> verifyRecoveryCodeLogin({
    required String userId,
    required String recoveryCode,
    bool trustDevice = false,
    String deviceId = '',
    String deviceName = '',
  }) async {
    final codeHash = TotpHelper.hashCodeString(recoveryCode);

    String? deviceTokenHash;
    String? rawDeviceToken;
    if (trustDevice) {
      rawDeviceToken = _generateSecureToken();
      deviceTokenHash = TotpHelper.hashCodeString(rawDeviceToken);
    }

    try {
      final res = await _supabase.rpc('verify_recovery_code_login', params: {
        'p_user_id': userId,
        'p_code_hash': codeHash,
        'p_device_id': deviceId,
        'p_device_name': deviceName,
        'p_trust_device': trustDevice,
        'p_device_token_hash': deviceTokenHash,
      });

      if (res != null && res['success'] == true) {
        markRecentlyVerified();

        if (trustDevice && rawDeviceToken != null) {
          await _saveTrustedDeviceToken(userId, rawDeviceToken);
        }

        return {
          'success': true,
          'remaining_codes': res['remaining_codes'] ?? 0,
        };
      } else {
        return {'success': false, 'error': res?['error'] ?? 'Invalid verification code. Please try again.'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Verification error: $e'};
    }
  }

  /// Verifies high-security 32-bit / 64-bit server-generated security key during login.
  static Future<Map<String, dynamic>> verifyServerSecurityKeyLogin({
    required String userId,
    required String key,
    bool trustDevice = false,
    String deviceId = '',
    String deviceName = '',
  }) async {
    final keyHash = TotpHelper.hashCodeString(key);

    String? deviceTokenHash;
    String? rawDeviceToken;
    if (trustDevice) {
      rawDeviceToken = _generateSecureToken();
      deviceTokenHash = TotpHelper.hashCodeString(rawDeviceToken);
    }

    try {
      final res = await _supabase.rpc('verify_server_security_key_login', params: {
        'p_user_id': userId,
        'p_key_hash': keyHash,
        'p_device_id': deviceId,
        'p_device_name': deviceName,
        'p_trust_device': trustDevice,
        'p_device_token_hash': deviceTokenHash,
      });

      if (res != null && res['success'] == true) {
        markRecentlyVerified();

        if (trustDevice && rawDeviceToken != null) {
          await _saveTrustedDeviceToken(userId, rawDeviceToken);
        }

        return {
          'success': true,
          'remaining_keys': res['remaining_keys'] ?? 0,
        };
      } else {
        return {'success': false, 'error': res?['error'] ?? 'Invalid server security key. Please try again.'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Verification error: $e'};
    }
  }

  /// Checks if current device is registered as trusted in backend.
  static Future<bool> isDeviceTrusted(String userId) async {
    if (userId.isEmpty) return false;

    final token = await _getTrustedDeviceToken(userId);
    if (token == null || token.isEmpty) return false;

    final tokenHash = TotpHelper.hashCodeString(token);
    try {
      final res = await _supabase.rpc('check_device_trust', params: {
        'p_user_id': userId,
        'p_token_hash': tokenHash,
      });

      if (res != null && res['trusted'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint('[TwoFactorService] checkDeviceTrust error: $e');
    }

    return false;
  }

  /// Disables 2FA in backend and revokes local trusted tokens.
  static Future<Map<String, dynamic>> disable2FA() async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return {'success': false, 'error': 'User session not found'};

    try {
      final res = await _supabase.rpc('disable_2fa_rpc', params: {'p_user_id': uid});
      if (res != null && res['success'] == true) {
        await _clearTrustedDeviceToken(uid);
        _recentSecurityVerification = null;

        // Update local User model
        final user = UserProfileCacheManager.currentUser;
        if (user != null) {
          final updated = user.copyWith(twoFactorEnabled: false);
          UserProfileCacheManager.setCurrentUser(updated);
        }

        return {'success': true};
      } else {
        return {'success': false, 'error': res?['error'] ?? 'Failed to disable 2FA'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Failed to disable 2FA: $e'};
    }
  }

  /// Regenerates recovery codes for current user.
  static Future<Map<String, dynamic>> regenerateRecoveryCodes() async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return {'success': false, 'error': 'User session not found'};

    final newCodes = TotpHelper.generateRecoveryCodes(count: 10);
    final hashes = newCodes.map((c) => TotpHelper.hashCodeString(c)).toList();

    try {
      final res = await _supabase.rpc('regenerate_recovery_codes_rpc', params: {
        'p_user_id': uid,
        'p_new_hashes': hashes,
      });

      if (res != null && res['success'] == true) {
        markRecentlyVerified();
        return {
          'success': true,
          'codes': newCodes,
        };
      } else {
        return {'success': false, 'error': res?['error'] ?? 'Failed to regenerate recovery codes'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Server error: $e'};
    }
  }

  /// Revokes a trusted device.
  static Future<bool> revokeTrustedDevice(String deviceId) async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return false;

    try {
      final res = await _supabase.rpc('revoke_trusted_device_rpc', params: {
        'p_user_id': uid,
        'p_device_id': deviceId,
      });
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[TwoFactorService] revokeTrustedDevice error: $e');
      return false;
    }
  }

  // ── Secure Local Storage Helpers ─────────────────────────────────────────

  static Future<void> _saveTrustedDeviceToken(String userId, String token) async {
    try {
      await _storage.write(key: '$_trustedTokenKeyPrefix$userId', value: token);
    } catch (e) {
      debugPrint('[TwoFactorService] Save trusted token error: $e');
    }
  }

  static Future<String?> _getTrustedDeviceToken(String userId) async {
    try {
      return await _storage.read(key: '$_trustedTokenKeyPrefix$userId');
    } catch (e) {
      return null;
    }
  }

  static Future<void> _clearTrustedDeviceToken(String userId) async {
    try {
      await _storage.delete(key: '$_trustedTokenKeyPrefix$userId');
    } catch (_) {}
  }

  static String _generateSecureToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
