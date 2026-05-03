import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/provider/version_provider.dart';
import 'package:magicshare_app/widget/about_magicshare_card.dart';
import 'package:refena_flutter/refena_flutter.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  String version = '1.17.0 (58)',
  Future<void> Function(Uri url)? onOpenUrl,
}) async {
  LocaleSettings.setLocaleSync(AppLocale.en);
  await tester.pumpWidget(
    RefenaScope(
      overrides: [
        versionProvider.overrideWithFuture((_) async => version),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: AboutMagicShareCard(onOpenUrl: onOpenUrl),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('renders the LocalSend attribution and the LICENSE link', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    await tester.pumpWidget(
      RefenaScope(
        overrides: [
          versionProvider.overrideWithFuture((_) async => '1.17.0 (58)'),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: Scaffold(
              body: AboutMagicShareCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('About MagicShare'), findsOneWidget);
    expect(find.text('MagicShare is a fork of LocalSend.'), findsOneWidget);
    expect(find.text('Open localsend.org'), findsOneWidget);
    expect(find.text('View license'), findsOneWidget);
    expect(find.text('Version 1.17.0 (58)'), findsOneWidget);
  });

  testWidgets('view-license button opens the bundled LICENSE URL', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    final openedUrls = <Uri>[];
    await _pumpCard(
      tester,
      onOpenUrl: (url) async => openedUrls.add(url),
    );

    await tester.tap(find.text('View license'));
    await tester.pump();

    expect(openedUrls, hasLength(1));
    expect(openedUrls.single.toString(), 'https://github.com/mekedron/MagicShare/blob/main/LICENSE');
  });

  testWidgets('open-localsend button opens https://localsend.org', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    final openedUrls = <Uri>[];
    await _pumpCard(
      tester,
      onOpenUrl: (url) async => openedUrls.add(url),
    );

    await tester.tap(find.text('Open localsend.org'));
    await tester.pump();

    expect(openedUrls, hasLength(1));
    expect(openedUrls.single.toString(), 'https://localsend.org');
  });
}
