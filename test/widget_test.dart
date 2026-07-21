import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_verse/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders without error', (tester) async {
    // Pumped in isolation (not via MyApp) so this test never touches
    // Firebase or the real 2.5s navigation timer owned by SplashWrapper.
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
