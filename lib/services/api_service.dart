import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:watch_verse/models/media.dart';

/// Supplied at build/run time via `--dart-define-from-file=secrets.json`
/// (see secrets.example.json). Never hardcode a real key here.
const apiKey = String.fromEnvironment('TMDB_API_KEY');

/// Thin wrapper around the TMDB v3 REST API.
///
/// All browse/search endpoints return the unified [MediaItem] shape so the UI
/// can render movies and TV shows with the same widgets. Detail endpoints
/// return the richer [TvShow] / [Episode] models used for episode tracking.
class APIservices {
  static const String _base = 'https://api.themoviedb.org/3';
  static const String _lang = 'en-US';

  Uri _uri(String path, [Map<String, String>? params]) {
    if (apiKey.isEmpty) {
      throw StateError(
        'TMDB_API_KEY is not set. Run with '
        '--dart-define-from-file=secrets.json (see secrets.example.json).',
      );
    }
    final query = {
      'api_key': apiKey,
      'language': _lang,
      ...?params,
    };
    return Uri.parse('$_base$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('TMDB request failed (${response.statusCode}) for $url');
  }

  /// Fetches a `results`-style list and maps each entry with [mapper].
  Future<List<MediaItem>> _getList(
    String path,
    MediaItem Function(Map<String, dynamic>) mapper, {
    Map<String, String>? params,
  }) async {
    final data = await _getJson(_uri(path, params));
    final results = (data['results'] as List<dynamic>? ?? []);
    return results
        .map((e) => mapper(e as Map<String, dynamic>))
        .where((m) => m.id != 0)
        .toList();
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  // ---------------------------------------------------------------- Movies ---

  Future<List<MediaItem>> getNowPlayingMovies() =>
      _getList('/movie/now_playing', MediaItem.fromMovieMap);

  Future<List<MediaItem>> getTrendingMovies() =>
      _getList('/trending/movie/week', MediaItem.fromMovieMap);

  /// Genuinely-upcoming films: popular titles whose release date is still in the
  /// future. Uses `discover` (not `/movie/upcoming`, which overlaps `popular`).
  Future<List<MediaItem>> getUpcomingMovies() =>
      _getList('/discover/movie', MediaItem.fromMovieMap, params: {
        'sort_by': 'popularity.desc',
        'with_release_type': '2|3',
        'primary_release_date.gte': _today(),
        'region': 'US',
      });

  Future<List<MediaItem>> getPopularMovies() =>
      _getList('/movie/popular', MediaItem.fromMovieMap);

  Future<List<MediaItem>> getTopRatedMovies() =>
      _getList('/movie/top_rated', MediaItem.fromMovieMap);

  // ------------------------------------------------------------------- TV ----

  Future<List<MediaItem>> getTrendingTv() =>
      _getList('/trending/tv/week', MediaItem.fromTvMap);

  Future<List<MediaItem>> getAiringTodayTv() =>
      _getList('/tv/airing_today', MediaItem.fromTvMap);

  Future<List<MediaItem>> getOnTheAirTv() =>
      _getList('/tv/on_the_air', MediaItem.fromTvMap);

  Future<List<MediaItem>> getPopularTv() =>
      _getList('/tv/popular', MediaItem.fromTvMap);

  Future<List<MediaItem>> getTopRatedTv() =>
      _getList('/tv/top_rated', MediaItem.fromTvMap);

  /// Full details for a single show, including its season list (no episodes).
  Future<TvShow> getTvDetails(int showId) async {
    final data = await _getJson(_uri('/tv/$showId'));
    return TvShow.fromMap(data);
  }

  /// Episodes for one season of a show.
  Future<List<Episode>> getSeasonEpisodes(int showId, int seasonNumber) async {
    final data = await _getJson(_uri('/tv/$showId/season/$seasonNumber'));
    final episodes = (data['episodes'] as List<dynamic>? ?? []);
    return episodes
        .map((e) => Episode.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------------- Discover ---

  /// Genre list for movies or TV (for the "browse by genre" chips).
  Future<List<Genre>> getGenres(MediaType type) async {
    final data = await _getJson(_uri('/genre/${type.apiPath}/list'));
    final list = (data['genres'] as List<dynamic>? ?? []);
    return list
        .map((g) => Genre.fromMap(g as Map<String, dynamic>))
        .where((g) => g.id != 0)
        .toList();
  }

  /// Popular titles of a given genre — paginated so the discover screen can
  /// lazily load more as the user scrolls.
  Future<List<MediaItem>> discoverByGenre(MediaType type, int genreId,
      {int page = 1}) {
    final mapper =
        type == MediaType.movie ? MediaItem.fromMovieMap : MediaItem.fromTvMap;
    return _getList('/discover/${type.apiPath}', mapper, params: {
      'with_genres': '$genreId',
      'sort_by': 'popularity.desc',
      'vote_count.gte': '50',
      'include_adult': 'false',
      'page': '$page',
    });
  }

  // ---------------------------------------------------------------- Search ---

  /// Multi-search across movies and TV shows (people are filtered out).
  Future<List<MediaItem>> searchMulti(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _getJson(
      _uri('/search/multi', {'query': query, 'include_adult': 'false'}),
    );
    final results = (data['results'] as List<dynamic>? ?? []);
    return results
        .map((e) => MediaItem.fromMultiMap(e as Map<String, dynamic>))
        .whereType<MediaItem>()
        .where((m) => m.id != 0)
        .toList();
  }

  /// Up to 8 title suggestions for the search bar's autocomplete.
  Future<List<String>> getSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    final results = await searchMulti(query);
    return results
        .map((m) => m.title)
        .where((t) => t.isNotEmpty)
        .toSet()
        .take(8)
        .toList();
  }

  // ------------------------------------------------------ Detail extras ------

  /// Top-billed cast for a movie or show.
  Future<List<CastMember>> getCredits(MediaType type, int id) async {
    final data = await _getJson(_uri('/${type.apiPath}/$id/credits'));
    final cast = (data['cast'] as List<dynamic>? ?? []);
    return cast
        .map((c) => CastMember.fromMap(c as Map<String, dynamic>))
        .where((c) => c.id != 0)
        .toList();
  }

  /// "Because you watched this" recommendations (same media type).
  Future<List<MediaItem>> getRecommendations(MediaType type, int id) {
    final mapper =
        type == MediaType.movie ? MediaItem.fromMovieMap : MediaItem.fromTvMap;
    return _getList('/${type.apiPath}/$id/recommendations', mapper);
  }

  /// YouTube key of the best available trailer/teaser, or null.
  Future<String?> getTrailerKey(MediaType type, int id) async {
    final data = await _getJson(_uri('/${type.apiPath}/$id/videos'));
    final yt = (data['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((m) =>
            m['site'] == 'YouTube' &&
            m['key'] is String &&
            (m['key'] as String).isNotEmpty)
        .toList();
    if (yt.isEmpty) return null;
    Map<String, dynamic>? byType(String t) {
      for (final m in yt) {
        if (m['type'] == t) return m;
      }
      return null;
    }

    final best = byType('Trailer') ?? byType('Teaser') ?? yt.first;
    return best['key'] as String;
  }

  /// Read-only community reviews (from TMDB — no UGC to moderate).
  Future<List<Review>> getReviews(MediaType type, int id) async {
    final data = await _getJson(_uri('/${type.apiPath}/$id/reviews'));
    final results = (data['results'] as List<dynamic>? ?? []);
    return results
        .map((r) => Review.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Where-to-watch providers for a title in [region] (e.g. 'TR', 'US'),
  /// falling back to US when the region isn't listed. Streaming (flatrate/free/
  /// ads) is listed first, then rent/buy — so titles that aren't on any
  /// subscription service still surface somewhere to watch them. De-duplicated.
  Future<List<WatchProvider>> getWatchProviders(
      MediaType type, int id, String region) async {
    final data = await _getJson(_uri('/${type.apiPath}/$id/watch/providers'));
    final results = (data['results'] as Map<String, dynamic>? ?? {});
    final regionData =
        (results[region] ?? results['US']) as Map<String, dynamic>?;
    if (regionData == null) return [];

    final seen = <int>{};
    final out = <WatchProvider>[];
    for (final bucket in ['flatrate', 'free', 'ads', 'rent', 'buy']) {
      final list = (regionData[bucket] as List<dynamic>? ?? []);
      for (final p in list) {
        final wp = WatchProvider.fromMap(p as Map<String, dynamic>);
        if (wp.id != 0 && seen.add(wp.id)) out.add(wp);
      }
    }
    return out;
  }

  Future<Person> getPersonDetails(int id) async {
    final data = await _getJson(_uri('/person/$id'));
    return Person.fromMap(data);
  }

  /// A person's filmography (movies + TV), de-duplicated and ordered so titles
  /// with artwork and recent releases come first.
  Future<List<MediaItem>> getPersonCredits(int id) async {
    final data = await _getJson(_uri('/person/$id/combined_credits'));
    final cast = (data['cast'] as List<dynamic>? ?? []);
    final items = cast
        .map((c) => MediaItem.fromMultiMap(c as Map<String, dynamic>))
        .whereType<MediaItem>()
        .where((m) => m.id != 0);

    final seen = <String>{};
    final unique = <MediaItem>[];
    for (final m in items) {
      if (seen.add('${m.mediaType}-${m.id}')) unique.add(m);
    }
    unique.sort((a, b) {
      final ap = a.posterPath.isEmpty ? 1 : 0;
      final bp = b.posterPath.isEmpty ? 1 : 0;
      if (ap != bp) return ap - bp;
      return b.date.compareTo(a.date);
    });
    return unique;
  }
}
