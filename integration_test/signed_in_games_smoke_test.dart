// On-device smoke test for the games that need an account (Daily Movie,
// Plot, Who's the Actor?): creates a throwaway Firebase Auth user, plays one
// guess in each against real Firestore + TMDB, then deletes the user's
// gamePlays docs and the account. Run on a simulator:
//   flutter test integration_test/signed_in_games_smoke_test.dart \
//     --dart-define-from-file=secrets.json -d <simulator-id>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watch_verse/firebase_options.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/actor_guess_screen.dart';
import 'package:watch_verse/screens/daily_game_screen.dart';
import 'package:watch_verse/screens/games/plot_guess_screen.dart';
import 'package:watch_verse/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      home: home,
    );

Future<void> _wait(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void _dumpTexts(String label) {
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .where((t) => t.trim().isNotEmpty)
      .take(30)
      .toList();
  debugPrint('SMOKE[$label] texts: $texts');
}

/// Types [query] into the screen's search field and taps the first result.
Future<void> _guess(WidgetTester tester, String label, String query) async {
  final field = find.byType(TextField);
  expect(field, findsWidgets, reason: '$label has no search field');
  await tester.enterText(field.first, query);
  await _wait(tester, 5);
  _dumpTexts('$label-results');
  final results = find.byType(ListTile);
  if (results.evaluate().isEmpty) {
    debugPrint('SMOKE[$label] no ListTile results to tap');
    return;
  }
  await tester.tap(results.first, warnIfMissed: false);
  await _wait(tester, 6);
  _dumpTexts('$label-after-guess');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  User? user;

  setUpAll(() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'smoke-$stamp@example.com', password: 'smoke-$stamp-pw');
    user = cred.user;
    debugPrint('SMOKE created temp user ${user?.uid}');
  });

  tearDownAll(() async {
    final u = user;
    if (u == null) return;
    final plays = await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('gamePlays')
        .get();
    for (final d in plays.docs) {
      await d.reference.delete();
    }
    await u.delete();
    debugPrint('SMOKE cleaned up ${plays.size} gamePlays doc(s) + user');
  });

  testWidgets('Daily movie game loads and accepts a guess', (tester) async {
    await tester.pumpWidget(_app(const DailyGameScreen()));
    await _wait(tester, 8);
    // First visit opens the how-to sheet; close it.
    final gotIt = find.text('Anladım');
    if (gotIt.evaluate().isNotEmpty) {
      await tester.tap(gotIt.first);
      await _wait(tester, 2);
    }
    _dumpTexts('daily');
    await _guess(tester, 'daily', 'Inception');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plot game loads and accepts a guess', (tester) async {
    await tester.pumpWidget(_app(const PlotGuessScreen()));
    await _wait(tester, 6);
    _dumpTexts('plot');
    await _guess(tester, 'plot', 'Titanic');
    expect(tester.takeException(), isNull);
  });

  testWidgets("Who's the Actor? loads and accepts a guess", (tester) async {
    await tester.pumpWidget(_app(const ActorGuessScreen()));
    await _wait(tester, 6);
    _dumpTexts('actor');
    await _guess(tester, 'actor', 'Tom Hanks');
    expect(tester.takeException(), isNull);
  });
}
