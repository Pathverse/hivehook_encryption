import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hivehook/hivehook.dart';
import 'package:hivehook_encryption/hivehook_encryption.dart';

import 'log_entry.dart';

const _keyStorageKey = 'hivehook_encryption_demo_key';
const _envId = 'encrypted_demo';

/// Callback for logging messages
typedef LogCallback = void Function(String message, {LogLevel level});

/// Service that manages encryption, key rotation, and HiveHook integration.
///
/// This demonstrates automatic key rotation when decryption fails:
/// 1. On decryption failure, `onDecryptFailure` is called
/// 2. If auto-rotate is enabled, generates new key
/// 3. Clears all encrypted data (can't decrypt with wrong key anyway)
/// 4. Re-initializes with new key
class EncryptionService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage;
  final LogCallback _log;

  HHive? _hive;
  EncryptionPlugin? _plugin;
  String? _currentKey;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _autoRotateEnabled = true;

  int _keyRotationCount = 0;
  int _decryptSuccessCount = 0;
  int _decryptFailureCount = 0;

  final Set<String> _failedKeys = {};

  EncryptionService({
    FlutterSecureStorage? secureStorage,
    required LogCallback log,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _log = log;

  // --- Getters ---

  HHive? get hive => _hive;
  String? get currentKey => _currentKey;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get autoRotateEnabled => _autoRotateEnabled;
  int get keyRotationCount => _keyRotationCount;
  int get decryptSuccessCount => _decryptSuccessCount;
  int get decryptFailureCount => _decryptFailureCount;

  set autoRotateEnabled(bool value) {
    _autoRotateEnabled = value;
    notifyListeners();
  }

  // --- Handlers ---

  void _onDecryptSuccess(String? key, dynamic value) {
    _decryptSuccessCount++;
    _failedKeys.remove(key);
    notifyListeners();
  }

  void _onDecryptFailure(String? key, Object error) {
    _decryptFailureCount++;
    _log('✗ Decryption failed for "$key"', level: LogLevel.error);

    if (key != null) {
      _failedKeys.add(key);
    }

    // Trigger automatic key rotation if enabled
    if (_autoRotateEnabled && _failedKeys.isNotEmpty) {
      _log('⚡ Auto-rotation triggered!', level: LogLevel.warning);
      Future.microtask(() => rotateKey());
    }

    notifyListeners();
  }

  // --- Public Methods ---

  /// Initialize the encryption service
  Future<void> initialize() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    _log('━━━ Initializing ━━━', level: LogLevel.header);

    try {
      // Try to load existing key
      _currentKey = await _secureStorage.read(key: _keyStorageKey);

      if (_currentKey != null) {
        _log('Loaded existing key: ${_currentKey!.substring(0, 12)}...',
            level: LogLevel.data);
      } else {
        _currentKey = KeyUtils.generateKey();
        await _secureStorage.write(key: _keyStorageKey, value: _currentKey);
        _log('Generated new key: ${_currentKey!.substring(0, 12)}...',
            level: LogLevel.data);
      }

      // Create encryption plugin with handlers
      _plugin = EncryptionPlugin(
        key: _currentKey!,
        onDecryptSuccess: [_onDecryptSuccess],
        onDecryptFailure: [_onDecryptFailure],
      );

      // Initialize HiveHook
      if (!HHiveCore.isInitialized) {
        HHiveCore.register(HiveConfig(
          env: _envId,
          boxCollectionName: 'encryption_demo',
          withMeta: true,
          hooks: _plugin!.build().hooks,
        ));
        await HHiveCore.initialize();
      }

      _hive = await HHive.createFromConfig(HiveConfig(
        env: _envId,
        boxCollectionName: 'encryption_demo',
        withMeta: true,
        hooks: _plugin!.build().hooks,
      ));

      _isInitialized = true;
      _log(
          '✓ Initialized with auto-rotation ${_autoRotateEnabled ? "ON" : "OFF"}',
          level: LogLevel.success);
    } catch (e) {
      _log('✗ Initialization failed: $e', level: LogLevel.error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Rotate to a new encryption key and clear all data
  Future<void> rotateKey() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    _log('\n━━━ 🔄 KEY ROTATION ━━━', level: LogLevel.header);

    try {
      // Generate new key
      final newKey = KeyUtils.generateKey();
      _log('Generated new key: ${newKey.substring(0, 12)}...',
          level: LogLevel.data);

      // Clear all encrypted data
      if (_hive != null) {
        await _hive!.clear();
        _log('Cleared all encrypted data', level: LogLevel.warning);
      }

      // Store new key securely
      await _secureStorage.write(key: _keyStorageKey, value: newKey);
      _log('Stored new key in secure storage', level: LogLevel.success);

      // Update state
      _currentKey = newKey;
      _failedKeys.clear();
      _plugin?.clearCache();
      _keyRotationCount++;

      // Re-initialize with new key
      await _reinitialize();

      _log('✓ Key rotation complete!', level: LogLevel.success);
    } catch (e) {
      _log('✗ Key rotation failed: $e', level: LogLevel.error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Write test data
  Future<void> writeTestData() async {
    if (!_isInitialized || _hive == null) {
      _log('Not initialized!', level: LogLevel.error);
      return;
    }

    _log('\n━━━ Writing Test Data ━━━', level: LogLevel.header);

    try {
      final testData = {
        'user': {'name': 'Alice', 'email': 'alice@example.com'},
        'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        'settings': {'theme': 'dark', 'notifications': true},
      };

      for (final entry in testData.entries) {
        await _hive!.put(entry.key, entry.value);
        _log('  Stored "${entry.key}"', level: LogLevel.success);
      }

      _log('✓ ${testData.length} items encrypted and stored',
          level: LogLevel.success);
    } catch (e) {
      _log('✗ Write failed: $e', level: LogLevel.error);
    }
  }

  /// Read all stored data
  Future<void> readAllData() async {
    if (!_isInitialized || _hive == null) {
      _log('Not initialized!', level: LogLevel.error);
      return;
    }

    _log('\n━━━ Reading All Data ━━━', level: LogLevel.header);

    final keys = await _hive!.keys().toList();
    if (keys.isEmpty) {
      _log('No data stored', level: LogLevel.warning);
      return;
    }

    _log('Found ${keys.length} keys', level: LogLevel.data);

    for (final key in keys) {
      final value = await _hive!.get(key);
      if (value != null) {
        _log('  $key: $value', level: LogLevel.success);
      } else {
        _log('  $key: (decryption failed or null)', level: LogLevel.warning);
      }
    }
  }

  /// Simulate key loss by replacing with a different key
  Future<void> simulateKeyLoss() async {
    _log('\n━━━ 🔥 Simulating Key Loss ━━━', level: LogLevel.header);

    try {
      final current = await _secureStorage.read(key: _keyStorageKey);
      if (current == null) {
        _log('No key to corrupt', level: LogLevel.warning);
        return;
      }

      // Replace with a different valid key
      final wrongKey = KeyUtils.generateKey();
      await _secureStorage.write(key: _keyStorageKey, value: wrongKey);

      _log('Old key: ${current.substring(0, 12)}...', level: LogLevel.data);
      _log('Wrong key: ${wrongKey.substring(0, 12)}...',
          level: LogLevel.warning);
      _log('✓ Key replaced with wrong key', level: LogLevel.success);
      _log('', level: LogLevel.info);
      _log('Next read will fail → triggering auto-rotation',
          level: LogLevel.info);

      // Re-initialize with the "wrong" key
      _currentKey = wrongKey;
      await _reinitialize();
    } catch (e) {
      _log('✗ Simulation failed: $e', level: LogLevel.error);
    }
  }

  /// Show current status
  Future<void> showStatus() async {
    _log('\n━━━ Status ━━━', level: LogLevel.header);

    final key = await _secureStorage.read(key: _keyStorageKey);
    _log('Key: ${key?.substring(0, 12) ?? "(none)"}...', level: LogLevel.data);
    _log('Auto-rotate: ${_autoRotateEnabled ? "ON" : "OFF"}',
        level: LogLevel.data);
    _log('Rotations: $_keyRotationCount', level: LogLevel.data);
    _log('Decrypt OK: $_decryptSuccessCount', level: LogLevel.success);
    _log('Decrypt FAIL: $_decryptFailureCount', level: LogLevel.error);

    if (_hive != null) {
      final count = await _hive!.keys().length;
      _log('Stored items: $count', level: LogLevel.data);
    }
  }

  /// Clear all data and reset
  Future<void> clearAll() async {
    _log('\n━━━ Clearing All ━━━', level: LogLevel.header);

    await _secureStorage.delete(key: _keyStorageKey);
    if (_hive != null) {
      await _hive!.clear();
    }
    _plugin?.clearCache();

    _isInitialized = false;
    _hive = null;
    _plugin = null;
    _currentKey = null;
    _keyRotationCount = 0;
    _decryptSuccessCount = 0;
    _decryptFailureCount = 0;
    _failedKeys.clear();

    HHive.dispose(_envId);
    notifyListeners();

    _log('✓ All data and keys cleared', level: LogLevel.success);
  }

  // --- Private Methods ---

  Future<void> _reinitialize() async {
    HHive.dispose(_envId);
    _hive = null;

    _plugin = EncryptionPlugin(
      key: _currentKey!,
      onDecryptSuccess: [_onDecryptSuccess],
      onDecryptFailure: [_onDecryptFailure],
    );

    _hive = await HHive.createFromConfig(HiveConfig(
      env: _envId,
      boxCollectionName: 'encryption_demo',
      withMeta: true,
      hooks: _plugin!.build().hooks,
    ));

    _isInitialized = true;
    notifyListeners();
  }
}
