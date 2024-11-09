import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_quotes/main.dart';

void main() {
  testWidgets('Quote app basic UI test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(QuoteApp());

    // Verify that the app title is present
    expect(find.text('Daily Motivation'), findsOneWidget);

    // Verify that the initial loading state is present
    expect(find.text('Loading...'), findsOneWidget);

    // Verify that the "Get New Quote" button exists
    expect(find.text('Get New Quote'), findsOneWidget);

    // Verify that the notifications toggle exists
    expect(find.text('Enable Daily Notifications'), findsOneWidget);

    // Verify that the notification time setting exists
    expect(find.text('Notification Time'), findsOneWidget);
  });
}