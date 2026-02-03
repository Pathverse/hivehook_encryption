import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hivehook/hivehook.dart';
import 'package:hivehook_encryption/hivehook_encryption.dart';

const _keyStorageKey = 'hivehook_encryption_demo_key';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EncryptionDemoApp());
}

class EncryptionDemoApp extends StatelessWidget {
  const EncryptionDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Encryption Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const EncryptionDemoPage(),
    );
  }
}

class EncryptionDemoPage extends StatefulWidget {
  const EncryptionDemoPage({super.key});

  @override
  State<EncryptionDemoPage> createState() => _EncryptionDemoPageState();
}

class _EncryptionDemoPageState extends State<EncryptionDemoPage> {
  final _secureStorage = const FlutterSecureStorage();
  final _logs = <LogEntry>[];
  final _scrollController = ScrollController();

  HHive? _hive;
  String? _currentKey;
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _log(String message, {LogLevel level = LogLevel.info}) {
    setState(() {
      _logs.add(LogEntry(message, level));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    _log('━━━ Initializing ━━━', level: LogLevel.header);

    try {
      // 1. Try to load existing key from secure storage
      _currentKey = await _secureStorage.read(key: _keyStorageKey);

      if (_currentKey != null) {
        _log('Loaded existing key from secure storage');
        _log('Key: ${_currentKey!.substring(0, 20)}...', level: LogLevel.data);
      } else {
        // Generate new key
        final plugin = EncryptionPlugin.generate();
        _currentKey = plugin.key;
        await _secureStorage.write(key: _keyStorageKey, value: _currentKey);
        _log('Generated new key and stored securely');
        _log('Key: ${_currentKey!.substring(0, 20)}...', level: LogLevel.data);
      }

      // 2. Create encryption plugin with the key
      final plugin = EncryptionPlugin(key: _currentKey!);

      // 3. Register and initialize HiveHook
      final envId = 'encrypted_demo';

      // Register config (may already exist from previous init)
      try {
        HHiveCore.register(HiveConfig(
          env: envId,
          boxCollectionName: 'encryption_demo',
          withMeta: true,
          hooks: plugin.build().hooks,
        ));
      } catch (e) {
        _log('Env already registered, reusing...', level: LogLevel.warning);
      }

      if (!HHiveCore.isInitialized) {
        await HHiveCore.initialize();
      }

      _hive = await HHive.create(envId);
      _isInitialized = true;

      _log('✓ HiveHook initialized with encryption', level: LogLevel.success);
    } catch (e) {
      _log('✗ Initialization failed: $e', level: LogLevel.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _writeData() async {
    if (!_isInitialized || _hive == null) {
      _log('Not initialized!', level: LogLevel.error);
      return;
    }

    _log('\n━━━ Write Operation ━━━', level: LogLevel.header);

    try {
      const testData = {
        'secret-message': 'Hello, encrypted world!',
        'password': 'super-secret-123',
        'api-key': 'sk_live_abc123xyz',
      };

      for (final entry in testData.entries) {
        await _hive!.put(entry.key, entry.value);
        _log('Stored "${entry.key}": "${entry.value}"');
      }

      _log('✓ All data written (encrypted)', level: LogLevel.success);
    } catch (e) {
      _log('✗ Write failed: $e', level: LogLevel.error);
    }
  }

  Future<void> _readData() async {
    if (!_isInitialized || _hive == null) {
      _log('Not initialized!', level: LogLevel.error);
      return;
    }

    _log('\n━━━ Read Operation ━━━', level: LogLevel.header);

    try {
      final keys = ['secret-message', 'password', 'api-key'];

      for (final key in keys) {
        // Read raw (encrypted)
        final rawValue = await _hive!.store.get(key);
        // Read through HHive (decrypted)
        final decryptedValue = await _hive!.get<String>(key);

        _log('Key: "$key"', level: LogLevel.data);
        _log('  Raw: ${rawValue ?? "(null)"}');
        _log('  Decrypted: ${decryptedValue ?? "(null)"}',
            level: decryptedValue != null ? LogLevel.success : LogLevel.warning);
      }
    } catch (e) {
      _log('✗ Read failed: $e', level: LogLevel.error);
    }
  }

  Future<void> _showRawStorage() async {
    if (!_isInitialized || _hive == null) {
      _log('Not initialized!', level: LogLevel.error);
      return;
    }

    _log('\n━━━ Raw Storage Contents ━━━', level: LogLevel.header);

    try {
      final allKeys = await _hive!.keys().toList();
      _log('Keys found: ${allKeys.length}', level: LogLevel.data);

      for (final key in allKeys) {
        final rawValue = await _hive!.store.get(key);
        _log('$key: ${rawValue ?? "(null)"}');
      }
    } catch (e) {
      _log('✗ Failed: $e', level: LogLevel.error);
    }
  }

  Future<void> _corruptKey() async {
    _log('\n━━━ Corrupting Key ━━━', level: LogLevel.header);

    try {
      // Read current key and corrupt it
      final current = await _secureStorage.read(key: _keyStorageKey);
      if (current == null) {
        _log('No key found to corrupt', level: LogLevel.warning);
        return;
      }

      // Corrupt by changing a few characters
      final corrupted = 'CORRUPT${current.substring(7)}';
      await _secureStorage.write(key: _keyStorageKey, value: corrupted);

      _log('Original: ${current.substring(0, 20)}...', level: LogLevel.data);
      _log('Corrupted: ${corrupted.substring(0, 20)}...', level: LogLevel.warning);
      _log('✓ Key corrupted in secure storage', level: LogLevel.success);
      _log('Restart app or re-initialize to see effect', level: LogLevel.info);

      _isInitialized = false;
      _hive = null;
      _currentKey = null;
    } catch (e) {
      _log('✗ Corrupt failed: $e', level: LogLevel.error);
    }
  }

  Future<void> _deleteKey() async {
    _log('\n━━━ Deleting Key ━━━', level: LogLevel.header);

    try {
      await _secureStorage.delete(key: _keyStorageKey);
      _log('✓ Key deleted from secure storage', level: LogLevel.success);
      _log('Re-initialize to generate a new key', level: LogLevel.info);
      _log('⚠ Previous data will be unreadable!', level: LogLevel.warning);

      _isInitialized = false;
      _hive = null;
      _currentKey = null;
    } catch (e) {
      _log('✗ Delete failed: $e', level: LogLevel.error);
    }
  }

  Future<void> _showKeyStatus() async {
    _log('\n━━━ Key Status ━━━', level: LogLevel.header);

    try {
      final key = await _secureStorage.read(key: _keyStorageKey);
      if (key == null) {
        _log('No key in secure storage', level: LogLevel.warning);
      } else {
        _log('Key exists: ${key.substring(0, 20)}...', level: LogLevel.data);
        _log('Length: ${key.length} characters', level: LogLevel.data);

        // Validate key format
        try {
          KeyUtils.validateKey(key);
          _log('✓ Key format is valid', level: LogLevel.success);
        } catch (e) {
          _log('✗ Key format invalid: $e', level: LogLevel.error);
        }
      }

      _log('Initialized: $_isInitialized', level: LogLevel.data);
    } catch (e) {
      _log('✗ Status check failed: $e', level: LogLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encryption Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _isInitialized ? Colors.green.shade900 : Colors.orange.shade900,
            child: Row(
              children: [
                Icon(
                  _isInitialized ? Icons.lock : Icons.lock_open,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _isInitialized ? 'Initialized' : 'Not Initialized',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_currentKey != null)
                  Text(
                    'Key: ${_currentKey!.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _ActionButton(
                  icon: Icons.play_arrow,
                  label: 'Initialize',
                  color: Colors.green,
                  onPressed: _isLoading ? null : _initialize,
                ),
                _ActionButton(
                  icon: Icons.edit,
                  label: 'Write',
                  color: Colors.blue,
                  onPressed: !_isInitialized ? null : _writeData,
                ),
                _ActionButton(
                  icon: Icons.visibility,
                  label: 'Read',
                  color: Colors.teal,
                  onPressed: !_isInitialized ? null : _readData,
                ),
                _ActionButton(
                  icon: Icons.storage,
                  label: 'Raw',
                  color: Colors.purple,
                  onPressed: !_isInitialized ? null : _showRawStorage,
                ),
                _ActionButton(
                  icon: Icons.key,
                  label: 'Key Status',
                  color: Colors.amber,
                  onPressed: _showKeyStatus,
                ),
                _ActionButton(
                  icon: Icons.warning,
                  label: 'Corrupt Key',
                  color: Colors.orange,
                  onPressed: _corruptKey,
                ),
                _ActionButton(
                  icon: Icons.delete_forever,
                  label: 'Delete Key',
                  color: Colors.red,
                  onPressed: _deleteKey,
                ),
              ],
            ),
          ),

          const Divider(),

          // Log output
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      log.message,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: log.level.color,
                        fontWeight: log.level == LogLevel.header
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color : Colors.grey.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
    );
  }
}

enum LogLevel { info, data, success, warning, error, header }

extension on LogLevel {
  Color get color => switch (this) {
        LogLevel.info => Colors.white70,
        LogLevel.data => Colors.cyan,
        LogLevel.success => Colors.greenAccent,
        LogLevel.warning => Colors.orange,
        LogLevel.error => Colors.redAccent,
        LogLevel.header => Colors.white,
      };
}

class LogEntry {
  final String message;
  final LogLevel level;

  LogEntry(this.message, this.level);
}
