import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/common_ground.dart';
import 'package:watch_verse/services/common_ground_source.dart';
import 'package:watch_verse/services/social_service.dart';

Map<String, dynamic> _movie(int id,
        {String status = 'watchlist', double? rating, String? title}) =>
    {
      'id': id,
      'title': title ?? 'Movie $id',
      'posterPath': '/p$id.jpg',
      'releaseDate': '2020-01-01',
      'status': status,
      'rating': ?rating,
    };

Map<String, dynamic> _show(int id,
        {String status = 'watchlist', int watchedCount = 0}) =>
    {
      'id': id,
      'name': 'Show $id',
      'posterPath': '',
      'firstAirDate': '2019-05-01',
      'status': status,
      'watchedCount': watchedCount,
    };

void main() {
  group('sharedWatchlist', () {
    test('keeps movies on both watchlists, in their order', () {
      final shared = sharedWatchlist(
        theirMovies: [_movie(3), _movie(1), _movie(2), _movie(9)],
        myMoviesById: {
          1: _movie(1),
          2: _movie(2, status: 'watched'), // I already saw it
          3: _movie(3),
        },
      );
      expect(shared.map((m) => m.id), [3, 1]);
      expect(shared.first.mediaType, MediaType.movie);
      expect(shared.first.title, 'Movie 3');
      expect(shared.first.year, '2020');
    });

    test('ignores their non-watchlist docs, duplicates and bad ids', () {
      final shared = sharedWatchlist(
        theirMovies: [
          _movie(1, status: 'watched'),
          _movie(2),
          _movie(2),
          _movie(0),
        ],
        myMoviesById: {1: _movie(1), 2: _movie(2), 0: _movie(0)},
      );
      expect(shared.map((m) => m.id), [2]);
    });

    test('adds shows only when neither side has started them', () {
      final shared = sharedWatchlist(
        theirMovies: const [],
        myMoviesById: const {},
        theirShows: [
          _show(10),
          _show(11),
          _show(12, status: 'watching', watchedCount: 3),
          _show(13),
        ],
        myShowsById: {
          10: _show(10),
          11: _show(11, status: 'watching', watchedCount: 1),
          12: _show(12),
        },
      );
      expect(shared.map((m) => m.id), [10]);
      expect(shared.single.mediaType, MediaType.tv);
      expect(shared.single.title, 'Show 10');
    });

    test('movies come before shows; a movie and a show may share an id', () {
      final shared = sharedWatchlist(
        theirMovies: [_movie(5)],
        myMoviesById: {5: _movie(5)},
        theirShows: [_show(5)],
        myShowsById: {5: _show(5)},
      );
      expect(shared.map((m) => m.mediaType), [MediaType.movie, MediaType.tv]);
    });

    test('empty when nothing overlaps', () {
      expect(
        sharedWatchlist(
            theirMovies: [_movie(1)], myMoviesById: {2: _movie(2)}),
        isEmpty,
      );
    });
  });

  group('rankByAvailability', () {
    final items = sharedWatchlist(
      theirMovies: [_movie(1), _movie(2), _movie(3), _movie(4)],
      myMoviesById: {
        for (final id in [1, 2, 3, 4]) id: _movie(id)
      },
    );

    test('streamable titles first, otherwise stable', () {
      final ranked = rankByAvailability(items, (m) => m.id.isEven);
      expect(ranked.map((m) => m.id), [2, 4, 1, 3]);
    });

    test('no-op when nothing (or everything) is streamable', () {
      expect(rankByAvailability(items, (_) => false).map((m) => m.id),
          [1, 2, 3, 4]);
      expect(rankByAvailability(items, (_) => true).map((m) => m.id),
          [1, 2, 3, 4]);
    });
  });

  test('pollCandidates caps at 6', () {
    final items = sharedWatchlist(
      theirMovies: [for (var i = 1; i <= 9; i++) _movie(i)],
      myMoviesById: {for (var i = 1; i <= 9; i++) i: _movie(i)},
    );
    expect(pollCandidates(items).map((m) => m.id), [1, 2, 3, 4, 5, 6]);
    expect(pollCandidates(items.take(2).toList()), hasLength(2));
  });

  group('computeAgreement', () {
    test('ratings within 1 star agree; counts and ratio', () {
      final a = computeAgreement(
        theirRated: [
          _movie(1, status: 'watched', rating: 4),
          _movie(2, status: 'watched', rating: 5),
          _movie(3, status: 'watched', rating: 1),
          _movie(4, status: 'watched', rating: 3.5),
          _movie(5, status: 'watched', rating: 2), // I never rated it
        ],
        myMoviesById: {
          1: _movie(1, status: 'watched', rating: 4), // diff 0
          2: _movie(2, status: 'watched', rating: 4), // diff 1 → agrees
          3: _movie(3, status: 'watched', rating: 5), // diff 4
          4: _movie(4, status: 'watched', rating: 2), // diff 1.5
          5: _movie(5, status: 'watched'),
        },
      );
      expect(a.total, 4);
      expect(a.agreed, 2);
      expect(a.ratio, 0.5);
      expect(a.topAgreements.map((p) => p.item.id), [1, 2]);
      expect(a.topDisagreements.map((p) => p.item.id), [3, 4]);
      expect(a.topDisagreements.first.difference, 4);
      expect(a.topDisagreements.first.myRating, 5);
      expect(a.topDisagreements.first.theirRating, 1);
    });

    test('ties among agreements favour the film you both liked more', () {
      final a = computeAgreement(
        theirRated: [
          _movie(1, rating: 2),
          _movie(2, rating: 5),
          _movie(3, rating: 3),
        ],
        myMoviesById: {
          1: _movie(1, rating: 2),
          2: _movie(2, rating: 5),
          3: _movie(3, rating: 3),
        },
      );
      expect(a.agreed, 3);
      expect(a.topAgreements.map((p) => p.item.id), [2, 3, 1]);
      expect(a.topDisagreements, isEmpty);
    });

    test('caps highlights and ignores zero ratings / duplicates', () {
      final a = computeAgreement(
        theirRated: [
          for (var i = 1; i <= 6; i++) _movie(i, rating: 5),
          _movie(1, rating: 1), // duplicate id, ignored
          _movie(7, rating: 0),
        ],
        myMoviesById: {
          for (var i = 1; i <= 6; i++) i: _movie(i, rating: 4.5),
          7: _movie(7, rating: 3),
        },
      );
      expect(a.total, 6);
      expect(a.topAgreements, hasLength(agreementHighlights));
    });

    test('empty when no film was rated by both', () {
      final a = computeAgreement(
          theirRated: [_movie(1, rating: 3)], myMoviesById: const {});
      expect(a.total, 0);
      expect(a.agreed, 0);
      expect(a.ratio, isNull);
      expect(a.topAgreements, isEmpty);
    });
  });

  group('canShowCommonGround', () {
    test('hidden for guests and on your own profile', () {
      expect(
          canShowCommonGround(
              myUid: null, targetUid: 'b', myBlocked: [], theirBlocked: []),
          isFalse);
      expect(
          canShowCommonGround(
              myUid: 'a', targetUid: 'a', myBlocked: [], theirBlocked: []),
          isFalse);
    });

    test('hidden when either side blocked the other', () {
      expect(
          canShowCommonGround(
              myUid: 'a', targetUid: 'b', myBlocked: ['b'], theirBlocked: []),
          isFalse);
      expect(
          canShowCommonGround(
              myUid: 'a', targetUid: 'b', myBlocked: [], theirBlocked: ['a']),
          isFalse);
    });

    test('shown otherwise', () {
      expect(
          canShowCommonGround(
              myUid: 'a',
              targetUid: 'b',
              myBlocked: ['c'],
              theirBlocked: ['d']),
          isTrue);
    });
  });

  group('FirestoreCommonGroundSource', () {
    late FakeFirebaseFirestore db;
    late FirestoreCommonGroundSource source;

    Future<void> put(String uid, String col, Map<String, dynamic> doc,
        {Object? watchedAt}) async {
      await db
          .collection('users')
          .doc(uid)
          .collection(col)
          .doc('${doc['id']}')
          .set({...doc, 'watchedAt': ?watchedAt});
    }

    setUp(() {
      db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
          signedIn: true, mockUser: MockUser(uid: 'me'));
      source = FirestoreCommonGroundSource(
        firestore: db,
        social: SocialService.test(firestore: db, auth: auth),
      );
    });

    test('loads their samples and only my matching docs', () async {
      final t = DateTime(2026, 1, 1);
      await put('them', 'movies', _movie(1));
      await put('them', 'movies', _movie(2));
      await put('them', 'movies', _movie(3, status: 'watched', rating: 4),
          watchedAt: t);
      await put('them', 'movies', _movie(4, status: 'watched'),
          watchedAt: t); // unrated
      await put('them', 'shows', _show(10));
      await put('them', 'shows', _show(11, status: 'watching', watchedCount: 2));

      await put('me', 'movies', _movie(1));
      await put('me', 'movies', _movie(3, status: 'watched', rating: 3.5));
      await put('me', 'movies', _movie(99)); // not in their sample
      await put('me', 'shows', _show(10));

      final data = await source.load(myUid: 'me', theirUid: 'them');
      expect(data.theirWatchlistMovies.map((d) => d['id']),
          unorderedEquals([1, 2]));
      expect(data.theirWatchlistShows.map((d) => d['id']), [10]);
      expect(data.theirRatedMovies.map((d) => d['id']), [3]);
      expect(data.myMoviesById.keys, unorderedEquals([1, 3]));
      expect(data.myShowsById.keys, [10]);

      final shared = sharedWatchlist(
        theirMovies: data.theirWatchlistMovies,
        myMoviesById: data.myMoviesById,
        theirShows: data.theirWatchlistShows,
        myShowsById: data.myShowsById,
      );
      expect(shared.map((m) => '${m.mediaType.name}${m.id}'),
          ['movie1', 'tv10']);
      final agreement = computeAgreement(
          theirRated: data.theirRatedMovies, myMoviesById: data.myMoviesById);
      expect(agreement.agreed, 1);
      expect(agreement.total, 1);
    });

    test('looks up more than 30 ids in chunks', () async {
      for (var i = 1; i <= 45; i++) {
        await put('them', 'movies', _movie(i));
        if (i.isOdd) await put('me', 'movies', _movie(i));
      }
      final data = await source.load(myUid: 'me', theirUid: 'them');
      expect(data.myMoviesById, hasLength(23));
    });

    test('caps how many of their docs are read', () async {
      for (var i = 1;
          i <= FirestoreCommonGroundSource.maxWatchlistMovies + 5;
          i++) {
        await put('them', 'movies', _movie(i));
      }
      final data = await source.load(myUid: 'me', theirUid: 'them');
      expect(data.theirWatchlistMovies,
          hasLength(FirestoreCommonGroundSource.maxWatchlistMovies));
    });

    test('empty libraries load fine', () async {
      final data = await source.load(myUid: 'me', theirUid: 'them');
      expect(data.theirWatchlistMovies, isEmpty);
      expect(data.myMoviesById, isEmpty);
    });
  });
}
