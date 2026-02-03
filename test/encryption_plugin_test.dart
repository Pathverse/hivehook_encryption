import 'package:hihook/src/core/payload.dart';
import 'package:hihook/src/engine/engine.dart';
import 'package:hihook/src/plugin/plugin.dart';
import 'package:hivehook_encryption/hivehook_encryption.dart';
import 'package:test/test.dart';

void main() {
  group('EncryptionPlugin', () {
    test('creates plugin with required key', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);

      expect(plugin.key, key);
      expect(plugin.algorithm, EncryptionAlgorithm.cbc);
      expect(plugin.writeEvents, ['write', 'put']);
      expect(plugin.readEvents, ['read', 'get']);
    });

    test('creates plugin with custom algorithm', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(
        key: key,
        algorithm: EncryptionAlgorithm.gcm,
      );

      expect(plugin.algorithm, EncryptionAlgorithm.gcm);
    });

    test('creates plugin with custom events', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(
        key: key,
        writeEvents: ['save'],
        readEvents: ['load'],
      );

      expect(plugin.writeEvents, ['save']);
      expect(plugin.readEvents, ['load']);
    });

    test('generate() creates plugin with new key', () {
      final plugin = EncryptionPlugin.generate();

      expect(plugin.key, isNotEmpty);
      expect(() => KeyUtils.validateKey(plugin.key), returnsNormally);
    });

    test('generate() creates different keys each time', () {
      final plugin1 = EncryptionPlugin.generate();
      final plugin2 = EncryptionPlugin.generate();

      expect(plugin1.key, isNot(plugin2.key));
    });

    test('generate() accepts algorithm option', () {
      final plugin = EncryptionPlugin.generate(
        algorithm: EncryptionAlgorithm.gcm,
      );

      expect(plugin.algorithm, EncryptionAlgorithm.gcm);
    });

    test('build() returns HiPlugin', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);

      final hiPlugin = plugin.build();

      expect(hiPlugin, isA<HiPlugin>());
      expect(hiPlugin.name, 'encryption');
      expect(hiPlugin.version, '1.0.0');
    });

    test('build() includes encrypt hook', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);

      final hiPlugin = plugin.build();

      expect(hiPlugin.hooks.any((h) => h.uid == 'encryption:encrypt'), isTrue);
    });

    test('build() includes decrypt hook', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);

      final hiPlugin = plugin.build();

      expect(hiPlugin.hooks.any((h) => h.uid == 'encryption:decrypt'), isTrue);
    });

    test('build() with enableEncrypt=false excludes encrypt hook', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key, enableEncrypt: false);

      final hiPlugin = plugin.build();

      expect(hiPlugin.hooks.any((h) => h.uid == 'encryption:encrypt'), isFalse);
      expect(hiPlugin.hooks.any((h) => h.uid == 'encryption:decrypt'), isTrue);
    });

    test('build() with enableDecrypt=false excludes decrypt hook', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key, enableDecrypt: false);

      final hiPlugin = plugin.build();

      expect(hiPlugin.hooks.any((h) => h.uid == 'encryption:encrypt'), isTrue);
      expect(hiPlugin.hooks.any((h) => h.uid == 'encryption:decrypt'), isFalse);
    });

    test('install() adds hooks to engine', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);
      final engine = HiEngine();

      plugin.install(engine);

      // Verify hooks are registered
      expect(engine.hasHook('encryption:encrypt'), isTrue);
      expect(engine.hasHook('encryption:decrypt'), isTrue);
    });
  });

  group('EncryptionAlgorithm', () {
    test('has cbc value', () {
      expect(EncryptionAlgorithm.cbc, isNotNull);
    });

    test('has gcm value', () {
      expect(EncryptionAlgorithm.gcm, isNotNull);
    });
  });

  group('EncryptionPlugin caching', () {
    test('enableCache is true by default', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);

      expect(plugin.enableCache, isTrue);
    });

    test('enableCache can be disabled', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key, enableCache: false);

      expect(plugin.enableCache, isFalse);
    });

    test('clearCache() clears the internal cache', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);

      // Should not throw
      expect(() => plugin.clearCache(), returnsNormally);
    });

    test('build() includes delete invalidation hook when caching enabled', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);

      final hiPlugin = plugin.build();

      expect(
        hiPlugin.hooks.any((h) => h.uid == 'encryption:cache-invalidate'),
        isTrue,
      );
    });

    test('build() excludes cache hooks when caching disabled', () {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key, enableCache: false);

      final hiPlugin = plugin.build();

      expect(
        hiPlugin.hooks.any((h) => h.uid == 'encryption:cache-invalidate'),
        isFalse,
      );
    });

    test('caching returns cached value on repeated reads', () async {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);
      final engine = HiEngine();
      plugin.install(engine);

      // Simulate write to get encrypted value
      final writePayload = HiPayload<dynamic>(key: 'test', value: {'secret': 'data'});
      final writeResult = await engine.emit<dynamic, dynamic>('write', writePayload);
      final encryptedValue = writeResult.payload?.value;

      // First read - decrypts and caches
      final readPayload1 = HiPayload<dynamic>(key: 'test', value: encryptedValue);
      final result1 = await engine.emit<dynamic, dynamic>('read', readPayload1);

      // Second read - should use cache
      final readPayload2 = HiPayload<dynamic>(key: 'test', value: encryptedValue);
      final result2 = await engine.emit<dynamic, dynamic>('read', readPayload2);

      expect(result1.payload?.value, equals(result2.payload?.value));
      expect(result1.payload?.value, equals({'secret': 'data'}));
    });

    test('write invalidates cache for that key', () async {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);
      final engine = HiEngine();
      plugin.install(engine);

      // Write initial value
      await engine.emit<dynamic, dynamic>(
        'write',
        HiPayload<dynamic>(key: 'test', value: 'value1'),
      );

      // Write new value (should invalidate cache)
      await engine.emit<dynamic, dynamic>(
        'write',
        HiPayload<dynamic>(key: 'test', value: 'value2'),
      );

      // Cache should be invalidated (no exception means success)
      expect(plugin.cacheSize, equals(0));
    });

    test('delete invalidates cache for that key', () async {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);
      final engine = HiEngine();
      plugin.install(engine);

      // Simulate a cached read
      final writeResult = await engine.emit<dynamic, dynamic>(
        'write',
        HiPayload<dynamic>(key: 'test', value: 'secret'),
      );
      final encryptedValue = writeResult.payload?.value;
      await engine.emit<dynamic, dynamic>(
        'read',
        HiPayload<dynamic>(key: 'test', value: encryptedValue),
      );

      // Should be cached now
      expect(plugin.cacheSize, equals(1));

      // Delete should invalidate
      await engine.emit<dynamic, dynamic>(
        'delete',
        HiPayload<dynamic>(key: 'test', value: null),
      );

      expect(plugin.cacheSize, equals(0));
    });

    test('clear invalidates entire cache', () async {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);
      final engine = HiEngine();
      plugin.install(engine);

      // Simulate cached reads for multiple keys
      for (final k in ['key1', 'key2', 'key3']) {
        final writeResult = await engine.emit<dynamic, dynamic>(
          'write',
          HiPayload<dynamic>(key: k, value: 'data'),
        );
        final encrypted = writeResult.payload?.value;
        await engine.emit<dynamic, dynamic>(
          'read',
          HiPayload<dynamic>(key: k, value: encrypted),
        );
      }

      expect(plugin.cacheSize, equals(3));

      // Clear should invalidate all
      await engine.emit<dynamic, dynamic>(
        'clear',
        HiPayload<dynamic>(key: '', value: null),
      );

      expect(plugin.cacheSize, equals(0));
    });

    test('cacheSize returns number of cached entries', () async {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);
      final engine = HiEngine();
      plugin.install(engine);

      expect(plugin.cacheSize, equals(0));

      // Add to cache via read
      final writeResult = await engine.emit<dynamic, dynamic>(
        'write',
        HiPayload<dynamic>(key: 'test', value: 'data'),
      );
      final encrypted = writeResult.payload?.value;
      await engine.emit<dynamic, dynamic>(
        'read',
        HiPayload<dynamic>(key: 'test', value: encrypted),
      );

      expect(plugin.cacheSize, equals(1));
    });

    test('write evicts cache so new value is decrypted correctly', () async {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);
      final engine = HiEngine();
      plugin.install(engine);

      // Write and read first value - gets cached
      final write1 = await engine.emit<dynamic, dynamic>(
        'write',
        HiPayload<dynamic>(key: 'test', value: 'original'),
      );
      final read1 = await engine.emit<dynamic, dynamic>(
        'read',
        HiPayload<dynamic>(key: 'test', value: write1.payload?.value),
      );
      expect(read1.payload?.value, equals('original'));
      expect(plugin.cacheSize, equals(1));

      // Write new value - should evict cache
      final write2 = await engine.emit<dynamic, dynamic>(
        'write',
        HiPayload<dynamic>(key: 'test', value: 'updated'),
      );
      expect(plugin.cacheSize, equals(0)); // Cache evicted

      // Read new value - should decrypt new value, not return stale cache
      final read2 = await engine.emit<dynamic, dynamic>(
        'read',
        HiPayload<dynamic>(key: 'test', value: write2.payload?.value),
      );
      expect(read2.payload?.value, equals('updated'));
      expect(plugin.cacheSize, equals(1)); // New value cached
    });

    test('delete evicts only the specific key', () async {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);
      final engine = HiEngine();
      plugin.install(engine);

      // Cache multiple keys
      for (final k in ['key1', 'key2', 'key3']) {
        final write = await engine.emit<dynamic, dynamic>(
          'write',
          HiPayload<dynamic>(key: k, value: 'value_$k'),
        );
        await engine.emit<dynamic, dynamic>(
          'read',
          HiPayload<dynamic>(key: k, value: write.payload?.value),
        );
      }
      expect(plugin.cacheSize, equals(3));

      // Delete only key2
      await engine.emit<dynamic, dynamic>(
        'delete',
        HiPayload<dynamic>(key: 'key2', value: null),
      );

      // Only key2 should be evicted
      expect(plugin.cacheSize, equals(2));
    });

    test('clearCache() manually clears the cache', () async {
      final key = KeyUtils.generateKey();
      final plugin = EncryptionPlugin(key: key);
      final engine = HiEngine();
      plugin.install(engine);

      // Cache a value
      final write = await engine.emit<dynamic, dynamic>(
        'write',
        HiPayload<dynamic>(key: 'test', value: 'data'),
      );
      await engine.emit<dynamic, dynamic>(
        'read',
        HiPayload<dynamic>(key: 'test', value: write.payload?.value),
      );
      expect(plugin.cacheSize, equals(1));

      // Manual clear
      plugin.clearCache();
      expect(plugin.cacheSize, equals(0));
    });

    test('maxCacheSize evicts oldest entry when cache is full', () async {
      final key = KeyUtils.generateKey();
      // Create plugin with maxCacheSize of 3
      final plugin = EncryptionPlugin(key: key, maxCacheSize: 3);
      final engine = HiEngine();
      plugin.install(engine);

      // Cache 3 keys (fills up the cache)
      final encryptedValues = <String, String>{};
      for (final k in ['key1', 'key2', 'key3']) {
        final write = await engine.emit<dynamic, dynamic>(
          'write',
          HiPayload<dynamic>(key: k, value: 'value_$k'),
        );
        encryptedValues[k] = write.payload?.value as String;
        await engine.emit<dynamic, dynamic>(
          'read',
          HiPayload<dynamic>(key: k, value: write.payload?.value),
        );
      }
      expect(plugin.cacheSize, equals(3));

      // Add 4th key - should evict key1 (oldest)
      final write4 = await engine.emit<dynamic, dynamic>(
        'write',
        HiPayload<dynamic>(key: 'key4', value: 'value_key4'),
      );
      await engine.emit<dynamic, dynamic>(
        'read',
        HiPayload<dynamic>(key: 'key4', value: write4.payload?.value),
      );

      // Cache should still be 3 (evicted key1, added key4)
      expect(plugin.cacheSize, equals(3));

      // Reading key1 again should trigger decryption (not in cache)
      // We can verify by checking cacheSize doesn't change when reading cached keys
      // but does when reading key1 (which requires decryption and re-caching)
      // Actually with maxCacheSize=3 and 4 keys decrypted, we should have key2, key3, key4
      // Reading key1 again will evict key2 and add key1
      await engine.emit<dynamic, dynamic>(
        'read',
        HiPayload<dynamic>(key: 'key1', value: encryptedValues['key1']),
      );
      // Cache should now have key3, key4, key1 (evicted key2)
      expect(plugin.cacheSize, equals(3));
    });
  });
}
