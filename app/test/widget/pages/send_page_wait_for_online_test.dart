import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/state/send/send_session_state.dart';
import 'package:magicshare_app/pages/send_page.dart';
import 'package:magicshare_app/provider/device_info_provider.dart';
import 'package:magicshare_app/provider/network/send_provider.dart';
import 'package:magicshare_app/provider/persistence_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../mocks.mocks.dart';

Device _device({String alias = 'Pixel 6'}) {
  return Device(
    version: '2.1',
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.mobile,
    download: false,
    endpoints: const {},
    discoveryMethods: const {},
  );
}

SendSessionState _sessionState({
  required SessionStatus status,
  required Device target,
  int? deadlineMs,
}) {
  return SendSessionState(
    sessionId: 'session-1',
    remoteSessionId: null,
    background: false,
    status: status,
    target: target,
    files: const {},
    startTime: null,
    endTime: null,
    sendingTasks: null,
    errorMessage: null,
    stableTargetId: 'target-cloud-id',
    waitDeadlineMs: deadlineMs,
  );
}

MockPersistenceService _stubPersistence() {
  final mock = MockPersistenceService();
  when(mock.getFavorites()).thenReturn(const []);
  return mock;
}

class _FakeSendNotifier extends SendNotifier {
  _FakeSendNotifier(this._initial);
  final SendSessionState _initial;

  @override
  Map<String, SendSessionState> init() => {_initial.sessionId: _initial};
}

Widget _wrap(SendSessionState session) {
  return RefenaScope(
    overrides: [
      persistenceProvider.overrideWithValue(_stubPersistence()),
      sendProvider.overrideWithNotifier((_) => _FakeSendNotifier(session)),
      deviceFullInfoProvider.overrideWithBuilder((_) => _device(alias: 'My laptop')),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: SendPage(
          showAppBar: false,
          closeSessionOnClose: true,
          sessionId: session.sessionId,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.en);
  });

  testWidgets('waitingForDevice renders a countdown and Cancel button only', (tester) async {
    final target = _device(alias: 'Pixel 6');
    final deadline = DateTime.now().add(const Duration(seconds: 42)).millisecondsSinceEpoch;
    final session = _sessionState(
      status: SessionStatus.waitingForDevice,
      target: target,
      deadlineMs: deadline,
    );

    await tester.pumpWidget(_wrap(session));
    // Flush the InitialSlide/Fade transitions (400 ms total) and a
    // couple of countdown ticks.
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Waiting for Pixel 6'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, t.general.cancel), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);

    // Tear down so the per-second countdown timer is cancelled before
    // the binding asserts "no pending timers".
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('waitingForDeviceTimedOut renders Cancel + Retry', (tester) async {
    final target = _device(alias: 'Pixel 6');
    final session = _sessionState(
      status: SessionStatus.waitingForDeviceTimedOut,
      target: target,
    );

    await tester.pumpWidget(_wrap(session));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining("didn't come online in time"), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, t.general.cancel), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
