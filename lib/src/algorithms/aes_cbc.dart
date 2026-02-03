import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../exceptions.dart';
import '../key_utils.dart';

/// AES-256-CBC encryption and decryption.
///
/// Data format: IV (16 bytes) + ciphertext
class AesCbc {
  AesCbc._();

  /// IV size for AES-CBC (128 bits).
  static const int ivLength = 16;

  /// Secure random for IV generation.
  static final Random _secureRandom = Random.secure();

  /// Encrypts plaintext using AES-256-CBC.
  ///
  /// Returns: IV (16 bytes) + ciphertext as Uint8List.
  static Uint8List encrypt(String plaintext, Uint8List key) {
    if (key.length != KeyUtils.keyLength) {
      throw InvalidKeyException(
        'Key must be ${KeyUtils.keyLength} bytes, got ${key.length}',
      );
    }

    final iv = _generateIv();
    final input = Uint8List.fromList(utf8.encode(plaintext));

    // Manually pad using PKCS7
    final blockSize = 16;
    final padLength = blockSize - (input.length % blockSize);
    final padded = Uint8List(input.length + padLength);
    padded.setRange(0, input.length, input);
    for (int i = input.length; i < padded.length; i++) {
      padded[i] = padLength;
    }

    // Use raw CBC cipher (no padding, we did it manually)
    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(true, ParametersWithIV(KeyParameter(key), iv));

    final encrypted = Uint8List(padded.length);
    for (int offset = 0; offset < padded.length; offset += blockSize) {
      cipher.processBlock(padded, offset, encrypted, offset);
    }

    // Prepend IV to ciphertext
    final result = Uint8List(iv.length + encrypted.length);
    result.setRange(0, iv.length, iv);
    result.setRange(iv.length, result.length, encrypted);
    return result;
  }

  /// Decrypts ciphertext using AES-256-CBC.
  ///
  /// Expects: IV (16 bytes) + ciphertext as input.
  /// Returns: decrypted plaintext.
  static String decrypt(Uint8List ciphertext, Uint8List key) {
    if (key.length != KeyUtils.keyLength) {
      throw InvalidKeyException(
        'Key must be ${KeyUtils.keyLength} bytes, got ${key.length}',
      );
    }

    if (ciphertext.length < ivLength + 16) {
      throw const EncryptionException(
        'Ciphertext too short (must include IV + at least one block)',
      );
    }

    try {
      // Extract IV and encrypted data
      final iv = ciphertext.sublist(0, ivLength);
      final encrypted = ciphertext.sublist(ivLength);

      // Use raw CBC cipher
      final cipher = CBCBlockCipher(AESEngine());
      cipher.init(false, ParametersWithIV(KeyParameter(key), iv));

      final blockSize = 16;
      final decrypted = Uint8List(encrypted.length);
      for (int offset = 0; offset < encrypted.length; offset += blockSize) {
        cipher.processBlock(encrypted, offset, decrypted, offset);
      }

      // Remove PKCS7 padding
      final padLength = decrypted.last;
      if (padLength < 1 || padLength > blockSize) {
        throw const EncryptionException('Invalid padding');
      }
      // Validate padding bytes
      for (int i = decrypted.length - padLength; i < decrypted.length; i++) {
        if (decrypted[i] != padLength) {
          throw const EncryptionException('Invalid padding');
        }
      }

      final unpadded = decrypted.sublist(0, decrypted.length - padLength);
      return utf8.decode(unpadded);
    } catch (e) {
      if (e is EncryptionException) rethrow;
      throw EncryptionException('Decryption failed', e);
    }
  }

  /// Generates a random 16-byte IV.
  static Uint8List _generateIv() {
    final iv = Uint8List(ivLength);
    for (int i = 0; i < ivLength; i++) {
      iv[i] = _secureRandom.nextInt(256);
    }
    return iv;
  }
}
