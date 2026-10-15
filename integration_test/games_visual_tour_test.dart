// Visual tour of the Games hub and the five non-daily games, for checking
// the UI by eye on a simulator. Signs in a throwaway Firebase Auth user (Plot
// and Who's the Actor? need an account), plays each game to its result card
// while holding a few seconds at the key states, then deletes the user's
// gamePlays docs, its users/{uid} doc and the account.
//
// Grab screenshots from another shell while it runs, e.g.
//   while true; do xcrun simctl io <udid> screenshot "shots/$(date +%s).png"; sleep 1.5; done
// and match them to the `TOUR[...]` lines this prints. Run:
//   flutter test integration_test/games_visual_tour_test.dart \
//     --dart-define-from-file=secrets.json -d <simulator-id>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watch_verse/firebase_options.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/actor_guess_screen.dart';
import 'package:watch_verse/screens/games/frames_game_screen.dart';
import 'package:watch_verse/screens/games/higher_lower_screen.dart';
import 'package:watch_verse/screens/games/plot_guess_screen.dart';
import 'package:watch_verse/screens/games/title_wordle_screen.dart';
import 'package:watch_verse/screens/games_hub_screen.dart';
import 'package:watch_verse/services/actor_guess_service.dart';
import 'package:watch_verse/services/games/game_day.dart';
import 'package:watch_verse/services/games/pools/title_wordle_pools.g.dart';
import 'package:watch_verse/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

Future<void> _wait(WidgetTester tester, num seconds) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Marks a state worth a screenshot and holds on it.
Future<void> _hold(WidgetTester tester, String label, [num seconds = 3]) async {
  await _wait(tester, 0.75);
  debugPrint('TOUR[$label] at ${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
  await _wait(tester, seconds);
  expect(tester.takeException(), isNull, reason: label);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    debugPrint('TOUR no "$text" to tap');
    return;
  }
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first, warnIfMissed: false);
  await _wait(tester, 1.5);
}

/// Types [query] into the (first) search field and taps the first result
/// that isn't [avoid].
Future<void> _searchAndPick(WidgetTester tester, String label, String query,
    {String? avoid, num holdResults = 0}) async {
  final field = find.byType(TextField);
  if (field.evaluate().isEmpty) {
    debugPrint('TOUR[$label] no search field');
    return;
  }
  await tester.tap(field.first);
  await tester.enterText(field.first, query);
  await _wait(tester, 4);
  if (holdResults > 0) await _hold(tester, '$label-results', holdResults);
  final tiles = find.byType(ListTile).evaluate().toList();
  for (final t in tiles) {
    final tile = t.widget as ListTile;
    final title = tile.title is Text ? (tile.title as Text).data : null;
    if (avoid != null && title == avoid) continue;
    if (tile.enabled == false) continue;
    await tester.tap(find.byWidget(tile), warnIfMissed: false);
    await _wait(tester, 3);
    return;
  }
  debugPrint('TOUR[$label] nothing pickable for "$query"');
  FocusManager.instance.primaryFocus?.unfocus();
  await _wait(tester, 1);
}

Future<void> _typeWord(WidgetTester tester, String letters) async {
  for (final ch in letters.split('')) {
    final key = LogicalKeyboardKey.findKeyByKeyId(
        LogicalKeyboardKey.keyA.keyId + ch.codeUnitAt(0) - 'A'.codeUnitAt(0));
    await tester.sendKeyEvent(key!);
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  User? user;

  setUpAll(() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'tour-$stamp@example.com', password: 'tour-$stamp-pw');
    user = cred.user;
    debugPrint('TOUR created temp user ${user?.uid}');
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
    await FirebaseFirestore.instance.collection('users').doc(u.uid).delete();
    await u.delete();
    debugPrint('TOUR cleaned up ${plays.size} gamePlays doc(s) + user');
  });

  testWidgets('Games hub (fresh)', (tester) async {
    await tester.pumpWidget(_app(const GamesHubScreen()));
    await _hold(tester, 'hub-fresh', 4);
  });

  testWidgets('Frames', (tester) async {
    await tester.pumpWidget(_app(const FramesGameScreen()));
    await _wait(tester, 8);
    await _hold(tester, 'frames-start');
    await _searchAndPick(tester, 'frames', 'Titanic', holdResults: 3);
    await _hold(tester, 'frames-after-wrong');
    for (var i = 0; i < 6; i++) {
      if (find.text('Skip').evaluate().isEmpty) break;
      await _tapText(tester, 'Skip');
    }
    await _wait(tester, 3);
    await _hold(tester, 'frames-result', 4);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await _hold(tester, 'frames-result-scrolled');
  });

  testWidgets('Title Wordle', (tester) async {
    final answer = dailyPoolEntry(titleWordleMoviePool,
            gamePuzzleNumber(DateTime.now().toUtc()))
        .letters;
    await tester.pumpWidget(_app(const TitleWordleScreen()));
    await _wait(tester, 4);
    await _hold(tester, 'wordle-start');
    // A wrong guess: the answer's letters rotated by one.
    final wrong = answer.substring(1) + answer[0];
    await _typeWord(tester, wrong);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _hold(tester, 'wordle-after-wrong');
    await _typeWord(tester, answer.substring(0, 3));
    await _hold(tester, 'wordle-typing');
    await _typeWord(tester, answer.substring(3));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _wait(tester, 2);
    await _hold(tester, 'wordle-won', 4);
  });

  testWidgets('Higher or Lower', (tester) async {
    await tester.pumpWidget(_app(const HigherLowerScreen()));
    await _wait(tester, 3);
    await _hold(tester, 'hl-categories');
    await _tapText(tester, 'Movie rating');
    await _hold(tester, 'hl-round');
    for (var i = 0; i < 12; i++) {
      final higher = find.text('Higher');
      if (higher.evaluate().isEmpty) break;
      await tester.tap(higher.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      if (i == 0) await _hold(tester, 'hl-reveal', 0);
      await _wait(tester, 2);
    }
    await _wait(tester, 2);
    await _hold(tester, 'hl-gameover', 4);
  });

  testWidgets('Plot', (tester) async {
    await tester.pumpWidget(_app(const PlotGuessScreen()));
    await _wait(tester, 5);
    await _hold(tester, 'plot-start');
    await _searchAndPick(tester, 'plot', 'Titanic', holdResults: 3);
    await _hold(tester, 'plot-after-wrong');
    for (var i = 0; i < 6; i++) {
      if (find.text('Skip').evaluate().isEmpty) break;
      await _tapText(tester, 'Skip');
      if (i == 1) await _hold(tester, 'plot-midgame');
    }
    await _wait(tester, 2);
    await _hold(tester, 'plot-result', 4);
  });

  testWidgets("Who's the Actor?", (tester) async {
    final puzzle =
        await ActorGuessService.instance.puzzleFor(DateTime.now().toUtc());
    await tester.pumpWidget(_app(const ActorGuessScreen()));
    await _wait(tester, 5);
    await _hold(tester, 'actor-start');
    const names = [
      'Tom Hanks',
      'Meryl Streep',
      'Denzel Washington',
      'Scarlett Johansson',
      'Keanu Reeves',
      'Cate Blanchett',
      'Samuel L. Jackson',
    ];
    var n = 0;
    for (final name in names) {
      if (name == puzzle?.name) continue;
      if (find.byType(TextField).evaluate().isEmpty) break;
      await _searchAndPick(tester, 'actor', name,
          avoid: puzzle?.name, holdResults: n == 0 ? 3 : 0);
      n++;
      if (n == 2) await _hold(tester, 'actor-midgame');
    }
    await _wait(tester, 2);
    await _hold(tester, 'actor-result', 4);
  });

  testWidgets('Games hub (after playing)', (tester) async {
    await tester.pumpWidget(_app(const GamesHubScreen()));
    await _wait(tester, 3);
    await _hold(tester, 'hub-played', 4);
  });
}
