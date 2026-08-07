// lib/services/auth/auth_memory_service.dart
//
// Production-grade Remember Me + Last Login service.
// All data is stored EXCLUSIVELY on device via Flutter Secure Storage
// (Android Keystore / iOS Keychain). NOTHING is sent to Supabase.
//
// Mirrors the behaviour of Instagram, Facebook, Telegram, Discord, Spotify.

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Login method enum
// ---------------------------------------------------------------------------
enum LoginMethod { email, google, facebook, phone, apple }

extension LoginMethodX on LoginMethod {
  String get key {
    switch (this) {
      case LoginMethod.email:
        return 'email';
      case LoginMethod.google:
        return 'google';
      case LoginMethod.facebook:
        return 'facebook';
      case LoginMethod.phone:
        return 'phone';
      case LoginMethod.apple:
        return 'apple';
    }
  }

  String get displayLabel {
    switch (this) {
      case LoginMethod.email:
        return 'Email Login';
      case LoginMethod.google:
        return 'Google Login';
      case LoginMethod.facebook:
        return 'Facebook Login';
      case LoginMethod.phone:
        return 'Phone OTP';
      case LoginMethod.apple:
        return 'Apple Login';
    }
  }

  String get emoji {
    switch (this) {
      case LoginMethod.email:
        return '📧';
      case LoginMethod.google:
        return '🔵';
      case LoginMethod.facebook:
        return '🔷';
      case LoginMethod.phone:
        return '📱';
      case LoginMethod.apple:
        return '🍎';
    }
  }

  static LoginMethod fromKey(String key) {
    switch (key) {
      case 'google':
        return LoginMethod.google;
      case 'facebook':
        return LoginMethod.facebook;
      case 'phone':
        return LoginMethod.phone;
      case 'apple':
        return LoginMethod.apple;
      default:
        return LoginMethod.email;
    }
  }
}

// ---------------------------------------------------------------------------
// AuthMemoryService
// ---------------------------------------------------------------------------
class AuthMemoryService {
  AuthMemoryService._();

  // ── Secure Storage instance ──────────────────────────────────────────────
  // Single cached instance — Android uses EncryptedSharedPreferences,
  // iOS uses Keychain with first_unlock accessibility.
  static final FlutterSecureStorage _store = _buildStore();

  static FlutterSecureStorage _buildStore() {
    if (kIsWeb) {
      // Web: flutter_secure_storage uses localStorage — only store non-sensitive data
      return const FlutterSecureStorage();
    }
    // Android Keystore
    try {
      return const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
    } catch (_) {
      return const FlutterSecureStorage();
    }
  }


  // ── Storage keys ─────────────────────────────────────────────────────────
  static const _kRememberMe = 'auth_remember_me';
  static const _kLastEmail = 'auth_last_email';
  static const _kLastMethod = 'auth_last_method';
  static const _kLastLoginAt = 'auth_last_login_at';
  static const _kLastLoginSuccess = 'auth_last_login_success';
  static const _kRefreshToken = 'auth_refresh_token';

  // ── In-memory cache (populated by load()) ────────────────────────────────
  static bool _rememberMe = false;
  static String? _lastEmail;
  static LoginMethod? _lastMethod;
  static DateTime? _lastLoginAt;
  static bool _lastLoginSuccess = false;
  static bool _loaded = false;

  // ── Public read-only accessors ────────────────────────────────────────────
  static bool get rememberMe => _rememberMe;
  static String? get lastEmail => _lastEmail;
  static LoginMethod? get lastMethod => _lastMethod;
  static DateTime? get lastLoginAt => _lastLoginAt;
  static bool get lastLoginSuccess => _lastLoginSuccess;
  static bool get hasLastLogin => _lastLoginAt != null;

  /// Masked display email: "anuragkumarbharti@gmail.com" → "anu***@gmail.com"
  static String get maskedEmail {
    final email = _lastEmail;
    if (email == null || !email.contains('@')) return email ?? '';
    final parts = email.split('@');
    final local = parts[0];
    final domain = parts[1];
    final visible = local.length >= 3 ? local.substring(0, 3) : local;
    return '$visible***@$domain';
  }

  /// Human-readable last login time: "07 Aug 2026 • 10:42 PM"
  static String get formattedLoginTime {
    final dt = _lastLoginAt;
    if (dt == null) return '';
    return DateFormat("dd MMM yyyy • hh:mm a").format(dt);
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Load all fields from secure storage into memory.
  /// Must be called once before rendering the login or splash screen.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final vals = await _store.readAll();
      _rememberMe = (vals[_kRememberMe] ?? 'false') == 'true';
      _lastEmail = vals[_kLastEmail];
      final methodStr = vals[_kLastMethod];
      _lastMethod = methodStr != null ? LoginMethodX.fromKey(methodStr) : null;
      final atStr = vals[_kLastLoginAt];
      _lastLoginAt = atStr != null ? DateTime.tryParse(atStr) : null;
      _lastLoginSuccess = (vals[_kLastLoginSuccess] ?? 'false') == 'true';
      _loaded = true;
      debugPrint('[AuthMemory] Loaded — rememberMe=$_rememberMe email=$_lastEmail method=${_lastMethod?.key}');
    } catch (e) {
      debugPrint('[AuthMemory] Load error: $e');
      _loaded = true; // don't retry infinitely
    }
  }

  // ── Auto-login ────────────────────────────────────────────────────────────

  /// Try to restore the Supabase session from the stored refresh token.
  /// Returns true if the session was successfully restored.
  static Future<bool> tryRestoreSession() async {
    if (!_rememberMe) return false;
    try {
      final refreshToken = await _store.read(key: _kRefreshToken);
      if (refreshToken == null || refreshToken.isEmpty) return false;

      // Supabase auto-refreshes via its own persistence layer (pkce/session).
      // We use the current session as the primary check.
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null && !currentSession.isExpired) {
        debugPrint('[AuthMemory] Session still valid — auto-login OK');
        return true;
      }

      // Try to refresh using stored token
      final response = await Supabase.instance.client.auth.setSession(refreshToken);
      if (response.session != null) {
        debugPrint('[AuthMemory] Session restored via refresh token');
        // Update stored refresh token with the new one
        await _store.write(key: _kRefreshToken, value: response.session!.refreshToken ?? refreshToken);
        return true;
      }
    } catch (e) {
      debugPrint('[AuthMemory] tryRestoreSession error: $e');
      // Token invalid/expired — clear it but keep email + last login info
      await _store.delete(key: _kRefreshToken);
    }
    return false;
  }

  // ── Save on successful login ──────────────────────────────────────────────

  /// Call this immediately after every successful authentication.
  /// [rememberMe] is the checkbox value from the UI.
  static Future<void> saveSuccessfulLogin({
    required LoginMethod method,
    required bool rememberMe,
    String? email,
    String? refreshToken,
  }) async {
    try {
      _rememberMe = rememberMe;
      _lastMethod = method;
      _lastEmail = email ?? _lastEmail;
      _lastLoginAt = DateTime.now();
      _lastLoginSuccess = true;

      final futures = <Future<void>>[
        _store.write(key: _kRememberMe, value: rememberMe.toString()),
        _store.write(key: _kLastMethod, value: method.key),
        _store.write(key: _kLastLoginAt, value: _lastLoginAt!.toIso8601String()),
        _store.write(key: _kLastLoginSuccess, value: 'true'),
      ];
      if (email != null && email.isNotEmpty) {
        futures.add(_store.write(key: _kLastEmail, value: email));
      }
      if (refreshToken != null && refreshToken.isNotEmpty && rememberMe) {
        futures.add(_store.write(key: _kRefreshToken, value: refreshToken));
      } else if (!rememberMe) {
        futures.add(_store.delete(key: _kRefreshToken));
      }
      await Future.wait(futures);

      debugPrint('[AuthMemory] Saved login — method=${method.key} rememberMe=$rememberMe email=$email');
    } catch (e) {
      debugPrint('[AuthMemory] saveSuccessfulLogin error: $e');
    }
  }

  // ── Remember Me toggle ────────────────────────────────────────────────────

  /// Update only the Remember Me flag without changing anything else.
  static Future<void> setRememberMe(bool value) async {
    _rememberMe = value;
    try {
      await _store.write(key: _kRememberMe, value: value.toString());
      if (!value) {
        // Clear stored token if user turns off Remember Me
        await _store.delete(key: _kRefreshToken);
      }
    } catch (e) {
      debugPrint('[AuthMemory] setRememberMe error: $e');
    }
  }

  // ── Normal logout ─────────────────────────────────────────────────────────

  /// Normal logout: clears session/token, KEEPS email + last login info.
  /// Mirrors Instagram/Telegram behaviour.
  static Future<void> clearSession() async {
    try {
      await _store.delete(key: _kRefreshToken);
      debugPrint('[AuthMemory] clearSession — session token removed, last login preserved');
    } catch (e) {
      debugPrint('[AuthMemory] clearSession error: $e');
    }
  }

  // ── Forget Device ─────────────────────────────────────────────────────────

  /// Full wipe — deletes every auth memory key from secure storage.
  /// Use for "Logout & Forget Device" flows.
  static Future<void> forgetDevice() async {
    _rememberMe = false;
    _lastEmail = null;
    _lastMethod = null;
    _lastLoginAt = null;
    _lastLoginSuccess = false;
    _loaded = false;
    try {
      await Future.wait([
        _store.delete(key: _kRememberMe),
        _store.delete(key: _kLastEmail),
        _store.delete(key: _kLastMethod),
        _store.delete(key: _kLastLoginAt),
        _store.delete(key: _kLastLoginSuccess),
        _store.delete(key: _kRefreshToken),
      ]);
      debugPrint('[AuthMemory] forgetDevice — all auth memory wiped');
    } catch (e) {
      debugPrint('[AuthMemory] forgetDevice error: $e');
    }
  }

  // ── Password changed ──────────────────────────────────────────────────────

  /// Password changed: clear stored session token, keep email + last login.
  static Future<void> onPasswordChanged() async {
    await _store.delete(key: _kRefreshToken);
    debugPrint('[AuthMemory] onPasswordChanged — refresh token cleared');
  }

  // ── Account deleted ───────────────────────────────────────────────────────

  /// Account deleted: wipe everything.
  static Future<void> onAccountDeleted() async {
    await forgetDevice();
    debugPrint('[AuthMemory] onAccountDeleted — full wipe');
  }

  // ── Refresh token update ──────────────────────────────────────────────────

  /// Store a new refresh token (e.g. after Supabase token rotation).
  static Future<void> updateRefreshToken(String token) async {
    if (!_rememberMe || token.isEmpty) return;
    try {
      await _store.write(key: _kRefreshToken, value: token);
    } catch (e) {
      debugPrint('[AuthMemory] updateRefreshToken error: $e');
    }
  }
}
