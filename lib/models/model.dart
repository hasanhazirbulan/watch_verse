class Movie {
  final int id;
  final String title;
  final String overview; // Description of the movie
  final String posterPath; // Path for the poster image
  final String backDropPath; // Path for the backdrop image
  final String releaseDate; // Release date of the movie
  final double voteAverage; // Average vote score
  final int runtime; // Minutes; 0 when unknown (only the detail endpoint has it)
  final List<String> genres; // Empty when unknown (only the detail endpoint has it)

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backDropPath,
    required this.releaseDate,
    required this.voteAverage,
    this.runtime = 0,
    this.genres = const [],
  });

  /// Whether the movie's release date is today or in the past. Defaults to
  /// `true` when the date is missing/unparsable — unlike [Episode.hasAired],
  /// we shouldn't block "mark watched" just because TMDB is missing a date.
  bool get hasReleased {
    if (releaseDate.isEmpty) return true;
    final d = DateTime.tryParse(releaseDate);
    if (d == null) return true;
    return !d.isAfter(DateTime.now());
  }

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      id: map['id']?.toInt() ?? 0,
      title: map['title'] ?? '',
      overview: map['overview'] ?? '',
      posterPath: map['poster_path'] ?? map['posterPath'] ?? '', //
      backDropPath:
          map['backdrop_path'] ?? map['backDropPath'] ?? map['backdropPath'] ?? '',
      releaseDate: map['release_date'] ?? map['releaseDate'] ?? '',
      voteAverage: (map['vote_average'] ?? map['voteAverage'] ?? 0).toDouble(),
      runtime: (map['runtime'] ?? 0).toInt(),
      genres: (map['genres'] as List<dynamic>? ?? [])
          .map((g) => g is Map
              ? (g['name'] as String? ?? '')
              : g?.toString() ?? '')
          .where((g) => g.isNotEmpty)
          .toList(),
    );
  }

  /// Same movie with [runtime]/[genres] overridden — used once the detail
  /// fetch resolves, right before logging a watch.
  Movie withDetails({int? runtime, List<String>? genres}) => Movie(
        id: id,
        title: title,
        overview: overview,
        posterPath: posterPath,
        backDropPath: backDropPath,
        releaseDate: releaseDate,
        voteAverage: voteAverage,
        runtime: runtime ?? this.runtime,
        genres: genres ?? this.genres,
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath, // Ensure consistent naming when saving to Firestore
      'backdrop_path': backDropPath,
      'release_date': releaseDate,
      'vote_average': voteAverage,
      'runtime': runtime,
      'genres': genres,
    };
  }
}
