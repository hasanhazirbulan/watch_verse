import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/common_ground_screen.dart';
import 'package:watch_verse/screens/create_watch_poll_screen.dart';
import 'package:watch_verse/services/common_ground_source.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

import '../streaming_fakes.dart';

class _FakeSource implements CommonGroundSource {
  _FakeSource(this.data);
  final CommonGroundData data;
  @override
  Future<CommonGroundData> load(
          {required String myUid, required String theirUid}) async =>
      data;
}

Map<String, dynamic> _movie(int id, String title,
        {String status = 'watchlist', double? rating}) =>
    {
      'id': id,
      'title': title,
      'posterPath': '',
      'releaseDate': '2021-01-01',
      'status': status,
      'rating': ?rating,
    };

class _PushObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

Widget _wrap(Widget child, {NavigatorObserver? observer}) => MaterialApp(
      theme: AppTheme.dark,
      navigatorObservers: [?observer],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

StreamingDeps _deps(StreamingPrefs prefs, FakeStreamingSource source) =>
    StreamingDeps(
      prefs: FakePrefsStore(prefs),
      source: source,
      cache: AvailabilityCache(),
      deviceCountry: () => 'DE',
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final overlapping = CommonGroundData(
    theirWatchlistMovies: [_movie(1, 'Alpha'), _movie(2, 'Bravo')],
    theirWatchlistShows: const [],
    theirRatedMovies: [
      _movie(3, 'Charlie', status: 'watched', rating: 4),
      _movie(4, 'Delta', status: 'watched', rating: 1),
    ],
    myMoviesById: {
      1: _movie(1, 'Alpha'),
      2: _movie(2, 'Bravo'),
      3: _movie(3, 'Charlie', status: 'watched', rating: 4.5),
      4: _movie(4, 'Delta', status: 'watched', rating: 5),
    },
    myShowsById: const {},
  );

  testWidgets('shows shared titles, agreement and opens a prefilled poll',
      (tester) async {
    final observer = _PushObserver();
    await tester.pumpWidget(_wrap(observer: observer, CommonGroundScreen(
      userId: 'them',
      name: 'Sam Lee',
      myUid: 'me',
      source: _FakeSource(overlapping),
      streamingDeps: _deps(StreamingPrefs.empty, FakeStreamingSource()),
    )));
    await _settle(tester);

    expect(find.text('You & Sam Lee'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text('You agree on 1 of 2'), findsOneWidget);
    expect(find.text('You ★4.5 · Sam ★4'), findsOneWidget);
    expect(find.text('You ★5 · Sam ★1'), findsOneWidget);
    // No services set up → no ranking note.
    expect(find.text('Titles on your streaming services come first.'),
        findsNothing);

    // Checked without building the poll screen (it needs Firebase): the
    // route is recorded synchronously on push, before the next frame.
    final route = observer.pushed.length;
    await tester.tap(find.byKey(const ValueKey('common-ground-start-poll')));
    expect(observer.pushed, hasLength(route + 1));
    final page = (observer.pushed.last as MaterialPageRoute<dynamic>)
        .builder(tester.element(find.byType(CommonGroundScreen)));
    expect(page, isA<CreateWatchPollScreen>());
    expect((page as CreateWatchPollScreen).initialOptions.map((m) => m.id),
        [1, 2]);
  });

  testWidgets('ranks titles on my services first', (tester) async {
    final source = FakeStreamingSource(availabilityById: const {
      2: [netflix],
      1: [mubi],
    });
    await tester.pumpWidget(_wrap(CommonGroundScreen(
      userId: 'them',
      name: 'Sam',
      myUid: 'me',
      source: _FakeSource(overlapping),
      streamingDeps: _deps(
          const StreamingPrefs(region: 'DE', providerIds: {8}), source),
    )));
    await _settle(tester);

    expect(find.text('Titles on your streaming services come first.'),
        findsOneWidget);
    final alpha = tester.getTopLeft(find.text('Alpha')).dx;
    final bravo = tester.getTopLeft(find.text('Bravo')).dx;
    expect(bravo, lessThan(alpha));
    expect(find.byKey(const ValueKey('streaming-badge')), findsOneWidget);
  });

  testWidgets('empty states when nothing overlaps', (tester) async {
    await tester.pumpWidget(_wrap(CommonGroundScreen(
      userId: 'them',
      name: 'Sam',
      myUid: 'me',
      source: _FakeSource(const CommonGroundData(
        theirWatchlistMovies: [],
        theirWatchlistShows: [],
        theirRatedMovies: [],
        myMoviesById: {},
        myShowsById: {},
      )),
      streamingDeps: _deps(StreamingPrefs.empty, FakeStreamingSource()),
    )));
    await _settle(tester);

    expect(find.textContaining('Nothing is on both your watchlists'),
        findsOneWidget);
    expect(find.text("You haven't rated any of the same films yet."),
        findsOneWidget);
    expect(find.byKey(const ValueKey('common-ground-start-poll')),
        findsNothing);
  });
}
