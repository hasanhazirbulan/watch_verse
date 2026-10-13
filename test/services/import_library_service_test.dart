import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/import/import_models.dart';
import 'package:watch_verse/services/import/import_parser.dart';
import 'package:watch_verse/services/import/library_import_service.dart';
import 'package:watch_verse/services/import/title_matcher.dart';

MediaItem movie(int id, String title, String date) => MediaItem(
      id: id,
      title: title,
      overview: '',
      posterPath: '/p$id.jpg',
      backdropPath: '',
      date: date,
      voteAverage: 7,
      mediaType: MediaType.movie,
    );

MediaItem tv(int id, String title) => MediaItem(
      id: id,
      title: title,
      overview: '',
      posterPath: '/t$id.jpg',
      backdropPath: '',
      date: '2008-01-20',
      voteAverage: 9,
      mediaType: MediaType.tv,
    );

/// In-memory TMDB: `search` is keyed by "title" (no year) and "title|year"
/// (TMDB's `year` filter); `find` by IMDb id. Records every call.
class FakeApi implements ImportLookupApi {
  final Map<String, List<MediaItem>> search = {};
  final Map<String, ({MediaItem? movie, MediaItem? tv})> find = {};
  final Set<String> failing = {};
  final calls = <String>[];
  int inFlight = 0;
  int maxInFlight = 0;

  Future<T> _call<T>(String key, T Function() body) async {
    calls.add(key);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    inFlight--;
    if (failing.contains(key)) throw Exception('network down');
    return body();
  }

  @override
  Future<List<MediaItem>> searchMovies(String query, {int? year}) {
    final key = year == null ? query : '$query|$year';
    return _call('search:$key', () => search[key] ?? const []);
  }

  @override
  Future<({MediaItem? movie, MediaItem? tv})> findByImdbId(String imdbId) =>
      _call('find:$imdbId', () => find[imdbId] ?? (movie: null, tv: null));

  @override
  Future<TvShow> getTvDetails(int showId) => _call(
      'tv:$showId',
      () => TvShow.fromMap({
            'id': showId,
            'name': 'Breaking Bad',
            'number_of_episodes': 62,
            'number_of_seasons': 5,
            'genres': [
              {'id': 18, 'name': 'Drama'}
            ],
          }));
}

ImportFile csv(String name, String text) =>
    ImportFile(name, Uint8List.fromList(utf8.encode(text)));

void main() {
  const uid = 'user-1';
  late FakeFirebaseFirestore db;
  late FakeApi api;
  late LibraryImportService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    api = FakeApi();
    service = LibraryImportService(
      firestore: db,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true),
      api: api,
      retryDelay: Duration.zero,
    );
  });

  DocumentReference<Map<String, dynamic>> userRef() =>
      db.collection('users').doc(uid);
  Future<Map<String, dynamic>?> movieDoc(int id) async =>
      (await userRef().collection('movies').doc('$id').get()).data();

  ParsedImport parse(List<ImportFile> files) =>
      const LibraryImportParser().parseFiles(files);

  group('TitleMatcher (Letterboxd title + year)', () {
    test('prefers exact year, and an identical title within that year', () async {
      api.search['Heat|1995'] = [
        movie(1, 'Heat Wave', '1995-03-01'),
        movie(949, 'Heat', '1995-12-15'),
      ];
      final m = TitleMatcher(api, retryDelay: Duration.zero);
      final hit = await m.match(ImportedTitle(
          source: ImportSource.letterboxd, key: 'k', title: 'Heat', year: 1995));
      expect(hit!.id, 949);
    });

    test('falls back to ±1 year, then an unfiltered search', () async {
      api.search['Festival Film|2019'] = [movie(5, 'Festival Film', '2020-01-10')];
      api.search['Other|2001'] = [];
      api.search['Other'] = [
        movie(6, 'Other', '1980-01-01'),
        movie(7, 'Other', '2002-05-01'),
      ];
      final m = TitleMatcher(api, retryDelay: Duration.zero);
      final a = await m.match(ImportedTitle(
          source: ImportSource.letterboxd,
          key: 'a',
          title: 'Festival Film',
          year: 2019));
      expect(a!.id, 5);
      final b = await m.match(ImportedTitle(
          source: ImportSource.letterboxd, key: 'b', title: 'Other', year: 2001));
      expect(b!.id, 7);
    });

    test('no confident match → null (wrong year, or no year + different title)',
        () async {
      api.search['Hamlet|1948'] = [movie(1, 'Hamlet', '1996-12-25')];
      api.search['Hamlet'] = [movie(1, 'Hamlet', '1996-12-25')];
      api.search['Untitled'] = [movie(2, 'Untitled Project', '2010-01-01')];
      final m = TitleMatcher(api, retryDelay: Duration.zero);
      expect(
          await m.match(ImportedTitle(
              source: ImportSource.letterboxd,
              key: 'h',
              title: 'Hamlet',
              year: 1948)),
          isNull);
      expect(
          await m.match(ImportedTitle(
              source: ImportSource.letterboxd,
              key: 'u',
              title: 'Untitled',
              year: null)),
          isNull);
    });

    test('normalizeTitle ignores case, punctuation and & vs and', () {
      expect(TitleMatcher.normalizeTitle('Fast & Furious'),
          TitleMatcher.normalizeTitle('fast and furious'));
      expect(TitleMatcher.normalizeTitle('Amélie'), 'amélie');
      expect(TitleMatcher.normalizeTitle('Se7en!'), 'se7en');
    });
  });

  group('LibraryImportService', () {
    const lbWatched = 'Date,Name,Year,Letterboxd URI\n'
        '2023-05-01,Heat,1995,x\n'
        '2023-05-02,Nowhere Film,1999,y\n';
    const lbRatings = 'Date,Name,Year,Letterboxd URI,Rating\n'
        '2023-06-01,Heat,1995,x,4.5\n';
    const lbDiary =
        'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n'
        '2023-05-01,Heat,1995,e1,4,,,2023-04-30\n'
        '2024-02-10,Heat,1995,e2,4.5,Yes,,2024-02-08\n';
    const lbWatchlist = 'Date,Name,Year,Letterboxd URI\n'
        '2024-01-01,Stalker,1979,z\n';

    void seedLetterboxd() {
      api.search['Heat|1995'] = [movie(949, 'Heat', '1995-12-15')];
      api.search['Stalker|1979'] = [movie(1398, 'Stalker', '1979-05-25')];
      // "Nowhere Film" stays unmatched.
    }

    List<ImportFile> lbFiles() => [
          csv('watched.csv', lbWatched),
          csv('ratings.csv', lbRatings),
          csv('diary.csv', lbDiary),
          csv('watchlist.csv', lbWatchlist),
        ];

    test('imports watched (dated), rating, diary, watchlist; lists unmatched',
        () async {
      seedLetterboxd();
      final progress = <int>[];
      final s = await service.run(parse(lbFiles()),
          onProgress: (done, total) => progress.add(done));

      expect(s.moviesWatched, 1);
      expect(s.ratings, 1);
      expect(s.watchlist, 1);
      expect(s.diaryEntries, 2);
      expect(s.unmatched.map((u) => u.title), ['Nowhere Film']);
      expect(s.cancelled, isFalse);
      expect(progress.first, 0);
      expect(progress.last, 3);

      final heat = await movieDoc(949);
      expect(heat!['status'], 'watched');
      expect(heat['rating'], 4.5);
      expect(heat['title'], 'Heat');
      expect((heat['watchedAt'] as Timestamp).toDate(), DateTime(2024, 2, 8));

      final activity =
          await userRef().collection('activity').doc('movie-949').get();
      expect((activity.data()!['at'] as Timestamp).toDate(),
          DateTime(2024, 2, 8),
          reason: 'dated to the watch, not "now", so feeds are not flooded');

      expect((await movieDoc(1398))!['status'], 'watchlist');

      final diary = await userRef().collection('diary').get();
      expect(diary.docs.map((d) => d.data()['rating']).toSet(), {4.0, 4.5});

      final user = await userRef().get();
      expect(user.data()!['timeStatsBackfilledV2'], isFalse,
          reason: 'triggers the runtime/genre backfill for imported films');
    });

    test('re-importing the same files is a no-op (idempotent)', () async {
      seedLetterboxd();
      await service.run(parse(lbFiles()));
      final before = await userRef().collection('diary').get();

      final s = await service.run(parse(lbFiles()));
      expect(s.moviesWatched, 0);
      expect(s.ratings, 0);
      expect(s.watchlist, 0);
      expect(s.diaryEntries, 0);
      expect(s.alreadyInLibrary, 2);
      final after = await userRef().collection('diary').get();
      expect(after.docs, hasLength(before.docs.length));
    });

    test('never overwrites newer WatchVerse data', () async {
      seedLetterboxd();
      // Already rated + watched in WatchVerse, with a hand-logged diary
      // entry on one of the imported dates.
      await userRef().collection('movies').doc('949').set({
        'id': 949,
        'title': 'Heat',
        'status': 'watched',
        'rating': 2.0,
        'note': 'mine',
      });
      await userRef().collection('diary').add({
        'mediaType': 'movie',
        'id': 949,
        'watchedOn': Timestamp.fromDate(DateTime(2024, 2, 8)),
      });
      // Already watched → must not be pushed back to watchlist.
      await userRef().collection('movies').doc('1398').set(
          {'id': 1398, 'status': 'watched'});

      final s = await service.run(parse(lbFiles()));
      final heat = await movieDoc(949);
      expect(heat!['rating'], 2.0);
      expect(heat['note'], 'mine');
      expect(s.ratings, 0);
      expect(s.moviesWatched, 0);
      expect(s.diaryEntries, 1, reason: 'only the 2023-04-30 entry is new');
      expect((await movieDoc(1398))!['status'], 'watched');
      expect(s.watchlist, 0);
    });

    test('watchlist entry is upgraded to watched by an imported watch', () async {
      seedLetterboxd();
      await userRef().collection('movies').doc('949').set(
          {'id': 949, 'title': 'Heat', 'status': 'watchlist'});
      final s = await service.run(parse([csv('watched.csv', lbWatched)]));
      expect(s.moviesWatched, 1);
      expect((await movieDoc(949))!['status'], 'watched');
    });

    test('IMDb: exact /find match, rating ÷2, series tracked without episodes',
        () async {
      api.find['tt0111161'] = (movie: movie(278, 'Shawshank', '1994-09-23'), tv: null);
      api.find['tt0903747'] = (movie: null, tv: tv(1396, 'Breaking Bad'));
      const ratings = 'Const,Your Rating,Date Rated,Title,Title Type,Year\n'
          'tt0111161,9,2024-03-01,The Shawshank Redemption,Movie,1994\n'
          'tt0903747,10,2024-03-02,Breaking Bad,TV Series,2008\n'
          'tt9999999,6,2024-03-02,Unknown To TMDB,Movie,2020\n';
      final s = await service.run(parse([csv('ratings.csv', ratings)]));

      expect(api.calls.where((c) => c.startsWith('search:')), isEmpty);
      final m = await movieDoc(278);
      expect(m!['status'], 'watched');
      expect(m['rating'], 4.5);
      expect((m['watchedAt'] as Timestamp).toDate(), DateTime(2024, 3, 1));

      final show =
          (await userRef().collection('shows').doc('1396').get()).data()!;
      expect(show['status'], 'watchlist');
      expect(show['watchedCount'], 0);
      expect(show['userRating'], 5.0);
      expect(show['totalEpisodes'], 62);
      final watchedEps = await userRef()
          .collection('shows')
          .doc('1396')
          .collection('watched')
          .get();
      expect(watchedEps.docs, isEmpty);

      expect(s.moviesWatched, 1);
      expect(s.shows, 1);
      expect(s.ratings, 2);
      expect(s.unmatched.single.title, 'Unknown To TMDB');

      // Re-import: tracked + rated show needs no TMDB details call.
      api.calls.clear();
      final again = await service.run(parse([csv('ratings.csv', ratings)]));
      expect(again.shows, 0);
      expect(again.ratings, 0);
      expect(api.calls.where((c) => c.startsWith('tv:')), isEmpty);
    });

    test('two source rows resolving to one TMDB id write once', () async {
      api.search['Heat|1995'] = [movie(949, 'Heat', '1995-12-15')];
      api.find['tt0113277'] = (movie: movie(949, 'Heat', '1995-12-15'), tv: null);
      final s = await service.run(parse([
        csv('watched.csv', 'Date,Name,Year,Letterboxd URI\n2023-05-01,Heat,1995,x\n'),
        csv('ratings.csv', 'Const,Your Rating,Date Rated,Title,Title Type,Year\n'
            'tt0113277,8,2024-03-01,Heat,Movie,1995\n'),
      ]));
      expect(s.moviesWatched, 1);
      expect(s.ratings, 1);
      expect((await movieDoc(949))!['rating'], 4.0);
    });

    test('lookup failures are reported, not fatal', () async {
      api.failing.add('search:Heat|1995');
      final s = await service.run(parse([csv('watched.csv', lbWatched)]));
      final heat = s.unmatched.singleWhere((u) => u.title == 'Heat');
      expect(heat.lookupFailed, isTrue);
      expect(api.calls.where((c) => c == 'search:Heat|1995'), hasLength(2),
          reason: 'retried once');
    });

    test('large library: bounded concurrency, batched writes, all imported',
        () async {
      final buf = StringBuffer('Date,Name,Year,Letterboxd URI\n');
      for (var i = 0; i < 1200; i++) {
        buf.writeln('2023-01-01,Film $i,2000,x$i');
        api.search['Film $i|2000'] = [movie(10000 + i, 'Film $i', '2000-01-01')];
      }
      final s = await service.run(parse([csv('watched.csv', buf.toString())]));
      expect(s.moviesWatched, 1200);
      expect(api.maxInFlight, lessThanOrEqualTo(4));
      final docs = await userRef().collection('movies').get();
      expect(docs.docs, hasLength(1200));
    });

    test('cancel stops lookups early but keeps what was matched', () async {
      final buf = StringBuffer('Date,Name,Year,Letterboxd URI\n');
      for (var i = 0; i < 50; i++) {
        buf.writeln('2023-01-01,Film $i,2000,x$i');
        api.search['Film $i|2000'] = [movie(10000 + i, 'Film $i', '2000-01-01')];
      }
      final token = ImportCancelToken();
      final s = await service.run(parse([csv('watched.csv', buf.toString())]),
          cancel: token, onProgress: (done, _) {
        if (done == 10) token.cancel();
      });
      expect(s.cancelled, isTrue);
      expect(s.moviesWatched, inInclusiveRange(10, 14));
      final docs = await userRef().collection('movies').get();
      expect(docs.docs, hasLength(s.moviesWatched));
    });

    test('guests (no Firebase user) are refused', () async {
      final guest = LibraryImportService(
          firestore: db, auth: MockFirebaseAuth(), api: api);
      expect(() => guest.run(parse([csv('watched.csv', lbWatched)])),
          throwsStateError);
    });
  });
}
