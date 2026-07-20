// Smoke test for the Patroller panel UI.
//
// Imports patroller_panel.dart (not main.dart) so VM tests avoid the
// web-only dart:js_interop dependency from package:devtools_extensions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patroller_devtools_extension/patroller_panel.dart';

void main() {
  testWidgets('Patroller panel shows offline state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PatrollerPanel(serverUrl: 'http://127.0.0.1:1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Patroller'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(
      find.text('Not connected to Patroller extension server.'),
      findsOneWidget,
    );

    // Dispose cancels the reconnect timer.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
