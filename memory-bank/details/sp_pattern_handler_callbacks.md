# Handler Callbacks Pattern

## Overview

The `onDecryptSuccess` and `onDecryptFailure` handler lists allow applications to react to decryption outcomes. This enables key rotation, logging, metrics, and custom error handling.

## Handler Signatures

```dart
/// Called after successful decryption
typedef DecryptSuccessHandler = void Function(String? key, dynamic value);

/// Called when decryption fails (before HiPanic is returned)
typedef DecryptFailureHandler = void Function(String? key, Object error);
```

## Plugin Configuration

```dart
final plugin = EncryptionPlugin(
  key: myKey,
  onDecryptSuccess: [
    (key, value) => _logSuccess(key),
    (key, value) => _updateMetrics('decrypt_success'),
  ],
  onDecryptFailure: [
    (key, error) => _logFailure(key, error),
    (key, error) => _triggerKeyRotation(),
  ],
);
```

## Execution Flow

### Success Path

```
┌─────────────────────────────────────────────┐
│  1. decryptHook receives payload            │
│     (post-phase, read/get event)            │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  2. Extract encrypted value (base64 string) │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  3. Check cache (if enabled)                │
│     - Cache hit → skip decryption           │
│     - Cache miss → proceed                  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  4. Decrypt: base64 → bytes → plaintext     │
│     - Uses AesCbc.decrypt or AesGcm.decrypt │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  5. INVOKE: onDecryptSuccess handlers       │
│     for (final handler in onDecryptSuccess) │
│       handler(payload.key, decryptedValue); │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  6. Cache the result (if enabled)           │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  7. Return HiContinue with decrypted value  │
└─────────────────────────────────────────────┘
```

### Failure Path

```
┌─────────────────────────────────────────────┐
│  1. decryptHook receives payload            │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  2. Attempt decryption...                   │
│     → THROWS: EncryptionException           │
│     (wrong key, corrupted data, bad format) │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  3. Catch exception in hook handler         │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  4. INVOKE: onDecryptFailure handlers       │
│     for (final handler in onDecryptFailure) │
│       handler(payload.key, error);          │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  5. Return HiPanic with error message       │
│     → Engine returns HiPanic result         │
│     → Caller receives result.asPanic()      │
└─────────────────────────────────────────────┘
```

## HiPanic Behavior

**Important**: HiPanic does NOT throw an exception. It returns a result object.

```dart
// In decryptHook:
return HiPanic(message: 'Decryption failed: $error');

// In HiEngine (hihook internals):
// HiPanic is returned directly to caller, not thrown

// Caller receives:
final result = await engine.execute(...);
if (result.isPanic) {
  final panic = result.asPanic();
  print(panic.message); // "Decryption failed: ..."
}
```

## Implementation in EncryptionPlugin

```dart
HiHook _buildDecryptHook() {
  return HiHook(
    uid: 'encryption:decrypt',
    events: readEvents.toSet(),
    phase: HiPhase.post,
    handler: (payload, ctx) async {
      final value = payload.value;
      if (value is! String) return const HiContinue();

      // Check cache first
      if (enableCache) {
        final cached = _cache[payload.key];
        if (cached != null) {
          // Call success handlers for cache hit
          for (final handler in onDecryptSuccess) {
            handler(payload.key, cached);
          }
          return HiContinue(payload: payload.copyWith(value: cached));
        }
      }

      try {
        final decrypted = _decrypt(value);
        
        // Call success handlers
        for (final handler in onDecryptSuccess) {
          handler(payload.key, decrypted);
        }

        // Cache result
        if (enableCache) {
          _addToCache(payload.key, decrypted);
        }

        return HiContinue(payload: payload.copyWith(value: decrypted));
      } catch (e) {
        // Call failure handlers
        for (final handler in onDecryptFailure) {
          handler(payload.key, e);
        }
        return HiPanic(message: 'Decryption failed: $e');
      }
    },
  );
}
```

## Use Cases

### 1. Logging
```dart
onDecryptSuccess: [
  (key, value) => logger.debug('Decrypted: $key'),
],
onDecryptFailure: [
  (key, error) => logger.error('Decrypt failed: $key - $error'),
],
```

### 2. Metrics
```dart
onDecryptSuccess: [
  (key, _) => metrics.increment('decrypt.success'),
],
onDecryptFailure: [
  (key, _) => metrics.increment('decrypt.failure'),
],
```

### 3. Key Rotation (see [sp_pattern_key_rotation.md](sp_pattern_key_rotation.md))
```dart
onDecryptFailure: [
  (key, error) => _triggerKeyRotation(),
],
```

### 4. Circuit Breaker
```dart
int _failureCount = 0;

onDecryptSuccess: [
  (_, __) => _failureCount = 0, // Reset on success
],
onDecryptFailure: [
  (_, __) {
    _failureCount++;
    if (_failureCount >= 3) {
      _triggerEmergencyKeyRotation();
    }
  },
],
```
