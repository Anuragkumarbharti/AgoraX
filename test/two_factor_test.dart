// test/two_factor_test.dart
// Unit tests verifying TOTP calculation, clock drift, Base32 secret generation, recovery code formatting, and hashing.

import 'package:flutter_test/flutter_test.dart';
import 'package:creania/services/auth/totp_helper.dart';

void main() {
  group('Two-Factor Authentication (2FA) Unit Tests', () {
    const String testSecret = 'JBSWY3DPEHPK3PXP'; // Standard RFC test secret

    test('TEST 1: Generate valid 16-char Base32 secret', () {
      final secret = TotpHelper.generateSecret();
      expect(secret.length, equals(16));
      expect(RegExp(r'^[A-Z2-7]+$').hasMatch(secret), isTrue);
    });

    test('TEST 2: TOTP calculation produces deterministic 6-digit PIN', () {
      final testTime = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final code1 = TotpHelper.generateTotpCode(testSecret, time: testTime);
      final code2 = TotpHelper.generateTotpCode(testSecret, time: testTime);

      expect(code1.length, equals(6));
      expect(int.tryParse(code1), isNotNull);
      expect(code1, equals(code2));
    });

    test('TEST 3: TOTP verification accepts code within current time step', () {
      final nowCode = TotpHelper.generateTotpCode(testSecret);
      final isValid = TotpHelper.verifyTotpCode(testSecret, nowCode);
      expect(isValid, isTrue);
    });

    test('TEST 4: TOTP verification accepts ±1 step (±30s) clock drift', () {
      final previousWindowTime = DateTime.now().subtract(const Duration(seconds: 25));
      final driftedCode = TotpHelper.generateTotpCode(testSecret, time: previousWindowTime);

      final isValid = TotpHelper.verifyTotpCode(testSecret, driftedCode);
      expect(isValid, isTrue);
    });

    test('TEST 5: TOTP verification rejects invalid codes', () {
      expect(TotpHelper.verifyTotpCode(testSecret, '000000'), isFalse);
      expect(TotpHelper.verifyTotpCode(testSecret, '999999'), isFalse);
      expect(TotpHelper.verifyTotpCode(testSecret, 'ABCDEF'), isFalse);
    });

    test('TEST 6: Generate 10 secure recovery codes in XXXX-XXXX format', () {
      final codes = TotpHelper.generateRecoveryCodes(count: 10);
      expect(codes.length, equals(10));
      for (final code in codes) {
        expect(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}$').hasMatch(code), isTrue);
      }
    });

    test('TEST 7: Recovery code hashing is deterministic and case-insensitive', () {
      const code1 = 'ABCD-1234';
      const code2 = 'abcd-1234';

      final hash1 = TotpHelper.hashCodeString(code1);
      final hash2 = TotpHelper.hashCodeString(code2);

      expect(hash1.length, equals(64)); // SHA-256 hex string length
      expect(hash1, equals(hash2));
    });

    test('TEST 8: Otpauth URI generation builds valid Authenticator link', () {
      final uri = TotpHelper.buildOtpauthUri(
        secret: testSecret,
        email: 'user@example.com',
        issuer: 'Creania',
      );

      expect(uri.startsWith('otpauth://totp/'), isTrue);
      expect(uri.contains('secret=$testSecret'), isTrue);
      expect(uri.contains('issuer=Creania'), isTrue);
    });

    test('TEST 9: Generate 4 high-security 64-bit server keys in XXXX-XXXX-XXXX-XXXX format', () {
      final keys = TotpHelper.generateServerSecurityKeys(count: 4);
      expect(keys.length, equals(4));
      for (final key in keys) {
        expect(RegExp(r'^[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$').hasMatch(key), isTrue);
      }
    });
  });
}
