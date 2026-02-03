# Product Context: HiveHook Encryption

## Why This Exists

### Problem Statement
HiveHook provides a powerful hook system for Hive, but lacks built-in encryption. While PVCache offers encryption, it:
- Requires Flutter (flutter_secure_storage)
- Has complex key rotation strategies
- Bundles many convenience features

**Many users need**: Simple encryption that works in pure Dart projects.

### Solution
HiveHook Encryption provides the encryption primitives without the Flutter dependencies or complexity. It's the encryption layer that:
- PVCache can use internally (with its own key storage)
- CLI tools can use (with file-based key storage)
- Server apps can use (with environment-based keys)

## How It Should Work

### User Experience Goals

#### 1. Simple Setup
```dart
// User manages their own key
final key = loadKeyFromSecureStorage(); // User's responsibility
final plugin = createEncryptedHook(key: key);

final hive = await HHive.createInstance(
  HHConfig('encrypted_box', plugins: [plugin]),
);
```

#### 2. Transparent Encryption
```dart
// Data is automatically encrypted on write
await hive.put('secret', 'my-password');

// Data is automatically decrypted on read
final value = await hive.get<String>('secret'); // 'my-password'

// Stored value is encrypted (base64-encoded ciphertext)
```

#### 3. Key Generation Helper
```dart
// For users who need to generate a key
final plugin = createEncryptedHook(autoGenerateKey: true);
final key = plugin.key; // Uint8List - user must store this securely

// Next app launch - user loads their stored key
final key = loadMyKey();
final plugin = createEncryptedHook(key: key);
```

## Target Users

### 1. Dart CLI/Server Developers
- Need encryption without Flutter
- Store keys in environment variables or config files
- Simple use cases

### 2. PVCache (Internal)
- Uses this package for encryption primitives
- Adds Flutter Secure Storage on top
- Adds key rotation strategies

### 3. Flutter Developers (Direct Use)
- Want more control than PVCache offers
- Handle key storage themselves
- Custom rotation/migration logic

## User Flow

```
┌─────────────────────────────────────────┐
│ 1. User obtains/generates AES key       │
│    - Load from env/file/secure storage  │
│    - OR let package generate one        │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│ 2. Create encrypted hook plugin         │
│    createEncryptedHook(key: key)        │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│ 3. Add to HHConfig plugins              │
│    HHConfig('box', plugins: [plugin])   │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│ 4. Use HHive normally                   │
│    Encryption/decryption is automatic   │
└─────────────────────────────────────────┘
```

## Constraints

### Must Have
- Pure Dart (no Flutter imports)
- Works with HiveHook's TerminalSerializationHook
- AES-256-CBC encryption
- Clear error messages for decryption failures

### Nice to Have
- Multiple cipher support (future)
- Compression before encryption (future)

### Will Not Have
- Key storage (user responsibility)
- Key rotation logic
- Flutter dependencies
