import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/widget/dialogs/cloud_device_remove_dialog.dart';

class _Harness {
  bool? result;
}

Future<_Harness> _show(WidgetTester tester, {required String name}) async {
  LocaleSettings.setLocaleSync(AppLocale.en);
  final harness = _Harness();
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  harness.result = await showDialog<bool>(
                    context: context,
                    builder: (_) => CloudDeviceRemoveDialog(deviceName: name),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testWidgets('renders title and interpolates the device name in the body', (tester) async {
    await _show(tester, name: 'Pixel 8');

    expect(find.text('Remove device?'), findsOneWidget);
    expect(
      find.text(
        'Remove Pixel 8 from this group? It will need to pair again to send to your other devices.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping Remove pops with true', (tester) async {
    final harness = await _show(tester, name: 'iPad');

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(harness.result, isTrue);
  });

  testWidgets('tapping Cancel pops with false', (tester) async {
    final harness = await _show(tester, name: 'iPad');

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(harness.result, isFalse);
  });
}
