# Active Context: HiveHook Encryption

## Current Status: ✅ Complete - Caching Feature Implemented

### Feature: Internal Decryption Cache

**Goal:** Avoid re-decrypting values on repeated reads.

**Implementation Complete:**
- Cache lives in `EncryptionPlugin` instance (one per env)
- `enableCache: true` by default (opt-in style, default on)
- `maxCacheSize: 1000` default limit with LRU eviction
- Invalidation on `write`, `delete` and `clear` events

**Hook Flow:**

| Event | Cache Action |
|-------|-------------|
| `write/put` | Invalidate that key, then encrypt |
| `read/get` | Return cached if exists, else decrypt & cache (LRU evict if full) |
| `delete` | Remove key from cache |
| `clear` | Clear entire cache |

**API:**
```dart
// Default: caching enabled, max 1000 entries
final plugin = EncryptionPlugin(key: myKey);

// Custom cache size
final plugin = EncryptionPlugin(key: myKey, maxCacheSize: 500);

// Disable caching
final plugin = EncryptionPlugin(key: myKey, enableCache: false);

// Manual cache operations
plugin.cacheSize; // Get current size
plugin.clearCache(); // Clear manually
```

### JSON Encoding in Hooks

Encryption hooks use JSON encode/decode for any JSON-serializable type:
- `encryptHook`: `jsonEncode(value)` → encrypt → base64
- `decryptHook`: base64 → decrypt → `jsonDecode()`

## Test Summary

| Test File | Count |
|-----------|-------|
| encryption_plugin_test | 28 |
| encryption_hook_test | (updated for JSON encoding) |
| algorithms, exceptions, key_utils | ... |
| **Total** | **100 passing** |

## Package Summary

| Aspect | Details |
|--------|---------|
| Type | Pure Dart hihook plugin |
| Pattern | Follows Base64Plugin |
| Algorithms | AES-256-CBC, AES-256-GCM |
| Caching | LRU with configurable size |
| Tests | 100 passing |

## Usage

```dart
// Create plugin (caching enabled by default)
final plugin = EncryptionPlugin.generate();
// Store key securely: plugin.key

// Register with hivehook
HHiveCore.register(HiveConfig(
  env: 'my-env',
  hooks: plugin.build().hooks,
));
await HHiveCore.initialize();

// Use normally - encryption is automatic
final hive = await HHive.create('my-env');
await hive.put('secret', 'my-password');
final value = await hive.get<String>('secret'); // 'my-password' (cached after first read)
```
