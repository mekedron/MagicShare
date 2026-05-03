import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';

void main() {
  group('cloudErrorCodeFromFirebase', () {
    test('maps every Firebase code the backend emits', () {
      expect(cloudErrorCodeFromFirebase('unauthenticated'), CloudErrorCode.unauthenticated);
      expect(cloudErrorCodeFromFirebase('invalid-argument'), CloudErrorCode.invalidArgument);
      expect(cloudErrorCodeFromFirebase('not-found'), CloudErrorCode.notFound);
      expect(cloudErrorCodeFromFirebase('failed-precondition'), CloudErrorCode.failedPrecondition);
      expect(cloudErrorCodeFromFirebase('resource-exhausted'), CloudErrorCode.resourceExhausted);
    });

    test('falls back to unknown for unrecognised codes', () {
      expect(cloudErrorCodeFromFirebase('internal'), CloudErrorCode.unknown);
      expect(cloudErrorCodeFromFirebase('cancelled'), CloudErrorCode.unknown);
      expect(cloudErrorCodeFromFirebase(''), CloudErrorCode.unknown);
      expect(cloudErrorCodeFromFirebase('future-code-not-yet-mapped'), CloudErrorCode.unknown);
    });
  });

  group('CloudException', () {
    test('stores code, message, and optional details', () {
      const ex = CloudException(
        code: CloudErrorCode.notFound,
        message: 'Token does not exist.',
        details: {'tokenId': 'tok-1'},
      );
      expect(ex.code, CloudErrorCode.notFound);
      expect(ex.message, 'Token does not exist.');
      expect(ex.details, {'tokenId': 'tok-1'});
    });

    test('toString is human-readable and includes code name', () {
      const ex = CloudException(
        code: CloudErrorCode.invalidArgument,
        message: 'Invalid value for "deviceId": must not be empty.',
      );
      expect(ex.toString(), contains('invalidArgument'));
      expect(ex.toString(), contains('Invalid value'));
    });

    test('fromFirebase maps a FirebaseFunctionsException', () {
      final firebaseError = FirebaseFunctionsException(
        message: 'Caller must be signed in.',
        code: 'unauthenticated',
        details: null,
      );
      final ex = CloudException.fromFirebase(firebaseError);
      expect(ex.code, CloudErrorCode.unauthenticated);
      expect(ex.message, 'Caller must be signed in.');
      expect(ex.details, isNull);
    });

    test('fromFirebase preserves details map', () {
      final firebaseError = FirebaseFunctionsException(
        message: 'Rate limit exceeded.',
        code: 'resource-exhausted',
        details: {'limit': 30, 'window': 'hour'},
      );
      final ex = CloudException.fromFirebase(firebaseError);
      expect(ex.code, CloudErrorCode.resourceExhausted);
      expect(ex.details, {'limit': 30, 'window': 'hour'});
    });
  });
}
