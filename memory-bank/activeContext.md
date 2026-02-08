# Active Context: HiveHook Encryption

## Current Status: ✅ Complete - Handler Callbacks & Key Rotation Demo

### Latest Feature: Decryption Handler Callbacks

**Goal:** Allow apps to react to decryption success/failure for key rotation, logging, etc.

**Implementation:**
- `onDecryptSuccess`: `List<void Function(String? key, dynamic value)>`
- `onDecryptFailure`: `List<void Function(String? key, Object error)>`

```dart
final plugin = EncryptionPlugin(
  key: myKey,
  onDecryptSuccess: [
    (key, value) => print('Decrypted $key'),
  ],
  onDecryptFailure: [
    (key, error) => triggerKeyRotation(),
  ],
);
```

### Feature: Internal Decryption Cache

- Cache lives in `EncryptionPlugin` instance
- `enableCache: true` by default
- `maxCacheSize: 1000` default limit with LRU eviction
- Invalidation on `write`, `delete` and `clear` events

### Example App: Key Rotation Demo

**Purpose:** Demonstrate automatic key rotation when decryption fails.

**Structure:**
```
example/lib/
├── main.dart                        # Entry point
└── src/
    ├── encryption_service.dart      # Core logic: key rotation, HiveHook
    ├── key_rotation_demo_page.dart  # Main UI page
    ├── log_entry.dart               # LogEntry model
    └── widgets/
        ├── widgets.dart             # Barrel export
        ├── action_button.dart
        ├── log_view.dart
        └── status_bar.dart
```

**Flow:**
1. On decrypt failure → `onDecryptFailure` handler called
2. If auto-rotate enabled → generate new key
3. Clear all encrypted data (can't decrypt anyway)
4. Store new key in secure storage
5. Re-initialize with new key

**Features:**
- Toggle auto-rotate on/off
- "Simulate Key Loss" button for testing
- Stats: rotation count, success/failure counts
- Timestamped log output

## Test Summary

| Test File | Count |
|-----------|-------|
| encryption_plugin_test | 28 |
| encryption_hook_test | 25 |
| algorithms, exceptions, key_utils | 47 |
| **Total** | **100 passing** |

## Package Summary

| Aspect | Details |
|--------|---------|
| Type | Pure Dart hihook plugin |
| Algorithms | AES-256-CBC, AES-256-GCM |
| Caching | LRU with configurable size |
| Handlers | onDecryptSuccess, onDecryptFailure |
| Tests | 100 passing |

## Usage with Key Rotation

```dart
class EncryptionService {
  void _onDecryptFailure(String? key, Object error) {
    // Trigger automatic key rotation
    rotateKey();
  }

  Future<void> rotateKey() async {
    final newKey = KeyUtils.generateKey();
    await hive.clear(); // Can't decrypt with new key
    await secureStorage.write(key: 'key', value: newKey);
    await reinitialize();
  }
}
```
await hive.put('secret', 'my-password');
final value = await hive.get<String>('secret'); // 'my-password' (cached after first read)
```

## Detail Files

See `details/` for expanded documentation:

- [Example Refactoring](details/ac_recentChange_example_refactor.md) - Multi-file structure changes
