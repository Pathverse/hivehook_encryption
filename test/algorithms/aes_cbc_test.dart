import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:hivehook_encryption/src/algorithms/aes_cbc.dart';
import 'package:hivehook_encryption/src/key_utils.dart';
import 'package:hivehook_encryption/src/exceptions.dart';

void main() {
  group('AesCbc', () {
    late Uint8List validKey;

    setUp(() {
      validKey = KeyUtils.generateKeyBytes();
    });

    group('encrypt', () {
      test('encrypts plaintext to bytes', () {
        final encrypted = AesCbc.encrypt('hello world', validKey);
        expect(encrypted, isNotEmpty);
        expect(encrypted.length, greaterThan(AesCbc.ivLength));
      });

      test('produces different output each time (random IV)', () {
        final encrypted1 = AesCbc.encrypt('hello', validKey);
        final encrypted2 = AesCbc.encrypt('hello', validKey);
        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('throws on invalid key length', () {
        final shortKey = Uint8List(16);
        expect(
          () => AesCbc.encrypt('hello', shortKey),
          throwsA(isA<InvalidKeyException>()),
        );
      });

      test('handles empty string', () {
        final encrypted = AesCbc.encrypt('', validKey);
        expect(encrypted.length, greaterThan(AesCbc.ivLength));
      });

      test('handles unicode', () {
        final encrypted = AesCbc.encrypt('こんにちは🎉', validKey);
        expect(encrypted, isNotEmpty);
      });
    });

    group('decrypt', () {
      test('decrypts to original plaintext', () {
        const original = 'hello world';
        final encrypted = AesCbc.encrypt(original, validKey);
        final decrypted = AesCbc.decrypt(encrypted, validKey);
        expect(decrypted, original);
      });

      test('decrypts empty string', () {
        const original = '';
        final encrypted = AesCbc.encrypt(original, validKey);
        final decrypted = AesCbc.decrypt(encrypted, validKey);
        expect(decrypted, original);
      });

      test('decrypts unicode', () {
        const original = 'こんにちは🎉';
        final encrypted = AesCbc.encrypt(original, validKey);
        final decrypted = AesCbc.decrypt(encrypted, validKey);
        expect(decrypted, original);
      });

      test('decrypts long text', () {
        final original = 'a' * 10000;
        final encrypted = AesCbc.encrypt(original, validKey);
        final decrypted = AesCbc.decrypt(encrypted, validKey);
        expect(decrypted, original);
      });

      test('throws on invalid key length', () {
        final encrypted = AesCbc.encrypt('hello', validKey);
        final shortKey = Uint8List(16);
        expect(
          () => AesCbc.decrypt(encrypted, shortKey),
          throwsA(isA<InvalidKeyException>()),
        );
      });

      test('throws on wrong key', () {
        final encrypted = AesCbc.encrypt('hello', validKey);
        final wrongKey = KeyUtils.generateKeyBytes();
        expect(
          () => AesCbc.decrypt(encrypted, wrongKey),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('throws on corrupted ciphertext', () {
        final encrypted = AesCbc.encrypt('hello', validKey);
        encrypted[20] ^= 0xFF; // Corrupt a byte
        expect(
          () => AesCbc.decrypt(encrypted, validKey),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('throws on ciphertext too short', () {
        final tooShort = Uint8List(10);
        expect(
          () => AesCbc.decrypt(tooShort, validKey),
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
          final encrypted = AesCbc.encrypt(original, validKey);
          final decrypted = AesCbc.decrypt(encrypted, validKey);
          expect(decrypted, original, reason: 'Failed for: $original');
        }
      });
    });
  });
}
