import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/services/year_in_review.dart';

/// Where the Year in Review screen gets its raw data. Injectable so widget
/// tests can feed fixed data without touching Firebase.
abstract class YearInReviewSource {
  /// The library (diary, movies, shows) plus the episodes watched in [year]
  /// and their exact runtimes, with every Timestamp converted to [DateTime].
  Future<YearInReviewInput> load(int year);
}

/// Reads the signed-in user's own data once (no live listeners — this is a
/// point-in-time report, same reasoning as the Watch Stats screen).
///
/// Reads per open: all diary entries, all movie docs and all show docs once
/// (cached across year switches), then per year one range query on each
/// relevant show's `watched` subcollection and one range query on the
/// activity timeline. Only shows with episodes watched whose `updatedAt` is
/// on/after Jan 1 of the year are queried — every episode write bumps
/// `updatedAt`, so a show not touched since before that year can't have
/// episodes watched in it.
class FirestoreYearInReviewSource implements YearInReviewSource {
  FirestoreYearInReviewSource({MovieService? movies, TvTrackingService? tv})
    : _movies = movies ?? MovieService.instance,
      _tv = tv ?? TvTrackingService.instance;

  final MovieService _movies;
  final TvTrackingService _tv;
  Future<_Library>? _library;

  Future<_Library> _loadLibrary() async {
    final results = await Future.wait([
      _movies.allDiaryEntriesOnce(),
      _movies.allMoviesOnce(),
      _tv.allShowsOnce(),
    ]);
    return _Library(
      results[0].map(_normalize).toList(),
      results[1].map(_normalize).toList(),
      results[2].map(_normalize).toList(),
    );
  }

  @override
  Future<YearInReviewInput> load(int year) async {
    final library = await (_library ??= _loadLibrary().catchError((Object e) {
      _library = null; // let a retry re-read instead of replaying the error
      throw e;
    }));
    final start = DateTime(year);
    final end = DateTime(year + 1);

    final showIds = <int>[
      for (final s in library.shows)
        if ((s['id'] as num?)?.toInt() case final id?)
          if (((s['watchedCount'] as num?)?.toInt() ?? 0) > 0)
            if (s['updatedAt'] is! DateTime ||
                !(s['updatedAt'] as DateTime).isBefore(start))
              id,
    ];

    final perShow = await Future.wait([
      for (final id in showIds) _tv.watchedEpisodesBetweenOnce(id, start, end),
    ]);
    final episodes = <EpisodeWatchRecord>[];
    for (var i = 0; i < showIds.length; i++) {
      for (final doc in perShow[i]) {
        final season = (doc['season'] as num?)?.toInt();
        final episode = (doc['episode'] as num?)?.toInt();
        final at = doc['watchedAt'];
        if (season == null || episode == null || at is! Timestamp) continue;
        episodes.add(
          EpisodeWatchRecord(
            showId: showIds[i],
            season: season,
            episode: episode,
            watchedAt: at.toDate(),
          ),
        );
      }
    }

    // Exact per-episode runtimes from the individual "episode watched"
    // activity entries (season/catch-up marks don't log per-episode ones).
    final runtimes = <String, int>{};
    if (showIds.isNotEmpty) {
      final activity = await _tv.activityBetweenOnce(start, end);
      for (final a in activity) {
        if (a['kind'] != 'episode') continue;
        final showId = (a['showId'] as num?)?.toInt();
        final season = (a['season'] as num?)?.toInt();
        final episode = (a['episode'] as num?)?.toInt();
        final runtime = (a['runtime'] as num?)?.toInt() ?? 0;
        if (showId == null || season == null || episode == null) continue;
        if (runtime <= 0) continue;
        runtimes[episodeRuntimeKey(showId, 's${season}e$episode')] = runtime;
      }
    }

    return YearInReviewInput(
      diaryEntries: library.diary,
      movies: library.movies,
      shows: library.shows,
      episodes: episodes,
      episodeRuntimes: runtimes,
    );
  }

  /// Top-level Timestamp → local DateTime, so the pure aggregation never
  /// sees a Firestore type.
  static Map<String, dynamic> _normalize(Map<String, dynamic> doc) => {
    for (final e in doc.entries)
      e.key: e.value is Timestamp ? (e.value as Timestamp).toDate() : e.value,
  };
}

class _Library {
  final List<Map<String, dynamic>> diary;
  final List<Map<String, dynamic>> movies;
  final List<Map<String, dynamic>> shows;
  _Library(this.diary, this.movies, this.shows);
}
