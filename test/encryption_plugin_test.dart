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
}
