import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/game_clue_movie.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/daily_game_service.dart';

/// Records which movie id the service resolved instead of calling TMDB.
class _FakeApi extends APIservices {
  final requested = <int>[];
  Object? error;

  @override
  Future<GameClueMovie> getGameClueData(int movieId) async {
    requested.add(movieId);
    final e = error;
    if (e != null) throw e;
    return GameClueMovie(
      id: movieId,
      title: 'M$movieId',
      posterPath: '',
      directors: const [],
      productionCompanies: const [],
      releaseYear: 2000,
      revenue: 0,
      voteAverage: 0,
      certification: '',
      genres: const [],
      cast: const [],
    );
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakeApi api;
  late DailyGameService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    api = _FakeApi();
    service = DailyGameService.test(
      firestore: firestore,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: 'u'), signedIn: true),
      api: api,
    );
  });

  Future<void> seed(Object? movieIds) => firestore
      .collection('gameConfig')
      .doc('dailyMoviePool')
      .set({'movieIds': movieIds});

  test('an unseeded pool returns null (puzzle not ready)', () async {
    expect(await service.mysteryMovieForDay(service.todayIndex), isNull);
    expect(api.requested, isEmpty);
  });

  test('a retry after seeding works without restarting the app', () async {
    expect(await service.mysteryMovieForDay(service.todayIndex), isNull);

    await seed([550]);

    final movie = await service.mysteryMovieForDay(service.todayIndex);
    expect(movie?.id, 550);
  });

  test('skips malformed pool entries instead of throwing', () async {
    // Only valid ids survive, in order — a single-entry pool makes the
    // pick deterministic regardless of today's date.
    await seed([null, 'abc', {'id': 1}, -5, 0, 27205.0]);

    final movie = await service.mysteryMovieForDay(service.todayIndex);
    expect(movie?.id, 27205);
  });

  test('accepts numeric-string ids', () async {
    await seed([' 603 ']);

    expect((await service.mysteryMovieForDay(service.todayIndex))?.id, 603);
  });

  test('a pool of only junk is treated as not ready', () async {
    await seed(['x', null]);

    expect(await service.mysteryMovieForDay(service.todayIndex), isNull);
  });

  test('a non-list movieIds field is reported as an error', () async {
    await seed('550,603');

    await expectLater(
        service.mysteryMovieForDay(service.todayIndex), throwsA(isA<FormatException>()));
  });

  test('TMDB failures propagate so the screen can offer a retry', () async {
    await seed([550]);
    api.error = Exception('TMDB down');

    await expectLater(
        service.mysteryMovieForDay(service.todayIndex), throwsA(isA<Exception>()));
  });

  test('consecutive days walk through the pool', () async {
    await seed([1, 2, 3]);

    final today = (await service.mysteryMovieForDay(service.todayIndex))!.id;
    final yesterday =
        (await service.mysteryMovieForDay(service.todayIndex - 1))!.id;
    expect(yesterday, ((today - 1 - 1) % 3) + 1);
  });

  group('day index', () {
    DailyGameService at(DateTime utc) => DailyGameService.test(
          firestore: firestore,
          auth: MockFirebaseAuth(mockUser: MockUser(uid: 'u'), signedIn: true),
          api: api,
          clock: () => utc,
        );

    test('rolls over at midnight EST (05:00 UTC), not UTC midnight', () {
      final before = at(DateTime.utc(2026, 10, 14, 4, 59));
      final after = at(DateTime.utc(2026, 10, 14, 5, 0));
      expect(after.todayIndex, before.todayIndex + 1);
      expect(before.dateKeyForDay(before.todayIndex), '2026-10-13');
      expect(after.dateKeyForDay(after.todayIndex), '2026-10-14');
    });

    test('a pinned day keeps its date key after the clock rolls over', () {
      var now = DateTime.utc(2026, 10, 14, 4, 0);
      final svc = DailyGameService.test(
        firestore: firestore,
        auth: MockFirebaseAuth(mockUser: MockUser(uid: 'u'), signedIn: true),
        api: api,
        clock: () => now,
      );
      final pinned = svc.todayIndex;
      now = DateTime.utc(2026, 10, 14, 6, 0);
      expect(svc.todayIndex, pinned + 1);
      expect(svc.dateKeyForDay(pinned), '2026-10-13');
    });
  });

  group('clueData cache', () {
    test('fetches each movie once', () async {
      await Future.wait([service.clueData(7), service.clueData(7)]);
      await service.clueData(7);
      expect(api.requested, [7]);
    });

    test('a failed fetch is retried on the next call', () async {
      api.error = Exception('offline');
      await expectLater(service.clueData(7), throwsA(isA<Exception>()));
      await Future<void>.delayed(Duration.zero);
      api.error = null;
      expect((await service.clueData(7)).id, 7);
      expect(api.requested, [7, 7]);
    });
  });

  group('progress', () {
    test('recordGuess appends guesses and never writes streak fields',
        () async {
      final day = service.todayIndex;
      await service.recordGuess(
          day: day, guessedMovieId: 1, won: false, finished: false);
      await service.recordGuess(
          day: day, guessedMovieId: 2, won: true, finished: true);

      final play = await service.progressStream(day).first;
      expect(play.guessedIds, [1, 2]);
      expect(play.won, isTrue);
      expect(play.finished, isTrue);
      expect((await firestore.collection('users').doc('u').get()).exists,
          isFalse);
    });

    test('an unplayed day is empty', () async {
      final play = await service.progressStream(service.todayIndex).first;
      expect(play.guessedIds, isEmpty);
      expect(play.finished, isFalse);
    });

    test('DailyGamePlay.fromMap tolerates odd stored values', () {
      final play = DailyGamePlay.fromMap({
        'guessedIds': [1, 2.0, 'x', null],
        'won': 'yes',
        'hintsUsed': 1.0,
      });
      expect(play.guessedIds, [1, 2]);
      expect(play.won, isFalse);
      expect(play.hintsUsed, 1);
    });
  });
}
