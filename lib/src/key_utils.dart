import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';


import 'exceptions.dart';

/// Utilities for key generation and validation.
class KeyUtils {
  KeyUtils._();

  /// AES-256 requires a 32-byte key.
  static const int keyLength = 32;

  /// Secure random instance for key generation.
  static final Random _secureRandom = Random.secure();

  /// Generates a cryptographically secure random 32-byte key.
  ///
  /// Returns the key as a base64-encoded string.
  static String generateKey() {
    return base64Encode(generateKeyBytes());
  }

  /// Generates a cryptographically secure random 32-byte key as bytes.
  static Uint8List generateKeyBytes() {
    final key = Uint8List(keyLength);
    for (int i = 0; i < keyLength; i++) {
      key[i] = _secureRandom.nextInt(256);
    }
    return key;
  }

  /// Validates that the key is exactly 32 bytes when decoded.
  ///
  /// Throws [InvalidKeyException] if the key is invalid.
  static void validateKey(String key) {
    if (key.isEmpty) {
      throw const InvalidKeyException('Key cannot be empty');
    }

    Uint8List decoded;
    try {
      decoded = base64Decode(key);
    } catch (e) {
      throw InvalidKeyException('Key is not valid base64', e);
    }

    if (decoded.length != keyLength) {
      throw InvalidKeyException(
        'Key must be $keyLength bytes, got ${decoded.length} bytes',
      );
    }
  }

  /// Decodes a base64 key to bytes, with validation.
  ///
  /// Throws [InvalidKeyException] if the key is invalid.
  static Uint8List decodeKey(String key) {
    validateKey(key);
    return base64Decode(key);
  }
}
