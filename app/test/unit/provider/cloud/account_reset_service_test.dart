import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/provider/cloud/account_reset_service.dart';

class _Recorder {
  final List<String> calls = [];

  AccountResetDeps deps({
    Future<void> Function()? deleteAccountOnCloud,
    Future<void> Function(String)? removeDeviceOnCloud,
    Future<void> Function()? clearGroupKey,
    Future<void> Function()? deleteAndResetAuth,
  }) {
    return AccountResetDeps(
      deleteAccountOnCloud: deleteAccountOnCloud ?? () async => calls.add('deleteAccount'),
      removeDeviceOnCloud: removeDeviceOnCloud ?? (deviceId) async => calls.add('removeDevice($deviceId)'),
      clearGroupKey: clearGroupKey ?? () async => calls.add('key'),
      deleteAndResetAuth: deleteAndResetAuth ?? () async => calls.add('auth'),
    );
  }
}

void main() {
  group('resetForGroupDeletion', () {
    test('runs deleteAccount → clearGroupKey → deleteAndResetAuth in order', () async {
      final r = _Recorder();
      final service = AccountResetService(r.deps());

      await service.resetForGroupDeletion();

      expect(r.calls, ['deleteAccount', 'key', 'auth']);
    });

    test('cloud failure does NOT block local cleanup (destroy intent wins)', () async {
      final r = _Recorder();
      final service = AccountResetService(
        r.deps(
          deleteAccountOnCloud: () async {
            r.calls.add('deleteAccount');
            throw const CloudException(
              code: CloudErrorCode.unauthenticated,
              message: 'not signed in',
            );
          },
        ),
      );

      await service.resetForGroupDeletion();

      // Cloud step recorded but failed; local steps still ran.
      expect(r.calls, ['deleteAccount', 'key', 'auth']);
    });

    test('group-key failure short-circuits; auth is not reset', () async {
      final r = _Recorder();
      final service = AccountResetService(
        r.deps(
          clearGroupKey: () async {
            r.calls.add('key');
            throw StateError('storage write failed');
          },
        ),
      );

      await expectLater(
        service.resetForGroupDeletion(),
        throwsA(isA<StateError>()),
      );

      expect(r.calls, ['deleteAccount', 'key']);
    });

    test('auth failure surfaces but cloud + key already ran', () async {
      final r = _Recorder();
      final service = AccountResetService(
        r.deps(
          deleteAndResetAuth: () async {
            r.calls.add('auth');
            throw StateError('requires-recent-login');
          },
        ),
      );

      await expectLater(
        service.resetForGroupDeletion(),
        throwsA(isA<StateError>()),
      );

      expect(r.calls, ['deleteAccount', 'key', 'auth']);
    });

    test('notFound on cloud step is treated as already-deleted; local state is wiped', () async {
      final r = _Recorder();
      final service = AccountResetService(
        r.deps(
          deleteAccountOnCloud: () async {
            r.calls.add('deleteAccount');
            throw const CloudException(
              code: CloudErrorCode.notFound,
              message: 'account does not exist',
            );
          },
        ),
      );

      await service.resetForGroupDeletion();

      expect(r.calls, ['deleteAccount', 'key', 'auth']);
    });
  });

  group('resetForLeaveGroup', () {
    test('runs removeDevice(deviceId) → clearGroupKey → deleteAndResetAuth in order', () async {
      final r = _Recorder();
      final service = AccountResetService(r.deps());

      await service.resetForLeaveGroup(currentDeviceId: 'device-x');

      expect(r.calls, ['removeDevice(device-x)', 'key', 'auth']);
    });

    test('non-notFound cloud failure short-circuits; local state is not wiped', () async {
      final r = _Recorder();
      final service = AccountResetService(
        r.deps(
          removeDeviceOnCloud: (id) async {
            r.calls.add('removeDevice($id)');
            throw const CloudException(
              code: CloudErrorCode.unauthenticated,
              message: 'not signed in',
            );
          },
        ),
      );

      await expectLater(
        service.resetForLeaveGroup(currentDeviceId: 'device-x'),
        throwsA(isA<CloudException>()),
      );

      expect(r.calls, ['removeDevice(device-x)']);
    });

    test('notFound on cloud step is treated as already-removed; local state is wiped', () async {
      final r = _Recorder();
      final service = AccountResetService(
        r.deps(
          removeDeviceOnCloud: (id) async {
            r.calls.add('removeDevice($id)');
            throw const CloudException(
              code: CloudErrorCode.notFound,
              message: 'device does not exist',
            );
          },
        ),
      );

      await service.resetForLeaveGroup(currentDeviceId: 'device-x');

      expect(r.calls, ['removeDevice(device-x)', 'key', 'auth']);
    });
  });
}
