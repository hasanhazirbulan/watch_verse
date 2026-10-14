import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/games/higher_lower_screen.dart';
import 'package:watch_verse/screens/games/plot_guess_screen.dart';
import 'package:watch_verse/services/games/higher_lower_service.dart';
import 'package:watch_verse/services/games/plot_guess_logic.dart';
import 'package:watch_verse/services/games/plot_guess_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final s = files[key];
    if (s == null) throw StateError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(s)));
  }
}

Map<String, dynamic> _hl(int id, num value) => {
      'id': id,
      'title': 'A Rather Long Movie Title Number $id For Wrapping',
      'year': 2000 + id,
      'posterPath': '',
      'backdropPath': '',
      'value': value,
    };

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// iPhone SE (1st gen) logical size — the smallest phone we support.
void _useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1136);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Higher or Lower: tie counts, a miss ends the run (small phone)',
      (tester) async {
    _useSmallPhone(tester);
    final service = HigherLowerService(
      bundle: _Bundle({
        HigherLowerService.poolAsset: jsonEncode({
          'categories': {
            // All equal: every guess is a (correct) tie.
            'movieRating': [_hl(1, 7.5), _hl(2, 7.5), _hl(3, 7.5)],
            // Two values: at most two "Higher" taps before a miss.
            'tvRating': [_hl(4, 1), _hl(5, 2)],
          },
        }),
      }),
    );
    await tester.pumpWidget(_app(HigherLowerScreen(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Movie rating'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Higher'));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text('Score: 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Change category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TV show rating'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2 && find.text('Game over').evaluate().isEmpty; i++) {
      await tester.tap(find.text('Higher'));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
    }
    expect(find.text('Game over'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
  });

  testWidgets('Higher or Lower: leaving during the miss reveal keeps the best',
      (tester) async {
    _useSmallPhone(tester);
    final service = HigherLowerService(
      bundle: _Bundle({
        HigherLowerService.poolAsset: jsonEncode({
          'categories': {
            'tvRating': [_hl(4, 1), _hl(5, 2)],
          },
        }),
      }),
    );
    await tester.pumpWidget(_app(HigherLowerScreen(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TV show rating'));
    await tester.pumpAndSettle();

    // Two titles valued 1 and 2: whichever is on top, the right call now is
    // the wrong one next round (the two swap places).
    final call =
        find.text('1.0 ★').evaluate().isNotEmpty ? 'Higher' : 'Lower';
    await tester.tap(find.text(call));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text('Score: 1'), findsOneWidget);
    await tester.tap(find.text(call));
    await tester.pump();
    expect(find.text('Wrong!'), findsOneWidget);
    // Back out before the 900 ms reveal ends.
    await tester.tap(find.byTooltip('Change category'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('higher_lower_best_tvRating'), 1);
  });

  testWidgets('Plot: skipping through all attempts reveals the answer',
      (tester) async {
    _useSmallPhone(tester);
    final items = [
      {
        'id': 11,
        'title': 'Secret Film',
        'year': 1999,
        'genres': ['Drama', 'Thriller'],
        'cast': ['Lead Actor', 'Second Actor'],
        'tagline': 'Nothing is what it seems.',
        'overview': 'A $plotRedaction does something unusual on a long day '
            'at the office. Then everything goes wrong. Nobody is safe.',
        'posterPath': '',
      },
    ];
    final service = PlotGuessService.test(
      firestore: FakeFirebaseFirestore(),
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
      bundle: _Bundle({
        PlotGuessService.poolAsset(PlotGameMode.movie):
            jsonEncode({'items': items}),
        PlotGuessService.poolAsset(PlotGameMode.tv): jsonEncode({'items': []}),
      }),
    );
    await tester.pumpWidget(_app(PlotGuessScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.textContaining('long day at the office', findRichText: true),
        findsOneWidget);
    expect(find.text('6 guesses left'), findsOneWidget);

    // Keyboard up on a small phone: the guess bar must still fit.
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 216 * 2);
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    for (var i = 0; i < plotGameMaxAttempts; i++) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Skip'), findsNothing); // guess bar gone
    await tester.scrollUntilVisible(find.text('Out of guesses'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Out of guesses'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Share result'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Secret Film'), findsOneWidget);

    // TV mode has an empty pool → friendly message, no crash.
    await tester.tap(find.text('TV'));
    await tester.pumpAndSettle();
    expect(find.textContaining("isn't available"), findsOneWidget);
  });
}
