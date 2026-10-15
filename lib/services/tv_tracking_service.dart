import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';

/// Handles per-user TV show + episode tracking in Firestore.
///
/// Layout:
///   users/{uid}/shows/{showId}                 -> show metadata + denormalized
///                                                 watchedCount / status
///   users/{uid}/shows/{showId}/watched/{key}   -> one doc per watched episode
///                                                 (key = "s2e5")
class TvTrackingService {
  TvTrackingService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  static final TvTrackingService instance = TvTrackingService._();

  /// Test-only factory: inject a fake Firestore/Auth instead of touching
  /// real backends.
  @visibleForTesting
  factory TvTrackingService.test(
          {required FirebaseFirestore firestore, required FirebaseAuth auth}) =>
      TvTrackingService._(firestore: firestore, auth: auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  /// Per-show lock around the read-modify-write in [setEpisodeWatched],
  /// [setSeasonWatched] and [markEpisodesWatched]. Each reads the watched
  /// set, then writes `watchedCount` and a `watchedMinutes` *increment*
  /// based on it; two of them racing (a double tap, or tapping a second
  /// episode before the first write lands) both saw the same stale set and
  /// both incremented — inflating watched minutes and logging duplicate
  /// history entries. Held only until the batch is handed to Firestore
  /// (`commit()` called, not awaited): the next read already sees that
  /// pending local write, so offline taps don't queue behind a server ack.
  final _showLocks = <int, Future<void>>{};

  Future<void Function()> _lockShow(int showId) async {
    final previous = _showLocks[showId];
    final done = Completer<void>();
    _showLocks[showId] = done.future;
    if (previous != null) await previous;
    return () {
      if (identical(_showLocks[showId], done.future)) {
        _showLocks.remove(showId);
      }
      done.complete();
    };
  }

  CollectionReference<Map<String, dynamic>>? get _showsCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('shows');
  }

  DocumentReference<Map<String, dynamic>>? _showRef(int showId) =>
      _showsCol?.doc(showId.toString());

  CollectionReference<Map<String, dynamic>>? get _activityCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('activity');
  }

  Map<String, dynamic> _metadata(TvShow show) => metadataFor(show);

  /// The metadata fields every show doc carries — public so the IMDb
  /// importer (`LibraryImportService`) writes exactly the same doc shape as
  /// [addShow].
  static Map<String, dynamic> metadataFor(TvShow show) => {
        'id': show.id,
        'name': show.name,
        'posterPath': show.posterPath,
        'backdropPath': show.backdropPath,
        'firstAirDate': show.firstAirDate,
        'voteAverage': show.voteAverage,
        'totalEpisodes': show.numberOfEpisodes,
        'totalSeasons': show.numberOfSeasons,
        // ISO date string (or '' when unknown) — lets a scheduled Cloud
        // Function find "airs tomorrow"/"airs today" shows with a single
        // collectionGroup('shows') query instead of re-fetching every
        // tracked show from TMDB itself.
        'nextEpisodeAirDate': show.nextEpisodeToAir?.airDate ?? '',
        // Powers the genre-time breakdown chart on the profile screen.
        if (show.genres.isNotEmpty) 'genres': show.genres,
      };

  String _statusFor(int watched, int total) {
    if (total > 0 && watched >= total) return 'completed';
    if (watched > 0) return 'watching';
    return 'watchlist';
  }

  // --------------------------------------------------------------- reads ----

  /// Live stream of watched-episode keys for a show (drives the detail screen).
  Stream<Set<String>> watchedKeysStream(int showId) {
    final ref = _showRef(showId);
    if (ref == null) return Stream.value(<String>{});
    return ref
        .collection('watched')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  Future<Set<String>> watchedKeys(int showId) async {
    final ref = _showRef(showId);
    if (ref == null) return <String>{};
    final snap = await ref.collection('watched').get();
    return snap.docs.map((d) => d.id).toSet();
  }

  /// When the most recently watched episode of this show was marked watched,
  /// or null if none has been watched yet. Drives the "Up Next" feed's
  /// most-recently-watched-first ordering.
  Future<DateTime?> lastWatchedAt(int showId) async {
    final ref = _showRef(showId);
    if (ref == null) return null;
    final snap = await ref
        .collection('watched')
        .orderBy('watchedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final ts = snap.docs.first.data()['watchedAt'];
    return ts is Timestamp ? ts.toDate() : null;
  }

  /// When each watched episode of this show was marked watched, keyed by
  /// episode key (`s2e5`) — the keys are exactly the watched set. Null when
  /// a doc has no usable timestamp. Feeds the Up Next recap sheet; served
  /// from Firestore's local cache when offline.
  Future<Map<String, DateTime?>> watchedAtByKey(int showId) async {
    final ref = _showRef(showId);
    if (ref == null) return {};
    final snap = await ref.collection('watched').get(const GetOptions(
        serverTimestampBehavior: ServerTimestampBehavior.estimate));
    return {
      for (final d in snap.docs)
        d.id: switch (d.data()['watchedAt']) {
          final Timestamp ts => ts.toDate(),
          _ => null,
        },
    };
  }

  Future<bool> isTracked(int showId) async {
    final ref = _showRef(showId);
    if (ref == null) return false;
    final snap = await ref.get();
    return snap.exists;
  }

  /// Live show document (metadata + status), or null when not tracked.
  Stream<Map<String, dynamic>?> showStream(int showId) {
    final ref = _showRef(showId);
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map((s) => s.exists ? s.data() : null);
  }

  DocumentReference<Map<String, dynamic>>? _noteRef(int showId, String key) =>
      _showRef(showId)?.collection('notes').doc(key);

  /// Live private note + rating for a single episode (key = `s2e5`).
  Stream<Map<String, dynamic>?> episodeNoteStream(int showId, String key) {
    final ref = _noteRef(showId, key);
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map((s) => s.exists ? s.data() : null);
  }

  /// Saves the user's private note and/or rating for an episode.
  Future<void> setEpisodeNote(int showId, String key,
      {String? note, double? rating}) async {
    final ref = _noteRef(showId, key);
    if (ref == null) return;
    await ref.set({
      if (note != null) 'note': note,
      if (rating != null) 'rating': rating,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Live list of tracked shows (for the Watchlist "Shows" tab), newest first.
  Stream<List<Map<String, dynamic>>> trackedShowsStream() {
    final col = _showsCol;
    if (col == null) return Stream.value([]);
    return col.orderBy('updatedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => d.data()).toList(),
        );
  }

  /// Every tracked show, once — used by [ExportService] to build the
  /// full-library CSV export.
  Future<List<Map<String, dynamic>>> allShowsOnce() async {
    final col = _showsCol;
    if (col == null) return [];
    final snap = await col.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Live watch-history timeline, newest first. Ordered by `at` only, so it
  /// needs just a single-field index (created automatically by Firestore).
  Stream<List<Map<String, dynamic>>> activityStream({int limit = 60}) {
    final col = _activityCol;
    if (col == null) return Stream.value([]);
    return col.orderBy('at', descending: true).limit(limit).snapshots().map(
          (snap) => snap.docs.map((d) => d.data()).toList(),
        );
  }

  /// One-time read of the same timeline as [activityStream], for screens
  /// that render a snapshot rather than watch it live (e.g. the stats
  /// charts) — avoids holding an open Firestore listener (and its ongoing
  /// read cost) for data that doesn't need to update in real time.
  Future<List<Map<String, dynamic>>> activityOnce({int limit = 60}) async {
    final col = _activityCol;
    if (col == null) return [];
    final snap =
        await col.orderBy('at', descending: true).limit(limit).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Watched-episode docs of one show whose `watchedAt` is in
  /// `[start, end)`, read once (Year in Review). A single-field range filter
  /// on the subcollection, so Firestore's automatic index covers it.
  Future<List<Map<String, dynamic>>> watchedEpisodesBetweenOnce(
      int showId, DateTime start, DateTime end) async {
    final ref = _showRef(showId);
    if (ref == null) return [];
    final snap = await ref
        .collection('watched')
        .where('watchedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Activity-timeline entries with `at` in `[start, end)`, read once
  /// (Year in Review uses the `kind: 'episode'` ones for exact runtimes).
  Future<List<Map<String, dynamic>>> activityBetweenOnce(
      DateTime start, DateTime end) async {
    final col = _activityCol;
    if (col == null) return [];
    final snap = await col
        .where('at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // -------------------------------------------------------------- writes ----

  /// Adds a show to tracking without marking any episode (status: watchlist).
  Future<void> addShow(TvShow show) async {
    final ref = _showRef(show.id);
    if (ref == null) return;
    final snap = await ref.get();
    await ref.set({
      ..._metadata(show),
      if (!snap.exists) ...{
        'watchedCount': 0,
        'status': 'watchlist',
        'addedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stores the user's star rating for a show (creates the tracking doc if
  /// needed). Rating a show implicitly adds it to My Shows.
  Future<void> setRating(TvShow show, double rating) async {
    final ref = _showRef(show.id);
    if (ref == null) return;
    final snap = await ref.get();
    await ref.set({
      ..._metadata(show),
      'userRating': rating,
      if (!snap.exists) ...{
        'watchedCount': 0,
        'status': 'watchlist',
        'addedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Marks/unmarks a show as a favorite (creates the tracking doc if needed).
  Future<void> setFavorite(TvShow show, bool favorite) async {
    final ref = _showRef(show.id);
    if (ref == null) return;
    final snap = await ref.get();
    await ref.set({
      ..._metadata(show),
      'favorite': favorite,
      if (!snap.exists) ...{
        'watchedCount': 0,
        'status': 'watchlist',
        'addedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Batch "catch up": marks a list of earlier episodes watched in one write,
  /// keeping the denormalized count in sync. No per-episode activity entry, so
  /// catching up doesn't flood the history/friends feed.
  Future<void> markEpisodesWatched(TvShow show, List<Episode> episodes) async {
    final ref = _showRef(show.id);
    if (ref == null || episodes.isEmpty) return;
    final unlock = await _lockShow(show.id);
    final Future<void> commit;
    try {
      final current = await watchedKeys(show.id);
      final ops = <void Function(WriteBatch)>[];
      var minutesDelta = 0;
      for (final ep in episodes) {
        if (!current.contains(ep.key)) {
          ops.add((b) => b.set(ref.collection('watched').doc(ep.key), {
                'season': ep.seasonNumber,
                'episode': ep.episodeNumber,
                'watchedAt': FieldValue.serverTimestamp(),
              }));
          current.add(ep.key);
          minutesDelta += ep.runtime;
        }
      }
      final count = current.length;
      ops.add((b) => b.set(ref, {
            ..._metadata(show),
            'watchedCount': count,
            if (minutesDelta > 0)
              'watchedMinutes': FieldValue.increment(minutesDelta),
            'status': _statusFor(count, show.numberOfEpisodes),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)));
      commit = _commitChunked(ops);
    } finally {
      unlock();
    }
    await commit;
  }

  /// Removes a show and all of its watched-episode records and notes.
  Future<void> removeShow(int showId) async {
    final ref = _showRef(showId);
    if (ref == null) return;
    final watched = await ref.collection('watched').get();
    final notes = await ref.collection('notes').get();
    await _commitChunked([
      for (final doc in [...watched.docs, ...notes.docs])
        (WriteBatch b) => b.delete(doc.reference),
      (WriteBatch b) => b.delete(ref),
    ]);
  }

  /// Firestore caps a batch at 500 writes; long-running shows (One Piece,
  /// The Simpsons) exceed that when caught up or removed in one go. Applies
  /// [ops] in batches of 450, the last op landing in the final batch — so
  /// callers put the parent show doc's count update last. Every batch is
  /// committed before awaiting any, so all writes hit the local cache at
  /// once (same as a single batch) for whoever reads next under the lock.
  Future<void> _commitChunked(List<void Function(WriteBatch)> ops) {
    const size = 450;
    final commits = <Future<void>>[];
    for (var i = 0; i < ops.length; i += size) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(size)) {
        op(batch);
      }
      commits.add(batch.commit());
    }
    return Future.wait(commits);
  }

  /// Toggles a single episode's watched state, keeping the denormalized
  /// count/status on the parent show document in sync.
  ///
  /// Uses a plain batch (like [setSeasonWatched]/[markEpisodesWatched])
  /// instead of a transaction: `runTransaction` always forces a server
  /// round-trip before resolving, which is what made each single-episode tap
  /// feel laggy compared to the batch-based season/catch-up actions. Races
  /// between taps on the same show are handled by [_lockShow] instead.
  Future<void> setEpisodeWatched(
      TvShow show, Episode episode, bool watched) async {
    final ref = _showRef(show.id);
    if (ref == null) return;
    final epRef = ref.collection('watched').doc(episode.key);

    final unlock = await _lockShow(show.id);
    final pending = <Future<void>>[];
    try {
      await _setEpisodeWatchedLocked(
          ref, epRef, show, episode, watched, pending);
    } finally {
      unlock();
    }
    await Future.wait(pending);
  }

  /// Body of [setEpisodeWatched], run under [_lockShow]. Writes are started
  /// (applied locally) but not awaited — they're collected in [pending].
  Future<void> _setEpisodeWatchedLocked(
      DocumentReference<Map<String, dynamic>> ref,
      DocumentReference<Map<String, dynamic>> epRef,
      TvShow show,
      Episode episode,
      bool watched,
      List<Future<void>> pending) async {
    final current = await watchedKeys(show.id);
    final already = current.contains(episode.key);
    final changed = watched != already;
    if (!changed) return;

    final batch = _db.batch();
    if (watched) {
      batch.set(epRef, {
        'season': episode.seasonNumber,
        'episode': episode.episodeNumber,
        'watchedAt': FieldValue.serverTimestamp(),
      });
      current.add(episode.key);
    } else {
      batch.delete(epRef);
      current.remove(episode.key);
    }
    final count = current.length;
    batch.set(ref, {
      ..._metadata(show),
      'watchedCount': count,
      // Denormalized running total of watched-episode runtime, minutes.
      // 0-runtime episodes (TMDB doesn't always have it) simply contribute
      // nothing — this undercounts rather than blocking the feature.
      if (episode.runtime > 0)
        'watchedMinutes': FieldValue.increment(
            watched ? episode.runtime : -episode.runtime),
      'status': _statusFor(count, show.numberOfEpisodes),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    pending.add(batch.commit());

    // Mirror the change into the watch-history timeline.
    final epRefKey = 'ep-${show.id}-${episode.key}';
    final activity = _activityCol;
    if (watched && activity != null) {
      pending.add(activity.add({
        'kind': 'episode',
        'ref': epRefKey,
        'showId': show.id,
        'showName': show.name,
        'posterPath': show.posterPath,
        'season': episode.seasonNumber,
        'episode': episode.episodeNumber,
        'episodeName': episode.name,
        if (episode.runtime > 0) 'runtime': episode.runtime,
        'at': FieldValue.serverTimestamp(),
      }));
    } else if (!watched) {
      pending.addAll(await _deleteActivity(epRefKey));
    }
  }

  /// Starts deleting every activity entry for [ref] and returns the pending
  /// deletes instead of awaiting them (see [_lockShow]).
  Future<List<Future<void>>> _deleteActivity(String ref) async {
    final col = _activityCol;
    if (col == null) return const [];
    final q = await col.where('ref', isEqualTo: ref).get();
    return [for (final doc in q.docs) doc.reference.delete()];
  }

  /// Marks/unmarks every episode of a season in one batch.
  Future<void> setSeasonWatched(
      TvShow show, List<Episode> episodes, bool watched) async {
    final ref = _showRef(show.id);
    if (ref == null || episodes.isEmpty) return;

    final unlock = await _lockShow(show.id);
    final pending = <Future<void>>[];
    try {
      await _setSeasonWatchedLocked(ref, show, episodes, watched, pending);
    } finally {
      unlock();
    }
    await Future.wait(pending);
  }

  /// Body of [setSeasonWatched], run under [_lockShow] — same pattern as
  /// [_setEpisodeWatchedLocked].
  Future<void> _setSeasonWatchedLocked(
      DocumentReference<Map<String, dynamic>> ref,
      TvShow show,
      List<Episode> episodes,
      bool watched,
      List<Future<void>> pending) async {
    final current = await watchedKeys(show.id);
    // Chunked like markEpisodesWatched: some shows list one "season" with
    // more than 500 episodes (long-running anime/daily shows), which a
    // single batch can't hold.
    final ops = <void Function(WriteBatch)>[];
    var minutesDelta = 0;

    for (final ep in episodes) {
      final epRef = ref.collection('watched').doc(ep.key);
      if (watched && !current.contains(ep.key)) {
        ops.add((b) => b.set(epRef, {
              'season': ep.seasonNumber,
              'episode': ep.episodeNumber,
              'watchedAt': FieldValue.serverTimestamp(),
            }));
        current.add(ep.key);
        minutesDelta += ep.runtime;
      } else if (!watched && current.contains(ep.key)) {
        ops.add((b) => b.delete(epRef));
        current.remove(ep.key);
        minutesDelta -= ep.runtime;
      }
    }

    final count = current.length;
    ops.add((b) => b.set(ref, {
          ..._metadata(show),
          'watchedCount': count,
          if (minutesDelta != 0)
            'watchedMinutes': FieldValue.increment(minutesDelta),
          'status': _statusFor(count, show.numberOfEpisodes),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));

    pending.add(_commitChunked(ops));

    // Log a single season-level entry in the watch history.
    final seasonNumber = episodes.first.seasonNumber;
    final seasonRef = 'season-${show.id}-$seasonNumber';
    final activity = _activityCol;
    if (watched && activity != null) {
      pending.add(activity.add({
        'kind': 'season',
        'ref': seasonRef,
        'showId': show.id,
        'showName': show.name,
        'posterPath': show.posterPath,
        'season': seasonNumber,
        'count': episodes.length,
        'runtime': episodes.fold<int>(0, (acc, e) => acc + e.runtime),
        'at': FieldValue.serverTimestamp(),
      }));
    } else if (!watched) {
      pending.addAll(await _deleteActivity(seasonRef));
    }
  }

  /// One-time backfill for shows tracked before `watchedMinutes`/`genres`/
  /// `nextEpisodeAirDate` existed: recomputes watched minutes from scratch
  /// by re-fetching each watched season's episode runtimes from TMDB and
  /// summing the ones actually marked watched, and fills in genres +
  /// next-episode air date from the show detail endpoint if either is
  /// missing (the latter is what lets the episode-reminder notifications —
  /// see scripts/notify/run.js — find this show at all). Safe to call
  /// repeatedly (minutes are overwritten, not incremented).
  Future<void> backfillShowDetails(int showId) async {
    final ref = _showRef(showId);
    if (ref == null) return;
    final showSnap = await ref.get();
    final watchedSnap = await ref.collection('watched').get();

    final update = <String, dynamic>{};

    final hasGenres =
        ((showSnap.data()?['genres'] as List?) ?? const []).isNotEmpty;
    final hasAirDate =
        (showSnap.data()?['nextEpisodeAirDate'] as String? ?? '').isNotEmpty;
    if (!hasGenres || !hasAirDate) {
      try {
        final show = await APIservices().getTvDetails(showId);
        if (show.genres.isNotEmpty) update['genres'] = show.genres;
        update['nextEpisodeAirDate'] = show.nextEpisodeToAir?.airDate ?? '';
      } catch (_) {
        // Leave both unset; the rest of the backfill can still proceed.
      }
    }

    if (watchedSnap.docs.isNotEmpty) {
      final episodeNumbersBySeason = <int, Set<int>>{};
      for (final doc in watchedSnap.docs) {
        final season = (doc.data()['season'] as num?)?.toInt();
        final episode = (doc.data()['episode'] as num?)?.toInt();
        if (season == null || episode == null) continue;
        (episodeNumbersBySeason[season] ??= <int>{}).add(episode);
      }

      final api = APIservices();
      var minutes = 0;
      for (final entry in episodeNumbersBySeason.entries) {
        try {
          final episodes = await api.getSeasonEpisodes(showId, entry.key);
          for (final ep in episodes) {
            if (entry.value.contains(ep.episodeNumber)) minutes += ep.runtime;
          }
        } catch (_) {
          // Skip a season TMDB couldn't return; the rest still get counted.
        }
      }
      update['watchedMinutes'] = minutes;
    }

    if (update.isNotEmpty) {
      await ref.set(update, SetOptions(merge: true));
    }
  }

  /// Runs [backfillShowDetails] across every show the user tracks.
  Future<void> backfillAllShowDetails() async {
    final col = _showsCol;
    if (col == null) return;
    final snap = await col.get();
    for (final doc in snap.docs) {
      final id = (doc.data()['id'] as num?)?.toInt();
      if (id != null) await backfillShowDetails(id);
    }
  }
}
