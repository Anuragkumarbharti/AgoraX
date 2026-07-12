import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' as pc;

class ChatCrypto {
  static final BigInt _p = (BigInt.one << 255) - BigInt.from(19);

  static BigInt _mod(BigInt val) {
    var r = val % _p;
    if (r < BigInt.zero) r += _p;
    return r;
  }

  static BigInt _inv(BigInt val) {
    return val.modInverse(_p);
  }

  /// Generates a random X25519 private key (32 bytes).
  static Uint8List generatePrivateKey() {
    final rand = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = rand.nextInt(256);
    }
    return bytes;
  }

  /// Calculates the X25519 public key corresponding to a private key.
  static Uint8List getPublicKey(Uint8List privateKey) {
    final basePoint = Uint8List(32);
    basePoint[0] = 9;
    return x25519(privateKey, basePoint);
  }

  /// X25519 Montgomery Ladder scalar multiplication.
  static Uint8List x25519(Uint8List scalar, Uint8List uBytes) {
    var s = Uint8List.fromList(scalar);
    s[0] &= 248;
    s[31] &= 127;
    s[31] |= 64;

    BigInt u = BigInt.zero;
    for (int i = 0; i < 32; i++) {
      u += BigInt.from(uBytes[i]) << (8 * i);
    }

    BigInt x1 = u;
    BigInt x2 = BigInt.one;
    BigInt z2 = BigInt.zero;
    BigInt x3 = u;
    BigInt z3 = BigInt.one;

    for (int t = 254; t >= 0; t--) {
      int bit = (s[t >> 3] >> (t & 7)) & 1;
      if (bit == 1) {
        var tempX = x2; x2 = x3; x3 = tempX;
        var tempZ = z2; z2 = z3; z3 = tempZ;
      }

      BigInt a = _mod(x2 + z2);
      BigInt b = _mod(x2 - z2);
      BigInt c = _mod(x3 + z3);
      BigInt d = _mod(x3 - z3);

      BigInt da = _mod(d * a);
      BigInt cb = _mod(c * b);

      x3 = _mod((da + cb) * (da + cb));
      z3 = _mod(x1 * _mod((da - cb) * (da - cb)));

      BigInt aa = _mod(a * a);
      BigInt bb = _mod(b * b);
      BigInt e = _mod(aa - bb);

      x2 = _mod(aa * bb);
      z2 = _mod(e * _mod(bb + _mod(BigInt.from(121665) * e)));

      if (bit == 1) {
        var tempX = x2; x2 = x3; x3 = tempX;
        var tempZ = z2; z2 = z3; z3 = tempZ;
      }
    }

    BigInt result = _mod(x2 * _inv(z2));
    var out = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      out[i] = ((result >> (8 * i)) & BigInt.from(0xff)).toInt();
    }
    return out;
  }

  /// Derives a shared 256-bit AES key from a local private key and a remote public key
  /// using X25519 key agreement followed by HKDF-SHA256.
  static Uint8List deriveSharedKey(Uint8List localPrivate, Uint8List remotePublic) {
    final sharedSecret = x25519(localPrivate, remotePublic);
    
    // HKDF-SHA256 Key Derivation
    final salt = Uint8List(32); // All-zero salt
    final info = utf8.encode('creania-chat-key-agreement');
    
    // Extract
    final hmacExtract = Hmac(sha256, salt);
    final prk = hmacExtract.convert(sharedSecret).bytes;
    
    // Expand
    final hmacExpand = Hmac(sha256, prk);
    final builder = BytesBuilder();
    builder.add(info);
    builder.addByte(1);
    final key = hmacExpand.convert(builder.toBytes()).bytes;
    
    return Uint8List.fromList(key.sublist(0, 32)); // return 256-bit key
  }

  /// Encrypts plaintext using AES-256-GCM.
  /// Returns a Base64-encoded string representing: IV (12 bytes) + Ciphertext + Auth Tag.
  static String encryptMessage(String plaintext, Uint8List aesKey) {
    if (plaintext.isEmpty) return '';
    try {
      final rand = Random.secure();
      final iv = Uint8List(12);
      for (int i = 0; i < 12; i++) {
        iv[i] = rand.nextInt(256);
      }

      final plaintextBytes = utf8.encode(plaintext) as Uint8List;
      final cipher = pc.GCMBlockCipher(pc.AESEngine());
      cipher.init(
        true, // encrypt
        pc.AEADParameters(
          pc.KeyParameter(aesKey),
          128, // Auth Tag length (16 bytes)
          iv,
          Uint8List(0), // Associated Data
        ),
      );

      final ciphertext = cipher.process(plaintextBytes);
      
      // Combine IV + Ciphertext
      final combined = BytesBuilder();
      combined.add(iv);
      combined.add(ciphertext);
      return base64.encode(combined.toBytes());
    } catch (e) {
      return '';
    }
  }

  /// Decrypts ciphertext (Base64-encoded IV + Ciphertext + Auth Tag) using AES-256-GCM.
  static String decryptMessage(String ciphertextBase64, Uint8List aesKey) {
    if (ciphertextBase64.isEmpty) return '';
    try {
      final decoded = base64.decode(ciphertextBase64);
      if (decoded.length <= 12) return '[Decryption Failed: Invalid Payload]';

      final iv = decoded.sublist(0, 12);
      final ciphertextBytes = decoded.sublist(12);

      final cipher = pc.GCMBlockCipher(pc.AESEngine());
      cipher.init(
        false, // decrypt
        pc.AEADParameters(
          pc.KeyParameter(aesKey),
          128,
          iv,
          Uint8List(0),
        ),
      );

      final plaintextBytes = cipher.process(ciphertextBytes);
      return utf8.decode(plaintextBytes);
    } catch (e) {
      return '[Encrypted Message: Decryption Failed]';
    }
  }

  /// Generates a derived session key from two user IDs for fallback/initial offline use.
  static Uint8List deriveFallbackKey(String userId1, String userId2) {
    final list = [userId1, userId2]..sort();
    final combined = list.join(':');
    final hash = sha256.convert(utf8.encode(combined));
    return Uint8List.fromList(hash.bytes);
  }
}
