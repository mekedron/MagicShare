import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/widget/dialogs/cloud_device_icon_picker_dialog.dart';

class _Harness {
  CloudDeviceIcon? result;
}

Future<_Harness> _show(WidgetTester tester, {required CloudDeviceIcon current}) async {
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
                  harness.result = await showDialog<CloudDeviceIcon>(
                    context: context,
                    builder: (_) => CloudDeviceIconPickerDialog(current: current),
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
  testWidgets('renders a label for every CloudDeviceIcon variant', (tester) async {
    await _show(tester, current: CloudDeviceIcon.laptop);

    expect(find.text('Laptop'), findsOneWidget);
    expect(find.text('Desktop'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Tablet'), findsOneWidget);
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Headless'), findsOneWidget);
    expect(find.text('Generic'), findsOneWidget);
  });

  testWidgets('tapping an icon pops with that icon', (tester) async {
    final harness = await _show(tester, current: CloudDeviceIcon.laptop);

    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();

    expect(harness.result, CloudDeviceIcon.phone);
  });

  testWidgets('tapping Cancel pops with null', (tester) async {
    final harness = await _show(tester, current: CloudDeviceIcon.laptop);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(harness.result, isNull);
  });

  testWidgets('every variant is selectable in turn', (tester) async {
    for (final icon in CloudDeviceIcon.values) {
      final harness = await _show(tester, current: CloudDeviceIcon.laptop);
      final label = switch (icon) {
        CloudDeviceIcon.laptop => 'Laptop',
        CloudDeviceIcon.desktop => 'Desktop',
        CloudDeviceIcon.phone => 'Phone',
        CloudDeviceIcon.tablet => 'Tablet',
        CloudDeviceIcon.server => 'Server',
        CloudDeviceIcon.headless => 'Headless',
        CloudDeviceIcon.other => 'Generic',
      };
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(harness.result, icon, reason: 'tap on $label should pop $icon');
    }
  });
}
