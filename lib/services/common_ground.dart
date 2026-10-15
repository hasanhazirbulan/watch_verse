import 'package:watch_verse/models/media.dart';

// Pure "common ground" logic between the signed-in viewer and another user:
// which titles both still want to watch, and how closely their film ratings
// line up. No Firestore here — `CommonGroundSource` fetches the raw library
// docs (same shape `MovieService` / `TvTrackingService` write) and this file
// turns them into the screen's model, so it's fully unit-testable.

/// Two ratings "agree" when they are at most this far apart on the app's
/// 0–5 star scale (so 4 vs. 5 agrees, 3 vs. 4.5 does not).
const double agreementTolerance = 1.0;

/// How many of the closest / furthest pairs the screen lists.
const int agreementHighlights = 3;

double? _rating(Map<String, dynamic>? doc, [String field = 'rating']) {
  final v = doc?[field];
  if (v is! num) return null;
  final d = v.toDouble();
  return d > 0 ? d : null;
}

int _id(Map<String, dynamic> doc) => ((doc['id'] ?? 0) as num).toInt();

MediaItem movieItemFromDoc(Map<String, dynamic> d) => MediaItem(
      id: _id(d),
      title: (d['title'] ?? '') as String,
      overview: '',
      posterPath: (d['posterPath'] ?? '') as String,
      backdropPath: (d['backdropPath'] ?? '') as String,
      date: (d['releaseDate'] ?? '') as String,
      voteAverage: ((d['voteAverage'] ?? 0) as num).toDouble(),
      mediaType: MediaType.movie,
    );

MediaItem showItemFromDoc(Map<String, dynamic> d) => MediaItem(
      id: _id(d),
      title: (d['name'] ?? '') as String,
      overview: '',
      posterPath: (d['posterPath'] ?? '') as String,
      backdropPath: (d['backdropPath'] ?? '') as String,
      date: (d['firstAirDate'] ?? '') as String,
      voteAverage: ((d['voteAverage'] ?? 0) as num).toDouble(),
      mediaType: MediaType.tv,
    );

bool _isWatchlistMovie(Map<String, dynamic>? d) => d?['status'] == 'watchlist';

/// A show "neither has started": still on the watchlist with no episode
/// marked watched.
bool _isUnstartedShow(Map<String, dynamic>? d) =>
    d != null &&
    d['status'] == 'watchlist' &&
    ((d['watchedCount'] ?? 0) as num) == 0;

/// Titles on both users' watchlists: movies both have as `watchlist`, plus
/// shows neither has started. Keeps [theirMovies] / [theirShows] order
/// (movies first), drops duplicates and docs without a valid id.
List<MediaItem> sharedWatchlist({
  required List<Map<String, dynamic>> theirMovies,
  required Map<int, Map<String, dynamic>> myMoviesById,
  List<Map<String, dynamic>> theirShows = const [],
  Map<int, Map<String, dynamic>> myShowsById = const {},
}) {
  final out = <MediaItem>[];
  final seenMovies = <int>{};
  for (final d in theirMovies) {
    final id = _id(d);
    if (id <= 0 || !_isWatchlistMovie(d)) continue;
    if (!_isWatchlistMovie(myMoviesById[id])) continue;
    if (seenMovies.add(id)) out.add(movieItemFromDoc(d));
  }
  final seenShows = <int>{};
  for (final d in theirShows) {
    final id = _id(d);
    if (id <= 0 || !_isUnstartedShow(d)) continue;
    if (!_isUnstartedShow(myShowsById[id])) continue;
    if (seenShows.add(id)) out.add(showItemFromDoc(d));
  }
  return out;
}

/// [items] with the ones [isOnMyServices] says are streamable first; order is
/// otherwise kept (stable partition). Unknown availability counts as "not".
List<MediaItem> rankByAvailability(
  List<MediaItem> items,
  bool Function(MediaItem item) isOnMyServices,
) {
  final on = <MediaItem>[];
  final off = <MediaItem>[];
  for (final item in items) {
    (isOnMyServices(item) ? on : off).add(item);
  }
  return [...on, ...off];
}

/// Up to [max] titles to pre-fill a watch poll with.
List<MediaItem> pollCandidates(List<MediaItem> shared, {int max = 6}) =>
    shared.take(max).toList();

/// One film both users rated.
class RatedPair {
  final MediaItem item;
  final double myRating;
  final double theirRating;
  const RatedPair(
      {required this.item, required this.myRating, required this.theirRating});

  double get difference => (myRating - theirRating).abs();

  // Small epsilon so 0.5-step ratings stored as doubles compare cleanly.
  bool get agrees => difference <= agreementTolerance + 1e-9;
}

class TasteAgreement {
  /// Every film both rated.
  final List<RatedPair> pairs;

  /// Closest pairs first (ties: the one you both liked more first).
  final List<RatedPair> topAgreements;

  /// Pairs outside the tolerance, furthest apart first.
  final List<RatedPair> topDisagreements;

  const TasteAgreement({
    required this.pairs,
    required this.topAgreements,
    required this.topDisagreements,
  });

  int get total => pairs.length;
  int get agreed => pairs.where((p) => p.agrees).length;

  /// 0–1 share of agreeing pairs, or null with nothing to compare.
  double? get ratio => total == 0 ? null : agreed / total;
}

/// Compares the films [theirRated] (their movie docs) that the viewer also
/// rated in [myMoviesById]. Agreement = ratings within [agreementTolerance]
/// stars of each other.
TasteAgreement computeAgreement({
  required List<Map<String, dynamic>> theirRated,
  required Map<int, Map<String, dynamic>> myMoviesById,
  int highlights = agreementHighlights,
}) {
  final pairs = <RatedPair>[];
  final seen = <int>{};
  for (final d in theirRated) {
    final id = _id(d);
    if (id <= 0 || !seen.add(id)) continue;
    final theirs = _rating(d);
    final mine = _rating(myMoviesById[id]);
    if (theirs == null || mine == null) continue;
    pairs.add(RatedPair(
        item: movieItemFromDoc(d), myRating: mine, theirRating: theirs));
  }

  final agreeing = pairs.where((p) => p.agrees).toList()
    ..sort((a, b) {
      final byDiff = a.difference.compareTo(b.difference);
      if (byDiff != 0) return byDiff;
      return (b.myRating + b.theirRating).compareTo(a.myRating + a.theirRating);
    });
  final disagreeing = pairs.where((p) => !p.agrees).toList()
    ..sort((a, b) => b.difference.compareTo(a.difference));

  return TasteAgreement(
    pairs: List.unmodifiable(pairs),
    topAgreements: List.unmodifiable(agreeing.take(highlights)),
    topDisagreements: List.unmodifiable(disagreeing.take(highlights)),
  );
}

/// Whether the "Common ground" entry point should show on [targetUid]'s
/// profile for viewer [myUid]: never for guests, your own profile, or when
/// either side has the other in their `blocked` list.
bool canShowCommonGround({
  required String? myUid,
  required String targetUid,
  required List<String> myBlocked,
  required List<String> theirBlocked,
}) {
  if (myUid == null || myUid.isEmpty || myUid == targetUid) return false;
  if (myBlocked.contains(targetUid)) return false;
  if (theirBlocked.contains(myUid)) return false;
  return true;
}
