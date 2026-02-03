import 'dart:convert';

import 'package:test/test.dart';
import 'package:hivehook_encryption/src/key_utils.dart';
import 'package:hivehook_encryption/src/exceptions.dart';

void main() {
  group('KeyUtils.generateKey', () {
    test('generates a base64 string', () {
      final key = KeyUtils.generateKey();
      expect(key, isNotEmpty);
      // Should not throw
      base64Decode(key);
    });

    test('generates 32 bytes when decoded', () {
      final key = KeyUtils.generateKey();
      final decoded = base64Decode(key);
      expect(decoded.length, 32);
    });

    test('generates unique keys', () {
      final key1 = KeyUtils.generateKey();
      final key2 = KeyUtils.generateKey();
      expect(key1, isNot(equals(key2)));
    });
  });

  group('KeyUtils.generateKeyBytes', () {
    test('generates 32 bytes', () {
      final key = KeyUtils.generateKeyBytes();
      expect(key.length, 32);
    });

    test('generates unique keys', () {
      final key1 = KeyUtils.generateKeyBytes();
      final key2 = KeyUtils.generateKeyBytes();
      expect(key1, isNot(equals(key2)));
    });
  });

  group('KeyUtils.validateKey', () {
    test('accepts valid 32-byte base64 key', () {
      final key = KeyUtils.generateKey();
      // Should not throw
      KeyUtils.validateKey(key);
    });

    test('throws on empty key', () {
      expect(
        () => KeyUtils.validateKey(''),
        throwsA(isA<InvalidKeyException>()),
      );
    });

    test('throws on invalid base64', () {
      expect(
        () => KeyUtils.validateKey('not-valid-base64!!!'),
        throwsA(isA<InvalidKeyException>()),
      );
    });

    test('throws on wrong length (too short)', () {
      final shortKey = base64Encode(List.filled(16, 0)); // 16 bytes
      expect(
        () => KeyUtils.validateKey(shortKey),
        throwsA(isA<InvalidKeyException>()),
      );
    });

    test('throws on wrong length (too long)', () {
      final longKey = base64Encode(List.filled(64, 0)); // 64 bytes
      expect(
        () => KeyUtils.validateKey(longKey),
        throwsA(isA<InvalidKeyException>()),
      );
    });
  });

  group('KeyUtils.decodeKey', () {
    test('decodes valid key to bytes', () {
      final key = KeyUtils.generateKey();
      final decoded = KeyUtils.decodeKey(key);
      expect(decoded.length, 32);
    });

    test('throws on invalid key', () {
      expect(
        () => KeyUtils.decodeKey('invalid'),
        throwsA(isA<InvalidKeyException>()),
      );
    });
  });
}
