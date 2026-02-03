import 'package:test/test.dart';
import 'package:hivehook_encryption/src/exceptions.dart';

void main() {
  group('EncryptionException', () {
    test('creates with message only', () {
      const exception = EncryptionException('test message');
      expect(exception.message, 'test message');
      expect(exception.cause, isNull);
    });

    test('creates with message and cause', () {
      final cause = Exception('original error');
      final exception = EncryptionException('test message', cause);
      expect(exception.message, 'test message');
      expect(exception.cause, cause);
    });

    test('toString without cause', () {
      const exception = EncryptionException('test message');
      expect(exception.toString(), 'EncryptionException: test message');
    });

    test('toString with cause', () {
      final cause = Exception('original error');
      final exception = EncryptionException('test message', cause);
      expect(
        exception.toString(),
        contains('EncryptionException: test message'),
      );
      expect(exception.toString(), contains('caused by'));
    });
  });

  group('InvalidKeyException', () {
    test('extends EncryptionException', () {
      const exception = InvalidKeyException('bad key');
      expect(exception, isA<EncryptionException>());
    });

    test('toString without cause', () {
      const exception = InvalidKeyException('bad key');
      expect(exception.toString(), 'InvalidKeyException: bad key');
    });

    test('toString with cause', () {
      final cause = FormatException('invalid base64');
      final exception = InvalidKeyException('bad key', cause);
      expect(exception.toString(), contains('InvalidKeyException: bad key'));
      expect(exception.toString(), contains('caused by'));
    });
  });
}
