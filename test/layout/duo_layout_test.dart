// Layout smoke tests for every main screen at phone and iPhone Duo window
// sizes (outer 466x678, inner 669x951 / 951x669) plus a landscape phone.
// Each screen is pumped against an in-memory Firestore + fake TMDB and must
// lay out without overflow or exceptions.
//
// Set DUO_PNG_DIR=/some/dir to also write a PNG of each screen per window
// (real fonts) for eyeballing; nothing is written by default and no golden
// files are kept in the repo.
import 'dart:io';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/screens/actor_guess_screen.dart';
import 'package:watch_verse/screens/comments_screen.dart';
import 'package:watch_verse/screens/daily_game_screen.dart';
import 'package:watch_verse/screens/games/frames_game_screen.dart';
import 'package:watch_verse/screens/games/higher_lower_screen.dart';
import 'package:watch_verse/screens/games/plot_guess_screen.dart';
import 'package:watch_verse/screens/games/title_wordle_screen.dart';
import 'package:watch_verse/screens/common_ground_screen.dart';
import 'package:watch_verse/screens/edit_profile_screen.dart';
import 'package:watch_verse/screens/episode_detail_screen.dart';
import 'package:watch_verse/screens/fits_tonight_screen.dart';
import 'package:watch_verse/screens/games_hub_screen.dart';
import 'package:watch_verse/screens/history_screen.dart';
import 'package:watch_verse/screens/lists_screen.dart';
import 'package:watch_verse/screens/login.dart';
import 'package:watch_verse/screens/main_screen.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart';
import 'package:watch_verse/screens/person_screen.dart';
import 'package:watch_verse/screens/public_profile_screen.dart';
import 'package:watch_verse/screens/register.dart';
import 'package:watch_verse/screens/settings_screen.dart';
import 'package:watch_verse/screens/tv_detail_screen.dart';
import 'package:watch_verse/screens/watch_stats_screen.dart';
import 'package:watch_verse/screens/watched_movies_screen.dart';
import 'package:watch_verse/screens/year_in_review_screen.dart';
import 'package:watch_verse/services/app_firebase.dart';
import 'package:watch_verse/widgets/add_to_list_sheet.dart';
import 'package:watch_verse/widgets/paywall_sheet.dart';
import 'package:watch_verse/widgets/quick_add_sheet.dart';
import 'package:watch_verse/widgets/recap_sheet.dart';

import 'layout_harness.dart';

final _movie = Movie(
  id: 105,
  title: movieTitle(105),
  overview:
      'A gifted but restless cartographer is hired to map a city that redraws '
      'itself every night.',
  posterPath: '',
  backDropPath: '',
  releaseDate: '2024-03-01',
  voteAverage: 7.8,
);

MediaItem _tvSeed(int id) => MediaItem(
      id: id,
      title: showTitle(id),
      overview: '',
      posterPath: '',
      backdropPath: '',
      date: '2022-02-18',
      voteAverage: 8.1,
      mediaType: MediaType.tv,
    );

const _show = TvShow(
  id: 201,
  name: 'An Extremely Long Television Show Name 201',
  overview: 'Overview',
  posterPath: '',
  backdropPath: '',
  firstAirDate: '2022-02-18',
  lastAirDate: '',
  voteAverage: 8,
  numberOfSeasons: 1,
  numberOfEpisodes: 10,
  status: 'Returning Series',
  genres: ['Drama'],
  seasons: [],
);

Episode _ep(int n) => Episode(
      id: n,
      episodeNumber: n,
      seasonNumber: 1,
      name: 'The One Where Everything Changes $n',
      overview: 'Mark and Helly finally compare notes about the elevator.',
      stillPath: '',
      airDate: '2025-02-1$n',
      voteAverage: 7.9,
      runtime: 52,
    );

/// Hosts a button that opens a bottom sheet, so sheets are laid out the way
/// the app shows them (modal route, safe area, M3 width constraint).
class _SheetHost extends StatelessWidget {
  const _SheetHost(this.open);
  final void Function(BuildContext) open;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('open sheet'),
            ),
          ),
        ),
      );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open sheet'));
  await settle(tester);
}

Future<void> Function(WidgetTester) _tab(IconData icon) => (tester) async {
      await tester.tap(find.descendant(
          of: find.byType(CurvedNavigationBar), matching: find.byIcon(icon)));
      await settle(tester, frames: 20);
    };

class _Case {
  const _Case(this.name, this.build, {this.then});
  final String name;
  final Widget Function() build;
  final Future<void> Function(WidgetTester)? then;
}

final _cases = <_Case>[
  _Case('home', () => const MainScreen()),
  _Case('up_next', () => const MainScreen(),
      then: _tab(Icons.live_tv_rounded)),
  _Case('my_shows', () => const MainScreen(), then: (tester) async {
    await _tab(Icons.live_tv_rounded)(tester);
    await tester.tap(find.text('My Shows'));
    await settle(tester);
  }),
  _Case('upcoming', () => const MainScreen(), then: (tester) async {
    await _tab(Icons.live_tv_rounded)(tester);
    await tester.tap(find.text('Upcoming'));
    await settle(tester);
  }),
  _Case('watchlist', () => const MainScreen(),
      then: _tab(Icons.movie_rounded)),
  _Case('search', () => const MainScreen(), then: (tester) async {
    await _tab(Icons.search_rounded)(tester);
    await tester.enterText(find.byType(TextField), 'night');
    await settle(tester, frames: 20);
  }),
  _Case('profile', () => const MainScreen(),
      then: _tab(Icons.person_rounded)),
  _Case('movie_detail', () => MovieDetailsScreen(movie: _movie)),
  _Case('tv_detail', () => TvDetailScreen(seed: _tvSeed(201))),
  _Case('episode_detail',
      () => EpisodeDetailScreen(show: _show, episode: _ep(4))),
  _Case('settings', () => const SettingsScreen()),
  _Case('edit_profile', () => const EditProfileScreen()),
  _Case(
      'comments',
      () => CommentsScreen(
          mediaType: MediaType.movie, mediaId: 105, title: movieTitle(105))),
  _Case('games_hub', () => const GamesHubScreen()),
  _Case('daily_game', () => const DailyGameScreen()),
  _Case('title_wordle', () => const TitleWordleScreen()),
  _Case('frames', () => const FramesGameScreen()),
  _Case('plot_guess', () => const PlotGuessScreen()),
  _Case('higher_lower', () => const HigherLowerScreen()),
  _Case('actor_guess', () => const ActorGuessScreen()),
  _Case('year_in_review',
      () => YearInReviewScreen(clock: () => DateTime(2026, 10, 15))),
  _Case('fits_tonight', () => const FitsTonightScreen()),
  _Case('common_ground',
      () => const CommonGroundScreen(userId: friendUid, name: 'Sam Rivera')),
  _Case('public_profile',
      () => const PublicProfileScreen(userId: friendUid, name: 'Sam Rivera')),
  _Case('watch_stats', () => const WatchStatsScreen()),
  _Case('watched_movies', () => const WatchedMoviesScreen()),
  _Case('person', () => const PersonScreen(personId: 901, name: 'Actor 1')),
  _Case('lists', () => const ListsScreen()),
  _Case('history', () => const HistoryScreen()),
  _Case('login', () => const LoginScreen()),
  _Case('register', () => const RegisterScreen()),
  _Case(
      'quick_add_sheet',
      () => _SheetHost((c) => showQuickAddSheet(
          c,
          MediaItem(
              id: 105,
              title: movieTitle(105),
              overview: '',
              posterPath: '',
              backdropPath: '',
              date: '2024-03-01',
              voteAverage: 7.8,
              mediaType: MediaType.movie))),
      then: _openSheet),
  _Case(
      'add_to_list_sheet',
      () => _SheetHost((c) => showAddToListSheet(
          c,
          MediaItem(
              id: 105,
              title: movieTitle(105),
              overview: '',
              posterPath: '',
              backdropPath: '',
              date: '2024-03-01',
              voteAverage: 7.8,
              mediaType: MediaType.movie))),
      then: _openSheet),
  _Case(
      'recap_sheet',
      () => _SheetHost(
          (c) => showRecapSheet(c, _show, [for (var i = 1; i <= 6; i++) _ep(i)])),
      then: _openSheet),
  _Case('log_sheet', () => _SheetHost((c) => showMovieLogSheet(c, _movie)),
      then: _openSheet),
  _Case('paywall_sheet', () => _SheetHost(showPaywallSheet),
      then: _openSheet),
];

void main() {
  final pngDir = Platform.environment['DUO_PNG_DIR'];

  setUpAll(() async {
    await installFakeBackend();
    // Real glyph widths (SF Pro is close to Roboto): the default test font
    // draws every glyph as a 1em square, which overflows rows that are fine
    // on a device and hides the ones that aren't.
    await loadRealFonts();
  });

  tearDownAll(() {
    AppFirebase.firestoreOverride = null;
    AppFirebase.authOverride = null;
  });

  for (final c in _cases) {
    group(c.name, () {
      for (final window in allWindows) {
        testWidgets('lays out at $window', (tester) async {
          useWindow(tester, window);
          final boundary = GlobalKey();
          await withFakeTmdb(() async {
            await tester.pumpWidget(testApp(c.build(), boundaryKey: boundary));
            // Long enough for every fake fetch, including the detail
            // screens' streaming-region lookup (3 s timeout), to land.
            await settle(tester, frames: 45);
            await c.then?.call(tester);
            expect(tester.takeException(), isNull);
            if (pngDir != null) {
              final slug = window.name.toLowerCase().replaceAll(' ', '_');
              await capturePng(
                  tester, boundary, '$pngDir/${c.name}__$slug.png');
            }
            // Unmount inside the fake-TMDB zone so dispose-time work (and
            // any last fetches) still hit the fake.
            await tester.pumpWidget(const SizedBox());
            // Outlast the app's own fetch timeouts (e.g. the 3 s region
            // lookup) so no timer is left pending.
            await tester.pump(const Duration(seconds: 20));
          });
        }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
      }
    });
  }
}
