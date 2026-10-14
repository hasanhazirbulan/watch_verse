/// A movie resolved into exactly the 8 attributes the daily guessing game
/// reveals as clue tiles — director(s), production studios, release year,
/// worldwide box office gross, community rating, content rating, cast, and
/// genres. Built once per movie by [APIservices.getGameClueData] (see
/// `lib/services/api_service.dart`), so the game screen never has to know
/// which raw endpoint each field came from.
///
/// Unknown values are empty strings/lists or 0 (TMDB reports an unknown box
/// office as 0) — the clue comparison treats those as "no information"
/// rather than as a real value.
class GameClueMovie {
  final int id;
  final String title;
  final String posterPath;
  final List<String> directors;

  /// In TMDB's billing order; the first is treated as the primary studio.
  final List<String> productionCompanies;
  final int releaseYear;
  final int revenue;
  final double voteAverage;
  final String certification;
  final List<String> genres;

  /// Top-billed cast, at most 5, in billing order.
  final List<String> cast;

  const GameClueMovie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.directors,
    required this.productionCompanies,
    required this.releaseYear,
    required this.revenue,
    required this.voteAverage,
    required this.certification,
    required this.genres,
    required this.cast,
  });
}
