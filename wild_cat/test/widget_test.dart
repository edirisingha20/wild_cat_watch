import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wild_cat/main.dart';

void main() {
  testWidgets('App starts on splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const WildCatWatchApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
