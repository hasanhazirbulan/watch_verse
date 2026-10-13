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
      director: '',
      productionCompany: '',
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
    expect(await service.mysteryMovieForDaysAgo(0), isNull);
    expect(api.requested, isEmpty);
  });

  test('a retry after seeding works without restarting the app', () async {
    expect(await service.mysteryMovieForDaysAgo(0), isNull);

    await seed([550]);

    final movie = await service.mysteryMovieForDaysAgo(0);
    expect(movie?.id, 550);
  });

  test('skips malformed pool entries instead of throwing', () async {
    // Only valid ids survive, in order — a single-entry pool makes the
    // pick deterministic regardless of today's date.
    await seed([null, 'abc', {'id': 1}, -5, 0, 27205.0]);

    final movie = await service.mysteryMovieForDaysAgo(0);
    expect(movie?.id, 27205);
  });

  test('accepts numeric-string ids', () async {
    await seed([' 603 ']);

    expect((await service.mysteryMovieForDaysAgo(0))?.id, 603);
  });

  test('a pool of only junk is treated as not ready', () async {
    await seed(['x', null]);

    expect(await service.mysteryMovieForDaysAgo(0), isNull);
  });

  test('a non-list movieIds field is reported as an error', () async {
    await seed('550,603');

    await expectLater(
        service.mysteryMovieForDaysAgo(0), throwsA(isA<FormatException>()));
  });

  test('TMDB failures propagate so the screen can offer a retry', () async {
    await seed([550]);
    api.error = Exception('TMDB down');

    await expectLater(
        service.mysteryMovieForDaysAgo(0), throwsA(isA<Exception>()));
  });

  test('consecutive days walk through the pool', () async {
    await seed([1, 2, 3]);

    final today = (await service.mysteryMovieForDaysAgo(0))!.id;
    final yesterday = (await service.mysteryMovieForDaysAgo(1))!.id;
    expect(yesterday, ((today - 1 - 1) % 3) + 1);
  });
}
