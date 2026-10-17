import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/app_firebase.dart';

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
      : _db = firestore ?? AppFirebase.firestore,
        _auth = auth ?? AppFirebase.auth;
  static final MovieService instance = MovieService._();

  /// Test-only factory: inject a fake Firestore/Auth instead of touching
  /// real backends.
  @visibleForTesting
  factory MovieService.test(
          {required FirebaseFirestore firestore, required FirebaseAuth auth}) =>
      MovieService._(firestore: firestore, auth: auth);

  /// The profile "showcase" always has exactly 3 slots, manually chosen by
  /// the user from their (unlimited) favorites — see [setShowcaseSlot].
  static const showcaseSlots = 3;

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
      // Minutes this watch contributed — powers the weekly/day-of-week
      // watch-time charts, which sum activity entries rather than re-fetch
      // from TMDB. 0/missing just doesn't contribute (same as the profile's
      // running totals).
      if (m.runtime > 0) 'runtime': m.runtime,
      'at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _unlogWatched(int id) async {
    await _activityCol?.doc('movie-$id').delete();
  }

  Map<String, dynamic> _meta(Movie m) => metaFor(m);

  /// The metadata fields every movie doc carries — public so the
  /// Letterboxd/IMDb importer (`LibraryImportService`) writes exactly the
  /// same doc shape as the in-app write paths.
  static Map<String, dynamic> metaFor(Movie m) => {
        'id': m.id,
        'title': m.title,
        'posterPath': m.posterPath,
        'backdropPath': m.backDropPath,
        'releaseDate': m.releaseDate,
        'voteAverage': m.voteAverage,
        'overview': m.overview,
        // Only known once resolved via APIservices.getMovieDetailExtras (the
        // list endpoints this app browses with don't include either) — 0/
        // empty means "unknown", not "none", and is left out of the
        // time-spent sum / genre chart on the profile screen.
        if (m.runtime > 0) 'runtime': m.runtime,
        if (m.genres.isNotEmpty) 'genres': m.genres,
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

  /// The manually-curated 3-slot showcase — a subset of [favoritesStream],
  /// ordered by the slot the user picked (0, 1, 2) rather than add date.
  Stream<List<Map<String, dynamic>>> showcaseStream() =>
      favoritesStream().map((items) {
        final showcased = items.where((m) => m['showcaseSlot'] != null)
            .toList()
          ..sort((a, b) =>
              (a['showcaseSlot'] as num).compareTo(b['showcaseSlot'] as num));
        return showcased;
      });

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

  /// Every diary entry this user has ever logged (all movies), newest first.
  /// A one-time fetch, not a stream — same "point-in-time report" reasoning
  /// as `TvTrackingService.activityOnce`, used by [ExportService] to build
  /// the CSV export.
  Future<List<Map<String, dynamic>>> allDiaryEntriesOnce() async {
    final col = _diaryCol;
    if (col == null) return [];
    final snap = await col.orderBy('watchedOn', descending: true).get();
    return snap.docs.map((d) => {...d.data(), 'entryId': d.id}).toList();
  }

  /// Every movie in this user's library (watchlist + watched), once — same
  /// "point-in-time report" reasoning as [allDiaryEntriesOnce], used by
  /// [ExportService] to build the full-library CSV export.
  Future<List<Map<String, dynamic>>> allMoviesOnce() async {
    final col = _col;
    if (col == null) return [];
    final snap = await col.get();
    return snap.docs.map((d) => d.data()).toList();
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

  /// Marks/unmarks a movie as a favorite (an unlimited "liked films" list —
  /// separate from the 3-slot profile showcase, see [setShowcaseSlot]).
  Future<void> setFavorite(Movie m, bool favorite) async {
    await _upsert(m, {
      'favorite': favorite,
      // Un-favoriting also drops it out of the showcase, if it was in it.
      if (!favorite) 'showcaseSlot': null,
    });
  }

  /// Puts/removes a favorited movie in one of the 3 profile showcase slots
  /// (0, 1 or 2). Pass `null` to remove it from the showcase without
  /// un-favoriting it.
  Future<void> setShowcaseSlot(int movieId, int? slot) async {
    await _ref(movieId)?.set(
      {'showcaseSlot': slot}, SetOptions(merge: true));
  }

  Future<void> setRating(Movie m, double rating) =>
      _upsert(m, {'rating': rating});

  /// Diary entry: marks watched and stores rating + note in one go.
  ///
  /// The note is a *private* diary field, but `users/{uid}/movies/{id}` is
  /// readable by every signed-in user (public profiles) — so this goes
  /// through [logWatch], which keeps the note in the owner-only `diary`
  /// collection and never on the movie doc.
  Future<void> saveDiary(Movie m, {double? rating, String? note}) =>
      logWatch(m, rating: rating, note: note);

  /// Logs a (re)watch: appends a dated diary entry AND keeps the movie doc's
  /// status/rating in sync with this latest watch. Enables rewatches —
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
      'rating': ?rating,
      // The note stays in the private diary entry above only — see
      // [saveDiary] for why it must not sit on the movie doc.
      'note': FieldValue.delete(),
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

  /// One-time backfill for movies watched before `runtime`/`genres` existed:
  /// fetches both from TMDB for every watched movie still missing either.
  /// Safe to call repeatedly — already-known values are left untouched.
  Future<void> backfillDetails() async {
    final col = _col;
    if (col == null) return;
    final snap = await col.where('status', isEqualTo: 'watched').get();
    final api = APIservices();
    for (final doc in snap.docs) {
      final data = doc.data();
      final hasRuntime = ((data['runtime'] ?? 0) as num).toInt() > 0;
      final hasGenres = ((data['genres'] as List?) ?? const []).isNotEmpty;
      if (hasRuntime && hasGenres) continue;
      final id = (data['id'] as num?)?.toInt();
      if (id == null) continue;
      try {
        final extras = await api.getMovieDetailExtras(id);
        final update = <String, dynamic>{
          if (extras.runtime > 0) 'runtime': extras.runtime,
          if (extras.genres.isNotEmpty) 'genres': extras.genres,
        };
        if (update.isNotEmpty) {
          await doc.reference.set(update, SetOptions(merge: true));
        }
      } catch (_) {
        // Skip a movie TMDB couldn't return; the rest still get backfilled.
      }
    }
  }
}
