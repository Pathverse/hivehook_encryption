import 'dart:convert';
import 'dart:typed_data';

import 'package:hihook/src/core/payload.dart';
import 'package:hihook/src/core/result.dart';
import 'package:hihook/src/core/types.dart';
import 'package:hihook/src/engine/engine.dart';
import 'package:hihook/src/hook/hook.dart';
import 'package:hihook/src/plugin/plugin.dart';

import 'algorithms/aes_cbc.dart';
import 'algorithms/aes_gcm.dart';
import 'encryption_hook.dart';
import 'key_utils.dart';

/// Encryption Plugin - Automatic encryption/decryption of payload values.
///
/// Bundles encryption and decryption hooks for easy installation.
/// Follows the same pattern as Base64Plugin from hihook.
///
/// ## Features
///
/// - **Encrypt hook**: Encrypts payload value before storage
/// - **Decrypt hook**: Decrypts value after reading from storage
/// - **Algorithm choice**: AES-256-CBC (default) or AES-256-GCM
/// - **Caching**: Caches decrypted values to avoid re-decryption (default on)
/// - **Pure Dart**: No Flutter dependencies, works everywhere
///
/// ## Example
///
/// ```dart
/// final engine = HiEngine();
///
/// // With your own key
/// EncryptionPlugin(key: myBase64Key).install(engine);
///
/// // With auto-generated key
/// final plugin = EncryptionPlugin.generate();
/// final key = plugin.key; // Store this securely!
/// plugin.install(engine);
///
/// // With GCM algorithm
/// EncryptionPlugin(
///   key: myKey,
///   algorithm: EncryptionAlgorithm.gcm,
/// ).install(engine);
///
/// // Disable caching
/// EncryptionPlugin(
///   key: myKey,
///   enableCache: false,
/// ).install(engine);
/// ```
class EncryptionPlugin {
  /// The base64-encoded 32-byte encryption key.
  final String key;

  /// The encryption algorithm to use.
  final EncryptionAlgorithm algorithm;

  /// Events that trigger encryption.
  final List<String> writeEvents;

  /// Events that trigger decryption.
  final List<String> readEvents;

  /// Whether to register the encrypt hook.
  final bool enableEncrypt;

  /// Whether to register the decrypt hook.
  final bool enableDecrypt;

  /// Whether to cache decrypted values in memory.
  ///
  /// When enabled, decrypted values are stored in memory and returned
  /// on subsequent reads without re-decryption. The cache is invalidated
  /// on write, delete, and clear operations.
  final bool enableCache;

  /// Maximum number of entries to cache.
  ///
  /// When the cache exceeds this limit, the oldest entries are evicted.
  /// Set to 0 for unlimited cache (not recommended for production).
  /// Default is 1000 entries.
  final int maxCacheSize;

  /// Internal cache for decrypted values.
  final Map<String, dynamic> _cache = {};

  /// Creates an encryption plugin with the given key.
  ///
  /// The [key] must be a valid base64-encoded 32-byte key.
  /// Use [KeyUtils.generateKey] to create a new key.
  EncryptionPlugin({
    required this.key,
    this.algorithm = EncryptionAlgorithm.cbc,
    this.writeEvents = const ['write', 'put'],
    this.readEvents = const ['read', 'get'],
    this.enableEncrypt = true,
    this.enableDecrypt = true,
    this.enableCache = true,
    this.maxCacheSize = 1000,
  });

  /// Creates an encryption plugin with an auto-generated key.
  ///
  /// Access the generated key via [key] property.
  /// **Important**: Store this key securely - you'll need it to decrypt data!
  factory EncryptionPlugin.generate({
    EncryptionAlgorithm algorithm = EncryptionAlgorithm.cbc,
    List<String> writeEvents = const ['write', 'put'],
    List<String> readEvents = const ['read', 'get'],
    bool enableEncrypt = true,
    bool enableDecrypt = true,
    bool enableCache = true,
    int maxCacheSize = 1000,
  }) {
    return EncryptionPlugin(
      key: KeyUtils.generateKey(),
      algorithm: algorithm,
      writeEvents: writeEvents,
      readEvents: readEvents,
      enableEncrypt: enableEncrypt,
      enableDecrypt: enableDecrypt,
      enableCache: enableCache,
      maxCacheSize: maxCacheSize,
    );
  }

  /// Returns the number of cached entries.
  int get cacheSize => _cache.length;

  /// Clears the internal cache.
  void clearCache() => _cache.clear();

  /// Builds the HiPlugin for installation.
  HiPlugin build() {
    final hooks = <HiHook<dynamic, dynamic>>[];
    final keyBytes = KeyUtils.decodeKey(key);

    if (enableEncrypt) {
      hooks.add(_buildEncryptHook(keyBytes));
    }

    if (enableDecrypt) {
      hooks.add(_buildDecryptHook(keyBytes));
    }

    if (enableCache) {
      hooks.add(_buildCacheInvalidateHook());
    }

    return HiPlugin(
      name: 'encryption',
      version: '1.0.0',
      description: 'AES encryption/decryption for payload values',
      hooks: hooks,
    );
  }

  /// Builds the encrypt hook with cache invalidation.
  HiHook<dynamic, dynamic> _buildEncryptHook(Uint8List keyBytes) {
    return HiHook<dynamic, dynamic>(
      uid: 'encryption:encrypt',
      events: writeEvents,
      phase: HiPhase.pre,
      priority: 0,
      handler: (payload, ctx) {
        // Invalidate cache on write
        if (enableCache && payload.key != null) {
          _cache.remove(payload.key);
        }

        final value = payload.value;

        // Pass through null unchanged
        if (value == null) {
          return const HiContinue();
        }

        try {
          // JSON encode the value first (handles any JSON-serializable type)
          final jsonString = jsonEncode(value);

          final encrypted = switch (algorithm) {
            EncryptionAlgorithm.cbc => AesCbc.encrypt(jsonString, keyBytes),
            EncryptionAlgorithm.gcm => AesGcm.encrypt(jsonString, keyBytes),
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

  /// Builds the decrypt hook with caching.
  HiHook<dynamic, dynamic> _buildDecryptHook(Uint8List keyBytes) {
    return HiHook<dynamic, dynamic>(
      uid: 'encryption:decrypt',
      events: readEvents,
      phase: HiPhase.post,
      priority: 0,
      handler: (payload, ctx) {
        final value = payload.value;

        // Pass through null unchanged
        if (value == null) {
          return const HiContinue();
        }

        // Non-string values pass through
        if (value is! String) {
          return const HiContinue();
        }

        // Check cache first
        final cacheKey = payload.key;
        if (enableCache && cacheKey != null && _cache.containsKey(cacheKey)) {
          return HiContinue(
            payload: HiPayload(
              key: payload.key,
              value: _cache[cacheKey],
              metadata: payload.metadata,
            ),
          );
        }

        try {
          final encrypted = base64.decode(value);

          final decryptedJson = switch (algorithm) {
            EncryptionAlgorithm.cbc => AesCbc.decrypt(encrypted, keyBytes),
            EncryptionAlgorithm.gcm => AesGcm.decrypt(encrypted, keyBytes),
          };

          // JSON decode to restore original value type
          final decryptedValue = jsonDecode(decryptedJson);

          // Cache the result with LRU eviction
          if (enableCache && cacheKey != null) {
            // Evict oldest entries if cache is full
            if (maxCacheSize > 0 && _cache.length >= maxCacheSize) {
              // Remove oldest entry (first key in insertion order)
              final oldestKey = _cache.keys.first;
              _cache.remove(oldestKey);
            }
            _cache[cacheKey] = decryptedValue;
          }

          return HiContinue(
            payload: HiPayload(
              key: payload.key,
              value: decryptedValue,
              metadata: payload.metadata,
            ),
          );
        } catch (e) {
          return HiPanic('Decryption failed: $e');
        }
      },
    );
  }

  /// Builds the cache invalidation hook for delete/clear events.
  HiHook<dynamic, dynamic> _buildCacheInvalidateHook() {
    return HiHook<dynamic, dynamic>(
      uid: 'encryption:cache-invalidate',
      events: const ['delete', 'clear'],
      phase: HiPhase.pre,
      priority: 0,
      handler: (payload, ctx) {
        final key = payload.key;
        if (key == null || key.isEmpty) {
          // 'clear' event - clear entire cache
          _cache.clear();
        } else {
          // 'delete' event - remove specific key
          _cache.remove(key);
        }
        return const HiContinue();
      },
    );
  }

  /// Convenience method to build and install in one step.
  void install(HiEngine engine) => build().install(engine);
}
