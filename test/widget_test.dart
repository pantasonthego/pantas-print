// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:pantas_print/main.dart';

void main() {
  testWidgets('App starts and displays splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PantasPrintApp());

    // Verify that the app title is present on the splash screen.
    expect(find.text('PANTAS PRINT'), findsOneWidget);
  });
}
