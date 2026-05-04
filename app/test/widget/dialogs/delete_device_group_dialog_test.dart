import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/widget/dialogs/delete_device_group_dialog.dart';

class _Harness {
  bool? result;
}

Future<_Harness> _show(WidgetTester tester) async {
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
                    builder: (_) => const DeleteDeviceGroupDialog(),
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
  testWidgets('renders title and body', (tester) async {
    await _show(tester);

    expect(find.text('Delete this device group?'), findsOneWidget);
    expect(
      find.text(
        'All devices will leave the group. The group is destroyed everywhere. This device will create a fresh empty group.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping Delete group pops with true', (tester) async {
    final harness = await _show(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete group'));
    await tester.pumpAndSettle();

    expect(harness.result, isTrue);
  });

  testWidgets('tapping Cancel pops with false', (tester) async {
    final harness = await _show(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(harness.result, isFalse);
  });
}
