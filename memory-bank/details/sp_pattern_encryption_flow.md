# Encryption/Decryption Flow

## Overview

This document details the complete data flow through the encryption plugin, from user-facing API calls to storage and back.

## Write Flow (Encrypt)

```
User Code                    EncryptionPlugin              Storage
    │                              │                          │
    │  hive.put('key', 'value')    │                          │
    │──────────────────────────────>│                          │
    │                              │                          │
    │                              │ encryptHook (HiPhase.pre) │
    │                              │                          │
    │                              │ 1. Check if String       │
    │                              │    if not → passthrough  │
    │                              │                          │
    │                              │ 2. Invalidate cache      │
    │                              │    _cache.remove(key)    │
    │                              │                          │
    │                              │ 3. Encrypt               │
    │                              │    a. UTF-8 encode       │
    │                              │    b. Generate random IV │
    │                              │    c. AES-256 encrypt    │
    │                              │    d. Prepend IV         │
    │                              │    e. Base64 encode      │
    │                              │                          │
    │                              │ 4. Return HiContinue     │
    │                              │    with encrypted value  │
    │                              │                          │
    │                              │──────────────────────────>│
    │                              │      Store base64 string │
    │<─────────────────────────────│<─────────────────────────│
```

### Encryption Detail

```dart
String _encrypt(String plaintext) {
  // 1. Convert to bytes
  final plaintextBytes = utf8.encode(plaintext);

  // 2. Generate random 16-byte IV
  final iv = _generateRandomIv(); // 16 bytes

  // 3. Create cipher
  final cipher = algorithm == EncryptionAlgorithm.cbc
      ? AesCbc(keyBytes, iv)
      : AesGcm(keyBytes, iv);

  // 4. Encrypt with PKCS7 padding
  final encrypted = cipher.encrypt(plaintextBytes);

  // 5. Prepend IV to ciphertext
  final combined = Uint8List(iv.length + encrypted.length);
  combined.setAll(0, iv);
  combined.setAll(iv.length, encrypted);

  // 6. Encode as base64 for storage
  return base64.encode(combined);
}
```

## Read Flow (Decrypt)

```
User Code                    EncryptionPlugin              Storage
    │                              │                          │
    │  hive.get<String>('key')     │                          │
    │──────────────────────────────>│                          │
    │                              │──────────────────────────>│
    │                              │      Load base64 string  │
    │                              │<─────────────────────────│
    │                              │                          │
    │                              │ decryptHook (HiPhase.post)│
    │                              │                          │
    │                              │ 1. Check if String       │
    │                              │    if not → passthrough  │
    │                              │                          │
    │                              │ 2. Check cache           │
    │                              │    if hit → return cached│
    │                              │                          │
    │                              │ 3. Decrypt               │
    │                              │    a. Base64 decode      │
    │                              │    b. Extract IV (16 B)  │
    │                              │    c. AES-256 decrypt    │
    │                              │    d. UTF-8 decode       │
    │                              │                          │
    │                              │ 4. If success:           │
    │                              │    - Call onDecryptSuccess│
    │                              │    - Add to cache        │
    │                              │    - Return HiContinue   │
    │                              │                          │
    │                              │ 5. If failure:           │
    │                              │    - Call onDecryptFailure│
    │                              │    - Return HiPanic      │
    │                              │                          │
    │<─────────────────────────────│                          │
```

### Decryption Detail

```dart
String _decrypt(String base64Ciphertext) {
  // 1. Decode base64
  final combined = base64.decode(base64Ciphertext);

  // 2. Extract IV (first 16 bytes)
  final iv = combined.sublist(0, 16);
  final ciphertext = combined.sublist(16);

  // 3. Create cipher
  final cipher = algorithm == EncryptionAlgorithm.cbc
      ? AesCbc(keyBytes, iv)
      : AesGcm(keyBytes, iv);

  // 4. Decrypt and remove padding
  final decrypted = cipher.decrypt(ciphertext);

  // 5. Decode UTF-8
  return utf8.decode(decrypted);
}
```

## Data Format

### Stored Value Structure

```
┌────────────────────────────────────────────────────────────┐
│                    Base64 Encoded                          │
├────────────────────────────────────────────────────────────┤
│ IV (16 bytes) │ Encrypted Data (variable) │ Padding       │
├───────────────┼───────────────────────────┼───────────────┤
│ Random        │ AES-256-CBC/GCM           │ PKCS7         │
└───────────────┴───────────────────────────┴───────────────┘
```

### Example Transformation

```
Original:      "Hello, World!"
                    │
                    ▼
UTF-8 bytes:   [72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33]
                    │
                    ▼
+ Random IV:   [a9, 3c, ...16 bytes...]
                    │
                    ▼
AES Encrypt:   [IV 16B][Encrypted 16B] (padded to block size)
                    │
                    ▼
Base64:        "qTwkL7xY9nE2Fp1xB4mK8vWnHqJz5Rab..."
                    │
                    ▼
Stored in Hive
```

## Algorithm Comparison

### AES-256-CBC

```dart
EncryptionPlugin(key: k, algorithm: EncryptionAlgorithm.cbc)
```

| Aspect | Detail |
|--------|--------|
| Mode | Cipher Block Chaining |
| IV Size | 16 bytes |
| Padding | PKCS7 |
| Auth | None (vulnerable to tampering) |
| Performance | Faster |
| Use Case | General storage encryption |

### AES-256-GCM

```dart
EncryptionPlugin(key: k, algorithm: EncryptionAlgorithm.gcm)
```

| Aspect | Detail |
|--------|--------|
| Mode | Galois/Counter Mode |
| Nonce Size | 12 bytes (standard) |
| Tag Size | 16 bytes |
| Auth | Built-in (AEAD) |
| Performance | Slightly slower |
| Use Case | When integrity matters |

## Error Scenarios

### Wrong Key

```
Stored: "qTwkL7..." (encrypted with key A)
Decrypt with key B:
  → Decryption produces garbage
  → UTF-8 decode fails OR invalid padding
  → EncryptionException thrown
  → onDecryptFailure handlers called
  → HiPanic returned
```

### Corrupted Data

```
Stored: "qTwk..." (truncated or modified)
Decrypt:
  → Base64 decode may fail
  → OR padding validation fails
  → EncryptionException thrown
  → onDecryptFailure handlers called
  → HiPanic returned
```

### Non-String Value

```dart
await hive.put('count', 42); // int, not String
```

```
encryptHook:
  payload.value is int (not String)
  → Return HiContinue unchanged
  → Value stored as-is (not encrypted)

decryptHook:
  payload.value is int (not String)
  → Return HiContinue unchanged
  → Value returned as-is
```

## Passthrough Behavior

Only String values are encrypted. Other types pass through unchanged:

| Type | Encrypted? |
|------|------------|
| String | ✅ Yes |
| int | ❌ No (passthrough) |
| double | ❌ No (passthrough) |
| bool | ❌ No (passthrough) |
| List | ❌ No (passthrough) |
| Map | ❌ No (passthrough) |
| null | ❌ No (passthrough) |

For complex types, consider JSON encoding first:

```dart
final json = jsonEncode({'name': 'John', 'age': 30});
await hive.put('user', json); // String → encrypted
```
