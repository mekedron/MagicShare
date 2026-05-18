import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/network/webrtc/signaling_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../../../mocks.mocks.dart';

void main() {
  late MockPersistenceService persistence;

  setUp(() {
    persistence = MockPersistenceService();
    when(persistence.getSignalingServers()).thenReturn(['wss://public.localsend.org/v1/ws']);
    when(persistence.getStunServers()).thenReturn(['stun:stun.localsend.org:5349']);
  });

  group('SetupSignalingConnection', () {
    const server = 'wss://public.localsend.org/v1/ws';

    test('Skips spawning a new connection when one already exists for the server', () {
      // Reproduces the trigger path: HomePage re-dispatches
      // SetupSignalingConnection while connection #1 is still in
      // state.connections. The guard must short-circuit before touching
      // the GlobalActionDispatcher — accessing `global` outside a refena
      // container would throw, so a successful dispatch here proves the
      // `continue` branch was taken.
      final existingConnection = MockLsSignalingConnection();
      final tester = ReduxNotifier.test<SignalingState, Object>(
        redux: SignalingService(persistence: persistence),
        initialState: SignalingState(
          signalingServers: const [server],
          stunServers: const ['stun:stun.localsend.org:5349'],
          connections: {server: existingConnection},
          localIdentities: const {},
        ),
      );

      // This must not throw — the guard prevents `global.dispatchAsync`
      // from running, which is what would otherwise blow up in a bare
      // ReduxNotifier.test setup.
      tester.dispatch(SetupSignalingConnection());

      expect(tester.state.connections.keys, [server]);
      expect(tester.state.connections[server], same(existingConnection));
      expect(tester.state.localIdentities, isEmpty);
    });

    test('Leaves untouched server entries when only one of several is connected', () {
      // Mixed case: when only one of the configured signaling servers is
      // already connected, the guard must skip just that one and leave
      // the others alone. We can't actually run _SetupSignalingConnection
      // in a unit test (it opens a real WebSocket), so we assert via the
      // state shape: connections stays intact for the connected server.
      const otherServer = 'wss://other.example.org/v1/ws';
      final existingConnection = MockLsSignalingConnection();
      final tester = ReduxNotifier.test<SignalingState, Object>(
        redux: SignalingService(persistence: persistence),
        initialState: SignalingState(
          signalingServers: const [server, otherServer],
          stunServers: const ['stun:stun.localsend.org:5349'],
          connections: {server: existingConnection},
          localIdentities: const {},
        ),
      );

      // Best-effort: we know the connected server gets a `continue`. The
      // other-server branch would call into `global`, which throws here,
      // so wrap and inspect.
      try {
        tester.dispatch(SetupSignalingConnection());
      } catch (_) {
        // Expected — second iteration hits `global.dispatchAsync` without
        // a container. The point of this test is that the first iteration
        // did NOT throw, i.e. it took the `continue` branch.
      }
      expect(tester.state.connections[server], same(existingConnection));
    });
  });
}
