import 'package:flutter_test/flutter_test.dart';

import 'package:wild_cat/main.dart';

void main() {
  testWidgets('App starts on login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const WildCatWatchApp());

    expect(find.text('Login'), findsNWidgets(2));
    expect(find.text('Email or Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
