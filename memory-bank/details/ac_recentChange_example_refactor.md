# Recent Change: Example App Refactoring

## Date: 2026-02-07

## Summary

Refactored the example app from a single `main.dart` file into a modular multi-file structure demonstrating automatic key rotation.

## Before (Single File)

```
example/lib/
└── main.dart          # ~300 lines, everything in one file
```

## After (Multi-File Structure)

```
example/lib/
├── main.dart                        # Entry point (~20 lines)
└── src/
    ├── log_entry.dart               # LogEntry model, LogLevel enum
    ├── encryption_service.dart      # Core logic with ChangeNotifier
    ├── key_rotation_demo_page.dart  # Main UI page
    └── widgets/
        ├── widgets.dart             # Barrel export
        ├── action_button.dart       # Styled button widget
        ├── log_view.dart            # Scrollable log output
        └── status_bar.dart          # Stats display bar
```

## File Responsibilities

### main.dart
```dart
import 'src/key_rotation_demo_page.dart';

void main() {
  runApp(MaterialApp(home: KeyRotationDemoPage()));
}
```

### log_entry.dart
```dart
enum LogLevel { info, warning, error, success }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  
  LogEntry(this.level, this.message) : timestamp = DateTime.now();
}
```

### encryption_service.dart
Core business logic:
- Key storage/loading with FlutterSecureStorage
- HHive lifecycle management
- EncryptionPlugin with handlers
- Key rotation logic
- Operation logging

### key_rotation_demo_page.dart
UI composition:
- Uses ListenableBuilder for EncryptionService
- StatusBar for rotation/success/failure counts
- ActionButtons for write/read/rotate/simulate
- LogView for timestamped output

### widgets/
Reusable UI components:
- **ActionButton**: Material 3 styled button with icon
- **StatusBar**: Horizontal stats with rotation count, successes, failures
- **LogView**: ListView.builder with colored log entries

## Deprecation Fixes

During refactoring, fixed Flutter deprecation warnings:

### SwitchListTile.activeColor → activeTrackColor
```dart
// Before
SwitchListTile(activeColor: Colors.green, ...)

// After
SwitchListTile(activeTrackColor: Colors.green, ...)
```

### Color.withOpacity → withValues
```dart
// Before
color.withOpacity(0.1)

// After
color.withValues(alpha: 0.1)
```

## Benefits of Refactoring

| Aspect | Before | After |
|--------|--------|-------|
| Navigation | Scroll through 300 lines | Jump to relevant file |
| Testing | Hard to test in isolation | Can unit test EncryptionService |
| Reuse | Copy-paste | Import widgets |
| Maintenance | Find code in monolith | Clear file boundaries |
| Collaboration | Merge conflicts | Independent files |

## Key Patterns Demonstrated

1. **ChangeNotifier + ListenableBuilder**
   - EncryptionService extends ChangeNotifier
   - UI rebuilds on notifyListeners()

2. **Barrel Exports**
   - widgets/widgets.dart exports all widgets
   - Single import for consumers

3. **Separation of Concerns**
   - Service: Business logic
   - Page: Composition
   - Widgets: Presentation

## Testing the Example

```bash
cd example
flutter run -d chrome
```

### Test Actions

1. **Write**: Creates encrypted entry
2. **Read**: Decrypts and displays (uses cache after first read)
3. **Rotate Key**: Manually triggers key rotation
4. **Simulate Key Loss**: Loads wrong key, next read triggers rotation
5. **Auto-rotate Toggle**: Enable/disable automatic rotation on failure
