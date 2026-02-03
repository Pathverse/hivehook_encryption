import 'package:hihook/src/engine/engine.dart';
import 'package:hihook/src/plugin/plugin.dart';

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
  }) {
    return EncryptionPlugin(
      key: KeyUtils.generateKey(),
      algorithm: algorithm,
      writeEvents: writeEvents,
      readEvents: readEvents,
      enableEncrypt: enableEncrypt,
      enableDecrypt: enableDecrypt,
    );
  }

  /// Builds the HiPlugin for installation.
  HiPlugin build() {
    final hooks = <dynamic>[];

    if (enableEncrypt) {
      hooks.add(encryptHook(
        uid: 'encryption:encrypt',
        key: key,
        algorithm: algorithm,
        events: writeEvents,
      ));
    }

    if (enableDecrypt) {
      hooks.add(decryptHook(
        uid: 'encryption:decrypt',
        key: key,
        algorithm: algorithm,
        events: readEvents,
      ));
    }

    return HiPlugin(
      name: 'encryption',
      version: '1.0.0',
      description: 'AES encryption/decryption for payload values',
      hooks: hooks.cast(),
    );
  }

  /// Convenience method to build and install in one step.
  void install(HiEngine engine) => build().install(engine);
}
