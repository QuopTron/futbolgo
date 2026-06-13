import 'package:flutter_test/flutter_test.dart';

import 'package:futbolgo/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FutbolGOApp());

    // Verify that our app renders correctly.
    expect(find.text('FutbolGO - AD-Blocker'), findsOneWidget);
  });
}
