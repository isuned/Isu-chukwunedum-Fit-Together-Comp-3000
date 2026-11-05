// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_together/main.dart';

void main() {
  testWidgets('FitTogether displays the home dashboard',
      (WidgetTester tester) async {
    // Launch the FitTogether application.
    await tester.pumpWidget(const FitTogetherApp());

    // Check that the app title is displayed.
    expect(find.text('FitTogether'), findsOneWidget);

    // Check that the daily step information is displayed.
    expect(find.text("Today's Steps"), findsOneWidget);
    expect(find.text('6500'), findsOneWidget);
    expect(find.text('of 10000 steps'), findsOneWidget);

    // Check that the navigation bar is present.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Friends screen shows sample friends',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FitTogetherApp());

    // Navigate to the Friends screen.
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();

    // Verify that the sample friends appear.
    expect(find.text('Friends & Family'), findsOneWidget);
    expect(find.text('Brother'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
  });
}
