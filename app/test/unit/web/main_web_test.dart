import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/main_web.dart';

void main() {
  testWidgets('MagicShareWebApp renders the under-construction placeholder', (tester) async {
    await tester.pumpWidget(const MagicShareWebApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('MagicShare'), findsWidgets);
    expect(find.textContaining('under construction'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
  });
}
