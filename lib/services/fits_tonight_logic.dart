/// Pure logic behind "Fits tonight": given a time budget, which watchlist
/// movies fit, and how many of each tracked show's next unwatched episodes
/// fit back to back. Kept free of Flutter/Firebase/network so it's
/// unit-testable (test/services/fits_tonight_logic_test.dart).
library;

/// Budget range offered by the screen, in minutes.
const fitsTonightMinBudget = 30;
const fitsTonightMaxBudget = 240;
const fitsTonightBudgetStep = 15;
const fitsTonightDefaultBudget = 90;

/// Items whose total lands within the same band of leftover minutes count as
/// "equally close" to the budget, so the secondary order (shows in progress,
/// then better-rated movies) decides between them instead of a 1-minute
/// difference.
const fitsTonightSlackBand = 5;

enum FitsKind { movie, show }

/// One episode, reduced to what packing needs. [runtime] 0 = unknown.
class FitsEpisode {
  final int season;
  final int episode;
  final int runtime;
  const FitsEpisode({
    required this.season,
    required this.episode,
    required this.runtime,
  });
}

/// A watchlist movie. [runtime] 0 = unknown. [payload] is opaque to this
/// file (the screen keeps its Firestore map there).
class FitsMovieCandidate<P> {
  final int id;
  final String title;
  final int runtime;
  final double voteAverage;
  final P payload;
  const FitsMovieCandidate({
    required this.id,
    required this.title,
    required this.runtime,
    this.voteAverage = 0,
    required this.payload,
  });
}

/// A tracked show and its aired-but-unwatched episodes, in watch order
/// (the first one is what Up Next shows as "next").
class FitsShowCandidate<P> {
  final int id;
  final String name;
  final List<FitsEpisode> unwatched;

  /// Stand-in for episodes TMDB has no runtime for — usually
  /// [typicalRuntime] of the show's known episodes. 0 = none known.
  final int fallbackRuntime;
  final DateTime? lastWatchedAt;
  final P payload;
  const FitsShowCandidate({
    required this.id,
    required this.name,
    required this.unwatched,
    this.fallbackRuntime = 0,
    this.lastWatchedAt,
    required this.payload,
  });
}

/// Something that fits the budget: a movie, or a run of a show's next
/// episodes.
sealed class FitsItem {
  const FitsItem();
  FitsKind get kind;
  int get id;
  String get title;

  /// Total minutes (estimated episodes included).
  int get minutes;
}

class MovieFit<P> extends FitsItem {
  final FitsMovieCandidate<P> movie;
  const MovieFit(this.movie);
  @override
  FitsKind get kind => FitsKind.movie;
  @override
  int get id => movie.id;
  @override
  String get title => movie.title;
  @override
  int get minutes => movie.runtime;
}

class EpisodeRunFit<P> extends FitsItem {
  final FitsShowCandidate<P> show;

  /// The first `episodes.length` entries of `show.unwatched`.
  final List<FitsEpisode> episodes;
  @override
  final int minutes;

  /// How many episodes in the run had no runtime and used
  /// `show.fallbackRuntime` instead (the total is then approximate).
  final int estimatedCount;

  const EpisodeRunFit({
    required this.show,
    required this.episodes,
    required this.minutes,
    required this.estimatedCount,
  });

  @override
  FitsKind get kind => FitsKind.show;
  @override
  int get id => show.id;
  @override
  String get title => show.name;
  bool get isEstimated => estimatedCount > 0;
  FitsEpisode get first => episodes.first;
  FitsEpisode get last => episodes.last;
}

class FitsTonightResult<P> {
  /// Episode runs, closest to the budget first.
  final List<EpisodeRunFit<P>> episodeRuns;

  /// Movies that fit, closest to the budget first.
  final List<MovieFit<P>> movies;

  /// Movies with no known runtime — can't be placed, listed separately.
  final List<FitsMovieCandidate<P>> unknownMovies;

  /// Shows whose next episode has no runtime (and no show average).
  final List<FitsShowCandidate<P>> unknownShows;

  /// Length of the shortest option among the included candidates (a
  /// movie, or a show's next episode), fitting or not — lets the screen say
  /// "the shortest thing on your lists is 2h 5m" when nothing fits. Null
  /// when no candidate has a known length.
  final int? shortest;

  const FitsTonightResult({
    required this.episodeRuns,
    required this.movies,
    required this.unknownMovies,
    required this.unknownShows,
    this.shortest,
  });

  bool get isEmpty =>
      episodeRuns.isEmpty &&
      movies.isEmpty &&
      unknownMovies.isEmpty &&
      unknownShows.isEmpty;

  bool get hasFits => episodeRuns.isNotEmpty || movies.isNotEmpty;
}

/// Median of the known (> 0) runtimes, or 0 when none are known. The median
/// (not the mean) so a double-length finale doesn't skew a show's estimate.
int typicalRuntime(Iterable<int> runtimes) {
  final known = runtimes.where((r) => r > 0).toList()..sort();
  if (known.isEmpty) return 0;
  final mid = known.length ~/ 2;
  if (known.length.isOdd) return known[mid];
  return ((known[mid - 1] + known[mid]) / 2).round();
}

/// The longest run of [show]'s next unwatched episodes, in order, whose
/// total fits [budget]. Episodes must be watched in sequence, so this is a
/// prefix — never "skip the long one". Null when not even the next episode
/// fits, or its length can't be known.
EpisodeRunFit<P>? packEpisodeRun<P>(FitsShowCandidate<P> show, int budget) {
  final picked = <FitsEpisode>[];
  var total = 0;
  var estimated = 0;
  for (final ep in show.unwatched) {
    final known = ep.runtime > 0;
    final minutes = known ? ep.runtime : show.fallbackRuntime;
    if (minutes <= 0) break; // can't tell how long — stop the run here
    if (total + minutes > budget) break;
    picked.add(ep);
    total += minutes;
    if (!known) estimated++;
  }
  if (picked.isEmpty) return null;
  return EpisodeRunFit<P>(
    show: show,
    episodes: List.unmodifiable(picked),
    minutes: total,
    estimatedCount: estimated,
  );
}

/// Whether [show]'s next episode has no usable length at all.
bool _nextRuntimeUnknown(FitsShowCandidate show) =>
    show.unwatched.isNotEmpty &&
    show.unwatched.first.runtime <= 0 &&
    show.fallbackRuntime <= 0;

int _band(int budget, int minutes) =>
    (budget - minutes) ~/ fitsTonightSlackBand;

/// Builds tonight's options for [budget] minutes.
///
/// [include] is the "On my services" filter (or any other) — applied to
/// every candidate before packing; null includes everything.
///
/// Ordering (both lists): closest to the budget first, in
/// [fitsTonightSlackBand]-minute bands. Ties: shows watched most recently
/// first (you're mid-way through them), then longer runs; movies with the
/// higher TMDB rating first. Title breaks any remaining tie, so the order is
/// stable.
FitsTonightResult<P> computeFitsTonight<P>({
  required int budget,
  required List<FitsMovieCandidate<P>> movies,
  required List<FitsShowCandidate<P>> shows,
  bool Function(FitsKind kind, int id)? include,
}) {
  bool ok(FitsKind kind, int id) => include == null || include(kind, id);

  int? shortest;
  void seen(int minutes) {
    if (minutes > 0 && (shortest == null || minutes < shortest!)) {
      shortest = minutes;
    }
  }

  final movieFits = <MovieFit<P>>[];
  final unknownMovies = <FitsMovieCandidate<P>>[];
  for (final m in movies) {
    if (!ok(FitsKind.movie, m.id)) continue;
    seen(m.runtime);
    if (m.runtime <= 0) {
      unknownMovies.add(m);
    } else if (m.runtime <= budget) {
      movieFits.add(MovieFit<P>(m));
    }
  }

  final runs = <EpisodeRunFit<P>>[];
  final unknownShows = <FitsShowCandidate<P>>[];
  for (final s in shows) {
    if (s.unwatched.isEmpty || !ok(FitsKind.show, s.id)) continue;
    if (_nextRuntimeUnknown(s)) {
      unknownShows.add(s);
      continue;
    }
    final next = s.unwatched.first;
    seen(next.runtime > 0 ? next.runtime : s.fallbackRuntime);
    final run = packEpisodeRun(s, budget);
    if (run != null) runs.add(run);
  }

  movieFits.sort((a, b) {
    final band = _band(budget, a.minutes).compareTo(_band(budget, b.minutes));
    if (band != 0) return band;
    final rating = b.movie.voteAverage.compareTo(a.movie.voteAverage);
    if (rating != 0) return rating;
    final closer = b.minutes.compareTo(a.minutes);
    if (closer != 0) return closer;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  runs.sort((a, b) {
    final band = _band(budget, a.minutes).compareTo(_band(budget, b.minutes));
    if (band != 0) return band;
    final la = a.show.lastWatchedAt;
    final lb = b.show.lastWatchedAt;
    if (la != null || lb != null) {
      if (la == null) return 1;
      if (lb == null) return -1;
      final recent = lb.compareTo(la);
      if (recent != 0) return recent;
    }
    final closer = b.minutes.compareTo(a.minutes);
    if (closer != 0) return closer;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  unknownMovies.sort(
    (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
  );
  unknownShows.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );

  return FitsTonightResult<P>(
    episodeRuns: runs,
    movies: movieFits,
    unknownMovies: unknownMovies,
    unknownShows: unknownShows,
    shortest: shortest,
  );
}

/// The aired, unwatched episodes of a show in watch order — the same "next
/// episode" rule Up Next uses (first aired episode not marked watched), plus
/// every later aired unwatched one after it.
List<E> unwatchedAiredInOrder<E>(
  List<E> flat, {
  required bool Function(E ep) hasAired,
  required bool Function(E ep) isWatched,
}) => [
  for (final e in flat)
    if (hasAired(e) && !isWatched(e)) e,
];

/// "S2 E4", "S2 E4–6", or "S2 E9 – S3 E2" for a run.
String episodeRangeLabel(FitsEpisode first, FitsEpisode last) {
  final start = 'S${first.season} E${first.episode}';
  if (identical(first, last) ||
      (first.season == last.season && first.episode == last.episode)) {
    return start;
  }
  if (first.season == last.season) return '$start–${last.episode}';
  return '$start – S${last.season} E${last.episode}';
}
