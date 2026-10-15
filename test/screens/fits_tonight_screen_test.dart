import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/fits_tonight_screen.dart';
import 'package:watch_verse/services/fits_tonight_logic.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

import '../streaming_fakes.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

StreamingDeps _deps({
  StreamingPrefs prefs = StreamingPrefs.empty,
  Map<int, List<WatchProvider>> availability = const {},
}) => StreamingDeps(
  prefs: FakePrefsStore(prefs),
  source: FakeStreamingSource(availabilityById: availability),
  cache: AvailabilityCache(),
  deviceCountry: () => 'DE',
);

FitsMovie _movie(int id, String title, int runtime) => FitsMovie(
  id: id,
  title: title,
  runtime: runtime,
  payload: {'id': id, 'title': title, 'posterPath': '', 'releaseDate': ''},
);

FitsShow _show(int id, String name, List<int> runtimes) {
  final eps = [
    for (var i = 0; i < runtimes.length; i++)
      Episode(
        id: id * 100 + i,
        episodeNumber: i + 1,
        seasonNumber: 1,
        name: 'Ep ${i + 1}',
        overview: '',
        stillPath: '',
        airDate: '2024-01-01',
        voteAverage: 0,
        runtime: runtimes[i],
      ),
  ];
  return FitsShow(
    id: id,
    name: name,
    unwatched: [
      for (final e in eps)
        FitsEpisode(
          season: e.seasonNumber,
          episode: e.episodeNumber,
          runtime: e.runtime,
        ),
    ],
    payload: FitsTonightShow(TvShow.fromMap({'id': id, 'name': name}), eps),
  );
}

Widget _screen(FitsTonightData data, {StreamingDeps? deps, int budget = 90}) =>
    FitsTonightScreen(
      load: () async => data,
      isSignedIn: () => true,
      streamingDeps: deps ?? _deps(),
      initialBudget: budget,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guests get a sign-in empty state', (tester) async {
    await tester.pumpWidget(
      _wrap(FitsTonightScreen(isSignedIn: () => false, streamingDeps: _deps())),
    );
    await _settle(tester);
    expect(
      find.text(
        'Sign in to see what fits tonight from your watchlist and your shows.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty lists get an empty state', (tester) async {
    await tester.pumpWidget(
      _wrap(_screen(const FitsTonightData(movies: [], shows: []))),
    );
    await _settle(tester);
    expect(find.text('Nothing to pick from yet'), findsOneWidget);
  });

  testWidgets('lists episode runs and movies that fit the budget', (
    tester,
  ) async {
    final data = FitsTonightData(
      movies: [
        _movie(1, 'Short One', 85),
        _movie(2, 'Epic', 170),
        _movie(3, 'Mystery Cut', 0),
      ],
      shows: [
        _show(10, 'Severance', [45, 40, 45, 50]),
      ],
    );
    await tester.pumpWidget(_wrap(_screen(data, budget: 135)));
    await _settle(tester);

    expect(find.text('2h 15m'), findsWidgets);
    expect(find.text('Severance'), findsOneWidget);
    expect(find.text('3 episodes · 2h 10m'), findsOneWidget);
    expect(find.text('S1 E1–3'), findsOneWidget);
    expect(find.text('Short One'), findsOneWidget);
    expect(find.text('Epic'), findsNothing);
    expect(find.text('Runtime unknown'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mystery Cut'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Mystery Cut'), findsOneWidget);

    // Bigger budget: the long movie now fits too.
    await tester.tap(find.text('3h'));
    await _settle(tester);
    expect(find.text('Epic'), findsOneWidget);
    expect(find.text('4 episodes · 3h'), findsOneWidget);
  });

  testWidgets('nothing fits offers to stretch the budget', (tester) async {
    final data = FitsTonightData(
      movies: [_movie(1, 'Long Film', 112)],
      shows: const [],
    );
    await tester.pumpWidget(_wrap(_screen(data, budget: 60)));
    await _settle(tester);

    expect(find.text('Nothing fits in 1h'), findsOneWidget);
    expect(
      find.text('The shortest thing on your lists is 1h 52m.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Make it 2h'));
    await _settle(tester);
    expect(find.text('Long Film'), findsOneWidget);
  });

  testWidgets('"On my services" keeps only titles on the user\'s services', (
    tester,
  ) async {
    final data = FitsTonightData(
      movies: [_movie(1, 'On Netflix', 80), _movie(2, 'Elsewhere', 80)],
      shows: [
        _show(10, 'Streaming Show', [30]),
      ],
    );
    final deps = _deps(
      prefs: const StreamingPrefs(region: 'DE', providerIds: {8}),
      availability: {
        1: const [netflix],
        2: const [mubi],
        10: const [netflix],
      },
    );
    await tester.pumpWidget(_wrap(_screen(data, deps: deps)));
    await _settle(tester);
    expect(find.text('Elsewhere'), findsOneWidget);

    await tester.tap(find.text('On my services'));
    await _settle(tester);
    expect(find.text('On Netflix'), findsOneWidget);
    expect(find.text('Streaming Show'), findsOneWidget);
    expect(find.text('Elsewhere'), findsNothing);
  });
}
