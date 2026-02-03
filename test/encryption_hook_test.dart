import 'dart:convert';
import 'dart:typed_data';

import 'package:hihook/src/context/context.dart';
import 'package:hihook/src/core/payload.dart';
import 'package:hihook/src/core/result.dart';
import 'package:hihook/src/core/types.dart';
import 'package:hivehook_encryption/hivehook_encryption.dart';
import 'package:test/test.dart';

void main() {
  group('encryptHook', () {
    late String testKey;
    late Uint8List keyBytes;

    setUp(() {
      testKey = KeyUtils.generateKey();
      keyBytes = KeyUtils.decodeKey(testKey);
    });

    test('creates hook with default parameters', () {
      final hook = encryptHook(key: testKey);

      expect(hook.uid, 'encryption:encrypt');
      expect(hook.events, ['write', 'put']);
      expect(hook.phase, HiPhase.pre);
    });

    test('creates hook with custom uid', () {
      final hook = encryptHook(key: testKey, uid: 'custom:encrypt');

      expect(hook.uid, 'custom:encrypt');
    });

    test('creates hook with custom events', () {
      final hook = encryptHook(key: testKey, events: ['save', 'store']);

      expect(hook.events, ['save', 'store']);
    });

    test('encrypts string payload value', () {
      final hook = encryptHook(key: testKey);
      final payload = HiPayload(key: 'test', value: 'hello world');
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload, isNotNull);
      expect(continueResult.payload!.key, 'test');
      // Value should be base64 encoded encrypted data
      expect(continueResult.payload!.value, isA<String>());
      expect(continueResult.payload!.value, isNot('hello world'));
      // Should be valid base64
      expect(() => base64.decode(continueResult.payload!.value as String),
          returnsNormally);
    });

    test('encrypts empty string', () {
      final hook = encryptHook(key: testKey);
      final payload = HiPayload(key: 'test', value: '');
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload, isNotNull);
      // Empty string should also be encrypted
      expect(continueResult.payload!.value, isA<String>());
      expect((continueResult.payload!.value as String).isNotEmpty, isTrue);
    });

    test('passes through non-string values unchanged', () {
      final hook = encryptHook(key: testKey);
      final payload = HiPayload(key: 'test', value: 12345);
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      // Should pass through unchanged (no payload modification)
      expect(continueResult.payload, isNull);
    });

    test('passes through null values unchanged', () {
      final hook = encryptHook(key: testKey);
      final payload = HiPayload(key: 'test', value: null);
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload, isNull);
    });

    test('preserves payload metadata', () {
      final hook = encryptHook(key: testKey);
      final payload = HiPayload(
        key: 'test',
        value: 'secret',
        metadata: {'ttl': 3600},
      );
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload!.metadata, {'ttl': 3600});
    });

    test('uses GCM algorithm when specified', () {
      final hook = encryptHook(
        key: testKey,
        algorithm: EncryptionAlgorithm.gcm,
      );
      final payload = HiPayload(key: 'test', value: 'hello');
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      // GCM produces different output format (nonce + ciphertext + tag)
      expect(continueResult.payload!.value, isA<String>());
    });
  });

  group('decryptHook', () {
    late String testKey;
    late Uint8List keyBytes;

    setUp(() {
      testKey = KeyUtils.generateKey();
      keyBytes = KeyUtils.decodeKey(testKey);
    });

    test('creates hook with default parameters', () {
      final hook = decryptHook(key: testKey);

      expect(hook.uid, 'encryption:decrypt');
      expect(hook.events, ['read', 'get']);
      expect(hook.phase, HiPhase.post);
    });

    test('creates hook with custom uid', () {
      final hook = decryptHook(key: testKey, uid: 'custom:decrypt');

      expect(hook.uid, 'custom:decrypt');
    });

    test('creates hook with custom events', () {
      final hook = decryptHook(key: testKey, events: ['load', 'fetch']);

      expect(hook.events, ['load', 'fetch']);
    });

    test('decrypts encrypted string payload value', () {
      // First encrypt
      final encrypted = AesCbc.encrypt('hello world', keyBytes);
      final encryptedBase64 = base64.encode(encrypted);

      final hook = decryptHook(key: testKey);
      final payload = HiPayload(key: 'test', value: encryptedBase64);
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload, isNotNull);
      expect(continueResult.payload!.value, 'hello world');
    });

    test('decrypts empty string correctly', () {
      final encrypted = AesCbc.encrypt('', keyBytes);
      final encryptedBase64 = base64.encode(encrypted);

      final hook = decryptHook(key: testKey);
      final payload = HiPayload(key: 'test', value: encryptedBase64);
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload!.value, '');
    });

    test('passes through non-string values unchanged', () {
      final hook = decryptHook(key: testKey);
      final payload = HiPayload(key: 'test', value: 12345);
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload, isNull);
    });

    test('passes through null values unchanged', () {
      final hook = decryptHook(key: testKey);
      final payload = HiPayload(key: 'test', value: null);
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload, isNull);
    });

    test('preserves payload metadata', () {
      final encrypted = AesCbc.encrypt('secret', keyBytes);
      final encryptedBase64 = base64.encode(encrypted);

      final hook = decryptHook(key: testKey);
      final payload = HiPayload(
        key: 'test',
        value: encryptedBase64,
        metadata: {'ttl': 3600},
      );
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload!.metadata, {'ttl': 3600});
    });

    test('decrypts GCM encrypted data when specified', () {
      final encrypted = AesGcm.encrypt('hello', keyBytes);
      final encryptedBase64 = base64.encode(encrypted);

      final hook = decryptHook(
        key: testKey,
        algorithm: EncryptionAlgorithm.gcm,
      );
      final payload = HiPayload(key: 'test', value: encryptedBase64);
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiContinue>());
      final continueResult = result as HiContinue;
      expect(continueResult.payload!.value, 'hello');
    });

    test('returns HiPanic on invalid base64', () {
      final hook = decryptHook(key: testKey);
      final payload = HiPayload(key: 'test', value: 'not-valid-base64!!!');
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiPanic>());
    });

    test('returns HiPanic on corrupted encrypted data', () {
      final hook = decryptHook(key: testKey);
      // Valid base64 but not valid encrypted data
      final payload = HiPayload(key: 'test', value: base64.encode([1, 2, 3]));
      final ctx = _MockContext();

      final result = hook.handler(payload, ctx);

      expect(result, isA<HiPanic>());
    });
  });

  group('encrypt/decrypt roundtrip', () {
    test('CBC roundtrip preserves original value', () {
      final testKey = KeyUtils.generateKey();
      final encHook = encryptHook(key: testKey);
      final decHook = decryptHook(key: testKey);
      final ctx = _MockContext();

      final original = HiPayload(key: 'test', value: 'sensitive data 123!');

      // Encrypt
      final encResult = encHook.handler(original, ctx) as HiContinue;
      final encryptedPayload = encResult.payload!;

      // Decrypt
      final decResult = decHook.handler(encryptedPayload, ctx) as HiContinue;
      final decryptedPayload = decResult.payload!;

      expect(decryptedPayload.value, 'sensitive data 123!');
      expect(decryptedPayload.key, 'test');
    });

    test('GCM roundtrip preserves original value', () {
      final testKey = KeyUtils.generateKey();
      final encHook = encryptHook(
        key: testKey,
        algorithm: EncryptionAlgorithm.gcm,
      );
      final decHook = decryptHook(
        key: testKey,
        algorithm: EncryptionAlgorithm.gcm,
      );
      final ctx = _MockContext();

      final original = HiPayload(key: 'test', value: 'secret GCM data');

      // Encrypt
      final encResult = encHook.handler(original, ctx) as HiContinue;
      final encryptedPayload = encResult.payload!;

      // Decrypt
      final decResult = decHook.handler(encryptedPayload, ctx) as HiContinue;
      final decryptedPayload = decResult.payload!;

      expect(decryptedPayload.value, 'secret GCM data');
    });

    test('roundtrip preserves metadata', () {
      final testKey = KeyUtils.generateKey();
      final encHook = encryptHook(key: testKey);
      final decHook = decryptHook(key: testKey);
      final ctx = _MockContext();

      final original = HiPayload(
        key: 'test',
        value: 'data',
        metadata: {'created': 12345, 'type': 'user'},
      );

      final encResult = encHook.handler(original, ctx) as HiContinue;
      final decResult =
          decHook.handler(encResult.payload!, ctx) as HiContinue;

      expect(decResult.payload!.metadata, {'created': 12345, 'type': 'user'});
    });
  });
}

/// Minimal mock context for testing hooks
class _MockContext implements HiContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
