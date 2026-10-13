import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:watch_verse/models/game_clue_movie.dart';
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

  /// A request that never comes back would leave the UI on a loading skeleton
  /// forever — a hanging Future neither resolves nor errors, so no amount of
  /// error handling upstream can catch it. Time out instead and fail loudly.
  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    final http.Response response;
    try {
      response = await http.get(url).timeout(_timeout);
    } on TimeoutException {
      throw Exception(
          'TMDB request timed out after ${_timeout.inSeconds}s for $url');
    }
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

  /// Runtime (minutes) and genre names from the movie detail endpoint —
  /// neither is present on any list endpoint, so this is fetched once,
  /// right before logging a watch, powering the profile's "time spent
  /// watching movies" stat and the genre-time breakdown chart.
  Future<({int runtime, List<String> genres})> getMovieDetailExtras(
      int movieId) async {
    final data = await _getJson(_uri('/movie/$movieId'));
    final genres = (data['genres'] as List<dynamic>? ?? [])
        .map((g) => (g as Map<String, dynamic>)['name'] as String? ?? '')
        .where((g) => g.isNotEmpty)
        .toList();
    return (runtime: (data['runtime'] as num?)?.toInt() ?? 0, genres: genres);
  }

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

  /// Process-lifetime cache around [getWatchProviders], keyed by
  /// type+id+region — the same poster re-renders on every scroll/rebuild of
  /// a rail (and appears in more than one rail), so without this a home
  /// screen with a few dozen posters showing provider badges would re-fetch
  /// every one of them repeatedly instead of once.
  static final _providerCache = <String, Future<List<WatchProvider>>>{};

  Future<List<WatchProvider>> getWatchProvidersCached(
      MediaType type, int id, String region) {
    final key = '${type.apiPath}-$id-$region';
    return _providerCache.putIfAbsent(
        key,
        () => getWatchProviders(type, id, region)
            .catchError((_) => <WatchProvider>[]));
  }

  Future<Person> getPersonDetails(int id) async {
    final data = await _getJson(_uri('/person/$id'));
    return Person.fromMap(data);
  }

  // ------------------------------------------------------- Daily game -------

  /// The 8 clue-tile attributes for the daily guessing game's mystery movie
  /// *and* every title the player guesses — both sides of every comparison
  /// go through this, so a guess is judged on exactly the same data shape as
  /// the answer. Combines three calls TMDB doesn't offer as one: movie
  /// details (genres/revenue/production company/rating — `/movie/{id}`
  /// already fetches this for [getMovieDetailExtras], just discarding the
  /// fields this needs), credits (cast + crew, only cast was kept before),
  /// and release dates (US certification — nothing else in the app calls
  /// this endpoint).
  Future<GameClueMovie> getGameClueData(int movieId) async {
    final results = await Future.wait([
      _getJson(_uri('/movie/$movieId')),
      _getJson(_uri('/movie/$movieId/credits')),
      _getJson(_uri('/movie/$movieId/release_dates')),
    ]);
    final details = results[0];
    final credits = results[1];
    final releaseDates = results[2];

    final genres = (details['genres'] as List<dynamic>? ?? [])
        .map((g) => (g as Map<String, dynamic>)['name'] as String? ?? '')
        .where((g) => g.isNotEmpty)
        .take(5)
        .toList();

    final companies = (details['production_companies'] as List<dynamic>? ?? []);
    final productionCompany = companies.isEmpty
        ? ''
        : (companies.first as Map<String, dynamic>)['name'] as String? ?? '';

    final crew = (credits['crew'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final director = crew.firstWhere(
      (c) => c['job'] == 'Director',
      orElse: () => const {},
    )['name'] as String? ?? '';

    final cast = (credits['cast'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map((c) => c['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .take(5)
        .toList();

    final certification = _usCertification(releaseDates);

    final releaseDate = details['release_date'] as String? ?? '';
    final releaseYear =
        releaseDate.length >= 4 ? int.tryParse(releaseDate.substring(0, 4)) ?? 0 : 0;

    return GameClueMovie(
      id: movieId,
      title: details['title'] as String? ?? '',
      posterPath: details['poster_path'] as String? ?? '',
      director: director,
      productionCompany: productionCompany,
      releaseYear: releaseYear,
      revenue: (details['revenue'] as num?)?.toInt() ?? 0,
      voteAverage: (details['vote_average'] as num?)?.toDouble() ?? 0,
      certification: certification,
      genres: genres,
      cast: cast,
    );
  }

  /// First non-empty certification from the US entry of `/movie/{id}/release_dates`.
  String _usCertification(Map<String, dynamic> releaseDatesResponse) {
    final entries = (releaseDatesResponse['results'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final us = entries.firstWhere(
      (e) => e['iso_3166_1'] == 'US',
      orElse: () => const {},
    );
    final dates = (us['release_dates'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final d in dates) {
      final cert = d['certification'] as String? ?? '';
      if (cert.isNotEmpty) return cert;
    }
    return '';
  }

  /// Movie search only (unlike [searchMulti], which mixes in TV) — the daily
  /// game's guess input only ever offers movies, since the mystery title is
  /// always a movie.
  ///
  /// [year] narrows results to titles with any release in that year — used
  /// by the Letterboxd importer to disambiguate same-name films.
  Future<List<MediaItem>> searchMovies(String query, {int? year}) async {
    if (query.trim().isEmpty) return [];
    final data = await _getJson(
      _uri('/search/movie', {
        'query': query,
        'include_adult': 'false',
        if (year != null) 'year': '$year',
      }),
    );
    final results = (data['results'] as List<dynamic>? ?? []);
    return results
        .map((e) => MediaItem.fromMovieMap(e as Map<String, dynamic>))
        .where((m) => m.id != 0)
        .toList();
  }

  /// Exact lookup of an IMDb id (`tt0111161`) via `/find` — used by the
  /// IMDb importer, so no fuzzy title matching is needed for those rows.
  /// A title resolves to at most one movie or one show; both are null when
  /// TMDB doesn't know the id.
  Future<({MediaItem? movie, MediaItem? tv})> findByImdbId(
      String imdbId) async {
    final data = await _getJson(
      _uri('/find/$imdbId', {'external_source': 'imdb_id'}),
    );
    MediaItem? first(String key, MediaItem Function(Map<String, dynamic>) f) {
      final list = (data[key] as List<dynamic>? ?? []);
      for (final e in list) {
        final m = f(e as Map<String, dynamic>);
        if (m.id != 0) return m;
      }
      return null;
    }

    return (
      movie: first('movie_results', MediaItem.fromMovieMap),
      tv: first('tv_results', MediaItem.fromTvMap),
    );
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
