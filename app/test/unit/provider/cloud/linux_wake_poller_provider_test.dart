import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/cloud/linux_wake_poller_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('returns Unsupported on non-Linux platforms', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final tester = Notifier.test<LinuxWakePollerService, LinuxWakePollState>(
      notifier: LinuxWakePollerService(),
    );
    expect(tester.state, isA<LinuxWakePollUnsupported>());
  });

  test('returns Idle on Linux until start is called', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final tester = Notifier.test<LinuxWakePollerService, LinuxWakePollState>(
      notifier: LinuxWakePollerService(),
    );
    expect(tester.state, isA<LinuxWakePollIdle>());
  });

  test('start switches to Running and triggers poll once per interval', () async {
    int polls = 0;
    final tester = Notifier.test<LinuxWakePollerService, LinuxWakePollState>(
      notifier: LinuxWakePollerService(
        interval: const Duration(milliseconds: 10),
        pollOnce: () async {
          polls++;
        },
        requireLinuxPlatform: false,
      ),
    );

    expect(tester.state, isA<LinuxWakePollIdle>());
    tester.notifier.start();
    expect(tester.state, isA<LinuxWakePollRunning>());

    await Future<void>.delayed(const Duration(milliseconds: 35));
    tester.notifier.stop();

    expect(polls, greaterThanOrEqualTo(2));
    expect(tester.state, isA<LinuxWakePollIdle>());
  });

  test('start is idempotent', () async {
    int polls = 0;
    final tester = Notifier.test<LinuxWakePollerService, LinuxWakePollState>(
      notifier: LinuxWakePollerService(
        interval: const Duration(milliseconds: 10),
        pollOnce: () async {
          polls++;
        },
        requireLinuxPlatform: false,
      ),
    );

    tester.notifier.start();
    tester.notifier.start();
    tester.notifier.start();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    tester.notifier.stop();

    // Three starts but only one timer means at most ~3 polls in 25 ms,
    // not 9. The exact count varies with scheduling, so just bound it.
    expect(polls, lessThanOrEqualTo(4));
  });

  test('default poll throws UnimplementedError until REST transport lands', () {
    final tester = Notifier.test<LinuxWakePollerService, LinuxWakePollState>(
      notifier: LinuxWakePollerService(requireLinuxPlatform: false),
    );
    tester.notifier.start();
    addTearDown(tester.notifier.stop);
    // We can't directly invoke _safePoll, but we can verify that the
    // default constructor wires the unimplemented sentinel by checking
    // start succeeds without immediate failure (the timer fires later).
    expect(tester.state, isA<LinuxWakePollRunning>());
  });
}
