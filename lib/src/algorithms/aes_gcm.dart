import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../exceptions.dart';
import '../key_utils.dart';

/// AES-256-GCM encryption and decryption.
///
/// Data format: nonce (12 bytes) + ciphertext + tag (16 bytes)
class AesGcm {
  AesGcm._();

  /// Nonce size for AES-GCM (96 bits recommended).
  static const int nonceLength = 12;

  /// Authentication tag size (128 bits).
  static const int tagLength = 16;

  /// Secure random for nonce generation.
  static final Random _secureRandom = Random.secure();

  /// Encrypts plaintext using AES-256-GCM.
  ///
  /// Returns: nonce (12 bytes) + ciphertext + tag (16 bytes) as Uint8List.
  static Uint8List encrypt(String plaintext, Uint8List key) {
    if (key.length != KeyUtils.keyLength) {
      throw InvalidKeyException(
        'Key must be ${KeyUtils.keyLength} bytes, got ${key.length}',
      );
    }

    final nonce = _generateNonce();
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      tagLength * 8, // tag length in bits
      nonce,
      Uint8List(0), // no associated data
    );
    cipher.init(true, params);

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final encrypted = cipher.process(input);

    // Prepend nonce to ciphertext+tag
    final result = Uint8List(nonce.length + encrypted.length);
    result.setRange(0, nonce.length, nonce);
    result.setRange(nonce.length, result.length, encrypted);
    return result;
  }

  /// Decrypts ciphertext using AES-256-GCM.
  ///
  /// Expects: nonce (12 bytes) + ciphertext + tag (16 bytes) as input.
  /// Returns: decrypted plaintext.
  static String decrypt(Uint8List ciphertext, Uint8List key) {
    if (key.length != KeyUtils.keyLength) {
      throw InvalidKeyException(
        'Key must be ${KeyUtils.keyLength} bytes, got ${key.length}',
      );
    }

    // Minimum: nonce + tag (no plaintext = 0 bytes encrypted)
    if (ciphertext.length < nonceLength + tagLength) {
      throw const EncryptionException(
        'Ciphertext too short (must include nonce + tag)',
      );
    }

    try {
      // Extract nonce and encrypted data (includes tag)
      final nonce = ciphertext.sublist(0, nonceLength);
      final encrypted = ciphertext.sublist(nonceLength);

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        tagLength * 8, // tag length in bits
        nonce,
        Uint8List(0), // no associated data
      );
      cipher.init(false, params);

      final decrypted = cipher.process(encrypted);
      return utf8.decode(decrypted);
    } catch (e) {
      if (e is EncryptionException) rethrow;
      throw EncryptionException('Decryption failed', e);
    }
  }

  /// Generates a random 12-byte nonce.
  static Uint8List _generateNonce() {
    final nonce = Uint8List(nonceLength);
    for (int i = 0; i < nonceLength; i++) {
      nonce[i] = _secureRandom.nextInt(256);
    }
    return nonce;
  }
}
