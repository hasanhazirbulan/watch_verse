// On-device smoke test for the Letterboxd/IMDb importer: creates a throwaway
// Firebase Auth user, parses the fixture exports in integration_test/fixtures
// (off the main isolate, like the import screen), runs LibraryImportService
// against real TMDB + Firestore, checks what landed in the user's library,
// waits for the runtime/genre backfill, re-imports to prove it's idempotent, opens Year in Review over the result,
// then deletes everything through AccountDeletionService. Run on a simulator:
//   flutter test integration_test/import_smoke_test.dart \
//     --dart-define-from-file=secrets.json -d <simulator-id>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watch_verse/firebase_options.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/year_in_review_screen.dart';
import 'package:watch_verse/services/account_deletion_service.dart';
import 'package:watch_verse/services/import/import_models.dart';
import 'package:watch_verse/services/import/import_parser.dart';
import 'package:watch_verse/services/import/library_import_service.dart';
import 'package:watch_verse/services/year_in_review.dart';
import 'package:watch_verse/services/year_in_review_source.dart';
import 'package:watch_verse/theme/app_theme.dart';

import 'fixtures/import_fixtures.dart';

// TMDB ids the fixture titles must resolve to.
const _parasite = 496243;
const _whiplash = 244786;
const _spiritedAway = 129;
const _theThing = 1091;
const _amelie = 194;
const _duneTwo = 693134;
const _pastLives = 666277;
const _shawshank = 278;
const _inception = 27205;
const _interstellar = 157336;
const _breakingBad = 1396;

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

Future<void> _wait(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  User? user;
  late String email;
  late String password;
  late DocumentReference<Map<String, dynamic>> userRef;

  setUpAll(() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    email = 'smoke-import-$stamp@example.com';
    password = 'smoke-$stamp-pw';
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    user = cred.user;
    userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    await userRef.set({'name': 'Import Smoke'});
    debugPrint('SMOKE created temp user ${user?.uid} ($email)');
  });

  tearDownAll(() async {
    if (user == null) return;
    // The real "Delete account" path — also purges everything imported.
    // Re-sign-in first in case the run outlasted its recent-login window.
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    debugPrint('SMOKE re-signed in; deleting account');
    await AccountDeletionService.instance.deleteAccount();
    debugPrint('SMOKE deleted temp user + data via AccountDeletionService');
  });

  testWidgets('Letterboxd zip + IMDb ratings import into Firestore',
      (tester) async {
    final files = [
      ImportFile('letterboxd-smoke-export.zip', letterboxdExportZip),
      ImportFile('ratings.csv', imdbRatingsCsv),
    ];
    // Same call the import screen makes (background isolate).
    final parsed =
        await tester.runAsync(() => compute(parseImportFiles, files));
    expect(parsed, isNotNull);
    expect(parsed!.unrecognizedFiles, isEmpty);
    expect(parsed.skippedRows, 1, reason: 'the IMDb TV episode row');
    // 7 Letterboxd films (Cats from deleted/ and Heat from lists/ ignored) +
    // 5 IMDb titles.
    expect(parsed.titles.map((t) => t.title).toSet(), {
      'Parasite', 'Whiplash', 'Spirited Away', 'The Thing', 'Amélie',
      'Dune: Part Two', 'Past Lives', 'The Shawshank Redemption',
      'Inception', 'Interstellar', 'Breaking Bad',
    });

    final progress = <int>[];
    final importer = LibraryImportService();
    final summary = (await tester.runAsync(() => importer
        .run(parsed, onProgress: (done, _) => progress.add(done))))!;
    debugPrint('SMOKE[import] watched=${summary.moviesWatched} '
        'ratings=${summary.ratings} watchlist=${summary.watchlist} '
        'shows=${summary.shows} diary=${summary.diaryEntries} '
        'already=${summary.alreadyInLibrary} skipped=${summary.skipped} '
        'unmatched=${summary.unmatched.map((u) => '${u.title}'
            '${u.lookupFailed ? '(lookup failed)' : ''}').toList()}');
    expect(summary.unmatched, isEmpty);
    expect(summary.moviesWatched, 8);
    expect(summary.watchlist, 2);
    expect(summary.shows, 1);
    expect(summary.diaryEntries, 5);
    // 5 Letterboxd films (The Thing's via its diary row) + 3 IMDb films +
    // Breaking Bad. Parasite is in both exports and rated once.
    expect(summary.ratings, 9);
    expect(summary.alreadyInLibrary, 1);
    expect(summary.skipped, 1);
    expect(progress.last, parsed.titles.length);

    // ---- what actually landed in Firestore ----
    final movies = {
      for (final d in (await userRef.collection('movies').get()).docs)
        int.parse(d.id): d.data(),
    };
    debugPrint('SMOKE[import] movies: ${movies.map((k, v) => MapEntry(k, '${v['title']}:${v['status']}:${v['rating']}'))}');
    expect(movies.keys.toSet(), {
      _parasite, _whiplash, _spiritedAway, _theThing, _amelie, _duneTwo,
      _pastLives, _shawshank, _inception, _interstellar,
    });
    void expectMovie(int id, String status, double? rating, [DateTime? at]) {
      final m = movies[id]!;
      expect(m['status'], status, reason: '${m['title']} status');
      expect((m['rating'] as num?)?.toDouble(), rating,
          reason: '${m['title']} rating');
      expect(m['id'], id);
      expect(m['title'], isA<String>());
      if (at != null) {
        expect((m['watchedAt'] as Timestamp).toDate(), at,
            reason: '${m['title']} watchedAt');
      }
    }

    expectMovie(_parasite, 'watched', 5, DateTime(2025, 11, 2));
    expectMovie(_whiplash, 'watched', 4.5, DateTime(2025, 3, 14));
    expectMovie(_spiritedAway, 'watched', 4, DateTime(2025, 6, 21));
    expectMovie(_theThing, 'watched', 4, DateTime(2025, 10, 31));
    expectMovie(_amelie, 'watched', 3.5, DateTime(2025, 12, 24));
    expectMovie(_duneTwo, 'watchlist', null);
    expectMovie(_pastLives, 'watchlist', null);
    expectMovie(_shawshank, 'watched', 5, DateTime(2025, 4, 5));
    expectMovie(_inception, 'watched', 4, DateTime(2025, 5, 12));
    expectMovie(_interstellar, 'watched', 3.5, DateTime(2025, 7, 19));

    final show = (await userRef.collection('shows').doc('$_breakingBad').get())
        .data();
    expect(show, isNotNull, reason: 'Breaking Bad tracked');
    expect(show!['status'], 'watchlist');
    expect(show['watchedCount'], 0);
    expect((show['userRating'] as num).toDouble(), 4.5);

    final diary = (await userRef.collection('diary').get())
        .docs
        .map((d) => d.data())
        .toList();
    String day(Map<String, dynamic> e) =>
        (e['watchedOn'] as Timestamp).toDate().toIso8601String().substring(0, 10);
    expect(
        diary.map((e) => '${e['id']}@${day(e)}').toSet(),
        {
          '$_parasite@2025-02-01',
          '$_parasite@2025-11-02',
          '$_whiplash@2025-03-14',
          '$_spiritedAway@2025-06-21',
          '$_theThing@2025-10-31',
        });
    expect(diary.every((e) => e['importedFrom'] == 'letterboxd'), isTrue);

    final activity = await userRef.collection('activity').get();
    expect(activity.docs.map((d) => d.id).toSet(), {
      for (final id in [
        _parasite, _whiplash, _spiritedAway, _theThing, _amelie,
        _shawshank, _inception, _interstellar,
      ])
        'movie-$id',
    });
    final parasiteActivity = activity.docs
        .singleWhere((d) => d.id == 'movie-$_parasite')
        .data();
    expect((parasiteActivity['at'] as Timestamp).toDate(),
        DateTime(2025, 11, 2),
        reason: 'activity dated to the watch, not "now"');

    // Runtime/genres are fetched in the background right after the import,
    // so Year in Review counts the hours without an app restart.
    expect(importer.detailsBackfill, isNotNull);
    await tester.runAsync(() => importer.detailsBackfill!);
    expect((await userRef.get()).data()!['timeStatsBackfilledV2'], true);
    final backfilled = (await userRef.collection('movies').get()).docs
        .map((d) => d.data())
        .where((m) => m['status'] == 'watched');
    for (final m in backfilled) {
      expect((m['runtime'] as num?) ?? 0, greaterThan(0),
          reason: '${m['title']} runtime');
      expect(m['genres'], isNotEmpty, reason: '${m['title']} genres');
    }

    // ---- re-import writes nothing ----
    final again = (await tester.runAsync(
        () => LibraryImportService().run(parsed)))!;
    debugPrint('SMOKE[reimport] watched=${again.moviesWatched} '
        'ratings=${again.ratings} diary=${again.diaryEntries} '
        'already=${again.alreadyInLibrary}');
    expect(again.moviesWatched, 0);
    expect(again.ratings, 0);
    expect(again.watchlist, 0);
    expect(again.shows, 0);
    expect(again.diaryEntries, 0);
    expect(again.alreadyInLibrary, parsed.titles.length);
    expect((await userRef.collection('diary').get()).size, 5);
  });

  testWidgets('Year in Review aggregates the imported 2025', (tester) async {
    final input = (await tester
        .runAsync(() => FirestoreYearInReviewSource().load(2025)))!;
    final yir = computeYearInReview(input, 2025, now: DateTime.now());
    debugPrint('SMOKE[yir] filmWatches=${yir.filmWatches} '
        'distinct=${yir.distinctFilms} minutes=${yir.filmMinutes} '
        'noRuntime=${yir.filmsWithoutRuntime}');
    // 5 diary entries + Amélie, Shawshank, Inception, Interstellar (movie
    // docs with no same-day diary entry). Parasite's movie doc shares its
    // Nov 2 date with a diary entry, so it isn't counted twice.
    expect(yir.filmWatches, 9);
    expect(yir.distinctFilms, 8);
    expect(yir.filmsWithoutRuntime, 0);
    expect(yir.filmMinutes, greaterThan(9 * 60));
    expect(
        yearsWithData(input, now: DateTime.now()), contains(2025));

    await tester.pumpWidget(_app(const YearInReviewScreen(initialYear: 2025)));
    await _wait(tester, 8);
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => t.trim().isNotEmpty)
        .take(40)
        .toList();
    debugPrint('SMOKE[yir] texts: $texts');
    expect(tester.takeException(), isNull);
    expect(find.textContaining('2025'), findsWidgets);
  });
}
