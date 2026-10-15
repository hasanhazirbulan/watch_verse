import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/fits_tonight_logic.dart';

FitsMovieCandidate<String> movie(
  int id,
  int runtime, {
  double rating = 0,
  String? title,
}) => FitsMovieCandidate(
  id: id,
  title: title ?? 'Movie $id',
  runtime: runtime,
  voteAverage: rating,
  payload: 'm$id',
);

FitsEpisode ep(int s, int e, int runtime) =>
    FitsEpisode(season: s, episode: e, runtime: runtime);

FitsShowCandidate<String> show(
  int id,
  List<FitsEpisode> unwatched, {
  int fallback = 0,
  DateTime? lastWatched,
  String? name,
}) => FitsShowCandidate(
  id: id,
  name: name ?? 'Show $id',
  unwatched: unwatched,
  fallbackRuntime: fallback,
  lastWatchedAt: lastWatched,
  payload: 's$id',
);

void main() {
  group('typicalRuntime', () {
    test('median of known runtimes, ignoring unknown (0)', () {
      expect(typicalRuntime([0, 50, 45, 0, 90]), 50);
      expect(typicalRuntime([40, 50]), 45);
      expect(typicalRuntime([0, 0]), 0);
      expect(typicalRuntime(const []), 0);
    });
  });

  group('packEpisodeRun', () {
    test('takes the longest in-order prefix that fits', () {
      final s = show(1, [
        ep(2, 4, 45),
        ep(2, 5, 40),
        ep(2, 6, 50),
        ep(2, 7, 30),
      ]);
      final run = packEpisodeRun(s, 130)!;
      expect(run.episodes.length, 2); // 45 + 40 = 85; +50 = 135 > 130
      expect(run.minutes, 85);
      expect(run.isEstimated, isFalse);
    });

    test('never skips a long episode to fit a later short one', () {
      final s = show(1, [ep(1, 1, 30), ep(1, 2, 90), ep(1, 3, 20)]);
      final run = packEpisodeRun(s, 60)!;
      expect(run.episodes.map((e) => e.episode), [1]);
      expect(run.minutes, 30);
    });

    test('exact fit is included', () {
      final run = packEpisodeRun(show(1, [ep(1, 1, 30), ep(1, 2, 30)]), 60)!;
      expect(run.episodes.length, 2);
      expect(run.minutes, 60);
    });

    test('null when the next episode alone is too long', () {
      expect(packEpisodeRun(show(1, [ep(1, 1, 70)]), 60), isNull);
    });

    test('unknown runtimes use the fallback and are flagged', () {
      final s = show(1, [ep(1, 1, 0), ep(1, 2, 42)], fallback: 44);
      final run = packEpisodeRun(s, 90)!;
      expect(run.minutes, 86);
      expect(run.estimatedCount, 1);
      expect(run.isEstimated, isTrue);
    });

    test('stops at an unknown runtime with no fallback', () {
      final s = show(1, [ep(1, 1, 30), ep(1, 2, 0), ep(1, 3, 30)]);
      final run = packEpisodeRun(s, 120)!;
      expect(run.episodes.length, 1);
    });
  });

  group('computeFitsTonight', () {
    test('movies: fits under budget, too long dropped, unknown separate', () {
      final r = computeFitsTonight(
        budget: 120,
        movies: [movie(1, 95), movie(2, 150), movie(3, 0), movie(4, 120)],
        shows: const [],
      );
      expect(r.movies.map((m) => m.id), [4, 1]);
      expect(r.unknownMovies.map((m) => m.id), [3]);
      expect(r.hasFits, isTrue);
    });

    test('closest to budget first, rating breaks ties within a band', () {
      final r = computeFitsTonight(
        budget: 120,
        movies: [
          movie(1, 100, rating: 9),
          movie(2, 117, rating: 6), // band 0 (3 min spare)
          movie(3, 119, rating: 7), // band 0 (1 min spare)
          movie(4, 60, rating: 8),
        ],
        shows: const [],
      );
      // 2 and 3 are equally close → higher rated first.
      expect(r.movies.map((m) => m.id), [3, 2, 1, 4]);
    });

    test('episode runs sorted by closeness, then most recently watched', () {
      final now = DateTime(2026, 10, 1);
      final r = computeFitsTonight(
        budget: 90,
        movies: const [],
        shows: [
          show(1, [
            ep(1, 1, 30),
            ep(1, 2, 30),
            ep(1, 3, 30),
          ], lastWatched: now.subtract(const Duration(days: 30))),
          show(2, [ep(3, 1, 45), ep(3, 2, 44)], lastWatched: now),
          show(3, [ep(1, 1, 50), ep(1, 2, 50)]),
        ],
      );
      // Shows 1 (90) and 2 (89) share band 0 → 2 watched more recently.
      expect(r.episodeRuns.map((x) => x.id), [2, 1, 3]);
      expect(r.episodeRuns.first.episodes.length, 2);
      expect(r.episodeRuns[2].minutes, 50);
    });

    test('shows whose next runtime is unknown are listed separately', () {
      final r = computeFitsTonight(
        budget: 60,
        movies: const [],
        shows: [
          show(1, [ep(1, 1, 0)]),
          show(2, [ep(1, 1, 0)], fallback: 25),
          show(3, const []), // caught up — not a candidate
        ],
      );
      expect(r.unknownShows.map((s) => s.id), [1]);
      expect(r.episodeRuns.single.id, 2);
      expect(r.episodeRuns.single.episodes.length, 1);
    });

    test('include predicate filters before packing (On my services)', () {
      final r = computeFitsTonight(
        budget: 120,
        movies: [movie(1, 100), movie(2, 110), movie(3, 0)],
        shows: [
          show(10, [ep(1, 1, 40)]),
          show(11, [ep(1, 1, 40)]),
        ],
        include: (kind, id) =>
            (kind == FitsKind.movie && id == 2) ||
            (kind == FitsKind.show && id == 11),
      );
      expect(r.movies.map((m) => m.id), [2]);
      expect(r.unknownMovies, isEmpty);
      expect(r.episodeRuns.map((x) => x.id), [11]);
    });

    test('kind matters in the predicate (same id, different type)', () {
      final r = computeFitsTonight(
        budget: 120,
        movies: [movie(5, 100)],
        shows: [
          show(5, [ep(1, 1, 40)]),
        ],
        include: (kind, id) => kind == FitsKind.show,
      );
      expect(r.movies, isEmpty);
      expect(r.episodeRuns.single.id, 5);
    });

    test('nothing fits: reports the shortest option', () {
      final r = computeFitsTonight(
        budget: 30,
        movies: [movie(1, 125), movie(2, 0)],
        shows: [
          show(1, [ep(1, 1, 58)]),
          show(2, [ep(1, 1, 0)], fallback: 47),
        ],
      );
      expect(r.hasFits, isFalse);
      expect(r.isEmpty, isFalse); // still has an unknown-runtime movie
      expect(r.shortest, 47);
    });

    test('empty input', () {
      final r = computeFitsTonight<String>(
        budget: 90,
        movies: const [],
        shows: const [],
      );
      expect(r.isEmpty, isTrue);
      expect(r.shortest, isNull);
    });
  });

  test('unwatchedAiredInOrder keeps aired, unwatched episodes in order', () {
    final eps = [
      (k: 's1e1', aired: true),
      (k: 's1e2', aired: true),
      (k: 's1e3', aired: true),
      (k: 's1e4', aired: false),
    ];
    final out = unwatchedAiredInOrder(
      eps,
      hasAired: (e) => e.aired,
      isWatched: (e) => e.k == 's1e1' || e.k == 's1e3',
    );
    expect(out.map((e) => e.k), ['s1e2']);
  });

  test('episodeRangeLabel', () {
    expect(episodeRangeLabel(ep(2, 4, 0), ep(2, 4, 0)), 'S2 E4');
    expect(episodeRangeLabel(ep(2, 4, 0), ep(2, 6, 0)), 'S2 E4–6');
    expect(episodeRangeLabel(ep(2, 9, 0), ep(3, 1, 0)), 'S2 E9 – S3 E1');
  });
}
