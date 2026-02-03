import 'dart:convert';

import 'package:hihook/src/core/payload.dart';
import 'package:hihook/src/core/result.dart';
import 'package:hihook/src/core/types.dart';
import 'package:hihook/src/hook/hook.dart';

import 'algorithms/aes_cbc.dart';
import 'algorithms/aes_gcm.dart';
import 'key_utils.dart';

/// Encryption algorithm options.
enum EncryptionAlgorithm {
  /// AES-256-CBC with PKCS7 padding.
  cbc,

  /// AES-256-GCM with authentication tag.
  gcm,
}

/// Creates an encryption hook for write operations.
///
/// Encrypts payload string values before storage using AES-256.
/// Non-string values pass through unchanged.
///
/// ## Parameters
///
/// - [uid]: Unique hook identifier, defaults to 'encryption:encrypt'
/// - [key]: Base64-encoded 32-byte encryption key (required)
/// - [algorithm]: Encryption algorithm, defaults to [EncryptionAlgorithm.cbc]
/// - [events]: Events to listen for, defaults to ['write', 'put']
/// - [phase]: Hook phase, defaults to [HiPhase.pre] (encrypt before write)
/// - [priority]: Hook priority, defaults to 0
///
/// ## Payload Transformation
///
/// - String → Base64(encrypted bytes)
/// - Other types → passed through unchanged
///
/// ## Example
///
/// ```dart
/// engine.register(encryptHook(key: myBase64Key));
///
/// // Input: HiPayload(key: 'data', value: 'secret')
/// // Output: HiPayload(key: 'data', value: 'base64EncodedEncryptedData')
/// ```
HiHook<dynamic, dynamic> encryptHook({
  String uid = 'encryption:encrypt',
  required String key,
  EncryptionAlgorithm algorithm = EncryptionAlgorithm.cbc,
  List<String> events = const ['write', 'put'],
  HiPhase phase = HiPhase.pre,
  int priority = 0,
}) {
  final keyBytes = KeyUtils.decodeKey(key);

  return HiHook<dynamic, dynamic>(
    uid: uid,
    events: events,
    phase: phase,
    priority: priority,
    handler: (payload, ctx) {
      final value = payload.value;

      if (value is! String) {
        return const HiContinue();
      }

      try {
        final encrypted = switch (algorithm) {
          EncryptionAlgorithm.cbc => AesCbc.encrypt(value, keyBytes),
          EncryptionAlgorithm.gcm => AesGcm.encrypt(value, keyBytes),
        };

        return HiContinue(
          payload: HiPayload(
            key: payload.key,
            value: base64.encode(encrypted),
            metadata: payload.metadata,
          ),
        );
      } catch (e) {
        return HiPanic('Encryption failed: $e');
      }
    },
  );
}

/// Creates a decryption hook for read operations.
///
/// Decrypts payload string values after reading from storage.
/// Expects base64-encoded encrypted data. Non-string values pass through.
///
/// ## Parameters
///
/// - [uid]: Unique hook identifier, defaults to 'encryption:decrypt'
/// - [key]: Base64-encoded 32-byte encryption key (required)
/// - [algorithm]: Encryption algorithm, defaults to [EncryptionAlgorithm.cbc]
/// - [events]: Events to listen for, defaults to ['read', 'get']
/// - [phase]: Hook phase, defaults to [HiPhase.post] (decrypt after read)
/// - [priority]: Hook priority, defaults to 0
///
/// ## Payload Transformation
///
/// - Base64(encrypted bytes) → Original string
/// - Non-string values → passed through unchanged
///
/// ## Error Handling
///
/// Returns [HiAbort] if:
/// - Base64 decoding fails
/// - Decryption fails (wrong key, corrupted data)
///
/// ## Example
///
/// ```dart
/// engine.register(decryptHook(key: myBase64Key));
///
/// // Input: HiPayload(key: 'data', value: 'base64EncodedEncryptedData')
/// // Output: HiPayload(key: 'data', value: 'secret')
/// ```
HiHook<dynamic, dynamic> decryptHook({
  String uid = 'encryption:decrypt',
  required String key,
  EncryptionAlgorithm algorithm = EncryptionAlgorithm.cbc,
  List<String> events = const ['read', 'get'],
  HiPhase phase = HiPhase.post,
  int priority = 0,
}) {
  final keyBytes = KeyUtils.decodeKey(key);

  return HiHook<dynamic, dynamic>(
    uid: uid,
    events: events,
    phase: phase,
    priority: priority,
    handler: (payload, ctx) {
      final value = payload.value;

      if (value is! String) {
        return const HiContinue();
      }

      try {
        final encrypted = base64.decode(value);

        final decrypted = switch (algorithm) {
          EncryptionAlgorithm.cbc => AesCbc.decrypt(encrypted, keyBytes),
          EncryptionAlgorithm.gcm => AesGcm.decrypt(encrypted, keyBytes),
        };

        return HiContinue(
          payload: HiPayload(
            key: payload.key,
            value: decrypted,
            metadata: payload.metadata,
          ),
        );
      } catch (e) {
        return HiPanic('Decryption failed: $e');
      }
    },
  );
}
