import 'package:flutter/material.dart';

import 'src/key_rotation_demo_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KeyRotationDemoApp());
}

/// Demo app showcasing automatic key rotation with hivehook_encryption.
///
/// Features demonstrated:
/// - Automatic key rotation when decryption fails
/// - onDecryptSuccess / onDecryptFailure handlers
/// - Secure key storage with flutter_secure_storage
/// - Clear data on key rotation (can't decrypt with new key anyway)
class KeyRotationDemoApp extends StatelessWidget {
  const KeyRotationDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Key Rotation Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const KeyRotationDemoPage(),
    );
  }
}

