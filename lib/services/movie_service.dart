import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:watch_verse/models/model.dart';

/// Per-user movie library + ratings, mirroring [TvTrackingService] for shows.
///
/// One document per movie at `users/{uid}/movies/{movieId}`:
///   status   : 'watchlist' | 'watched'   (a movie has a single status)
///   favorite : bool
///   rating   : double (0–5)
///   note     : String  (diary note)
///
/// Ratings live here (not on a watchlist entry), so a rating persists even if
/// the movie is never added to a list — fixing "my ratings disappear".
class MovieService {
  MovieService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  static final MovieService instance = MovieService._();

  /// Test-only factory: inject a fake Firestore/Auth instead of touching
  /// real backends.
  @visibleForTesting
  factory MovieService.test(
          {required FirebaseFirestore firestore, required FirebaseAuth auth}) =>
      MovieService._(firestore: firestore, auth: auth);

  /// Letterboxd-style cap: a showcase of exactly 3 favorite films, not an
  /// unbounded list.
  static const maxFavorites = 3;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('movies');
  }

  DocumentReference<Map<String, dynamic>>? _ref(int id) =>
      _col?.doc(id.toString());

  CollectionReference<Map<String, dynamic>>? get _activityCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('activity');
  }

  CollectionReference<Map<String, dynamic>>? get _diaryCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('diary');
  }

  /// Mirrors a watched movie into the shared activity timeline (deterministic
  /// doc id → no duplicates). Used by history + the friends feed.
  Future<void> _logWatched(Movie m, double? rating) async {
    final col = _activityCol;
    if (col == null) return;
    await col.doc('movie-${m.id}').set({
      'kind': 'movie',
      'ref': 'movie-${m.id}',
      'movieId': m.id,
      'title': m.title,
      'posterPath': m.posterPath,
      if (rating != null && rating > 0) 'rating': rating,
      'at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _unlogWatched(int id) async {
    await _activityCol?.doc('movie-$id').delete();
  }

  Map<String, dynamic> _meta(Movie m) => {
        'id': m.id,
        'title': m.title,
        'posterPath': m.posterPath,
        'backdropPath': m.backDropPath,
        'releaseDate': m.releaseDate,
        'voteAverage': m.voteAverage,
        'overview': m.overview,
      };

  Future<void> _upsert(Movie m, Map<String, dynamic> fields) async {
    final ref = _ref(m.id);
    if (ref == null) return;
    final snap = await ref.get();
    await ref.set({
      ..._meta(m),
      ...fields,
      if (!snap.exists) 'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------- reads ---

  Stream<Map<String, dynamic>?> movieStream(int id) {
    final ref = _ref(id);
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map((s) => s.exists ? s.data() : null);
  }

  Stream<List<Map<String, dynamic>>> _streamWhere(String field, Object value) {
    final col = _col;
    if (col == null) return Stream.value([]);
    return col.where(field, isEqualTo: value).snapshots().map(
          (snap) => snap.docs.map((d) => d.data()).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> toWatchStream() =>
      _streamWhere('status', 'watchlist');
  Stream<List<Map<String, dynamic>>> watchedStream() =>
      _streamWhere('status', 'watched');
  Stream<List<Map<String, dynamic>>> favoritesStream() =>
      _streamWhere('favorite', true);

  /// All diary entries (watches + rewatches) for one movie, newest-watched
  /// first. Single-field `where` (auto-indexed); sorted client-side so no
  /// composite index is needed.
  Stream<List<Map<String, dynamic>>> diaryStream(int movieId) {
    final col = _diaryCol;
    if (col == null) return Stream.value([]);
    return col.where('id', isEqualTo: movieId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => {...d.data(), 'entryId': d.id})
          .toList();
      list.sort((a, b) {
        final ta = a['watchedOn'];
        final tb = b['watchedOn'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        return 0;
      });
      return list;
    });
  }

  // --------------------------------------------------------------- writes ---

  Future<void> setStatus(Movie m, String status) async {
    await _upsert(m, {
      'status': status,
      if (status == 'watched') 'watchedAt': FieldValue.serverTimestamp(),
    });
    if (status == 'watched') {
      await _logWatched(m, null);
    } else {
      await _unlogWatched(m.id);
    }
  }

  /// Marks/unmarks a movie as one of the user's top favorites. Returns `false`
  /// (without writing) when trying to favorite a 4th film while 3 are already
  /// picked — the caller should prompt the user to unpick one first.
  Future<bool> setFavorite(Movie m, bool favorite) async {
    if (favorite) {
      final col = _col;
      if (col != null) {
        final current =
            await col.where('favorite', isEqualTo: true).get();
        final alreadyFavorite =
            current.docs.any((d) => d.id == m.id.toString());
        if (!alreadyFavorite && current.docs.length >= maxFavorites) {
          return false;
        }
      }
    }
    await _upsert(m, {'favorite': favorite});
    return true;
  }

  Future<void> setRating(Movie m, double rating) =>
      _upsert(m, {'rating': rating});

  /// Diary entry: marks watched and stores rating + note in one go.
  Future<void> saveDiary(Movie m, {double? rating, String? note}) async {
    await _upsert(m, {
      'status': 'watched',
      'watchedAt': FieldValue.serverTimestamp(),
      if (rating != null) 'rating': rating,
      if (note != null) 'note': note,
    });
    await _logWatched(m, rating);
  }

  /// Logs a (re)watch: appends a dated diary entry AND keeps the movie doc's
  /// status/rating/note in sync with this latest watch. Enables rewatches —
  /// each call adds another entry rather than overwriting.
  Future<void> logWatch(Movie m,
      {double? rating, String? note, DateTime? watchedOn}) async {
    final col = _diaryCol;
    final when = watchedOn ?? DateTime.now();
    await col?.add({
      'mediaType': 'movie',
      'id': m.id,
      'title': m.title,
      'posterPath': m.posterPath,
      if (rating != null && rating > 0) 'rating': rating,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'watchedOn': Timestamp.fromDate(when),
      'loggedAt': FieldValue.serverTimestamp(),
    });
    await _upsert(m, {
      'status': 'watched',
      'watchedAt': Timestamp.fromDate(when),
      if (rating != null) 'rating': rating,
      if (note != null) 'note': note.trim(),
    });
    await _logWatched(m, rating);
  }

  Future<void> deleteDiaryEntry(String entryId) async {
    await _diaryCol?.doc(entryId).delete();
  }

  Future<void> remove(int id) async {
    await _ref(id)?.delete();
    await _unlogWatched(id);
  }
}
