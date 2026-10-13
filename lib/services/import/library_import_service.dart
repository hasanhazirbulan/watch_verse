import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/services/import/import_models.dart';
import 'package:watch_verse/services/import/title_matcher.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';

typedef ImportProgressCallback = void Function(int done, int total);

class ImportCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Writes a [ParsedImport] (Letterboxd/IMDb history) into the signed-in
/// user's library, so switching to WatchVerse doesn't mean starting over.
///
/// Where things land — the same docs, fields and shapes as the in-app write
/// paths ([MovieService.metaFor] / [TvTrackingService.metadataFor]), so the
/// existing owner-only rules on `users/{uid}/{movies,activity,diary,shows}`
/// already allow every write and nothing else in the app needs to know an
/// import happened:
///   * watched / rated film → `movies/{id}` status `watched` (watchedAt =
///     the source's watch date) + the `activity/movie-{id}` mirror, dated
///     the same so a big import doesn't flood friends' feeds as "just now".
///   * watchlist film → `movies/{id}` status `watchlist` (the app's own
///     watchlist — no custom list, so the free-tier list cap isn't touched).
///   * Letterboxd diary rows → `diary/` entries, one per dated watch.
///   * IMDb series (rated or watchlisted) → `shows/{id}` as `watchlist`
///     with zero episodes watched (we can't know which ones were).
///
/// Idempotent and never clobbers newer data: the library is read once up
/// front and each title only *fills gaps* — an existing rating is kept, a
/// watched film stays watched, diary entries are skipped when that film
/// already has an entry on that date, and nothing is ever moved from
/// watched back to watchlist. Re-importing the same file writes nothing.
class LibraryImportService {
  LibraryImportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ImportLookupApi? api,
    this.concurrency = 4,
    this.flushEvery = 100,
    Duration retryDelay = const Duration(seconds: 1),
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _api = api ?? TmdbImportLookupApi(),
        _retryDelay = retryDelay;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ImportLookupApi _api;
  final Duration _retryDelay;

  /// Parallel TMDB lookups — small, to stay far below TMDB's rate limit.
  final int concurrency;

  /// Matched titles are written in batches of this many, so progress is
  /// saved as it goes (a cancelled or interrupted import keeps what it
  /// matched, and a re-run skips it).
  final int flushEvery;

  /// Firestore's limit is 500 writes per batch.
  static const _maxBatchOps = 450;

  Future<ImportSummary> run(
    ParsedImport parsed, {
    ImportProgressCallback? onProgress,
    ImportCancelToken? cancel,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to import your history.');
    final userRef = _db.collection('users').doc(uid);
    final state = await _LibraryState.load(userRef);
    final summary = ImportSummary()..skipped = parsed.skippedRows;
    final matcher = TitleMatcher(_api, retryDelay: _retryDelay);
    final titles = parsed.titles;
    final total = titles.length;
    final pending = <_Matched>[];
    var flushing = Future<void>.value();
    Object? writeError;
    var next = 0;
    var done = 0;

    // Writes are serialized (one chunk at a time, in order) so planning
    // always sees the previous chunk's effect on the in-memory state.
    Future<void> flush() {
      if (pending.isEmpty) return flushing;
      final chunk = List<_Matched>.of(pending);
      pending.clear();
      return flushing = flushing
          .then((_) => _write(userRef, state, chunk, summary))
          .catchError((Object e) => writeError ??= e);
    }

    Future<void> worker() async {
      while (next < total &&
          writeError == null &&
          !(cancel?.isCancelled ?? false)) {
        final t = titles[next++];
        await _matchOne(matcher, t, state, pending, summary);
        done++;
        onProgress?.call(done, total);
        if (pending.length >= flushEvery) await flush();
      }
    }

    onProgress?.call(0, total);
    final workers = total == 0 ? 0 : math.min(math.max(concurrency, 1), total);
    await Future.wait(List.generate(workers, (_) => worker()));
    await flush();
    await flushing;
    final error = writeError;
    if (error != null) throw error;
    summary.cancelled = cancel?.isCancelled ?? false;

    if (summary.moviesWatched > 0) {
      // Imported films come from search results, which carry no runtime or
      // genres. Clearing the profile screen's one-time backfill flag makes
      // it fetch those (MovieService.backfillDetails) the next time the
      // profile opens, so time-spent/genre stats include the import — the
      // same mechanism that fixed up pre-runtime watches.
      await userRef.set(
          {'timeStatsBackfilledV2': false}, SetOptions(merge: true));
    }
    return summary;
  }

  Future<void> _matchOne(TitleMatcher matcher, ImportedTitle t,
      _LibraryState state, List<_Matched> out, ImportSummary summary) async {
    try {
      final hit = await matcher.match(t);
      if (hit == null) {
        summary.unmatched.add(UnmatchedTitle(
            title: t.title, year: t.year, source: t.source));
        return;
      }
      if (hit.mediaType == MediaType.movie) {
        out.add(_Matched(t, movie: hit.toMovie()));
        return;
      }
      // TV: details (episode counts, genres…) are only needed if the show
      // doc will actually be created or rated — skip the call otherwise.
      final existing = state.shows[hit.id];
      final needsRating = t.rating != null && !_hasRating(existing?['userRating']);
      if (existing != null && !needsRating) {
        summary.alreadyInLibrary++;
        return;
      }
      final show = await _retryDetails(hit.id);
      out.add(_Matched(t, show: show));
    } on LookupFailedException {
      summary.unmatched.add(UnmatchedTitle(
          title: t.title, year: t.year, source: t.source, lookupFailed: true));
    }
  }

  Future<TvShow> _retryDetails(int id) async {
    try {
      return await _api.getTvDetails(id);
    } catch (_) {
      await Future<void>.delayed(_retryDelay);
      try {
        return await _api.getTvDetails(id);
      } catch (e) {
        throw LookupFailedException(e);
      }
    }
  }

  // ---------------------------------------------------------------- writes --

  Future<void> _write(DocumentReference<Map<String, dynamic>> userRef,
      _LibraryState state, List<_Matched> chunk, ImportSummary summary) async {
    final ops = <void Function(WriteBatch)>[];
    for (final m in chunk) {
      final movie = m.movie;
      final show = m.show;
      if (movie != null) {
        _planMovie(userRef, state, m.title, movie, ops, summary);
      } else if (show != null) {
        _planShow(userRef, state, m.title, show, ops, summary);
      }
    }
    for (var i = 0; i < ops.length; i += _maxBatchOps) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(_maxBatchOps)) {
        op(batch);
      }
      await batch.commit();
    }
  }

  static bool _hasRating(Object? v) => v is num && v > 0;

  static Object _ts(DateTime? d) =>
      d == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(d);

  void _planMovie(
    DocumentReference<Map<String, dynamic>> userRef,
    _LibraryState state,
    ImportedTitle t,
    Movie movie,
    List<void Function(WriteBatch)> ops,
    ImportSummary summary,
  ) {
    final existing = state.movies[movie.id];
    final exStatus = existing?['status'];
    final watchedOn = t.watchedOn;
    final fields = <String, dynamic>{};
    var changed = false;

    // Watched wins over watchlist (like Letterboxd, where logging a film
    // takes it off your watchlist); nothing ever moves watched → watchlist.
    final wantsWatched = t.watched || t.diary.isNotEmpty;
    if (wantsWatched && exStatus != 'watched') {
      fields['status'] = 'watched';
      fields['watchedAt'] = _ts(watchedOn);
      summary.moviesWatched++;
    } else if (!wantsWatched && t.watchlist && exStatus == null) {
      fields['status'] = 'watchlist';
      summary.watchlist++;
    }
    final rating = t.rating;
    if (rating != null && !_hasRating(existing?['rating'])) {
      fields['rating'] = rating;
      summary.ratings++;
    }

    final movieRef = userRef.collection('movies').doc(movie.id.toString());
    if (fields.isNotEmpty) {
      changed = true;
      final data = existing == null
          ? {
              ...MovieService.metaFor(movie),
              ...fields,
              'addedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }
          : {...fields, 'updatedAt': FieldValue.serverTimestamp()};
      ops.add((b) => b.set(movieRef, data, SetOptions(merge: true)));
      state.movies[movie.id] = {...?existing, ...fields};

      if (fields['status'] == 'watched') {
        final effectiveRating =
            rating ?? (existing?['rating'] as num?)?.toDouble();
        // Same doc + fields as MovieService._logWatched, but dated to the
        // actual watch instead of "now".
        ops.add((b) => b.set(
              userRef.collection('activity').doc('movie-${movie.id}'),
              {
                'kind': 'movie',
                'ref': 'movie-${movie.id}',
                'movieId': movie.id,
                'title': movie.title,
                'posterPath': movie.posterPath,
                if (effectiveRating != null && effectiveRating > 0)
                  'rating': effectiveRating,
                'at': _ts(watchedOn),
              },
            ));
      }
    }

    // Diary: one entry per dated watch, skipping dates that already have
    // that many entries for this film (covers both re-imports and watches
    // the user already logged by hand in WatchVerse).
    final perDay = <String, int>{};
    final entries = [...t.diary]
      ..sort((a, b) => a.watchedOn.compareTo(b.watchedOn));
    for (final e in entries) {
      final day = _dayKey(e.watchedOn);
      final index = perDay[day] = (perDay[day] ?? -1) + 1;
      final countKey = '${movie.id}|$day';
      if (index < (state.diaryCounts[countKey] ?? 0)) continue;
      state.diaryCounts[countKey] = index + 1;
      changed = true;
      summary.diaryEntries++;
      final r = e.rating;
      ops.add((b) => b.set(
            userRef.collection('diary').doc('import-lb-${movie.id}-$day-$index'),
            {
              // Same shape as MovieService.logWatch.
              'mediaType': 'movie',
              'id': movie.id,
              'title': movie.title,
              'posterPath': movie.posterPath,
              if (r != null && r > 0) 'rating': r,
              'watchedOn': Timestamp.fromDate(e.watchedOn),
              'loggedAt': FieldValue.serverTimestamp(),
              'importedFrom': 'letterboxd',
            },
          ));
    }

    if (!changed) summary.alreadyInLibrary++;
  }

  void _planShow(
    DocumentReference<Map<String, dynamic>> userRef,
    _LibraryState state,
    ImportedTitle t,
    TvShow show,
    List<void Function(WriteBatch)> ops,
    ImportSummary summary,
  ) {
    final existing = state.shows[show.id];
    final ref = userRef.collection('shows').doc(show.id.toString());
    final rating = t.rating;
    final addRating = rating != null && !_hasRating(existing?['userRating']);
    if (existing == null) {
      // Same as TvTrackingService.addShow: tracked, nothing watched.
      ops.add((b) => b.set(ref, {
            ...TvTrackingService.metadataFor(show),
            'watchedCount': 0,
            'status': 'watchlist',
            if (addRating) 'userRating': rating,
            'addedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }));
      state.shows[show.id] = {
        'status': 'watchlist',
        if (addRating) 'userRating': rating,
      };
      summary.shows++;
      if (addRating) summary.ratings++;
    } else if (addRating) {
      ops.add((b) => b.set(
          ref,
          {'userRating': rating, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true)));
      state.shows[show.id] = {...existing, 'userRating': rating};
      summary.ratings++;
    } else {
      summary.alreadyInLibrary++;
    }
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';
}

class _Matched {
  final ImportedTitle title;
  final Movie? movie;
  final TvShow? show;
  _Matched(this.title, {this.movie, this.show});
}

/// The user's library as of the start of the import, kept up to date in
/// memory as the import writes — one read per collection instead of one
/// per title, and in-run duplicates (two rows resolving to the same TMDB
/// id) see each other's writes.
class _LibraryState {
  final Map<int, Map<String, dynamic>> movies;
  final Map<int, Map<String, dynamic>> shows;

  /// `"{movieId}|yyyymmdd"` → number of diary entries on that day.
  final Map<String, int> diaryCounts;

  _LibraryState(this.movies, this.shows, this.diaryCounts);

  static Future<_LibraryState> load(
      DocumentReference<Map<String, dynamic>> userRef) async {
    final results = await Future.wait([
      userRef.collection('movies').get(),
      userRef.collection('shows').get(),
      userRef.collection('diary').get(),
    ]);
    Map<int, Map<String, dynamic>> byId(
            QuerySnapshot<Map<String, dynamic>> s) =>
        {
          for (final d in s.docs)
            if (int.tryParse(d.id) != null) int.parse(d.id): d.data(),
        };
    final diary = <String, int>{};
    for (final d in results[2].docs) {
      final data = d.data();
      final id = data['id'];
      final at = data['watchedOn'];
      if (data['mediaType'] != 'movie' || id is! num || at is! Timestamp) {
        continue;
      }
      final key = '${id.toInt()}|${LibraryImportService._dayKey(at.toDate())}';
      diary[key] = (diary[key] ?? 0) + 1;
    }
    return _LibraryState(byId(results[0]), byId(results[1]), diary);
  }
}
