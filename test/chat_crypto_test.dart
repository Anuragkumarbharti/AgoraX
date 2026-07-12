import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/core/chat_crypto.dart';

void main() {
  group('E2EE ChatCrypto Tests', () {
    test('Generate KeyPair and derive matching shared secret keys', () {
      // 1. Generate Alice's KeyPair
      final alicePrivate = ChatCrypto.generatePrivateKey();
      final alicePublic = ChatCrypto.getPublicKey(alicePrivate);

      expect(alicePrivate.length, 32);
      expect(alicePublic.length, 32);

      // 2. Generate Bob's KeyPair
      final bobPrivate = ChatCrypto.generatePrivateKey();
      final bobPublic = ChatCrypto.getPublicKey(bobPrivate);

      expect(bobPrivate.length, 32);
      expect(bobPublic.length, 32);

      // 3. Derive shared key on Alice's side
      final aliceShared = ChatCrypto.deriveSharedKey(alicePrivate, bobPublic);

      // 4. Derive shared key on Bob's side
      final bobShared = ChatCrypto.deriveSharedKey(bobPrivate, alicePublic);

      expect(aliceShared.length, 32);
      expect(bobShared.length, 32);

      // Both derived shared keys must be identical
      expect(aliceShared, bobShared);
    });

    test('Encrypt and decrypt message with derived key', () {
      final alicePrivate = ChatCrypto.generatePrivateKey();
      final alicePublic = ChatCrypto.getPublicKey(alicePrivate);

      final bobPrivate = ChatCrypto.generatePrivateKey();
      final bobPublic = ChatCrypto.getPublicKey(bobPrivate);

      final aesKey = ChatCrypto.deriveSharedKey(alicePrivate, bobPublic);

      const originalMessage = 'Hello Bob! This is an E2EE secure message. 🔐';

      // Encrypt Alice -> Bob
      final encryptedBase64 = ChatCrypto.encryptMessage(originalMessage, aesKey);
      expect(encryptedBase64, isNotEmpty);
      expect(encryptedBase64, isNot(originalMessage));

      // Decrypt Bob side
      final decryptedMessage = ChatCrypto.decryptMessage(encryptedBase64, aesKey);
      expect(decryptedMessage, originalMessage);
    });

    test('Decryption with incorrect key fails gracefully', () {
      final alicePrivate = ChatCrypto.generatePrivateKey();
      final alicePublic = ChatCrypto.getPublicKey(alicePrivate);

      final bobPrivate = ChatCrypto.generatePrivateKey();
      final bobPublic = ChatCrypto.getPublicKey(bobPrivate);

      final correctKey = ChatCrypto.deriveSharedKey(alicePrivate, bobPublic);
      final incorrectKey = ChatCrypto.generatePrivateKey();

      const originalMessage = 'Top secret strategy details.';

      final encryptedBase64 = ChatCrypto.encryptMessage(originalMessage, correctKey);

      // Decrypt with wrong key
      final decrypted = ChatCrypto.decryptMessage(encryptedBase64, incorrectKey);
      expect(decrypted, contains('Decryption Failed'));
    });
  });
}
