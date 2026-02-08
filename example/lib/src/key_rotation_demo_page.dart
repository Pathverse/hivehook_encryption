import 'package:flutter/material.dart';

import 'encryption_service.dart';
import 'log_entry.dart';
import 'widgets/widgets.dart';

/// Main demo page showcasing automatic key rotation
class KeyRotationDemoPage extends StatefulWidget {
  const KeyRotationDemoPage({super.key});

  @override
  State<KeyRotationDemoPage> createState() => _KeyRotationDemoPageState();
}

class _KeyRotationDemoPageState extends State<KeyRotationDemoPage> {
  final _logs = <LogEntry>[];
  final _scrollController = ScrollController();
  late final EncryptionService _service;

  @override
  void initState() {
    super.initState();
    _service = EncryptionService(log: _log);
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    setState(() {});
  }

  void _log(String message, {LogLevel level = LogLevel.info}) {
    setState(() {
      _logs.add(LogEntry(message, level));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔄 Key Rotation Demo'),
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
          StatusBar(
            isInitialized: _service.isInitialized,
            currentKey: _service.currentKey,
            rotationCount: _service.keyRotationCount,
            successCount: _service.decryptSuccessCount,
            failureCount: _service.decryptFailureCount,
          ),

          // Auto-rotate toggle
          SwitchListTile(
            title: const Text('Auto-rotate on decrypt failure'),
            subtitle: Text(
              _service.autoRotateEnabled
                  ? 'Will automatically rotate key and clear data'
                  : 'Manual key management',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            value: _service.autoRotateEnabled,
            onChanged: (v) => _service.autoRotateEnabled = v,
            activeTrackColor: Colors.green,
          ),

          const Divider(height: 1),

          // Action buttons
          _buildActionButtons(),

          const Divider(height: 1),

          // Log output
          Expanded(
            child: LogView(
              logs: _logs,
              controller: _scrollController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isReady = _service.isInitialized && !_service.isLoading;
    final canInit = !_service.isLoading;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          ActionButton(
            icon: Icons.play_arrow,
            label: 'Initialize',
            color: Colors.green,
            onPressed: canInit ? _service.initialize : null,
          ),
          ActionButton(
            icon: Icons.save,
            label: 'Write Data',
            color: Colors.blue,
            onPressed: isReady ? _service.writeTestData : null,
          ),
          ActionButton(
            icon: Icons.visibility,
            label: 'Read Data',
            color: Colors.teal,
            onPressed: isReady ? _service.readAllData : null,
          ),
          ActionButton(
            icon: Icons.sync,
            label: 'Rotate Key',
            color: Colors.purple,
            onPressed: isReady ? _service.rotateKey : null,
          ),
          ActionButton(
            icon: Icons.warning,
            label: 'Simulate Key Loss',
            color: Colors.orange,
            onPressed: isReady ? _service.simulateKeyLoss : null,
          ),
          ActionButton(
            icon: Icons.info,
            label: 'Status',
            color: Colors.amber,
            onPressed: canInit ? _service.showStatus : null,
          ),
          ActionButton(
            icon: Icons.delete_forever,
            label: 'Clear All',
            color: Colors.red,
            onPressed: canInit ? _service.clearAll : null,
          ),
        ],
      ),
    );
  }
}
