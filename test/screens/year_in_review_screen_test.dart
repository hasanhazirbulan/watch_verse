import 'dart:async';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/year_in_review_screen.dart';
import 'package:watch_verse/services/year_in_review.dart';
import 'package:watch_verse/services/year_in_review_source.dart';
import 'package:watch_verse/theme/app_theme.dart';

class _FakeSource implements YearInReviewSource {
  _FakeSource(this.input, {this.failFirst = false});
  final YearInReviewInput input;
  bool failFirst;
  final requested = <int>[];

  @override
  Future<YearInReviewInput> load(int year) async {
    requested.add(year);
    if (failFirst) {
      failFirst = false;
      throw Exception('offline');
    }
    return input;
  }
}

/// An image that never finishes loading (a stalled connection) or that
/// fails (404 / offline).
class _StuckImage extends ImageProvider<_StuckImage> {
  const _StuckImage({this.fail = false});
  final bool fail;

  @override
  Future<_StuckImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_StuckImage key, ImageDecoderCallback d) =>
      OneFrameImageStreamCompleter(
        fail
            ? Future<ImageInfo>.error(Exception('404'))
            : Completer<ImageInfo>().future,
      );
}

final _now = DateTime(2026, 10, 14, 12);

// No poster paths: TmdbImage then renders its static placeholder instead of
// trying the network / disk cache in tests.
YearInReviewInput _richInput() => YearInReviewInput(
  diaryEntries: [
    for (var i = 1; i <= 10; i++)
      {
        'mediaType': 'movie',
        'id': i,
        'title': 'A Film With A Rather Long Title Number $i',
        'rating': (i % 5) + 0.5,
        'watchedOn': DateTime(2026, i, 3, 21),
      },
    {
      'mediaType': 'movie',
      'id': 1,
      'title': 'A Film With A Rather Long Title Number 1',
      'watchedOn': DateTime(2026, 9, 3, 21),
    },
    {
      'mediaType': 'movie',
      'id': 2,
      'title': 'Last year',
      'watchedOn': DateTime(2024, 9, 3, 21),
    },
  ],
  movies: [
    for (var i = 1; i <= 10; i++)
      {
        'id': i,
        'title': 'A Film With A Rather Long Title Number $i',
        'status': 'watched',
        'runtime': 90 + i * 10,
        'genres': ['Science Fiction', 'Drama', 'Animation'],
      },
  ],
  shows: [
    {
      'id': 50,
      'name': 'An Extremely Long Television Show Name That Goes On',
      'watchedCount': 6,
      'watchedMinutes': 300,
      'genres': ['Comedy'],
    },
  ],
  episodes: [
    for (var e = 1; e <= 6; e++)
      EpisodeWatchRecord(
        showId: 50,
        season: 1,
        episode: e,
        watchedAt: DateTime(2026, 9, 3, 18),
      ),
  ],
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void _useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('renders every card on an iPhone SE without overflow', (
    tester,
  ) async {
    _useSmallPhone(tester);
    final source = _FakeSource(_richInput());
    await tester.pumpWidget(
      _wrap(YearInReviewScreen(source: source, clock: () => _now)),
    );
    await _settle(tester);

    expect(find.text('Your 2026 so far'), findsOneWidget);
    expect(find.text('11'), findsOneWidget); // film watches incl. rewatch
    expect(find.text('10 different films'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    for (final title in [
      'Top genres',
      'Busiest month',
      'Highest rated',
      'Most watched show',
      'First & latest',
      'Fun facts',
    ]) {
      await tester.scrollUntilVisible(find.text(title), 200, scrollable: list);
      await _settle(tester);
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(
      find.text(
        'Most rewatched: A Film With A Rather Long Title Number 1, 2 times',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.ios_share_rounded), findsWidgets);

    // Year picker offers 2024 (diary data) and switches years.
    await tester.tap(find.text('2026'));
    await _settle(tester);
    await tester.tap(find.text('2024').last);
    await _settle(tester);
    expect(source.requested, [2026, 2024]);
    expect(find.text('Your 2024 in film & TV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty year shows the empty state', (tester) async {
    _useSmallPhone(tester);
    await tester.pumpWidget(
      _wrap(
        YearInReviewScreen(
          source: _FakeSource(const YearInReviewInput()),
          clock: () => _now,
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Nothing logged in 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error shows retry, which reloads', (tester) async {
    _useSmallPhone(tester);
    final source = _FakeSource(_richInput(), failFirst: true);
    await tester.pumpWidget(
      _wrap(YearInReviewScreen(source: source, clock: () => _now)),
    );
    await _settle(tester);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await _settle(tester);
    expect(find.text('Your 2026 so far'), findsOneWidget);
    expect(source.requested.length, 2);
  });

  testWidgets('precacheForCapture gives up on stuck or failed posters', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    var done = false;
    unawaited(
      precacheForCapture(context, const [
        _StuckImage(),
        _StuckImage(fail: true),
      ]).then((_) => done = true),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(done, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(done, isTrue);
    expect(tester.takeException(), isNull);
    PaintingBinding.instance.imageCache.clear();
  });
}
