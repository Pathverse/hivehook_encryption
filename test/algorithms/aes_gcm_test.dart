import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:hivehook_encryption/src/algorithms/aes_gcm.dart';
import 'package:hivehook_encryption/src/key_utils.dart';
import 'package:hivehook_encryption/src/exceptions.dart';

void main() {
  group('AesGcm', () {
    late Uint8List validKey;

    setUp(() {
      validKey = KeyUtils.generateKeyBytes();
    });

    group('encrypt', () {
      test('encrypts plaintext to bytes', () {
        final encrypted = AesGcm.encrypt('hello world', validKey);
        expect(encrypted, isNotEmpty);
        // Should include nonce + ciphertext + tag
        expect(
          encrypted.length,
          greaterThanOrEqualTo(AesGcm.nonceLength + AesGcm.tagLength),
        );
      });

      test('produces different output each time (random nonce)', () {
        final encrypted1 = AesGcm.encrypt('hello', validKey);
        final encrypted2 = AesGcm.encrypt('hello', validKey);
        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('throws on invalid key length', () {
        final shortKey = Uint8List(16);
        expect(
          () => AesGcm.encrypt('hello', shortKey),
          throwsA(isA<InvalidKeyException>()),
        );
      });

      test('handles empty string', () {
        final encrypted = AesGcm.encrypt('', validKey);
        // nonce + tag, no ciphertext body
        expect(
          encrypted.length,
          equals(AesGcm.nonceLength + AesGcm.tagLength),
        );
      });

      test('handles unicode', () {
        final encrypted = AesGcm.encrypt('こんにちは🎉', validKey);
        expect(encrypted, isNotEmpty);
      });
    });

    group('decrypt', () {
      test('decrypts to original plaintext', () {
        const original = 'hello world';
        final encrypted = AesGcm.encrypt(original, validKey);
        final decrypted = AesGcm.decrypt(encrypted, validKey);
        expect(decrypted, original);
      });

      test('decrypts empty string', () {
        const original = '';
        final encrypted = AesGcm.encrypt(original, validKey);
        final decrypted = AesGcm.decrypt(encrypted, validKey);
        expect(decrypted, original);
      });

      test('decrypts unicode', () {
        const original = 'こんにちは🎉';
        final encrypted = AesGcm.encrypt(original, validKey);
        final decrypted = AesGcm.decrypt(encrypted, validKey);
        expect(decrypted, original);
      });

      test('decrypts long text', () {
        final original = 'a' * 10000;
        final encrypted = AesGcm.encrypt(original, validKey);
        final decrypted = AesGcm.decrypt(encrypted, validKey);
        expect(decrypted, original);
      });

      test('throws on invalid key length', () {
        final encrypted = AesGcm.encrypt('hello', validKey);
        final shortKey = Uint8List(16);
        expect(
          () => AesGcm.decrypt(encrypted, shortKey),
          throwsA(isA<InvalidKeyException>()),
        );
      });

      test('throws on wrong key', () {
        final encrypted = AesGcm.encrypt('hello', validKey);
        final wrongKey = KeyUtils.generateKeyBytes();
        expect(
          () => AesGcm.decrypt(encrypted, wrongKey),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('throws on corrupted ciphertext (authentication failure)', () {
        final encrypted = AesGcm.encrypt('hello', validKey);
        // Corrupt a byte in the ciphertext portion
        encrypted[AesGcm.nonceLength + 2] ^= 0xFF;
        expect(
          () => AesGcm.decrypt(encrypted, validKey),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('throws on corrupted tag (authentication failure)', () {
        final encrypted = AesGcm.encrypt('hello', validKey);
        // Corrupt the last byte (part of tag)
        encrypted[encrypted.length - 1] ^= 0xFF;
        expect(
          () => AesGcm.decrypt(encrypted, validKey),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('throws on ciphertext too short', () {
        final tooShort = Uint8List(10);
        expect(
          () => AesGcm.decrypt(tooShort, validKey),
          throwsA(isA<EncryptionException>()),
        );
      });
    });

    group('round-trip', () {
      test('encrypt then decrypt preserves data', () {
        final testCases = [
          'simple text',
          '',
          'a',
          'unicode: 日本語 emoji: 🔐',
          '{"json": "data", "number": 123}',
          'multi\nline\ntext',
          'special chars: <>&"\'',
        ];

        for (final original in testCases) {
          final encrypted = AesGcm.encrypt(original, validKey);
          final decrypted = AesGcm.decrypt(encrypted, validKey);
          expect(decrypted, original, reason: 'Failed for: $original');
        }
      });
    });

    group('GCM vs CBC differences', () {
      test('GCM detects tampering (authentication)', () {
        // This is the key advantage of GCM over CBC
        final encrypted = AesGcm.encrypt('sensitive data', validKey);
        encrypted[AesGcm.nonceLength] ^= 0x01; // Small change

        // GCM should detect and reject
        expect(
          () => AesGcm.decrypt(encrypted, validKey),
          throwsA(isA<EncryptionException>()),
        );
      });
    });
  });
}
