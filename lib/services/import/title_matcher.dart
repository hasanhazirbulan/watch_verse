import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/import/import_models.dart';

/// The TMDB calls the importer needs — an interface so tests can supply a
/// fake instead of hitting the network.
abstract class ImportLookupApi {
  Future<List<MediaItem>> searchMovies(String query, {int? year});
  Future<({MediaItem? movie, MediaItem? tv})> findByImdbId(String imdbId);
  Future<TvShow> getTvDetails(int showId);
}

class TmdbImportLookupApi implements ImportLookupApi {
  TmdbImportLookupApi([APIservices? api]) : _api = api ?? APIservices();
  final APIservices _api;

  @override
  Future<List<MediaItem>> searchMovies(String query, {int? year}) =>
      _api.searchMovies(query, year: year);

  @override
  Future<({MediaItem? movie, MediaItem? tv})> findByImdbId(String imdbId) =>
      _api.findByImdbId(imdbId);

  @override
  Future<TvShow> getTvDetails(int showId) => _api.getTvDetails(showId);
}

/// Thrown when TMDB couldn't be reached (after one retry), as opposed to a
/// lookup that simply found nothing.
class LookupFailedException implements Exception {
  final Object cause;
  const LookupFailedException(this.cause);
}

/// Resolves an [ImportedTitle] to a TMDB [MediaItem].
///
/// * IMDb rows: exact, via `/find/{imdb_id}` — the row's Title Type picks
///   which bucket (movie/tv) is preferred, falling back to the other (TMDB
///   sometimes files TV specials/movies differently from IMDb).
/// * Letterboxd rows: title + year search. Exact release year first (a
///   same-title result preferred over TMDB's top hit), then ±1 year (release
///   dates differ by region/festival), else unmatched. Rows with no year
///   only match a result whose title is identical — guessing on title alone
///   would mis-file remakes.
class TitleMatcher {
  TitleMatcher(this._api, {this.retryDelay = const Duration(seconds: 1)});
  final ImportLookupApi _api;
  final Duration retryDelay;

  /// Returns the match or null when there's no confident one. Throws
  /// [LookupFailedException] on network/API failure.
  Future<MediaItem?> match(ImportedTitle t) async {
    final imdbId = t.imdbId;
    if (imdbId != null) {
      final r = await _retry(() => _api.findByImdbId(imdbId));
      return t.kind == ImportKind.tv ? (r.tv ?? r.movie) : (r.movie ?? r.tv);
    }
    final year = t.year;
    if (year == null) {
      final results = await _retry(() => _api.searchMovies(t.title));
      return pickByTitle(results, t.title);
    }
    final filtered = await _retry(() => _api.searchMovies(t.title, year: year));
    final hit = pickByYear(filtered, t.title, year, tolerance: 0) ??
        pickByYear(filtered, t.title, year, tolerance: 1);
    if (hit != null) return hit;
    final open = await _retry(() => _api.searchMovies(t.title));
    return pickByYear(open, t.title, year, tolerance: 0) ??
        pickByYear(open, t.title, year, tolerance: 1);
  }

  Future<T> _retry<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (_) {
      // One retry covers TMDB's occasional 429/5xx and flaky mobile data.
      await Future<void>.delayed(retryDelay);
      try {
        return await call();
      } catch (e) {
        throw LookupFailedException(e);
      }
    }
  }

  /// Best result whose release year is within [tolerance] of [year]:
  /// identical (normalized) title first, else TMDB's highest-ranked one.
  static MediaItem? pickByYear(List<MediaItem> results, String title, int year,
      {required int tolerance}) {
    final inRange = results.where((m) {
      final y = int.tryParse(m.year);
      if (y == null) return false;
      final diff = (y - year).abs();
      return tolerance == 0 ? diff == 0 : diff > 0 && diff <= tolerance;
    }).toList();
    if (inRange.isEmpty) return null;
    final want = normalizeTitle(title);
    for (final m in inRange) {
      if (normalizeTitle(m.title) == want) return m;
    }
    return inRange.first;
  }

  static MediaItem? pickByTitle(List<MediaItem> results, String title) {
    final want = normalizeTitle(title);
    for (final m in results) {
      if (normalizeTitle(m.title) == want) return m;
    }
    return null;
  }

  /// Lowercase, `&` → `and`, letters/digits only (Unicode-aware, so
  /// "Amélie" and "Léon" keep their letters).
  static String normalizeTitle(String s) => s
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
}
