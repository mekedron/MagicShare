import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:magicshare_app/provider/cloud/cloud_bootstrap_service.dart';
import 'package:magicshare_app/provider/persistence_provider.dart';
import 'package:magicshare_app/widget/cloud/cloud_device_group_section.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../mocks.mocks.dart';

/// Subclass of [AccountRepository] whose init() short-circuits to the
/// supplied state so we can render any branch of the section under test.
/// The parent's auth/firestore subscriptions are never attached because
/// we do not call super.init().
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository(this._initial)
    : super(
        deps: AccountRepositoryDeps(
          authStateReader: () => const CloudAuthIdle(),
          authStateChanges: () => const Stream<CloudAuthState>.empty(),
          deviceIdResolver: () async => '',
          cloudSyncEnabledReader: () => false,
        ),
        supportedOverride: false,
      );

  final AccountState _initial;

  @override
  AccountState init() => _initial;
}

/// Subclass of [CloudAuthService] whose init() returns a fixed state and
/// whose [signInForNewGroup] just records the call. Real Firebase Auth is
/// never reached because the gateway streams are stubs.
class _FakeAuthService extends CloudAuthService {
  _FakeAuthService(this._initial)
    : super(
        gateway: CloudAuthGateway(
          userIdChanges: () => const Stream<String?>.empty(),
          signInAnonymously: () async => 'fake-uid',
          currentUserId: () => null,
          deleteCurrentUser: () async {},
          signOut: () async {},
        ),
      );

  final CloudAuthState _initial;
  int signInForNewGroupCalls = 0;
  int deleteAndResetCalls = 0;

  @override
  CloudAuthState init() => _initial;

  @override
  Future<void> signInForNewGroup() async {
    signInForNewGroupCalls++;
  }

  @override
  Future<void> deleteAndReset() async {
    deleteAndResetCalls++;
  }
}

class _FakeBootstrapService extends CloudBootstrapService {
  _FakeBootstrapService(this._initial)
    : super(
        deps: CloudBootstrapDeps(
          authStateReader: () => const CloudAuthIdle(),
          authStateChanges: () => const Stream<CloudAuthState>.empty(),
          deviceIdentity: () => throw UnimplementedError(),
          client: () => throw UnimplementedError(),
          fcmTokenReader: () => const FcmTokenAcquiring(),
          fcmTokenChanges: () => const Stream<FcmTokenSnapshot>.empty(),
          groupKeyReader: () => throw UnimplementedError(),
          ensureGroupKey: () async {},
          peerDeviceCountReader: () => 0,
          cloudSyncEnabledReader: () => false,
        ),
        supportedOverride: false,
      );

  final BootstrapState _initial;

  @override
  BootstrapState init() => _initial;
}

MockPersistenceService _stubPersistence({
  required bool cloudSyncEnabled,
  bool cloudWelcomeDismissed = false,
}) {
  final mock = MockPersistenceService();
  when(mock.getShowToken()).thenReturn('token');
  when(mock.getAlias()).thenReturn('alias');
  when(mock.getMulticastGroup()).thenReturn('224.0.0.0');
  when(mock.getPort()).thenReturn(53317);
  when(mock.getDiscoveryTimeout()).thenReturn(500);
  when(mock.getCloudSyncEnabled()).thenReturn(cloudSyncEnabled);
  when(mock.getCloudWelcomeDismissed()).thenReturn(cloudWelcomeDismissed);
  when(mock.setCloudWelcomeDismissed(any)).thenAnswer((_) async {});
  return mock;
}

CloudDevice _device({
  required String id,
  required String name,
  CloudDeviceIcon icon = CloudDeviceIcon.laptop,
  CloudDevicePresence presence = CloudDevicePresence.online,
}) {
  return CloudDevice(
    deviceId: id,
    displayName: name,
    icon: icon,
    fcmToken: null,
    platform: CloudDevicePlatform.macos,
    lastSeenAtMs: 0,
    presence: presence,
  );
}

Future<_FakeAuthService> _pump(
  WidgetTester tester,
  AccountState state, {
  CloudAuthState authState = const CloudAuthAuthenticated('fake-uid'),
  BootstrapState bootstrapState = const BootstrapDone(accountId: 'fake-uid', deviceId: 'fake-device'),
  bool cloudSyncEnabled = true,
  bool cloudWelcomeDismissed = false,
}) async {
  LocaleSettings.setLocaleSync(AppLocale.en);
  final auth = _FakeAuthService(authState);
  await tester.pumpWidget(
    RefenaScope(
      overrides: [
        persistenceProvider.overrideWithValue(
          _stubPersistence(
            cloudSyncEnabled: cloudSyncEnabled,
            cloudWelcomeDismissed: cloudWelcomeDismissed,
          ),
        ),
        cloudAuthProvider.overrideWithNotifier((ref) => auth),
        cloudBootstrapProvider.overrideWithNotifier((ref) => _FakeBootstrapService(bootstrapState)),
        accountRepositoryProvider.overrideWithNotifier((ref) => _FakeAccountRepository(state)),
      ],
      child: TranslationProvider(
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CloudDeviceGroupSection(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return auth;
}

void main() {
  group('rendering', () {
    testWidgets('hides the section entirely on AccountUnsupported', (tester) async {
      await _pump(tester, const AccountUnsupported());

      expect(find.text('Device group'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('shows a loading card on AccountIdle', (tester) async {
      await _pump(tester, const AccountIdle());

      expect(find.text('Device group'), findsOneWidget);
      expect(find.text('Loading device group…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows a loading card on AccountLoading', (tester) async {
      await _pump(
        tester,
        const AccountLoading(accountId: 'acc', currentDeviceId: 'dev'),
      );

      expect(find.text('Device group'), findsOneWidget);
      expect(find.text('Loading device group…'), findsOneWidget);
    });

    testWidgets('shows an error message on AccountFailed', (tester) async {
      await _pump(
        tester,
        const AccountFailed(message: 'boom', error: 'boom'),
      );

      expect(find.text('Could not load device group.'), findsOneWidget);
    });

    testWidgets('renders sorted device list, action buttons, and delete button', (tester) async {
      final state = AccountReady(
        accountId: 'acc-1',
        currentDeviceId: 'current',
        account: null,
        devices: [
          _device(id: 'offline-z', name: 'Zeta', presence: CloudDevicePresence.offline),
          _device(id: 'online-b', name: 'Bravo', presence: CloudDevicePresence.online),
          _device(id: 'current', name: 'Macbook'),
          _device(id: 'online-a', name: 'Alpha', presence: CloudDevicePresence.online),
          _device(id: 'offline-m', name: 'Mike', presence: CloudDevicePresence.offline),
        ],
      );

      await _pump(tester, state);

      expect(find.text('Device group'), findsOneWidget);
      expect(find.text('Macbook'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
      expect(find.text('Invite a device'), findsOneWidget);
      expect(find.text('Join an existing group'), findsOneWidget);
      expect(find.text('Delete this device group'), findsOneWidget);
    });
  });

  group('sortDevicesForSection', () {
    test('places current device first, then online by name, then offline by name', () {
      final devices = [
        _device(id: 'offline-z', name: 'Zeta', presence: CloudDevicePresence.offline),
        _device(id: 'online-b', name: 'Bravo', presence: CloudDevicePresence.online),
        _device(id: 'current', name: 'Macbook'),
        _device(id: 'online-a', name: 'Alpha', presence: CloudDevicePresence.online),
        _device(id: 'offline-m', name: 'Mike', presence: CloudDevicePresence.offline),
      ];

      final sorted = sortDevicesForSection(devices, 'current');

      expect(
        sorted.map((d) => d.deviceId).toList(),
        ['current', 'online-a', 'online-b', 'offline-m', 'offline-z'],
      );
    });

    test('case-insensitive name compare within each presence bucket', () {
      final devices = [
        _device(id: 'b', name: 'banana', presence: CloudDevicePresence.online),
        _device(id: 'a', name: 'Apple', presence: CloudDevicePresence.online),
      ];

      final sorted = sortDevicesForSection(devices, 'absent');

      expect(sorted.map((d) => d.displayName).toList(), ['Apple', 'banana']);
    });

    test('returns a copy and does not mutate the input', () {
      final input = [
        _device(id: 'b', name: 'B'),
        _device(id: 'a', name: 'A'),
      ];
      final inputOrder = input.map((d) => d.deviceId).toList();

      sortDevicesForSection(input, 'absent');

      expect(input.map((d) => d.deviceId).toList(), inputOrder);
    });
  });

  group('interaction', () {
    testWidgets('tapping a peer device opens the detail sheet with peer actions', (tester) async {
      final state = AccountReady(
        accountId: 'acc-1',
        currentDeviceId: 'current',
        account: null,
        devices: [
          _device(id: 'current', name: 'Macbook'),
          _device(id: 'peer', name: 'Pixel 8'),
        ],
      );

      await _pump(tester, state);

      await tester.tap(find.text('Pixel 8'));
      await tester.pumpAndSettle();

      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Change icon'), findsOneWidget);
      expect(find.text('Remove from group'), findsOneWidget);
      expect(find.text('Leave or destroy this group'), findsNothing);
    });

    testWidgets('tapping the current device opens the detail sheet with leave action', (tester) async {
      final state = AccountReady(
        accountId: 'acc-1',
        currentDeviceId: 'current',
        account: null,
        devices: [
          _device(id: 'current', name: 'Macbook'),
          _device(id: 'peer', name: 'Pixel 8'),
        ],
      );

      await _pump(tester, state);

      await tester.tap(find.text('Macbook'));
      await tester.pumpAndSettle();

      expect(find.text('Leave or destroy this group'), findsOneWidget);
      expect(find.text('Remove from group'), findsNothing);
    });

    testWidgets('tapping Invite a device shows the coming-soon snackbar', (tester) async {
      final state = AccountReady(
        accountId: 'acc-1',
        currentDeviceId: 'current',
        account: null,
        devices: [_device(id: 'current', name: 'Macbook')],
      );

      await _pump(tester, state);

      await tester.tap(find.text('Invite a device'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('tapping Delete this device group opens the confirmation dialog', (tester) async {
      final state = AccountReady(
        accountId: 'acc-1',
        currentDeviceId: 'current',
        account: null,
        devices: [_device(id: 'current', name: 'Macbook')],
      );

      await _pump(tester, state);

      await tester.tap(find.text('Delete this device group'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this device group?'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete group'), findsOneWidget);
    });
  });

  group('setup card — first-launch welcome variant', () {
    testWidgets('renders three CTAs when auth state is AwaitingChoice and welcome not dismissed', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
        bootstrapState: const BootstrapIdle(),
      );

      expect(find.text('Set up your device group'), findsOneWidget);
      expect(find.text('Create a new group'), findsOneWidget);
      expect(find.text('Join an existing group'), findsOneWidget);
      expect(find.text('Use without cloud'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tapping Create a new group calls signInForNewGroup', (tester) async {
      final auth = await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
        bootstrapState: const BootstrapIdle(),
      );

      await tester.tap(find.text('Create a new group'));
      await tester.pump();

      expect(auth.signInForNewGroupCalls, 1);
      // No deleteAndReset on the AwaitingChoice path — only stale sessions
      // need to be discarded first.
      expect(auth.deleteAndResetCalls, 0);
    });

    testWidgets('tapping Join an existing group surfaces the coming-soon snackbar', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
        bootstrapState: const BootstrapIdle(),
      );

      await tester.tap(find.text('Join an existing group'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('tapping Use without cloud dismisses welcome but keeps section visible', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
        bootstrapState: const BootstrapIdle(),
      );

      expect(find.text('Use without cloud'), findsOneWidget);
      await tester.tap(find.text('Use without cloud'));
      await tester.pump();
      await tester.pump();

      // The third CTA disappears, but the section title and the Create /
      // Join CTAs stay — the user can still set up cloud later.
      expect(find.text('Use without cloud'), findsNothing);
      expect(find.text('Set up your device group'), findsOneWidget);
      expect(find.text('Create a new group'), findsOneWidget);
      expect(find.text('Join an existing group'), findsOneWidget);
    });

    testWidgets('renders an inline error banner when auth state is Failed', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthFailed(message: 'boom', error: 'boom'),
        bootstrapState: const BootstrapIdle(),
      );

      expect(find.text('Set up your device group'), findsOneWidget);
      expect(
        find.textContaining('Something went wrong setting up your device group'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('setup card — post-dismissal variant', () {
    testWidgets('renders only Create + Join when welcome was dismissed', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
        bootstrapState: const BootstrapIdle(),
        cloudWelcomeDismissed: true,
      );

      expect(find.text('Set up your device group'), findsOneWidget);
      expect(find.text('Create a new group'), findsOneWidget);
      expect(find.text('Join an existing group'), findsOneWidget);
      // Use without cloud is intentionally absent in settings — Epic 14
      // ships a real master toggle for that.
      expect(find.text('Use without cloud'), findsNothing);
    });
  });

  group('setup card — stale-session variant', () {
    testWidgets('renders the setup card when bootstrap failed under an Authenticated UID', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAuthenticated('stale-uid'),
        bootstrapState: const BootstrapFailed(message: 'unknown', error: 'unknown'),
      );

      expect(find.text('Set up your device group'), findsOneWidget);
      expect(
        find.textContaining('Your previous device group is no longer available'),
        findsOneWidget,
      );
      expect(find.text('Create a new group'), findsOneWidget);
    });

    testWidgets('Create from stale-session discards the old session before signing in', (tester) async {
      final auth = await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAuthenticated('stale-uid'),
        bootstrapState: const BootstrapFailed(message: 'unknown', error: 'unknown'),
      );

      await tester.tap(find.text('Create a new group'));
      await tester.pump();
      await tester.pump();

      expect(auth.deleteAndResetCalls, 1);
      expect(auth.signInForNewGroupCalls, 1);
    });
  });

  group('cloud-sync-off rendering', () {
    testWidgets('hides the section when cloudSyncEnabled is false', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
        cloudSyncEnabled: false,
      );

      expect(find.text('Device group'), findsNothing);
      expect(find.text('Set up your device group'), findsNothing);
    });
  });
}
