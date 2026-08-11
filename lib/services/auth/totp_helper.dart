// lib/services/auth/totp_helper.dart
// Production-grade TOTP (RFC 6238) Engine and Recovery Code Generator for Creania.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TotpHelper {
  static const String _base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Generates a cryptographically random 16-character Base32 secret key.
  static String generateSecret() {
    final rand = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      buffer.write(_base32Chars[rand.nextInt(32)]);
    }
    return buffer.toString();
  }

  /// Formats the setup URI for Authenticator apps (Google Authenticator, Authy, etc.).
  /// Format: otpauth://totp/Creania:email?secret=SECRET&issuer=Creania
  static String buildOtpauthUri({
    required String secret,
    required String email,
    String issuer = 'Creania',
  }) {
    final encodedEmail = Uri.encodeComponent(email);
    final encodedIssuer = Uri.encodeComponent(issuer);
    return 'otpauth://totp/$encodedIssuer:$encodedEmail?secret=$secret&issuer=$encodedIssuer&algorithm=SHA1&digits=6&period=30';
  }

  /// Calculates a 6-digit TOTP code for a given Base32 secret and time step.
  static String generateTotpCode(String secret, {DateTime? time, int timeStepSeconds = 30}) {
    final now = time ?? DateTime.now();
    final timeStep = (now.millisecondsSinceEpoch ~/ 1000) ~/ timeStepSeconds;

    final secretBytes = _decodeBase32(secret.toUpperCase().replaceAll(' ', ''));
    if (secretBytes.isEmpty) return '000000';

    // 8-byte big-endian time buffer
    final timeBytes = Uint8List(8);
    var tempTime = timeStep;
    for (int i = 7; i >= 0; i--) {
      timeBytes[i] = tempTime & 0xff;
      tempTime >>= 8;
    }

    // HMAC-SHA1 calculation
    final hmac = Hmac(sha1, secretBytes);
    final hash = hmac.convert(timeBytes).bytes;

    // Dynamic truncation
    final offset = hash[hash.length - 1] & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);

    final otp = binary % 1000000;
    return otp.toString().padLeft(6, '0');
  }

  /// Validates a 6-digit TOTP code with ±1 time step (±30s) clock drift tolerance.
  static bool verifyTotpCode(String secret, String inputCode, {int timeStepSeconds = 30}) {
    final cleanedInput = inputCode.trim();
    if (cleanedInput.length != 6 || int.tryParse(cleanedInput) == null) {
      return false;
    }

    final now = DateTime.now();
    // Test current window T, previous window T-1, and next window T+1
    for (int drift = -1; drift <= 1; drift++) {
      final testTime = now.add(Duration(seconds: drift * timeStepSeconds));
      final generatedCode = generateTotpCode(secret, time: testTime, timeStepSeconds: timeStepSeconds);
      if (generatedCode == cleanedInput) {
        return true;
      }
    }

    return false;
  }

  /// Generates 10 secure random recovery codes in `XXXX-XXXX` format.
  static List<String> generateRecoveryCodes({int count = 10}) {
    final rand = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excludes confusing characters 0, O, 1, I
    final List<String> codes = [];

    for (int i = 0; i < count; i++) {
      final part1 = StringBuffer();
      final part2 = StringBuffer();
      for (int j = 0; j < 4; j++) {
        part1.write(chars[rand.nextInt(chars.length)]);
        part2.write(chars[rand.nextInt(chars.length)]);
      }
      codes.add('${part1.toString()}-${part2.toString()}');
    }

    return codes;
  }

  /// Computes SHA-256 hash string for storing recovery codes securely in backend.
  static String hashCodeString(String code) {
    final cleanedCode = code.toUpperCase().replaceAll('-', '').trim();
    final bytes = utf8.encode(cleanedCode);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Decodes Base32 string to byte array.
  static Uint8List _decodeBase32(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    if (cleaned.isEmpty) return Uint8List(0);

    final List<int> output = [];
    int buffer = 0;
    int bitsLeft = 0;

    for (int i = 0; i < cleaned.length; i++) {
      final val = _base32Chars.indexOf(cleaned[i]);
      if (val < 0) continue;

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        output.add((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }

    return Uint8List.fromList(output);
  }
}
