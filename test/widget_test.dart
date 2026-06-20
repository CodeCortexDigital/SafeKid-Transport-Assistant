import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safekid_transport_assistant/main.dart';
import 'package:safekid_transport_assistant/providers/app_state_provider.dart';

void main() {
  testWidgets('App renders loading state on startup', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider<AppStateProvider>(
        create: (_) => AppStateProvider(),
        child: const SafeKidApp(),
      ),
    );

    // Verify that the initial MaterialApp displays a CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
