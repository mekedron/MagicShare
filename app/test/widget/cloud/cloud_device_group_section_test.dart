import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
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
        ),
      );

  final CloudAuthState _initial;
  int signInForNewGroupCalls = 0;

  @override
  CloudAuthState init() => _initial;

  @override
  Future<void> signInForNewGroup() async {
    signInForNewGroupCalls++;
  }
}

MockPersistenceService _stubPersistence({required bool cloudSyncEnabled}) {
  final mock = MockPersistenceService();
  when(mock.getShowToken()).thenReturn('token');
  when(mock.getAlias()).thenReturn('alias');
  when(mock.getMulticastGroup()).thenReturn('224.0.0.0');
  when(mock.getPort()).thenReturn(53317);
  when(mock.getDiscoveryTimeout()).thenReturn(500);
  when(mock.getCloudSyncEnabled()).thenReturn(cloudSyncEnabled);
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
  bool cloudSyncEnabled = true,
}) async {
  LocaleSettings.setLocaleSync(AppLocale.en);
  final auth = _FakeAuthService(authState);
  await tester.pumpWidget(
    RefenaScope(
      overrides: [
        persistenceProvider.overrideWithValue(
          _stubPersistence(cloudSyncEnabled: cloudSyncEnabled),
        ),
        cloudAuthProvider.overrideWithNotifier((ref) => auth),
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

  group('welcome card', () {
    testWidgets('renders three CTAs when auth state is AwaitingChoice', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
      );

      expect(find.text('Set up your device group'), findsOneWidget);
      expect(find.text('Create a new group'), findsOneWidget);
      expect(find.text('Join an existing group'), findsOneWidget);
      expect(find.text('Use without cloud'), findsOneWidget);
      // No loading spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tapping Create a new group calls signInForNewGroup', (tester) async {
      final auth = await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
      );

      await tester.tap(find.text('Create a new group'));
      await tester.pump();

      expect(auth.signInForNewGroupCalls, 1);
    });

    testWidgets('tapping Join an existing group surfaces the coming-soon snackbar', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
      );

      // The Join CTA shares its label with the AccountReady card's button —
      // here the AccountReady branch isn't rendered so the welcome instance
      // is the only match.
      await tester.tap(find.text('Join an existing group'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('tapping Use without cloud flips cloudSyncEnabled and hides the card', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthAwaitingChoice(),
      );

      expect(find.text('Set up your device group'), findsOneWidget);
      await tester.tap(find.text('Use without cloud'));
      await tester.pump();
      await tester.pump();

      // Section disappears entirely once cloud sync is off.
      expect(find.text('Set up your device group'), findsNothing);
      expect(find.text('Device group'), findsNothing);
    });

    testWidgets('renders an inline error banner when auth state is Failed', (tester) async {
      await _pump(
        tester,
        const AccountIdle(),
        authState: const CloudAuthFailed(message: 'boom', error: 'boom'),
      );

      expect(find.text('Set up your device group'), findsOneWidget);
      expect(find.text("Couldn't create the device group. Try again?"), findsOneWidget);
      // Primary CTA flips to "Retry".
      expect(find.text('Retry'), findsOneWidget);
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
