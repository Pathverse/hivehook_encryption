# System Patterns: HiveHook Encryption

## Target Architecture (HiHook Plugin)

```
┌─────────────────────────────────────────────────────────────┐
│  hivehook_encryption                                         │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  EncryptionPlugin (user-facing)                         ││
│  │  - key: String (base64)                                 ││
│  │  - algorithm: EncryptionAlgorithm (.cbc | .gcm)         ││
│  │  - writeEvents / readEvents                             ││
│  │  - build() → HiPlugin                                   ││
│  │  - install(engine) → void                               ││
│  └─────────────────────────────────────────────────────────┘│
│                          │                                   │
│                          ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Hook Factories (pattern from Base64Plugin)             ││
│  │  - encryptHook() → HiHook (pre phase, encode value)     ││
│  │  - decryptHook() → HiHook (post phase, decode value)    ││
│  └─────────────────────────────────────────────────────────┘│
│                          │                                   │
│                          ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Pure Encryption Utilities (no hihook deps)             ││
│  │  - AesCbc.encrypt() / decrypt()                         ││
│  │  - AesGcm.encrypt() / decrypt()                         ││
│  │  - KeyUtils.generateKey() / validateKey()               ││
│  │  - EncryptionException / InvalidKeyException            ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  hihook (dependency)                                         │
│  - HiPlugin, HiHook, HiPayload, HiContinue, HiEngine        │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

```
lib/
├── hivehook_encryption.dart       # Public API exports
└── src/
    ├── exceptions.dart            # ✓ Exception types
    ├── key_utils.dart             # ✓ Key generation/validation
    ├── algorithms/
    │   ├── aes_cbc.dart           # ✓ AES-256-CBC
    │   └── aes_gcm.dart           # ✓ AES-256-GCM
    ├── encryption_hook.dart       # → Hook factory functions
    └── encryption_plugin.dart     # → Plugin wrapper class
```

## Plugin Pattern (Following Base64Plugin)

### Hook Factory Pattern
```dart
// Like base64EncodeHook() / base64DecodeHook()
HiHook<dynamic, dynamic> encryptHook({
  String uid = 'encryption:encrypt',
  required String key,
  EncryptionAlgorithm algorithm = EncryptionAlgorithm.cbc,
  List<String> events = const ['write', 'put'],
  HiPhase phase = HiPhase.pre,
});

HiHook<dynamic, dynamic> decryptHook({
  String uid = 'encryption:decrypt',
  required String key,
  EncryptionAlgorithm algorithm = EncryptionAlgorithm.cbc,
  List<String> events = const ['read', 'get'],
  HiPhase phase = HiPhase.post,
});
```

### Plugin Wrapper Pattern
```dart
// Like Base64Plugin
class EncryptionPlugin {
  final String key;
  final EncryptionAlgorithm algorithm;
  final List<String> writeEvents;
  final List<String> readEvents;

  EncryptionPlugin({
    required this.key,
    this.algorithm = EncryptionAlgorithm.cbc,
    this.writeEvents = const ['write', 'put'],
    this.readEvents = const ['read', 'get'],
  });
  
  /// Auto-generate a new key
  factory EncryptionPlugin.generate({...}) {
    return EncryptionPlugin(key: KeyUtils.generateKey(), ...);
  }

  HiPlugin build() { ... }
  void install(HiEngine engine) => build().install(engine);
}
```

## Data Flow

```
Write:
  User value (String) → encryptHook (pre) → base64(encrypted) → storage

Read:
  Storage → base64 string → decryptHook (post) → User value (String)
```

## Payload Transformation

```dart
// Encrypt hook (write path)
handler: (payload, ctx) {
  final value = payload.value;
  if (value is! String) return const HiContinue();
  
  final encrypted = AesCbc.encrypt(value, keyBytes);
  return HiContinue(
    payload: HiPayload(
      key: payload.key,
      value: base64.encode(encrypted),  // Store as base64 string
      metadata: payload.metadata,
    ),
  );
}

// Decrypt hook (read path)
handler: (payload, ctx) {
  final value = payload.value;
  if (value is! String) return const HiContinue();
  
  final encrypted = base64.decode(value);
  final decrypted = AesCbc.decrypt(encrypted, keyBytes);
  return HiContinue(
    payload: HiPayload(
      key: payload.key,
      value: decrypted,
      metadata: payload.metadata,
    ),
  );
}
```

## Design Decisions

1. **Storage-agnostic**: Works with any HiStore (Hive, SQLite, etc.)
2. **Base64 for storage**: Encrypted bytes stored as base64 strings
3. **String values only**: Only encrypts String payload values
4. **Passthrough for other types**: Non-strings pass through unchanged
