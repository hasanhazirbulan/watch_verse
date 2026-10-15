import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/recap_sheet.dart';

const _show = TvShow(
  id: 1,
  name: 'Severance',
  overview: '',
  posterPath: '',
  backdropPath: '',
  firstAirDate: '2022-02-18',
  lastAirDate: '',
  voteAverage: 8,
  numberOfSeasons: 1,
  numberOfEpisodes: 3,
  status: '',
  genres: [],
  seasons: [],
);

Episode _ep(int n, String overview) => Episode(
      id: n,
      episodeNumber: n,
      seasonNumber: 1,
      name: 'Episode $n title',
      overview: overview,
      stillPath: '',
      airDate: '2022-02-18',
      voteAverage: 0,
      runtime: 50,
    );

final _flat = [_ep(1, 'Overview one'), _ep(2, ''), _ep(3, 'SPOILER three')];

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows only watched episodes, dates and episode cast',
      (tester) async {
    final castRequests = <String>[];
    await tester.pumpWidget(_wrap(RecapSheet(
      show: _show,
      flat: _flat,
      loadHistory: (_) async => {
        's1e1': DateTime(2026, 8, 1),
        's1e2': DateTime(2026, 8, 3),
      },
      loadCast: (id, s, e) async {
        castRequests.add('s${s}e$e');
        return const [
          CastMember(
              id: 7, name: 'Adam Scott', character: 'Mark S.', profilePath: ''),
        ];
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('Where you left off'), findsOneWidget);
    expect(find.text('Episode 1 title'), findsOneWidget);
    expect(find.text('Episode 2 title'), findsOneWidget);
    expect(find.text('Overview one'), findsOneWidget);
    expect(find.text('No synopsis available for this episode.'),
        findsOneWidget);
    expect(find.text('Watched Aug 3, 2026'), findsOneWidget);
    // Never anything about the unwatched episode.
    expect(find.text('Episode 3 title'), findsNothing);
    expect(find.text('SPOILER three'), findsNothing);
    // Cast comes from the latest watched episode.
    expect(castRequests, ['s1e2']);
    expect(find.text('Adam Scott'), findsOneWidget);
    expect(find.text('Mark S.'), findsOneWidget);
  });

  testWidgets('offline: history failure shows a message, no crash',
      (tester) async {
    await tester.pumpWidget(_wrap(RecapSheet(
      show: _show,
      flat: _flat,
      loadHistory: (_) async => throw Exception('offline'),
      loadCast: (_, _, _) async => const [],
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't load your watch history"),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cast failure just hides the cast', (tester) async {
    await tester.pumpWidget(_wrap(RecapSheet(
      show: _show,
      flat: _flat,
      loadHistory: (_) async => {'s1e1': DateTime(2026, 8, 1)},
      loadCast: (_, _, _) async => throw Exception('offline'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Episode 1 title'), findsOneWidget);
    expect(find.text('Cast'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
