/// Exception thrown when encryption or decryption fails.
class EncryptionException implements Exception {
  /// Human-readable error message.
  final String message;

  /// The original error that caused this exception.
  final Object? cause;

  const EncryptionException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'EncryptionException: $message (caused by: $cause)';
    }
    return 'EncryptionException: $message';
  }
}

/// Exception thrown when an invalid key is provided.
class InvalidKeyException extends EncryptionException {
  const InvalidKeyException(super.message, [super.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'InvalidKeyException: $message (caused by: $cause)';
    }
    return 'InvalidKeyException: $message';
  }
}
