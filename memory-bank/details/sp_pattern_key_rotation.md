# Key Rotation Pattern

## Overview

Key rotation is the process of generating a new encryption key when the current key becomes invalid or compromised. This pattern leverages the `onDecryptFailure` handler to trigger automatic rotation.

## Key Rotation Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. TRIGGER: Decryption failure detected                    │
│     - Wrong key loaded                                       │
│     - Key corrupted in storage                               │
│     - Simulated key loss (testing)                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  2. onDecryptFailure handler invoked                        │
│     → Checks if autoRotate is enabled                        │
│     → Logs the failure                                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  3. rotateKey() called                                       │
│     a. Generate new key: KeyUtils.generateKey()              │
│     b. Clear all encrypted data: hive.clear()                │
│        (Cannot decrypt with new key anyway)                  │
│     c. Store new key: secureStorage.write(key, newKey)       │
│     d. Dispose old HHive instance                            │
│     e. Create new HHive with new EncryptionPlugin            │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Application continues with fresh encryption              │
│     - New key active                                         │
│     - Storage cleared (starts fresh)                         │
│     - Ready for new encrypted writes                         │
└─────────────────────────────────────────────────────────────┘
```

## Implementation

### EncryptionService (example app)

```dart
class EncryptionService extends ChangeNotifier {
  HHive? _hive;
  String? _currentKey;
  bool autoRotate = true;
  int rotationCount = 0;
  int successCount = 0;
  int failureCount = 0;

  /// Initialize with existing or new key
  Future<void> initialize() async {
    _currentKey = await _loadOrGenerateKey();
    await _createHive();
  }

  /// Called by onDecryptFailure handler
  void _onDecryptFailure(String? key, Object error) {
    failureCount++;
    _log(LogLevel.error, 'Decrypt failed: $error');
    
    if (autoRotate) {
      rotateKey();
    }
  }

  /// Called by onDecryptSuccess handler
  void _onDecryptSuccess(String? key, dynamic value) {
    successCount++;
    _log(LogLevel.info, 'Decrypted: $key');
  }

  /// Rotate to new key
  Future<void> rotateKey() async {
    rotationCount++;
    _log(LogLevel.warning, 'Rotating key (rotation #$rotationCount)');

    // 1. Generate new key
    final newKey = KeyUtils.generateKey();

    // 2. Clear all data (can't decrypt with new key)
    await _hive?.clear();

    // 3. Store new key securely
    await _secureStorage.write(key: 'encryption_key', value: newKey);
    _currentKey = newKey;

    // 4. Reinitialize with new key
    await _reinitialize();

    _log(LogLevel.info, 'Key rotation complete');
    notifyListeners();
  }

  /// Reinitialize HHive with current key
  Future<void> _reinitialize() async {
    await _hive?.dispose();
    await _createHive();
  }

  /// Create HHive with EncryptionPlugin
  Future<void> _createHive() async {
    final plugin = EncryptionPlugin(
      key: _currentKey!,
      onDecryptSuccess: [_onDecryptSuccess],
      onDecryptFailure: [_onDecryptFailure],
    );

    _hive = await HHive.create(
      directory: await _getDirectory(),
      boxName: 'encrypted_data',
      plugins: [plugin.build()],
    );
  }
}
```

## Testing Key Rotation

### Simulate Key Loss

```dart
/// Simulate losing the encryption key
Future<void> simulateKeyLoss() async {
  _log(LogLevel.warning, 'Simulating key loss...');

  // Store a random (wrong) key
  final wrongKey = KeyUtils.generateKey();
  await _secureStorage.write(key: 'encryption_key', value: wrongKey);

  // Reinitialize with wrong key
  await _reinitialize();

  // Next read will fail and trigger rotation (if autoRotate enabled)
  _log(LogLevel.info, 'Wrong key loaded - next read will fail');
}
```

### Manual Rotation Test

```dart
void _testKeyRotation() async {
  // Write data
  await service.write('test', 'value');
  
  // Simulate key loss
  await service.simulateKeyLoss();
  
  // Try to read - will fail and trigger rotation
  final value = await service.read('test');
  // value is null (data was cleared during rotation)
  
  // Verify new key is active
  await service.write('test', 'new-value');
  final newValue = await service.read('test');
  assert(newValue == 'new-value');
}
```

## Trade-offs

### Data Loss vs Security

**Key rotation clears all data** because:
- Cannot decrypt existing data with new key
- Cannot migrate data (would need old key)
- Clean slate prevents security gaps

For applications that need data preservation:
- Implement backup before rotation
- Use key versioning (multiple keys)
- Store old key securely for migration

### When to Rotate

| Scenario | Auto-Rotate? | Manual Rotate? |
|----------|--------------|----------------|
| Decrypt failure | ✅ | - |
| Scheduled (time-based) | - | ✅ |
| User request | - | ✅ |
| Security incident | - | ✅ |
| App reinstall | ✅ | - |

## Example UI Controls

```dart
// Auto-rotate toggle
SwitchListTile(
  title: Text('Auto-rotate on failure'),
  value: service.autoRotate,
  onChanged: (v) => service.autoRotate = v,
),

// Manual rotation button
ElevatedButton(
  onPressed: service.rotateKey,
  child: Text('Rotate Key Now'),
),

// Simulate failure button (testing)
OutlinedButton(
  onPressed: service.simulateKeyLoss,
  child: Text('Simulate Key Loss'),
),
```

## Statistics

The example app tracks:

| Metric | Description |
|--------|-------------|
| Rotation Count | Number of key rotations |
| Success Count | Successful decryptions |
| Failure Count | Failed decryptions |

```dart
Text('Rotations: ${service.rotationCount}'),
Text('Successes: ${service.successCount}'),
Text('Failures: ${service.failureCount}'),
```
