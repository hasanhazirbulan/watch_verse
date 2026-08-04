import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:watch_verse/models/media.dart';

/// Handles per-user TV show + episode tracking in Firestore.
///
/// Layout:
///   users/{uid}/shows/{showId}                 -> show metadata + denormalized
///                                                 watchedCount / status
///   users/{uid}/shows/{showId}/watched/{key}   -> one doc per watched episode
///                                                 (key = "s2e5")
class TvTrackingService {
  TvTrackingService._();
  static final TvTrackingService instance = TvTrackingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

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

  Map<String, dynamic> _metadata(TvShow show) => {
        'id': show.id,
        'name': show.name,
        'posterPath': show.posterPath,
        'backdropPath': show.backdropPath,
        'firstAirDate': show.firstAirDate,
        'voteAverage': show.voteAverage,
        'totalEpisodes': show.numberOfEpisodes,
        'totalSeasons': show.numberOfSeasons,
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

  /// Live watch-history timeline, newest first. Ordered by `at` only, so it
  /// needs just a single-field index (created automatically by Firestore).
  Stream<List<Map<String, dynamic>>> activityStream({int limit = 60}) {
    final col = _activityCol;
    if (col == null) return Stream.value([]);
    return col.orderBy('at', descending: true).limit(limit).snapshots().map(
          (snap) => snap.docs.map((d) => d.data()).toList(),
        );
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
    final current = await watchedKeys(show.id);
    final batch = _db.batch();
    for (final ep in episodes) {
      if (!current.contains(ep.key)) {
        batch.set(ref.collection('watched').doc(ep.key), {
          'season': ep.seasonNumber,
          'episode': ep.episodeNumber,
          'watchedAt': FieldValue.serverTimestamp(),
        });
        current.add(ep.key);
      }
    }
    batch.set(ref, {
      ..._metadata(show),
      'watchedCount': current.length,
      'status': _statusFor(current.length, show.numberOfEpisodes),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Removes a show and all of its watched-episode records.
  Future<void> removeShow(int showId) async {
    final ref = _showRef(showId);
    if (ref == null) return;
    final watched = await ref.collection('watched').get();
    final batch = _db.batch();
    for (final doc in watched.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(ref);
    await batch.commit();
  }

  /// Toggles a single episode's watched state, keeping the denormalized
  /// count/status on the parent show document in sync (atomic transaction).
  Future<void> setEpisodeWatched(
      TvShow show, Episode episode, bool watched) async {
    final ref = _showRef(show.id);
    if (ref == null) return;
    final epRef = ref.collection('watched').doc(episode.key);

    final changed = await _db.runTransaction<bool>((tx) async {
      final showSnap = await tx.get(ref);
      final epSnap = await tx.get(epRef);
      int count = (showSnap.data()?['watchedCount'] ?? 0) as int;
      final already = epSnap.exists;
      final didChange = (watched && !already) || (!watched && already);

      if (watched && !already) {
        tx.set(epRef, {
          'season': episode.seasonNumber,
          'episode': episode.episodeNumber,
          'watchedAt': FieldValue.serverTimestamp(),
        });
        count++;
      } else if (!watched && already) {
        tx.delete(epRef);
        count = count > 0 ? count - 1 : 0;
      }

      tx.set(ref, {
        ..._metadata(show),
        'watchedCount': count,
        'status': _statusFor(count, show.numberOfEpisodes),
        'addedAt': showSnap.exists
            ? (showSnap.data()?['addedAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return didChange;
    });

    // Mirror the change into the watch-history timeline (outside the tx).
    if (changed) {
      final epRefKey = 'ep-${show.id}-${episode.key}';
      if (watched) {
        await _activityCol?.add({
          'kind': 'episode',
          'ref': epRefKey,
          'showId': show.id,
          'showName': show.name,
          'posterPath': show.posterPath,
          'season': episode.seasonNumber,
          'episode': episode.episodeNumber,
          'episodeName': episode.name,
          'at': FieldValue.serverTimestamp(),
        });
      } else {
        await _deleteActivity(epRefKey);
      }
    }
  }

  Future<void> _deleteActivity(String ref) async {
    final col = _activityCol;
    if (col == null) return;
    final q = await col.where('ref', isEqualTo: ref).get();
    for (final doc in q.docs) {
      await doc.reference.delete();
    }
  }

  /// Marks/unmarks every episode of a season in one batch.
  Future<void> setSeasonWatched(
      TvShow show, List<Episode> episodes, bool watched) async {
    final ref = _showRef(show.id);
    if (ref == null || episodes.isEmpty) return;

    final current = await watchedKeys(show.id);
    final batch = _db.batch();

    for (final ep in episodes) {
      final epRef = ref.collection('watched').doc(ep.key);
      if (watched && !current.contains(ep.key)) {
        batch.set(epRef, {
          'season': ep.seasonNumber,
          'episode': ep.episodeNumber,
          'watchedAt': FieldValue.serverTimestamp(),
        });
        current.add(ep.key);
      } else if (!watched && current.contains(ep.key)) {
        batch.delete(epRef);
        current.remove(ep.key);
      }
    }

    final count = current.length;
    batch.set(ref, {
      ..._metadata(show),
      'watchedCount': count,
      'status': _statusFor(count, show.numberOfEpisodes),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    // Log a single season-level entry in the watch history.
    final seasonNumber = episodes.first.seasonNumber;
    final seasonRef = 'season-${show.id}-$seasonNumber';
    if (watched) {
      await _activityCol?.add({
        'kind': 'season',
        'ref': seasonRef,
        'showId': show.id,
        'showName': show.name,
        'posterPath': show.posterPath,
        'season': seasonNumber,
        'count': episodes.length,
        'at': FieldValue.serverTimestamp(),
      });
    } else {
      await _deleteActivity(seasonRef);
    }
  }
}
