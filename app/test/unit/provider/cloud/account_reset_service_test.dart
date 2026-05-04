import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/provider/cloud/account_reset_service.dart';

void main() {
  test('runs deleteAccount → clearGroupKey → deleteAndResetAuth in order', () async {
    final calls = <String>[];
    final service = AccountResetService(
      AccountResetDeps(
        deleteAccountOnCloud: () async => calls.add('cloud'),
        clearGroupKey: () async => calls.add('key'),
        deleteAndResetAuth: () async => calls.add('auth'),
      ),
    );

    await service.resetForGroupDeletion();

    expect(calls, ['cloud', 'key', 'auth']);
  });

  test('cloud failure short-circuits; local state is not wiped', () async {
    final calls = <String>[];
    final service = AccountResetService(
      AccountResetDeps(
        deleteAccountOnCloud: () async {
          calls.add('cloud');
          throw const CloudException(
            code: CloudErrorCode.unauthenticated,
            message: 'not signed in',
          );
        },
        clearGroupKey: () async => calls.add('key'),
        deleteAndResetAuth: () async => calls.add('auth'),
      ),
    );

    await expectLater(
      service.resetForGroupDeletion(),
      throwsA(isA<CloudException>()),
    );

    expect(calls, ['cloud']);
  });

  test('group-key failure short-circuits; auth is not reset', () async {
    final calls = <String>[];
    final service = AccountResetService(
      AccountResetDeps(
        deleteAccountOnCloud: () async => calls.add('cloud'),
        clearGroupKey: () async {
          calls.add('key');
          throw StateError('storage write failed');
        },
        deleteAndResetAuth: () async => calls.add('auth'),
      ),
    );

    await expectLater(
      service.resetForGroupDeletion(),
      throwsA(isA<StateError>()),
    );

    expect(calls, ['cloud', 'key']);
  });

  test('auth failure surfaces but cloud + key already cleared', () async {
    final calls = <String>[];
    final service = AccountResetService(
      AccountResetDeps(
        deleteAccountOnCloud: () async => calls.add('cloud'),
        clearGroupKey: () async => calls.add('key'),
        deleteAndResetAuth: () async {
          calls.add('auth');
          throw StateError('requires-recent-login');
        },
      ),
    );

    await expectLater(
      service.resetForGroupDeletion(),
      throwsA(isA<StateError>()),
    );

    expect(calls, ['cloud', 'key', 'auth']);
  });
}
