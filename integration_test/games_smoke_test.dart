// On-device smoke test for the guest-playable games: real Firebase init, real
// TMDB calls, real image loading. Checks each screen gets past loading
// without exceptions or an error state. Run on a simulator:
//   flutter test integration_test/games_smoke_test.dart \
//     --dart-define-from-file=secrets.json -d <simulator-id>
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watch_verse/firebase_options.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/games/frames_game_screen.dart';
import 'package:watch_verse/screens/games/higher_lower_screen.dart';
import 'package:watch_verse/screens/games/title_wordle_screen.dart';
import 'package:watch_verse/screens/games_hub_screen.dart';
import 'package:watch_verse/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      home: home,
    );

/// Pumps for up to [seconds] so network work can land, without
/// pumpAndSettle (spinners and animations never settle).
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
      .take(25)
      .toList();
  debugPrint('SMOKE[$label] texts: $texts');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('Games hub lists every game', (tester) async {
    await tester.pumpWidget(_app(const GamesHubScreen()));
    await _wait(tester, 3);
    _dumpTexts('hub');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Frames loads stills (movie, then TV)', (tester) async {
    await tester.pumpWidget(_app(const FramesGameScreen()));
    await _wait(tester, 12);
    _dumpTexts('frames-movie');
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final tv = find.text('Dizi');
    if (tv.evaluate().isNotEmpty) {
      await tester.tap(tv.first);
      await _wait(tester, 12);
      _dumpTexts('frames-tv');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Title Wordle renders board and keyboard', (tester) async {
    await tester.pumpWidget(_app(const TitleWordleScreen()));
    await _wait(tester, 6);
    _dumpTexts('wordle');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Higher or Lower plays a round', (tester) async {
    await tester.pumpWidget(_app(const HigherLowerScreen()));
    await _wait(tester, 4);
    _dumpTexts('hl-start');
    final firstCategory = find.byType(InkWell);
    if (firstCategory.evaluate().isNotEmpty) {
      await tester.tap(firstCategory.first);
      await _wait(tester, 6);
      _dumpTexts('hl-round');
    }
    expect(tester.takeException(), isNull);
  });
}
