/// A movie resolved into exactly the 8 attributes the daily guessing game
/// reveals as clue tiles — director, production studio, release year,
/// worldwide box office gross, community rating, content rating, cast, and
/// genres. Built once per game by [APIservices.getGameClueData] (see
/// `lib/services/api_service.dart`) from three combined TMDB calls, so the
/// game screen never has to know which raw endpoint each field came from.
class GameClueMovie {
  final int id;
  final String title;
  final String posterPath;
  final String director;
  final String productionCompany;
  final int releaseYear;
  final int revenue;
  final double voteAverage;
  final String certification;
  final List<String> genres;
  final List<String> cast;

  const GameClueMovie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.director,
    required this.productionCompany,
    required this.releaseYear,
    required this.revenue,
    required this.voteAverage,
    required this.certification,
    required this.genres,
    required this.cast,
  });
}
