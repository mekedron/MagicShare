import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/widget/dialogs/cloud_device_rename_dialog.dart';

class _Harness {
  String? result;
}

Future<_Harness> _show(WidgetTester tester, {required String initial}) async {
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
                  harness.result = await showDialog<String>(
                    context: context,
                    builder: (_) => CloudDeviceRenameDialog(initialName: initial),
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
  testWidgets('preselects the initial name in the text field', (tester) async {
    await _show(tester, initial: 'Macbook Pro');

    expect(find.widgetWithText(TextField, 'Macbook Pro'), findsOneWidget);
    expect(find.text('Rename device'), findsOneWidget);
  });

  testWidgets('Save is disabled while the field is whitespace-only', (tester) async {
    await _show(tester, initial: '   ');

    final saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('Save is enabled when the field has non-empty content', (tester) async {
    await _show(tester, initial: 'Macbook');

    final saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('tapping Save pops with the trimmed display name', (tester) async {
    final harness = await _show(tester, initial: 'Macbook Pro');

    await tester.enterText(find.byType(TextField), '  Macbook Air  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(harness.result, 'Macbook Air');
  });

  testWidgets('tapping Cancel pops with null', (tester) async {
    final harness = await _show(tester, initial: 'Macbook');

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(harness.result, isNull);
  });
}
