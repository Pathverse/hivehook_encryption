# Project Brief: HiveHook Encryption

## Overview
HiveHook Encryption is a **hihook encryption plugin** providing AES-256 encryption hooks. It follows the same pattern as `Base64Plugin` - a storage-agnostic plugin that works with any hihook-based storage adapter.

## Core Purpose
Provide a **hihook plugin** that:
1. Works with pure Dart (no Flutter dependency)
2. Provides AES-256-CBC and AES-256-GCM encryption/decryption
3. Offers simple key management
4. Integrates with hihook's plugin system (like Base64Plugin)

## Relationship to Other Packages

```
┌─────────────────────────────────────────────────────────────┐
│                    HiHook (abstract)                         │
│              Storage-agnostic hook framework                 │
│  ┌──────────┐ ┌──────────┐ ┌───────────────────────────┐    │
│  │Base64Plg│  │ TTLPlug  │  │ EncryptionPlugin (this)  │    │
│  └──────────┘ └──────────┘ └───────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  HiveHook (Hive implementation)                              │
│  - HBoxStore implements HiStore                              │
│  - HHive facade uses HiEngine                                │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  PVCache (Flutter caching layer)                             │
│  - Uses hivehook + this plugin                               │
│  - Adds SecureStorage key management                         │
└─────────────────────────────────────────────────────────────┘
```

## Key Goals

### 1. Follow hihook Plugin Pattern
- Pattern: Like `Base64Plugin` - factory creates `HiPlugin`
- Transform `payload.value` on write/read events
- Storage-agnostic: works with any `HiStore` implementation

### 2. Pure Dart
- No Flutter dependencies
- Works in CLI, server, and Flutter projects
- Cross-platform via PointyCastle

### 3. HiHook Integration
- `encryptHook()` / `decryptHook()` factory functions
- `EncryptionPlugin` class with configurable options
- Composable with other hihook plugins (TTL, LRU, Base64)

## Key Requirements

### Encryption System
- **Algorithms**: AES-256-CBC (default) and AES-256-GCM (authenticated)
- **IV/Nonce Handling**: Random IV/nonce prepended to ciphertext
- **Key Size**: 32 bytes (256 bits), base64 encoded for API

### Key Management (Simple)
- Accept key via constructor (base64 string)
- Optional: Generate key if none provided
- No secure storage (user handles persistence)
- No rotation strategies (user handles rotation)

### API Design (Following Base64Plugin pattern)
```dart
// Plugin-based installation (like Base64Plugin)
final engine = HiEngine();
EncryptionPlugin(key: myBase64Key).install(engine);

// With options
EncryptionPlugin(
  key: myKey,
  algorithm: EncryptionAlgorithm.gcm,  // or .cbc (default)
  writeEvents: ['write', 'put'],
  readEvents: ['read', 'get'],
).install(engine);

// Auto-generate key
final plugin = EncryptionPlugin.generate();
final key = plugin.key; // User stores this securely
```

## What This Package Does NOT Do
- ❌ Store keys (user responsibility)
- ❌ Key rotation strategies
- ❌ Flutter Secure Storage integration

## Success Criteria
1. Follows hihook plugin pattern (like Base64Plugin)
2. Correct AES-256-CBC and AES-256-GCM encryption
3. Works with any HiStore implementation
4. No Flutter dependencies
5. Comprehensive test coverage

## Dependencies
- **hihook**: Hook framework and plugin interface
- **pointycastle**: Cryptographic operations
- **pointycastle**: AES encryption implementation
