/// HiveHook Encryption - AES encryption plugin for HiHook.
///
/// This package provides:
/// - [EncryptionPlugin] - Easy installation of encryption hooks
/// - [encryptHook] / [decryptHook] - Hook factory functions
/// - AES-256-CBC and AES-256-GCM encryption algorithms
/// - Key generation and validation utilities
///
/// ## Quick Start
///
/// ```dart
/// // Create plugin with your key
/// final plugin = EncryptionPlugin(key: myBase64Key);
/// plugin.install(engine);
///
/// // Or generate a new key
/// final plugin = EncryptionPlugin.generate();
/// final key = plugin.key; // Store this securely!
/// plugin.install(engine);
/// ```
///
/// ## Pure Dart
/// This package has no Flutter dependencies and works in CLI, server,
/// and Flutter projects. Key storage is the user's responsibility.
library;

// Plugin and hooks
export 'src/encryption_plugin.dart';
export 'src/encryption_hook.dart';

// Exceptions
export 'src/exceptions.dart';

// Key utilities
export 'src/key_utils.dart';

// Encryption algorithms
export 'src/algorithms/aes_cbc.dart';
export 'src/algorithms/aes_gcm.dart';
