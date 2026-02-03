# Technical Context: HiveHook Encryption

## Technology Stack

### Core Dependencies
- **hihook**: ^0.1.0 - Abstract hook framework
- **pointycastle**: ^3.9.1 - AES encryption (pure Dart)

### Development Dependencies
- **test**: ^1.28.0 - Testing framework
- **lints**: ^5.0.0 - Dart linting rules

### What We DON'T Use
- ❌ flutter_secure_storage (Flutter dependency)
- ❌ Flutter SDK
- ❌ Any Flutter packages
- ❌ hivehook (we integrate at hihook level)

## Project Structure

```
hivehook_encryption/
├── lib/
│   ├── hivehook_encryption.dart    # Main export
│   └── src/
│       ├── exceptions.dart         # Exception types
│       ├── key_utils.dart          # Key generation utilities
│       ├── algorithms/
│       │   ├── aes_cbc.dart        # AES-256-CBC
│       │   └── aes_gcm.dart        # AES-256-GCM
│       ├── encryption_hook.dart    # Hook factory functions
│       └── encryption_plugin.dart  # Plugin wrapper class
├── test/
│   ├── exceptions_test.dart
│   ├── key_utils_test.dart
│   ├── algorithms/
│   │   ├── aes_cbc_test.dart
│   │   └── aes_gcm_test.dart
│   ├── encryption_hook_test.dart
│   └── encryption_plugin_test.dart
├── memory-bank/
├── pubspec.yaml
├── analysis_options.yaml
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Key Technical Decisions

### 1. Pure Dart Over Flutter
**Chosen**: No Flutter dependencies
**Reasoning**:
- Enables use in CLI tools, servers, and Flutter
- PVCache adds Flutter-specific features on top
- Simpler dependency tree

### 2. PointyCastle for Encryption
**Chosen**: pointycastle package
**Alternative considered**: encrypt, cryptography
**Reasoning**:
- Pure Dart implementation
- Well-tested and mature
- Full AES support with all modes
- No native dependencies

### 3. AES-256-CBC Mode
**Chosen**: CBC with random IV
**Alternative considered**: GCM, CTR
**Reasoning**:
- Widely compatible
- Well understood security properties
- IV can be prepended to ciphertext
- PKCS7 padding is standard

### 4. Key Provided by User
**Chosen**: User provides or generates key, we don't store
**Alternative considered**: Built-in key storage
**Reasoning**:
- Storage mechanisms vary by platform
- User knows their security requirements
- Simpler, single-responsibility design
- PVCache adds storage layer for Flutter

## Encryption Details

### Algorithm Specification
```
Cipher: AES-256-CBC
Key Size: 256 bits (32 bytes)
IV Size: 128 bits (16 bytes)
Padding: PKCS7
```

### Data Format
```
┌──────────────────────────────────────────────────────┐
│ Encrypted Data Format (stored as base64):            │
├──────────────────┬───────────────────────────────────┤
│ IV (16 bytes)    │ Encrypted Data (variable length)  │
└──────────────────┴───────────────────────────────────┘
```

### Flow
```
Encrypt:
  plaintext → UTF-8 bytes → AES-CBC encrypt → prepend IV → base64 → stored

Decrypt:
  stored → base64 decode → extract IV → AES-CBC decrypt → UTF-8 string
```

## HiveHook Integration

### Hook Type
Uses `TerminalSerializationHook` - runs last in serialization chain:
```dart
class _EncryptionTerminalHook extends TerminalSerializationHook {
  @override
  Future<String> serialize(String value, HHCtxI ctx);
  
  @override
  Future<String> deserialize(String value, HHCtxI ctx);
}
```

### Plugin Return
Returns `HHPlugin` with the hook:
```dart
HHPlugin(terminalSerializationHooks: [hook])
```

## Development Setup

### Prerequisites
```bash
dart pub get
```

### Running Tests
```bash
dart test
```

### Linting
```bash
dart analyze
```

## Error Handling

### Decryption Failures
When decryption fails (wrong key, corrupted data):
- Throw `EncryptionException` with clear message
- Include original error as cause
- Do not expose key material in error

### Invalid Key
When key is wrong size or null when required:
- Throw `ArgumentError` at plugin creation time
- Fail fast, not at first use
