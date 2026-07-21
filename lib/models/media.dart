import 'package:watch_verse/models/model.dart';

enum MediaType { movie, tv }

extension MediaTypeX on MediaType {
  String get label => this == MediaType.movie ? 'Movie' : 'TV Show';
  String get apiPath => this == MediaType.movie ? 'movie' : 'tv';
}

/// A lightweight, type-agnostic item used everywhere we render browse rails,
/// search results and carousels. Both movies and TV shows collapse into this
/// shape so a single card widget can render either one.
class MediaItem {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final String date; // release_date (movie) or first_air_date (tv)
  final double voteAverage;
  final MediaType mediaType;

  const MediaItem({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.date,
    required this.voteAverage,
    required this.mediaType,
  });

  /// Release/first-air year, or empty string when unknown.
  String get year => date.length >= 4 ? date.substring(0, 4) : '';

  factory MediaItem.fromMovieMap(Map<String, dynamic> map) => MediaItem(
        id: map['id']?.toInt() ?? 0,
        title: map['title'] ?? map['original_title'] ?? '',
        overview: map['overview'] ?? '',
        posterPath: map['poster_path'] ?? '',
        backdropPath: map['backdrop_path'] ?? '',
        date: map['release_date'] ?? '',
        voteAverage: (map['vote_average'] ?? 0).toDouble(),
        mediaType: MediaType.movie,
      );

  factory MediaItem.fromTvMap(Map<String, dynamic> map) => MediaItem(
        id: map['id']?.toInt() ?? 0,
        title: map['name'] ?? map['original_name'] ?? '',
        overview: map['overview'] ?? '',
        posterPath: map['poster_path'] ?? '',
        backdropPath: map['backdrop_path'] ?? '',
        date: map['first_air_date'] ?? '',
        voteAverage: (map['vote_average'] ?? 0).toDouble(),
        mediaType: MediaType.tv,
      );

  /// Used for TMDB `search/multi` results, which carry a `media_type` field.
  static MediaItem? fromMultiMap(Map<String, dynamic> map) {
    switch (map['media_type']) {
      case 'movie':
        return MediaItem.fromMovieMap(map);
      case 'tv':
        return MediaItem.fromTvMap(map);
      default:
        return null; // ignore 'person' and unknown types
    }
  }

  /// Bridge to the legacy [Movie] model so the existing movie detail /
  /// watchlist flow keeps working unchanged.
  Movie toMovie() => Movie(
        id: id,
        title: title,
        overview: overview,
        posterPath: posterPath,
        backDropPath: backdropPath,
        releaseDate: date,
        voteAverage: voteAverage,
      );
}

/// A streaming/rent provider for a title in a given region (from
/// `/{type}/{id}/watch/providers`, data courtesy of JustWatch via TMDB).
class WatchProvider {
  final int id;
  final String name;
  final String logoPath;
  const WatchProvider(
      {required this.id, required this.name, required this.logoPath});

  factory WatchProvider.fromMap(Map<String, dynamic> map) => WatchProvider(
        id: map['provider_id']?.toInt() ?? 0,
        name: map['provider_name'] ?? '',
        logoPath: map['logo_path'] ?? '',
      );
}

/// A TMDB genre (from `/genre/{type}/list`) used for the discover-by-genre flow.
class Genre {
  final int id;
  final String name;
  const Genre({required this.id, required this.name});

  factory Genre.fromMap(Map<String, dynamic> map) => Genre(
        id: map['id']?.toInt() ?? 0,
        name: map['name'] ?? '',
      );
}

/// Full TV show details (from `tv/{id}`).
class TvShow {
  final int id;
  final String name;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final String firstAirDate;
  final String lastAirDate;
  final double voteAverage;
  final int numberOfSeasons;
  final int numberOfEpisodes;
  final String status;
  final List<String> genres;
  final List<SeasonSummary> seasons;
  final Episode? nextEpisodeToAir;

  const TvShow({
    required this.id,
    required this.name,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.firstAirDate,
    required this.lastAirDate,
    required this.voteAverage,
    required this.numberOfSeasons,
    required this.numberOfEpisodes,
    required this.status,
    required this.genres,
    required this.seasons,
    this.nextEpisodeToAir,
  });

  String get year =>
      firstAirDate.length >= 4 ? firstAirDate.substring(0, 4) : '';

  factory TvShow.fromMap(Map<String, dynamic> map) {
    final seasonList = (map['seasons'] as List<dynamic>? ?? [])
        .map((s) => SeasonSummary.fromMap(s as Map<String, dynamic>))
        // TMDB exposes "Specials" as season 0; hide it from tracking by default.
        .where((s) => s.seasonNumber > 0)
        .toList();

    return TvShow(
      id: map['id']?.toInt() ?? 0,
      name: map['name'] ?? '',
      overview: map['overview'] ?? '',
      posterPath: map['poster_path'] ?? '',
      backdropPath: map['backdrop_path'] ?? '',
      firstAirDate: map['first_air_date'] ?? '',
      lastAirDate: map['last_air_date'] ?? '',
      voteAverage: (map['vote_average'] ?? 0).toDouble(),
      numberOfSeasons: map['number_of_seasons']?.toInt() ?? seasonList.length,
      numberOfEpisodes: map['number_of_episodes']?.toInt() ?? 0,
      status: map['status'] ?? '',
      genres: (map['genres'] as List<dynamic>? ?? [])
          .map((g) => (g as Map<String, dynamic>)['name'] as String? ?? '')
          .where((g) => g.isNotEmpty)
          .toList(),
      seasons: seasonList,
      nextEpisodeToAir: map['next_episode_to_air'] == null
          ? null
          : Episode.fromMap(map['next_episode_to_air'] as Map<String, dynamic>),
    );
  }

  MediaItem toMediaItem() => MediaItem(
        id: id,
        title: name,
        overview: overview,
        posterPath: posterPath,
        backdropPath: backdropPath,
        date: firstAirDate,
        voteAverage: voteAverage,
        mediaType: MediaType.tv,
      );
}

/// Season entry as returned inside a show's `seasons` array (no episodes yet).
class SeasonSummary {
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String posterPath;
  final String airDate;
  final String overview;

  const SeasonSummary({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    required this.posterPath,
    required this.airDate,
    required this.overview,
  });

  factory SeasonSummary.fromMap(Map<String, dynamic> map) => SeasonSummary(
        seasonNumber: map['season_number']?.toInt() ?? 0,
        name: map['name'] ?? '',
        episodeCount: map['episode_count']?.toInt() ?? 0,
        posterPath: map['poster_path'] ?? '',
        airDate: map['air_date'] ?? '',
        overview: map['overview'] ?? '',
      );
}

/// A cast member (from `/{type}/{id}/credits`).
class CastMember {
  final int id;
  final String name;
  final String character;
  final String profilePath;

  const CastMember({
    required this.id,
    required this.name,
    required this.character,
    required this.profilePath,
  });

  factory CastMember.fromMap(Map<String, dynamic> map) => CastMember(
        id: map['id']?.toInt() ?? 0,
        name: map['name'] ?? '',
        character: map['character'] ?? map['job'] ?? '',
        profilePath: map['profile_path'] ?? '',
      );
}

/// A community review (from `/{type}/{id}/reviews`) — read-only, sourced from
/// TMDB so there's no user-generated content to moderate.
class Review {
  final String author;
  final String content;
  final double? rating; // author's 0–10 rating, if given
  final String avatarPath;

  const Review({
    required this.author,
    required this.content,
    required this.rating,
    required this.avatarPath,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    final details = map['author_details'] as Map<String, dynamic>?;
    final r = details?['rating'];
    var avatar = (details?['avatar_path'] ?? '') as String;
    // TMDB sometimes stores a full gravatar URL prefixed with a slash.
    if (avatar.startsWith('/http')) avatar = avatar.substring(1);
    return Review(
      author: map['author'] ?? details?['username'] ?? 'Anonymous',
      content: map['content'] ?? '',
      rating: r == null ? null : (r as num).toDouble(),
      avatarPath: avatar,
    );
  }
}

/// Person details (from `/person/{id}`) for the filmography screen.
class Person {
  final int id;
  final String name;
  final String biography;
  final String profilePath;
  final String knownFor;

  const Person({
    required this.id,
    required this.name,
    required this.biography,
    required this.profilePath,
    required this.knownFor,
  });

  factory Person.fromMap(Map<String, dynamic> map) => Person(
        id: map['id']?.toInt() ?? 0,
        name: map['name'] ?? '',
        biography: map['biography'] ?? '',
        profilePath: map['profile_path'] ?? '',
        knownFor: map['known_for_department'] ?? '',
      );
}

/// A single episode (from `tv/{id}/season/{n}`).
class Episode {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String overview;
  final String stillPath;
  final String airDate;
  final double voteAverage;
  final int runtime; // minutes

  const Episode({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    required this.overview,
    required this.stillPath,
    required this.airDate,
    required this.voteAverage,
    required this.runtime,
  });

  /// Stable key used to store watched-state in Firestore, e.g. `s2e5`.
  String get key => 's${seasonNumber}e$episodeNumber';

  /// Whether this episode's air date is in the past (or today).
  bool get hasAired {
    if (airDate.isEmpty) return false;
    final parsed = DateTime.tryParse(airDate);
    if (parsed == null) return false;
    return !parsed.isAfter(DateTime.now());
  }

  factory Episode.fromMap(Map<String, dynamic> map) => Episode(
        id: map['id']?.toInt() ?? 0,
        episodeNumber: map['episode_number']?.toInt() ?? 0,
        seasonNumber: map['season_number']?.toInt() ?? 0,
        name: map['name'] ?? '',
        overview: map['overview'] ?? '',
        stillPath: map['still_path'] ?? '',
        airDate: map['air_date'] ?? '',
        voteAverage: (map['vote_average'] ?? 0).toDouble(),
        runtime: map['runtime']?.toInt() ?? 0,
      );
}
