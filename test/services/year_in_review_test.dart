import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/year_in_review.dart';

Map<String, dynamic> _diary(
  int id,
  DateTime on, {
  double? rating,
  String title = 'Film',
}) => {
  'mediaType': 'movie',
  'id': id,
  'title': '$title $id',
  'posterPath': '/p$id.jpg',
  'rating': ?rating,
  'watchedOn': on,
};

Map<String, dynamic> _movie(
  int id, {
  DateTime? watchedAt,
  int? runtime,
  List<String>? genres,
  double? rating,
  String status = 'watched',
}) => {
  'id': id,
  'title': 'Film $id',
  'posterPath': '/p$id.jpg',
  'status': status,
  'watchedAt': ?watchedAt,
  'runtime': ?runtime,
  'genres': ?genres,
  'rating': ?rating,
};

Map<String, dynamic> _show(
  int id, {
  int watchedCount = 0,
  int watchedMinutes = 0,
  List<String>? genres,
  DateTime? addedAt,
  DateTime? updatedAt,
}) => {
  'id': id,
  'name': 'Show $id',
  'posterPath': '/s$id.jpg',
  'watchedCount': watchedCount,
  'watchedMinutes': watchedMinutes,
  'genres': ?genres,
  'addedAt': ?addedAt,
  'updatedAt': ?updatedAt,
};

EpisodeWatchRecord _ep(int showId, int s, int e, DateTime at) =>
    EpisodeWatchRecord(showId: showId, season: s, episode: e, watchedAt: at);

final _now = DateTime(2026, 10, 14, 12);

YearInReview _compute(YearInReviewInput input, [int year = 2025]) =>
    computeYearInReview(input, year, now: _now);

void main() {
  group('year boundaries', () {
    test('only watches inside [Jan 1, Jan 1 next year) count', () {
      final r = _compute(
        YearInReviewInput(
          diaryEntries: [
            _diary(1, DateTime(2024, 12, 31, 23, 59, 59)),
            _diary(2, DateTime(2025, 1, 1)),
            _diary(3, DateTime(2025, 12, 31, 23, 59, 59)),
            _diary(4, DateTime(2026, 1, 1)),
          ],
          episodes: [
            _ep(10, 1, 1, DateTime(2024, 12, 31, 23)),
            _ep(10, 1, 2, DateTime(2025, 6, 1)),
            _ep(10, 1, 3, DateTime(2026, 1, 1, 0, 0, 1)),
          ],
          shows: [_show(10, watchedCount: 3, watchedMinutes: 90)],
        ),
      );
      expect(r.filmWatches, 2);
      expect(r.distinctFilms, 2);
      expect(r.episodes, 1);
      expect(r.firstWatch!.id, 2);
      expect(r.latestWatch!.id, 3);
      expect(r.isPartial, isFalse);
    });

    test('current year is flagged as partial', () {
      final r = computeYearInReview(
        YearInReviewInput(diaryEntries: [_diary(1, DateTime(2026, 2, 1))]),
        2026,
        now: _now,
      );
      expect(r.isPartial, isTrue);
      expect(r.filmWatches, 1);
    });
  });

  group('films', () {
    test(
      'rewatches count as watches, distinct films once, runtime each time',
      () {
        final r = _compute(
          YearInReviewInput(
            diaryEntries: [
              _diary(1, DateTime(2025, 2, 1), rating: 3),
              _diary(1, DateTime(2025, 8, 1), rating: 4.5),
              _diary(1, DateTime(2025, 9, 1)),
              _diary(2, DateTime(2025, 3, 1)),
            ],
            movies: [
              _movie(1, watchedAt: DateTime(2025, 9, 1), runtime: 100),
              _movie(2, watchedAt: DateTime(2025, 3, 1), runtime: 200),
            ],
          ),
        );
        expect(r.filmWatches, 4);
        expect(r.distinctFilms, 2);
        expect(r.repeatWatches, 2);
        expect(r.filmMinutes, 3 * 100 + 200);
        expect(r.mostRewatchedFilm!.id, 1);
        expect(r.mostRewatchedFilm!.value, 3);
        expect(r.longestFilm!.id, 2);
        expect(r.longestFilm!.value, 200);
        // Latest in-year diary rating that has one (Aug), not the Sep entry.
        expect(r.topRatedFilms.first.rating, 4.5);
      },
    );

    test('movie doc without a same-day diary entry counts as a watch', () {
      final r = _compute(
        YearInReviewInput(
          diaryEntries: [_diary(1, DateTime(2025, 5, 1, 20))],
          movies: [
            // Same day as the diary entry (logWatch) → not double-counted.
            _movie(1, watchedAt: DateTime(2025, 5, 1, 20), runtime: 90),
            // Quick-add mark watched, no diary entry.
            _movie(2, watchedAt: DateTime(2025, 7, 4), runtime: 120),
            // Watchlist docs never count.
            _movie(
              3,
              watchedAt: DateTime(2025, 7, 4),
              runtime: 80,
              status: 'watchlist',
            ),
            // Watched in another year.
            _movie(4, watchedAt: DateTime(2024, 7, 4), runtime: 80),
          ],
        ),
      );
      expect(r.filmWatches, 2);
      expect(r.distinctFilms, 2);
      expect(r.filmMinutes, 210);
    });

    test('diary entries for other media types are ignored', () {
      final r = _compute(
        YearInReviewInput(
          diaryEntries: [
            {..._diary(1, DateTime(2025, 5, 1)), 'mediaType': 'tv'},
          ],
        ),
      );
      expect(r.isEmpty, isTrue);
    });

    test('missing runtime and genres are counted as unknown, not guessed', () {
      final r = _compute(
        YearInReviewInput(
          diaryEntries: [
            _diary(1, DateTime(2025, 5, 1)),
            _diary(2, DateTime(2025, 5, 2)),
          ],
          movies: [
            _movie(1, watchedAt: DateTime(2025, 5, 1), genres: ['Drama']),
            _movie(2, watchedAt: DateTime(2025, 5, 2), runtime: 100),
          ],
        ),
      );
      expect(r.filmMinutes, 100);
      expect(r.filmsWithoutRuntime, 1);
      // Film 1 has a genre but no minutes; film 2 has minutes but no genre.
      expect(r.topGenres, isEmpty);
      expect(r.longestFilm!.id, 2);
    });

    test('film removed from library still shows diary title/poster', () {
      final r = _compute(
        YearInReviewInput(
          diaryEntries: [_diary(7, DateTime(2025, 5, 1), rating: 5)],
        ),
      );
      expect(r.filmWatches, 1);
      expect(r.filmsWithoutRuntime, 1);
      expect(r.topRatedFilms.single.title, 'Film 7');
      expect(r.topRatedFilms.single.posterPath, '/p7.jpg');
    });

    test('top rated: falls back to movie rating, sorted, capped at 10', () {
      final r = _compute(
        YearInReviewInput(
          movies: [
            for (var i = 1; i <= 12; i++)
              _movie(
                i,
                watchedAt: DateTime(2025, 1, i),
                rating: i <= 11 ? (i / 2).clamp(0.5, 5).toDouble() : null,
              ),
          ],
        ),
      );
      expect(r.topRatedFilms.length, 10);
      expect(r.ratedFilms, 11);
      expect(r.topRatedFilms.first.rating, 5);
      // Ties at 5.0 (ids 10 and 11): most recently watched first.
      expect(r.topRatedFilms.first.id, 11);
      expect(r.topRatedFilms[1].id, 10);
      for (var i = 1; i < r.topRatedFilms.length; i++) {
        expect(
          r.topRatedFilms[i - 1].rating,
          greaterThanOrEqualTo(r.topRatedFilms[i].rating),
        );
      }
    });
  });

  group('episodes', () {
    test('exact runtime, then show average, then unknown', () {
      final r = _compute(
        YearInReviewInput(
          shows: [
            _show(10, watchedCount: 4, watchedMinutes: 200, genres: ['Drama']),
            _show(20, watchedCount: 0, watchedMinutes: 0, genres: ['Comedy']),
          ],
          episodes: [
            _ep(10, 1, 1, DateTime(2025, 3, 3)),
            _ep(10, 1, 2, DateTime(2025, 3, 3)),
            _ep(20, 1, 1, DateTime(2025, 3, 4)),
          ],
          episodeRuntimes: {episodeRuntimeKey(10, 's1e1'): 61},
        ),
      );
      expect(r.episodes, 3);
      expect(r.showsWatched, 2);
      expect(r.episodeMinutes, 61 + 50);
      expect(r.episodesWithEstimatedRuntime, 1);
      expect(r.episodesWithoutRuntime, 1);
      expect(r.topGenres.map((e) => e.key), ['Drama']);
      expect(r.topShow!.id, 10);
      expect(r.topShow!.episodes, 2);
      expect(r.firstWatch!.kind, WatchKind.episode);
      expect(r.firstWatch!.season, 1);
    });

    test('top show breaks ties by minutes', () {
      final r = _compute(
        YearInReviewInput(
          shows: [
            _show(10, watchedCount: 1, watchedMinutes: 20),
            _show(20, watchedCount: 1, watchedMinutes: 60),
          ],
          episodes: [
            _ep(10, 1, 1, DateTime(2025, 3, 3)),
            _ep(20, 1, 1, DateTime(2025, 3, 2)),
          ],
        ),
      );
      expect(r.topShow!.id, 20);
    });
  });

  group('activity charts and genres', () {
    test('months/weekdays in minutes; genre minutes per genre', () {
      // 2025-01-06 is a Monday, 2025-03-08 a Saturday.
      final r = _compute(
        YearInReviewInput(
          diaryEntries: [
            _diary(1, DateTime(2025, 1, 6)),
            _diary(2, DateTime(2025, 3, 8)),
            _diary(3, DateTime(2025, 3, 8)),
          ],
          movies: [
            _movie(
              1,
              watchedAt: DateTime(2025, 1, 6),
              runtime: 100,
              genres: ['Drama', 'Crime'],
            ),
            _movie(
              2,
              watchedAt: DateTime(2025, 3, 8),
              runtime: 90,
              genres: ['Drama'],
            ),
            _movie(3, watchedAt: DateTime(2025, 3, 8), runtime: 30),
          ],
        ),
      );
      expect(r.activityInMinutes, isTrue);
      expect(r.byMonth[0], 100);
      expect(r.byMonth[2], 120);
      expect(r.busiestMonth, 2);
      expect(r.byWeekday[0], 100);
      expect(r.byWeekday[5], 120);
      expect(r.favouriteWeekday, 5);
      expect(r.topGenres.map((e) => '${e.key}:${e.value}'), [
        'Drama:190',
        'Crime:100',
      ]);
      expect(r.busiestDay!.day, DateTime(2025, 3, 8));
      expect(r.busiestDay!.films, 2);
    });

    test('falls back to counts when no runtime is known at all', () {
      final r = _compute(
        YearInReviewInput(
          diaryEntries: [
            _diary(1, DateTime(2025, 4, 1)),
            _diary(2, DateTime(2025, 4, 2)),
            _diary(3, DateTime(2025, 5, 2)),
          ],
        ),
      );
      expect(r.totalMinutes, 0);
      expect(r.activityInMinutes, isFalse);
      expect(r.byMonth[3], 2);
      expect(r.busiestMonth, 3);
      // No day with 2+ watches → no "busiest day" fact.
      expect(r.busiestDay, isNull);
    });
  });

  group('empty year', () {
    test('no data → empty, all optional sections null', () {
      final r = _compute(
        YearInReviewInput(
          diaryEntries: [_diary(1, DateTime(2023, 4, 1))],
          movies: [_movie(1, watchedAt: DateTime(2023, 4, 1), runtime: 90)],
        ),
      );
      expect(r.isEmpty, isTrue);
      expect(r.totalMinutes, 0);
      expect(r.topGenres, isEmpty);
      expect(r.topRatedFilms, isEmpty);
      expect(r.averageFilmRating, isNull);
      expect(r.topShow, isNull);
      expect(r.firstWatch, isNull);
      expect(r.latestWatch, isNull);
      expect(r.longestFilm, isNull);
      expect(r.mostRewatchedFilm, isNull);
      expect(r.busiestDay, isNull);
      expect(r.busiestMonth, isNull);
      expect(r.favouriteWeekday, isNull);
    });

    test('completely empty input', () {
      final r = _compute(const YearInReviewInput());
      expect(r.isEmpty, isTrue);
    });
  });

  group('yearsWithData', () {
    test('includes current year, data years and show spans, newest first', () {
      final years = yearsWithData(
        YearInReviewInput(
          diaryEntries: [_diary(1, DateTime(2021, 1, 1))],
          movies: [_movie(2, watchedAt: DateTime(2023, 1, 1))],
          shows: [
            _show(
              10,
              watchedCount: 3,
              addedAt: DateTime(2018, 5, 1),
              updatedAt: DateTime(2019, 2, 1),
            ),
            // Nothing watched → not a hint.
            _show(
              20,
              addedAt: DateTime(2010, 1, 1),
              updatedAt: DateTime(2010, 1, 1),
            ),
          ],
        ),
        now: _now,
      );
      expect(years, [2026, 2023, 2021, 2019, 2018]);
    });

    test('ignores future-dated data', () {
      final years = yearsWithData(
        YearInReviewInput(diaryEntries: [_diary(1, DateTime(2030, 1, 1))]),
        now: _now,
      );
      expect(years, [2026]);
    });
  });
}
