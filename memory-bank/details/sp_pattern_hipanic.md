# HiPanic Behavior

## Overview

HiPanic is the error-handling mechanism in hihook. **Critical**: HiPanic does NOT throw an exception - it returns a result object that the caller must check.

## How HiPanic Works

### In hihook Source

```dart
// From hihook/lib/src/hi_result.dart
sealed class HiResult<T> {
  const HiResult();
  
  bool get isPanic;
  bool get isContinue;
  
  HiPanic<T> asPanic();
  HiContinue<T> asContinue();
}

class HiPanic<T> extends HiResult<T> {
  final String message;
  final Object? cause;
  
  const HiPanic({required this.message, this.cause});
  
  @override
  bool get isPanic => true;
  
  @override
  bool get isContinue => false;
}
```

### In HiEngine

```dart
// From hihook/lib/src/hi_engine.dart
Future<HiResult<T>> execute<T>(HiPayload payload, HiContext ctx) async {
  for (final hook in hooks) {
    final result = await hook.handler(payload, ctx);
    
    // HiPanic is RETURNED, not thrown
    if (result.isPanic) {
      return result; // Engine returns the panic to caller
    }
    
    // Continue with next hook
    if (result.isContinue) {
      payload = result.asContinue().payload ?? payload;
    }
  }
  return HiContinue(payload: payload);
}
```

## Using HiPanic in EncryptionPlugin

### Decrypt Hook Returns HiPanic on Failure

```dart
HiHook _buildDecryptHook() {
  return HiHook(
    uid: 'encryption:decrypt',
    events: readEvents.toSet(),
    phase: HiPhase.post,
    handler: (payload, ctx) async {
      try {
        final decrypted = _decrypt(payload.value as String);
        return HiContinue(payload: payload.copyWith(value: decrypted));
      } catch (e) {
        // Call failure handlers BEFORE returning panic
        for (final handler in onDecryptFailure) {
          handler(payload.key, e);
        }
        
        // Return HiPanic - NOT throw
        return HiPanic(message: 'Decryption failed: $e', cause: e);
      }
    },
  );
}
```

### Caller Receives HiPanic

```dart
// In HHive (hivehook)
Future<T?> get<T>(String key) async {
  final result = await engine.execute(
    HiPayload(key: key, event: 'read'),
    context,
  );
  
  if (result.isPanic) {
    // HHive handles panic - may throw or return null
    final panic = result.asPanic();
    throw HiveHookException(panic.message);
    // OR: return null;
  }
  
  return result.asContinue().payload?.value as T?;
}
```

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  User: hive.get<String>('secret')                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  HHive: engine.execute(HiPayload(key: 'secret', ...))       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  HiEngine: Runs hooks in order                              │
│    └── decryptHook: Decrypt fails (wrong key)               │
│         └── return HiPanic(message: 'Decryption failed')    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  HiEngine: Returns HiPanic result (NOT throw)               │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  HHive: Checks result.isPanic                               │
│    └── throw HiveHookException(panic.message)               │
│        OR return null                                       │
│        (depends on HHive implementation)                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  User: Catches exception or handles null                    │
└─────────────────────────────────────────────────────────────┘
```

## Key Points

| Aspect | Behavior |
|--------|----------|
| HiPanic in hook | Returns result, doesn't throw |
| HiEngine behavior | Returns HiPanic to caller, stops hook chain |
| HHive behavior | May throw exception or return null |
| Handler timing | onDecryptFailure called BEFORE returning HiPanic |

## Why This Design?

1. **Explicit error handling**: Caller must check result type
2. **No exception magic**: Control flow is visible
3. **Handler opportunity**: Can run handlers before panic propagates
4. **Composability**: Hooks can decide how to handle errors

## Testing HiPanic

```dart
test('decrypt with wrong key returns HiPanic', () async {
  final plugin = EncryptionPlugin(key: wrongKey);
  final engine = HiEngine();
  plugin.install(engine);
  
  final result = await engine.execute(
    HiPayload(key: 'test', value: encryptedValue, event: 'read'),
    HiContext(),
  );
  
  expect(result.isPanic, isTrue);
  expect(result.asPanic().message, contains('Decryption failed'));
});
```
