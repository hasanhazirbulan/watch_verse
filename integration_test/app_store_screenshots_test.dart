// App Store screenshots from the real app with a realistic library.
//
// Creates two throwaway accounts — "Leo" (a friend) and "Maya" (the one the
// screenshots are taken as) — and fills them through the real import path
// (Letterboxd-style diary/watchlist CSVs → LibraryImportService against
// TMDB + Firestore), tracks a few TV shows with dated episode history, sets
// Maya's streaming services, then drives the app (MainScreen and its tabs)
// to eight screens and captures each one. Every created account is deleted
// through AccountDeletionService in tearDownAll; the temp emails/passwords
// are printed (`SHOTS account …`) so an interrupted run can be cleaned up by
// signing in with them and deleting the account.
//
// Device-independent: run it unchanged on any simulator (iPhone 6.3"/6.9",
// iPad, iPhone Duo outer/inner display). The whole run, including the clean
// status bar and alpha-free PNGs, is wrapped by:
//   tool/app_store_screenshots.sh <simulator-udid> build/screenshots/iphone_6_3
//
// Capture modes (--dart-define=SCREENSHOT_CAPTURE=…):
//  * `binding` (default): IntegrationTestWidgetsFlutterBinding.takeScreenshot;
//    the bytes reach the host through test_driver/screenshot_driver.dart,
//    which writes $SCREENSHOT_DIR/<name>.png. iOS renders only the app's
//    windows, so there's no status bar.
//  * `simctl`: prints `WVSHOT <name>` and holds the screen still for a few
//    seconds so the host (the script above) grabs it with
//    `xcrun simctl io <udid> screenshot` — full device pixels including the
//    overridden 9:41 status bar.
// Plain run:
//   flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/app_store_screenshots_test.dart \
//     -d <udid> --dart-define-from-file=secrets.json
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Type;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watch_verse/firebase_options.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/games_hub_screen.dart';
import 'package:watch_verse/screens/home_screen.dart';
import 'package:watch_verse/screens/main_screen.dart';
import 'package:watch_verse/screens/profile_screen.dart';
import 'package:watch_verse/screens/public_profile_screen.dart';
import 'package:watch_verse/screens/year_in_review_screen.dart';
import 'package:watch_verse/services/account_deletion_service.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/common_ground.dart';
import 'package:watch_verse/services/import/import_models.dart';
import 'package:watch_verse/services/import/import_parser.dart';
import 'package:watch_verse/services/import/library_import_service.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/utils/responsive.dart';

const _captureMode =
    String.fromEnvironment('SCREENSHOT_CAPTURE', defaultValue: 'binding');

/// Seconds the screen is held still after a `WVSHOT` line (simctl mode).
const _simctlHold = 4;

// ------------------------------------------------------------- demo data ----

/// (title, release year, Maya's rating). Watch dates are spread across the
/// current year in this order.
const _mayaWatched = <(String, int, double)>[
  ('Past Lives', 2023, 5),
  ('The Holdovers', 2023, 4.5),
  ('Perfect Days', 2023, 4.5),
  ('Anatomy of a Fall', 2023, 4.5),
  ('The Zone of Interest', 2023, 4),
  ('Poor Things', 2023, 4),
  ('Godzilla Minus One', 2023, 4),
  ('Oppenheimer', 2023, 4.5),
  ('Aftersun', 2022, 5),
  ('Barbie', 2023, 3.5),
  ('The Boy and the Heron', 2023, 4),
  ('Robot Dreams', 2023, 4.5),
  ('American Fiction', 2023, 4),
  ('The Iron Claw', 2023, 3.5),
  ('Challengers', 2024, 4.5),
  ('Civil War', 2024, 3.5),
  ('Furiosa: A Mad Max Saga', 2024, 4),
  ('Love Lies Bleeding', 2024, 3.5),
  ('The Fall Guy', 2024, 3.5),
  ('Inside Out 2', 2024, 4),
  ('Deadpool & Wolverine', 2024, 3),
  ('The Substance', 2024, 4),
  ('The Wild Robot', 2024, 4.5),
  ('Anora', 2024, 4.5),
  ('Wicked', 2024, 3.5),
  ('Nosferatu', 2024, 4),
  ('A Complete Unknown', 2024, 4),
  ('Mickey 17', 2025, 3.5),
  ('Sinners', 2025, 5),
  ('Thunderbolts*', 2025, 3.5),
  ('Mission: Impossible - The Final Reckoning', 2025, 3.5),
  ('The Phoenician Scheme', 2025, 3.5),
  ('28 Years Later', 2025, 4),
  ('Superman', 2025, 4),
  ('Eddington', 2025, 3),
  ('Weapons', 2025, 4.5),
  ('One Battle After Another', 2025, 5),
  ('Frankenstein', 2025, 4),
  // Last, so Home's "Because you watched" rail is seeded by it.
  ('Dune: Part Two', 2024, 5),
];

/// Maya's To Watch list — mostly runtimes that fit a 2-hour evening.
const _mayaWatchlist = <(String, int)>[
  ('The Brutalist', 2024),
  ('A Real Pain', 2024),
  ('Flow', 2024),
  ('Sing Sing', 2024),
  ('Conclave', 2024),
  ('Nickel Boys', 2024),
  ('Companion', 2025),
  ('Materialists', 2025),
  ('Sorry Baby', 2025),
  ('Bugonia', 2025),
  ('Hamnet', 2025),
  ('Sentimental Value', 2025),
];

const _leoWatched = <(String, int, double)>[
  ('Past Lives', 2023, 4.5),
  ('Anatomy of a Fall', 2023, 4.5),
  ('Oppenheimer', 2023, 4),
  ('Poor Things', 2023, 2.5),
  ('Barbie', 2023, 4.5),
  ('The Holdovers', 2023, 4),
  ('Dune: Part Two', 2024, 5),
  ('Challengers', 2024, 4),
  ('Furiosa: A Mad Max Saga', 2024, 4.5),
  ('Anora', 2024, 4),
  ('Wicked', 2024, 2),
  ('Sinners', 2025, 5),
  ('Superman', 2025, 3),
  ('Weapons', 2025, 4),
  ('One Battle After Another', 2025, 4.5),
];

const _leoWatchlist = <(String, int)>[
  ('The Brutalist', 2024),
  ('Conclave', 2024),
  ('Flow', 2024),
  ('Nickel Boys', 2024),
  ('Hamnet', 2025),
  ('Sentimental Value', 2025),
  ('Bugonia', 2025),
  ('Train Dreams', 2025),
];

/// Tracked shows: TMDB id, aired episodes watched (in airing order, specials
/// excluded) and how many days ago the last one was watched. Severance's 45
/// days makes Up Next offer its "Recap" (the only show past the 30-day
/// threshold).
const _shows = <(int, String, int, int)>[
  (126308, 'Shōgun', 5, 1),
  (136315, 'The Bear', 22, 3),
  (100088, 'The Last of Us', 12, 6),
  (83867, 'Andor', 15, 11),
  (95396, 'Severance', 15, 45),
  // Older next episodes, so they sort below Severance on phones; they fill
  // the three-column Up Next grid on iPad.
  (106379, 'Fallout', 4, 8),
  (95480, 'Slow Horses', 8, 14),
  (111803, 'The White Lotus', 7, 20),
  (97546, 'Ted Lasso', 10, 25),
];

/// US streaming services: Netflix, Hulu, Apple TV+, Max.
const _providerIds = {8, 15, 350, 1899};

const _featuredMovie = 'Dune: Part Two';

// --------------------------------------------------------------- helpers ----

String _q(String s) => '"${s.replaceAll('"', '""')}"';
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _slug(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

/// Letterboxd-format diary.csv + watchlist.csv for [watched] / [watchlist],
/// with watch dates spread from early in the current year to a few days ago.
List<ImportFile> _letterboxdFiles(List<(String, int, double)> watched,
    List<(String, int)> watchlist, DateTime now) {
  final start = DateTime(now.year, 1, 4);
  final end = now.subtract(const Duration(days: 2));
  final span = end.difference(start).inDays;
  final diary = StringBuffer(
      'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n');
  for (var i = 0; i < watched.length; i++) {
    final (title, year, rating) = watched[i];
    final day = start.add(Duration(
        days: watched.length == 1 ? 0 : (span * i) ~/ (watched.length - 1)));
    diary.writeln('${_ymd(day)},${_q(title)},$year,'
        'https://boxd.it/${_slug(title)},$rating,,,${_ymd(day)}');
  }
  final list = StringBuffer('Date,Name,Year,Letterboxd URI\n');
  for (final (title, year) in watchlist) {
    list.writeln('${_ymd(end)},${_q(title)},$year,'
        'https://letterboxd.com/film/${_slug(title)}/');
  }
  return [
    ImportFile('diary.csv', utf8.encode(diary.toString())),
    ImportFile('watchlist.csv', utf8.encode(list.toString())),
  ];
}

Future<void> _import(String who, List<ImportFile> files) async {
  final parsed = parseImportFiles(files);
  final importer = LibraryImportService();
  final summary = await importer.run(parsed);
  debugPrint('SHOTS[$who] imported watched=${summary.moviesWatched} '
      'watchlist=${summary.watchlist} ratings=${summary.ratings} '
      'unmatched=${summary.unmatched.map((u) => '${u.title} (${u.year})'
          '${u.lookupFailed ? ' lookup failed' : ''}').toList()}');
  await importer.detailsBackfill;
}

/// Tracks each of [_shows] with a dated episode history (show doc, watched
/// episode docs and activity entries — the same shape TvTrackingService
/// writes, but back-dated).
Future<void> _seedShows(String uid, DateTime now) async {
  final db = FirebaseFirestore.instance;
  final userRef = db.collection('users').doc(uid);
  final api = APIservices();
  for (final (id, name, count, daysAgo) in _shows) {
    final show = await api.getTvDetails(id);
    final aired = <Episode>[];
    for (final s in show.seasons.where((s) => s.seasonNumber > 0)) {
      final eps = await api.getSeasonEpisodes(id, s.seasonNumber);
      aired.addAll(eps.where((e) => e.hasAired));
    }
    // Always leave at least one aired episode to watch next.
    final n = count.clamp(1, aired.length - 1);
    final last = now.subtract(Duration(days: daysAgo, hours: 3));
    final watchedAt = <DateTime>[];
    for (var i = 0; i < n; i++) {
      // Two episodes an evening, one evening every ~3 days, back from [last].
      final back = n - 1 - i;
      watchedAt.add(last.subtract(
          Duration(days: (back ~/ 2) * 3, minutes: (back % 2) * 55)));
    }
    final batch = db.batch();
    final showRef = userRef.collection('shows').doc('$id');
    var minutes = 0;
    for (var i = 0; i < n; i++) {
      final ep = aired[i];
      minutes += ep.runtime;
      final at = Timestamp.fromDate(watchedAt[i]);
      batch.set(showRef.collection('watched').doc(ep.key), {
        'season': ep.seasonNumber,
        'episode': ep.episodeNumber,
        'watchedAt': at,
      });
      batch.set(userRef.collection('activity').doc(), {
        'kind': 'episode',
        'ref': 'ep-$id-${ep.key}',
        'showId': id,
        'showName': show.name,
        'posterPath': show.posterPath,
        'season': ep.seasonNumber,
        'episode': ep.episodeNumber,
        'episodeName': ep.name,
        if (ep.runtime > 0) 'runtime': ep.runtime,
        'at': at,
      });
    }
    batch.set(showRef, {
      ...TvTrackingService.metadataFor(show),
      'watchedCount': n,
      'watchedMinutes': minutes,
      'status': 'watching',
      'addedAt': Timestamp.fromDate(watchedAt.first),
      'updatedAt': Timestamp.fromDate(watchedAt.last),
    });
    await batch.commit();
    debugPrint('SHOTS[maya] tracking $name: $n episodes, '
        'last ${aired[n - 1].key} $daysAgo days ago');
  }
}

/// The app as `MyApp` builds it (dark theme, English, side safe areas, no
/// debug banner), opened straight on the signed-in MainScreen — no splash,
/// and no notification-permission prompt over the screenshots.
Widget _app() => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WatchVerse',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) =>
          SideSafeArea(color: AppColors.dark.background, child: child!),
      home: const MainScreen(),
    );

Future<void> _wait(WidgetTester tester, num seconds) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

bool _busy() =>
    find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
    find.byType(LinearProgressIndicator).evaluate().isNotEmpty;

/// Waits at least [min] seconds and until no progress indicator (screen
/// loads, network-image placeholders) is on screen, up to [max] seconds,
/// then lets images decode/fade in.
Future<void> _settle(WidgetTester tester, String label,
    {num min = 2, num max = 40}) async {
  final sw = Stopwatch()..start();
  await _wait(tester, min);
  while (_busy() && sw.elapsed.inSeconds < max) {
    await _wait(tester, 0.5);
  }
  if (_busy()) debugPrint('SHOTS[$label] still loading after ${max}s');
  await _wait(tester, 2);
}

Future<void> _capture(IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  if (_captureMode == 'simctl') {
    debugPrint('WVSHOT $name');
    await _wait(tester, _simctlHold);
  } else {
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot(name);
  }
  debugPrint('SHOTS captured $name');
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon).last, warnIfMissed: false);
  await _wait(tester, 1);
}

BuildContext _ctx(WidgetTester tester, Type screen) =>
    tester.element(find.byType(screen, skipOffstage: false).last);

// ------------------------------------------------------------------ test ----

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final accounts = <String, ({String email, String password, String uid})>{};
  late String leoUid;

  Future<String> createAccount(String who, Map<String, dynamic> profile) async {
    final email = 'wv-shots-${who.toLowerCase()}-$stamp@example.com';
    final password = 'wv-shots-$stamp-pw';
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    accounts[who] = (email: email, password: password, uid: uid);
    // Logged before anything else is written, for manual cleanup.
    debugPrint('SHOTS account $who uid=$uid email=$email password=$password');
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      ...profile,
      'profileImageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return uid;
  }

  setUpAll(() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    final now = DateTime.now();
    await FirebaseAuth.instance.signOut();

    leoUid = await createAccount('Leo', {'name': 'Leo'});
    await _import('leo', _letterboxdFiles(_leoWatched, _leoWatchlist, now));
    await FirebaseAuth.instance.signOut();

    final mayaUid = await createAccount('Maya', {
      'name': 'Maya',
      ...const StreamingPrefs(region: 'US', providerIds: _providerIds)
          .toUserDoc(),
    });
    await _import(
        'maya', _letterboxdFiles(_mayaWatched, _mayaWatchlist, now));
    await _seedShows(mayaUid, now);
    await SocialService.instance.follow(leoUid);
  });

  tearDownAll(() async {
    // Maya first (her follow of Leo is purged from his doc while it still
    // exists), then Leo. Each deletion re-signs in as that account.
    for (final who in ['Maya', 'Leo']) {
      final a = accounts[who];
      if (a == null) continue;
      try {
        await FirebaseAuth.instance.signOut();
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: a.email, password: a.password);
        await AccountDeletionService.instance.deleteAccount();
        debugPrint('SHOTS deleted $who (${a.uid}) via AccountDeletionService');
      } catch (e) {
        debugPrint('SHOTS FAILED to delete $who ${a.email}: $e — delete it '
            'by hand');
      }
    }
  });

  testWidgets('App Store screenshots', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester, 'home', min: 6);
    await _capture(binding, tester, '01_home');

    // 02 — a movie's detail page, opened from Home.
    final featured = (await tester.runAsync(() => FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('movies')
            .where('title', isEqualTo: _featuredMovie)
            .get()))!
        .docs
        .single
        .data();
    openMedia(_ctx(tester, HomeScreen), movieItemFromDoc(featured));
    await _settle(tester, 'detail', min: 4);
    await _capture(binding, tester, '02_movie_detail');
    Navigator.of(_ctx(tester, HomeScreen)).pop();
    await _wait(tester, 1);

    // 03 — Up Next, with Severance's Recap chip.
    await _tapIcon(tester, Icons.live_tv_rounded);
    await _settle(tester, 'upnext', min: 4, max: 60);
    expect(find.text('Recap'), findsOneWidget);
    await _capture(binding, tester, '03_up_next');

    // 04 — the recap sheet.
    await tester.tap(find.text('Recap'));
    await _settle(tester, 'recap', min: 3);
    await _capture(binding, tester, '04_recap');
    Navigator.of(tester.element(find.text('Where you left off')),
            rootNavigator: true)
        .pop();
    await _wait(tester, 1);

    // 05 — Fits tonight from the To Watch tab, 2-hour budget.
    await _tapIcon(tester, Icons.movie_rounded);
    await _settle(tester, 'watchlist', min: 2);
    await tester.tap(find.byIcon(Icons.timer_outlined).last);
    await _settle(tester, 'fits', min: 3, max: 60);
    await tester.tap(find.text('2h').last);
    await _settle(tester, 'fits-2h', min: 2);
    await tester.tap(find.text('On my services').last);
    await _settle(tester, 'fits-services', min: 3, max: 30);
    await _capture(binding, tester, '05_fits_tonight');

    // 07 — Games hub, from Home.
    await _tapIcon(tester, Icons.home_rounded);
    Navigator.of(_ctx(tester, HomeScreen)).push(
        MaterialPageRoute(builder: (_) => const GamesHubScreen()));
    await _settle(tester, 'games', min: 3);
    await _capture(binding, tester, '07_games_hub');

    // 06 — Common ground with Leo, from his profile.
    await _tapIcon(tester, Icons.person_rounded);
    await _settle(tester, 'profile', min: 2);
    Navigator.of(_ctx(tester, ProfileScreen)).push(MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: leoUid, name: 'Leo')));
    await _settle(tester, 'leo', min: 3);
    await tester.tap(find.byKey(const ValueKey('common-ground-button')));
    await _settle(tester, 'common-ground', min: 4, max: 60);
    await _capture(binding, tester, '06_common_ground');

    // 08 — Year in Review, from Profile.
    Navigator.of(_ctx(tester, ProfileScreen)).popUntil((r) => r.isFirst);
    await _wait(tester, 1);
    Navigator.of(_ctx(tester, ProfileScreen)).push(MaterialPageRoute(
        builder: (_) => const YearInReviewScreen()));
    await _settle(tester, 'yir', min: 4, max: 60);
    await _capture(binding, tester, '08_year_in_review');
  });
}
