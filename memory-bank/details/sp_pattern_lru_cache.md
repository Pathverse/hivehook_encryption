# LRU Cache Pattern

## Overview

The EncryptionPlugin includes an optional LRU (Least Recently Used) cache that stores decrypted values in memory. This avoids redundant decryption operations and improves read performance.

## Configuration

```dart
final plugin = EncryptionPlugin(
  key: myKey,
  enableCache: true,      // Default: true
  maxCacheSize: 1000,     // Default: 1000 entries
);
```

## Cache Behavior

### Cache Hit Flow

```
┌─────────────────────────────────────────────┐
│  1. decryptHook receives read event         │
│     payload.key = "user_name"               │
│     payload.value = "encrypted_string"      │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  2. Check _cache[payload.key]               │
│     → FOUND: "John Doe"                     │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  3. Invoke onDecryptSuccess handlers        │
│     (cache hit still counts as success)     │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  4. Return HiContinue with cached value     │
│     → Skips decryption entirely             │
└─────────────────────────────────────────────┘
```

### Cache Miss Flow

```
┌─────────────────────────────────────────────┐
│  1. Check _cache[payload.key]               │
│     → NOT FOUND                             │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  2. Decrypt: base64 → bytes → plaintext     │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  3. Add to cache: _cache[key] = plaintext   │
│     → LRU eviction if size > maxCacheSize   │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  4. Return HiContinue with decrypted value  │
└─────────────────────────────────────────────┘
```

## Cache Invalidation

The cache is automatically invalidated in these scenarios:

| Event | Action |
|-------|--------|
| `write` / `put` | Invalidate specific key |
| `delete` | Invalidate specific key |
| `clear` | Clear entire cache |
| Plugin dispose | Clear entire cache |

### Implementation

```dart
class EncryptionPlugin {
  final _cache = <String?, dynamic>{};
  final _cacheOrder = <String?>[]; // LRU tracking

  void _invalidateKey(String? key) {
    _cache.remove(key);
    _cacheOrder.remove(key);
  }

  void _clearCache() {
    _cache.clear();
    _cacheOrder.clear();
  }

  void _addToCache(String? key, dynamic value) {
    // Remove if exists (will re-add at end)
    _cacheOrder.remove(key);
    
    // Add to cache
    _cache[key] = value;
    _cacheOrder.add(key);

    // Evict oldest if over limit
    while (_cacheOrder.length > maxCacheSize) {
      final oldest = _cacheOrder.removeAt(0);
      _cache.remove(oldest);
    }
  }
}
```

## Hook Configuration for Invalidation

```dart
HiHook _buildEncryptHook() {
  return HiHook(
    uid: 'encryption:encrypt',
    events: writeEvents.toSet(), // ['write', 'put']
    phase: HiPhase.pre,
    handler: (payload, ctx) async {
      // Invalidate cache before write
      if (enableCache) {
        _invalidateKey(payload.key);
      }
      
      // ... encrypt value ...
    },
  );
}

// Clear cache hook (for 'clear' event)
HiHook _buildClearCacheHook() {
  return HiHook(
    uid: 'encryption:clear-cache',
    events: {'clear'},
    phase: HiPhase.pre,
    handler: (_, __) {
      _clearCache();
      return const HiContinue();
    },
  );
}
```

## Performance Characteristics

### Memory Usage

Cache stores decrypted values in memory:
- Each entry: key (String?) + value (dynamic)
- Worst case with 1000 entries of 1KB each: ~1MB
- Consider reducing `maxCacheSize` for memory-constrained apps

### Time Complexity

| Operation | Complexity |
|-----------|------------|
| Cache lookup | O(1) |
| Cache insert | O(1) amortized |
| LRU eviction | O(1) |
| Cache invalidation | O(n) for order list |

### Trade-offs

| With Cache | Without Cache |
|------------|---------------|
| ✅ Fast repeated reads | ✅ Lower memory |
| ✅ Reduces CPU usage | ✅ No stale data risk |
| ❌ Memory overhead | ❌ Slower repeated reads |
| ❌ Complexity | ❌ More CPU usage |

## When to Disable Cache

```dart
// Disable for:
// - Very low memory environments
// - Single-read patterns
// - Security-critical apps (minimize decrypted data in memory)

final plugin = EncryptionPlugin(
  key: myKey,
  enableCache: false,
);
```

## Tuning Cache Size

```dart
// Small app / few keys
final plugin = EncryptionPlugin(key: k, maxCacheSize: 100);

// Default (most apps)
final plugin = EncryptionPlugin(key: k); // 1000

// Large app / many keys
final plugin = EncryptionPlugin(key: k, maxCacheSize: 10000);
```
