import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/streaming_services_screen.dart';
import 'package:watch_verse/screens/watchlist_screen.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/detail_sections.dart';

import '../streaming_fakes.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// iPhone SE (1st gen) logical size — the smallest screen we support.
void _useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

StreamingDeps _deps(FakePrefsStore prefs, StreamingDataSource source) =>
    StreamingDeps(
      prefs: prefs,
      source: source,
      cache: AvailabilityCache(),
      deviceCountry: () => 'DE',
    );

class _FlakyCatalogSource extends FakeStreamingSource {
  _FlakyCatalogSource()
    : super(
        catalogs: {
          'DE': const [netflix],
        },
      );
  int calls = 0;
  @override
  Future<List<WatchProvider>> catalog(String region) async {
    calls++;
    if (calls == 1) throw StateError('TMDB down');
    return super.catalog(region);
  }
}

Map<String, dynamic> _movie(int id, String title) => {
  'id': id,
  'title': title,
  'posterPath': '',
  'releaseDate': '2024-01-01',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('StreamingServicesScreen', () {
    final source = FakeStreamingSource(
      regionList: const [
        StreamingRegion(code: 'DE', name: 'Germany'),
        StreamingRegion(code: 'US', name: 'United States of America'),
      ],
      catalogs: const {
        'DE': [netflix, disney, mubi],
        'US': [disney],
      },
    );

    testWidgets('defaults to the device region and saves picks', (
      tester,
    ) async {
      _useSmallPhone(tester);
      final prefs = FakePrefsStore();
      await tester.pumpWidget(
        _wrap(StreamingServicesScreen(deps: _deps(prefs, source))),
      );
      await _settle(tester);

      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('MUBI'), findsOneWidget);
      expect(find.text('No services selected'), findsOneWidget);
      expect(find.text('Streaming data by JustWatch'), findsOneWidget);

      await tester.tap(find.text('Netflix'));
      await _settle(tester);
      expect(find.text('1 service selected'), findsOneWidget);
      expect(prefs.saves.last.region, 'DE');
      expect(prefs.saves.last.providerIds, {8});

      // Search narrows the list.
      await tester.enterText(find.byType(TextField), 'mu');
      await _settle(tester);
      expect(find.text('MUBI'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing region reloads the catalog and keeps picks', (
      tester,
    ) async {
      _useSmallPhone(tester);
      final prefs = FakePrefsStore(
        const StreamingPrefs(region: 'DE', providerIds: {337}),
      );
      await tester.pumpWidget(
        _wrap(StreamingServicesScreen(deps: _deps(prefs, source))),
      );
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('streaming-region')));
      await _settle(tester);
      await tester.tap(find.text('United States of America').last);
      await _settle(tester);

      expect(find.text('Netflix'), findsNothing);
      expect(find.text('Disney Plus'), findsOneWidget);
      expect(prefs.saves.last.region, 'US');
      expect(prefs.saves.last.providerIds, {337});
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed catalog load shows an error with retry', (
      tester,
    ) async {
      _useSmallPhone(tester);
      final flaky = _FlakyCatalogSource();
      await tester.pumpWidget(
        _wrap(StreamingServicesScreen(deps: _deps(FakePrefsStore(), flaky))),
      );
      await _settle(tester);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(find.text('Netflix'), findsOneWidget);
    });
  });

  group('Watchlist "On my services" filter', () {
    final movies = [
      _movie(1, 'Streaming Movie'),
      _movie(2, 'Other Service Movie'),
      _movie(3, 'Flaky Movie'),
    ];

    Future<void> pumpWatchlist(WidgetTester tester, StreamingDeps deps) async {
      _useSmallPhone(tester);
      await tester.pumpWidget(
        _wrap(
          WatchlistScreen(
            streamFor: (_) => Stream.value(movies),
            streamingDeps: deps,
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('filters to titles on the user\'s services, with badges', (
      tester,
    ) async {
      final source = FakeStreamingSource(
        availabilityById: {
          1: const [disney, netflix],
          2: const [disney],
        },
        failingIds: {3},
      );
      await pumpWatchlist(
        tester,
        _deps(
          FakePrefsStore(const StreamingPrefs(region: 'US', providerIds: {8})),
          source,
        ),
      );

      // Filter off: everything listed, no requests fired.
      expect(find.text('Streaming Movie'), findsOneWidget);
      expect(find.text('Flaky Movie'), findsOneWidget);
      expect(source.requests, isEmpty);

      await tester.tap(find.text('On my services'));
      await _settle(tester);

      expect(find.text('Streaming Movie'), findsOneWidget);
      expect(find.text('Other Service Movie'), findsNothing);
      expect(find.text('Flaky Movie'), findsNothing);
      expect(find.byKey(const ValueKey('streaming-badge')), findsOneWidget);
      expect(find.text("Couldn't check 1 title"), findsOneWidget);
      expect(find.text('Streaming data by JustWatch'), findsOneWidget);
      expect(source.maxInFlight, lessThanOrEqualTo(4));

      // Retry once TMDB recovers.
      source.failingIds = {};
      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(find.text("Couldn't check 1 title"), findsNothing);

      // Filter off again: all titles, badge kept on the matching one.
      await tester.tap(find.text('On my services'));
      await _settle(tester);
      expect(find.text('Other Service Movie'), findsOneWidget);
      expect(find.byKey(const ValueKey('streaming-badge')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a set-up prompt when no services are chosen', (
      tester,
    ) async {
      await pumpWatchlist(
        tester,
        _deps(FakePrefsStore(), FakeStreamingSource()),
      );
      await tester.tap(find.text('On my services'));
      await _settle(tester);
      expect(find.text('Choose your streaming services'), findsOneWidget);
      expect(find.text('Choose services'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows progress while checking', (tester) async {
      final source = FakeStreamingSource(delay: const Duration(seconds: 1));
      await pumpWatchlist(
        tester,
        _deps(
          FakePrefsStore(const StreamingPrefs(region: 'US', providerIds: {8})),
          source,
        ),
      );
      await tester.tap(find.text('On my services'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.textContaining('Checking 0/3'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);
      expect(
        find.text('Nothing here is streaming on your services right now.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('detail "Where to Watch" puts the user\'s services first', (
    tester,
  ) async {
    _useSmallPhone(tester);
    await tester.pumpWidget(
      _wrap(
        const Scaffold(
          body: WatchProvidersSection(
            providers: [disney, mubi, netflix],
            myProviderIds: {8},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('On your Netflix'), findsOneWidget);
    expect(find.text('Streaming data by JustWatch'), findsOneWidget);
    final tooltips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((t) => t.message)
        .toList();
    expect(tooltips.first, 'Netflix');
  });
}
