import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/services/app_firebase.dart';

/// Raw library docs the Common Ground screen compares. "Their" lists are
/// capped samples of the other user's library; "my" maps hold only the
/// viewer's docs for ids that appear in those samples (keyed by TMDB id).
class CommonGroundData {
  final List<Map<String, dynamic>> theirWatchlistMovies;
  final List<Map<String, dynamic>> theirWatchlistShows;
  final List<Map<String, dynamic>> theirRatedMovies;
  final Map<int, Map<String, dynamic>> myMoviesById;
  final Map<int, Map<String, dynamic>> myShowsById;

  const CommonGroundData({
    required this.theirWatchlistMovies,
    required this.theirWatchlistShows,
    required this.theirRatedMovies,
    required this.myMoviesById,
    required this.myShowsById,
  });
}

/// Injectable so widget tests can feed fixed data.
abstract class CommonGroundSource {
  Future<CommonGroundData> load({required String myUid, required String theirUid});
}

/// Firestore reader, sized for the Spark plan's daily read quota.
///
/// Reads per open (worst case, every cap hit):
///  * their watchlist movies — 1 query, ≤ [maxWatchlistMovies] docs
///  * their not-started shows — 1 query, ≤ [maxWatchlistShows] docs
///  * their most recent watched movies (ratings) — 1 query via
///    [SocialService.userWatchedMovies], ≤ [maxRatedMovies] docs
///  * the viewer's matching docs — `documentId in [...]` lookups in chunks of
///    [_inChunk] over just those ids; billed per doc found (min 1 per query),
///    so it costs roughly the overlap, not the viewer's whole library.
/// i.e. ≤ 120 + 50 + 120 their docs + ≤ 290 of mine + ~10 empty-query
/// minimums ≈ 590 reads in the extreme; a typical pair is far below that.
class FirestoreCommonGroundSource implements CommonGroundSource {
  FirestoreCommonGroundSource({FirebaseFirestore? firestore, SocialService? social})
      : _dbOverride = firestore,
        _socialOverride = social;

  static const maxWatchlistMovies = 120;
  static const maxWatchlistShows = 50;
  static const maxRatedMovies = 120;
  static const _inChunk = 30; // Firestore's `in` operand limit.

  final FirebaseFirestore? _dbOverride;
  final SocialService? _socialOverride;
  FirebaseFirestore get _db => _dbOverride ?? AppFirebase.firestore;
  SocialService get _social => _socialOverride ?? SocialService.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid, String name) =>
      _db.collection('users').doc(uid).collection(name);

  Future<List<Map<String, dynamic>>> _whereStatus(
      String uid, String collection, String status, int limit) async {
    try {
      final s = await _col(uid, collection)
          .where('status', isEqualTo: status)
          .limit(limit)
          .get();
      return s.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  /// The viewer's docs in [collection] for exactly [ids] (doc id = TMDB id).
  Future<Map<int, Map<String, dynamic>>> _mineByIds(
      String uid, String collection, Iterable<int> ids) async {
    final unique = ids.where((id) => id > 0).toSet().toList();
    final chunks = <List<String>>[
      for (var i = 0; i < unique.length; i += _inChunk)
        unique
            .skip(i)
            .take(_inChunk)
            .map((id) => id.toString())
            .toList(),
    ];
    final results = await Future.wait(chunks.map((chunk) async {
      try {
        final s = await _col(uid, collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        return s.docs;
      } catch (_) {
        return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
    }));
    final out = <int, Map<String, dynamic>>{};
    for (final doc in results.expand((d) => d)) {
      final id = int.tryParse(doc.id);
      if (id != null) out[id] = doc.data();
    }
    return out;
  }

  static int _idOf(Map<String, dynamic> d) =>
      ((d['id'] ?? 0) as num).toInt();

  @override
  Future<CommonGroundData> load(
      {required String myUid, required String theirUid}) async {
    final theirs = await Future.wait([
      _whereStatus(theirUid, 'movies', 'watchlist', maxWatchlistMovies),
      _whereStatus(theirUid, 'shows', 'watchlist', maxWatchlistShows),
      _social.userWatchedMovies(theirUid, limit: maxRatedMovies),
    ]);
    final watchlistMovies = theirs[0];
    final watchlistShows = theirs[1];
    final rated = theirs[2]
        .where((d) => d['rating'] is num && (d['rating'] as num) > 0)
        .toList();

    final mine = await Future.wait([
      _mineByIds(myUid, 'movies',
          [...watchlistMovies.map(_idOf), ...rated.map(_idOf)]),
      _mineByIds(myUid, 'shows', watchlistShows.map(_idOf)),
    ]);
    return CommonGroundData(
      theirWatchlistMovies: watchlistMovies,
      theirWatchlistShows: watchlistShows,
      theirRatedMovies: rated,
      myMoviesById: mine[0],
      myShowsById: mine[1],
    );
  }
}
