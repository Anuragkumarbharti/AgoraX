import 'package:encrypt/encrypt.dart';

class ChatCrypto {
  // In a full production implementation, these keys are generated client-side
  // via a Diffie-Hellman Key Exchange (X25519) and stored in Secure Storage.
  static final _key = Key.fromUtf8('my32bytessecretkeyforagorax12345'); 
  static final _iv = IV.fromLength(16); 

  /// Encrypts plaintext message client-side before sending to database.
  static String encryptMessage(String plaintext) {
    if (plaintext.isEmpty) return '';
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    return encrypter.encrypt(plaintext, iv: _iv).base64;
  }

  /// Decrypts ciphertext message on receipt from database.
  static String decryptMessage(String ciphertext) {
    if (ciphertext.isEmpty) return '';
    try {
      final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
      return encrypter.decrypt(Encrypted.fromBase64(ciphertext), iv: _iv);
    } catch (e) {
      return '[Encrypted Message: Decryption Failed]';
    }
  }
}
