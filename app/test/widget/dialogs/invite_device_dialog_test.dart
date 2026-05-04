import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/pairing/pairing_lan_server.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/results/create_join_token_result.dart';
import 'package:magicshare_app/widget/dialogs/invite_device_dialog.dart';

class _StubCloudFunctionsClient extends CloudFunctionsClient {
  _StubCloudFunctionsClient({
    required this.tokenId,
    required this.expiresAtMs,
  }) : super(invoker: _alwaysThrows);

  final String tokenId;
  final int expiresAtMs;

  // Records every call so tests can assert the issuingDeviceId passed.
  final List<String> createJoinTokenCalls = [];

  @override
  Future<CreateJoinTokenResult> createJoinToken({required String issuingDeviceId}) async {
    createJoinTokenCalls.add(issuingDeviceId);
    return CreateJoinTokenResult(tokenId: tokenId, expiresAtMs: expiresAtMs);
  }

  static Future<Object?> _alwaysThrows(String name, Object? data) async {
    throw StateError('fake invoker not used');
  }
}

class _FakeLanServer implements PairingLanServerHandle {
  _FakeLanServer({this.boundPort = 49152});
  final int boundPort;
  bool started = false;
  bool stopped = false;
  final Completer<void> _handshake = Completer<void>();

  @override
  Future<int> start() async {
    started = true;
    return boundPort;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    // Production server completes the handshake future with a
    // TimeoutException only after its lifetime elapses. For widget
    // tests we just leave the future pending — the dialog only ever
    // resolves it via a real handshake or via timeout, neither of
    // which we want firing inside a unit-style widget test.
  }

  @override
  int get port {
    if (!started) throw StateError('not started');
    return boundPort;
  }

  @override
  Future<void> get handshakeCompleted => _handshake.future;
}

class _SpyServerFactory {
  final List<({String tokenId, Uint8List groupKey})> created = [];
  final List<_FakeLanServer> servers = [];

  PairingLanServerHandle call({
    required String tokenId,
    required dynamic issuerPrivateKey,
    required Uint8List groupKey,
  }) {
    created.add((tokenId: tokenId, groupKey: groupKey));
    final server = _FakeLanServer(boundPort: 49152 + servers.length);
    servers.add(server);
    return server;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required CloudFunctionsClient client,
  required _SpyServerFactory factory,
  required DateTime Function() now,
}) async {
  LocaleSettings.setLocaleSync(AppLocale.en);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => InviteDeviceDialog(
                  cloudFunctionsClient: client,
                  lanServerFactory: factory.call,
                  currentDeviceIdOverride: 'fake-current-device',
                  lanAddressOverride: '192.168.1.42',
                  groupKeyOverride: Uint8List(groupKeyLengthBytes),
                  now: now,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Allow the dialog to mount + post-frame callback to schedule the
  // async start path.
  await tester.pump();
  await tester.pump();
  // The async start does I/O (HttpServer.bind), so we need to yield
  // control back to the event loop a few times before checking the
  // ready state. We can't pumpAndSettle because the periodic 1-second
  // countdown ticker would prevent settling.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('renders QR (PrettyQrView), manual code, countdown, and copy button', (tester) async {
    final expiresAt = DateTime.utc(2026, 1, 1, 0, 5);
    final now = DateTime.utc(2026, 1, 1, 0, 0);
    final client = _StubCloudFunctionsClient(
      tokenId: 'STABLETOKEN0123456789ABCDEFGHIJKL',
      expiresAtMs: expiresAt.millisecondsSinceEpoch,
    );
    final factory = _SpyServerFactory();

    await _pump(
      tester,
      client: client,
      factory: factory,
      now: () => now,
    );

    // Title rendered.
    expect(find.text('Invite a device'), findsOneWidget);
    // Manual code label rendered.
    expect(find.text('Or type this code:'), findsOneWidget);
    // SelectableText (manual code) rendered.
    expect(find.byType(SelectableText), findsOneWidget);
    // Countdown text — 5 min remaining = 300s.
    expect(find.textContaining('Expires in 300s'), findsOneWidget);
    // Copy button.
    expect(find.text('Copy code'), findsOneWidget);
    // Cloud function was actually called with the right device ID.
    expect(client.createJoinTokenCalls, ['fake-current-device']);
    // Exactly one LAN server is created, configured with the minted
    // tokenId.
    expect(factory.created.length, 1);
    expect(factory.created.single.tokenId, 'STABLETOKEN0123456789ABCDEFGHIJKL');

    // Stop the dialog cleanly.
    await tester.pumpAndSettle();
    final closeFinder = find.text('Close');
    expect(closeFinder, findsOneWidget);
    await tester.tap(closeFinder);
    await tester.pumpAndSettle();
  });

  testWidgets('Copy button puts the manual code on the system clipboard', (tester) async {
    final captured = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = (call.arguments as Map?)?.cast<String, Object?>();
        final text = args?['text'];
        if (text is String) captured.add(text);
      }
      return null;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final expiresAt = DateTime.utc(2026, 1, 1, 0, 5);
    final now = DateTime.utc(2026, 1, 1, 0, 0);
    final client = _StubCloudFunctionsClient(
      tokenId: 'TOKENFORCLIPBOARDTEST123456789012',
      expiresAtMs: expiresAt.millisecondsSinceEpoch,
    );
    final factory = _SpyServerFactory();

    await _pump(
      tester,
      client: client,
      factory: factory,
      now: () => now,
    );

    final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
    final renderedManualCode = selectableText.data;
    expect(renderedManualCode, isNotNull);

    // The dialog is taller than the default 800x600 test viewport; the
    // Copy button is below the fold. Scroll to it before tapping.
    await tester.scrollUntilVisible(
      find.text('Copy code'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(find.text('Copy code'));
    // Pump a few microtask cycles so the async clipboard chain
    // (Clipboard.setData → mock platform-channel handler →
    // ScaffoldMessenger.showSnackBar) settles.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(captured, [renderedManualCode]);
    // "Code copied" snackbar shown.
    expect(find.text('Code copied'), findsOneWidget);

    // Cleanup.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('Countdown text decrements as the wall clock advances', (tester) async {
    var current = DateTime.utc(2026, 1, 1, 0, 0);
    final expiresAt = DateTime.utc(2026, 1, 1, 0, 5);
    final client = _StubCloudFunctionsClient(
      tokenId: 'COUNTDOWNTEST0123456789ABCDEFGHIJ',
      expiresAtMs: expiresAt.millisecondsSinceEpoch,
    );
    final factory = _SpyServerFactory();

    await _pump(
      tester,
      client: client,
      factory: factory,
      now: () => current,
    );

    expect(find.textContaining('Expires in 300s'), findsOneWidget);

    // Advance the simulated clock by 5 s and pump the periodic timer.
    current = current.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.textContaining('Expires in 295s'), findsOneWidget);

    // Cleanup.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
}
