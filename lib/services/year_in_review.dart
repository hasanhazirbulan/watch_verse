/// Pure "Year in Review" aggregation — no Flutter or Firebase imports, so it
/// can be unit-tested with plain maps (see test/services/year_in_review_test.dart).
///
/// The caller (see `year_in_review_source.dart`) hands over the raw docs it
/// read once from Firestore, with every Firestore `Timestamp` already
/// converted to a local [DateTime]. All year boundaries are in the device's
/// local time zone: a watch counts towards year Y when
/// `DateTime(Y) <= watchedAt < DateTime(Y + 1)`.
///
/// What counts, and where each number comes from:
///
/// * **Film watches** — the union of
///   1. every `users/{uid}/diary` entry whose `watchedOn` falls in the year
///      (each rewatch is its own entry), and
///   2. every `users/{uid}/movies` doc with `status == 'watched'` whose
///      `watchedAt` falls in the year *and* which has no diary entry for the
///      same film on the same calendar day. Quick-add "mark watched" writes
///      only the movie doc (no diary entry), while `logWatch` and the
///      Letterboxd importer write both with the same date — the same-day check
///      is what keeps the latter from being counted twice.
///   Known gap: a movie doc only keeps its *latest* `watchedAt`, so a quick-add
///   watch that was later superseded by another watch of the same film is
///   lost (it never had a diary entry). Imported films that came without any
///   date were stamped with the import time and count towards that year.
/// * **Distinct films** — distinct movie ids among those watches.
/// * **Film minutes** — per watch, the film's `runtime` from its movie doc
///   (a rewatch counts its runtime again). Films with no known runtime
///   contribute 0 and are counted in [YearInReview.filmsWithoutRuntime].
/// * **Episodes** — per-episode `users/{uid}/shows/{id}/watched/{key}` docs
///   whose `watchedAt` falls in the year. These are the source of truth (one
///   doc per episode, so an episode re-marked later only counts once, at its
///   latest date). Note season "mark all" and catch-up writes stamp every
///   episode with the time of the tap, not when it was actually seen.
/// * **Episode minutes** — exact runtime from the matching `kind: 'episode'`
///   activity entry when one exists (`episodeRuntimes`); otherwise
///   APPROXIMATED as the show's average episode length
///   (`watchedMinutes / watchedCount` on the show doc); otherwise unknown
///   (0, counted in [YearInReview.episodesWithoutRuntime]).
/// * **Genres** — minutes per genre; a title's minutes count under every
///   genre it has (same convention as the Watch Stats screen). Titles without
///   genres or without minutes don't contribute.
/// * **Months / weekdays** — minutes per calendar month / weekday of the watch
///   date. If nothing in the year has a known runtime, falls back to counting
///   watches (films + episodes) so the chart still says something true.
/// * **Ratings** — a film's rating for the year is the rating on its latest
///   in-year diary entry that has one, else the movie doc's current `rating`.
library;

/// One episode watch, as read from a show's `watched` subcollection.
class EpisodeWatchRecord {
  final int showId;
  final int season;
  final int episode;
  final DateTime watchedAt;

  const EpisodeWatchRecord({
    required this.showId,
    required this.season,
    required this.episode,
    required this.watchedAt,
  });

  /// Same key format as `Episode.key` / the watched doc id ("s2e5").
  String get key => 's${season}e$episode';
}

/// Everything the aggregation needs, as plain data.
class YearInReviewInput {
  /// `users/{uid}/diary` docs (`id`, `title`, `posterPath`, `rating`,
  /// `watchedOn` as [DateTime]).
  final List<Map<String, dynamic>> diaryEntries;

  /// `users/{uid}/movies` docs (`id`, `title`, `posterPath`, `status`,
  /// `watchedAt` as [DateTime], `runtime`, `genres`, `rating`).
  final List<Map<String, dynamic>> movies;

  /// `users/{uid}/shows` docs (`id`, `name`, `posterPath`, `genres`,
  /// `watchedCount`, `watchedMinutes`, `addedAt`/`updatedAt` as [DateTime]).
  final List<Map<String, dynamic>> shows;

  /// Watched-episode docs (only those in the requested year are needed, but
  /// extra ones are ignored).
  final List<EpisodeWatchRecord> episodes;

  /// Exact episode runtimes from the activity timeline, keyed by
  /// [episodeRuntimeKey].
  final Map<String, int> episodeRuntimes;

  const YearInReviewInput({
    this.diaryEntries = const [],
    this.movies = const [],
    this.shows = const [],
    this.episodes = const [],
    this.episodeRuntimes = const {},
  });
}

String episodeRuntimeKey(int showId, String episodeKey) =>
    '$showId|$episodeKey';

enum WatchKind { film, episode }

/// A single dated watch, used for "first/latest watch of the year".
class YearWatch {
  final WatchKind kind;
  final int id; // movie id or show id
  final String title; // film title or show name
  final String? posterPath;
  final DateTime at;
  final int? season;
  final int? episode;

  const YearWatch({
    required this.kind,
    required this.id,
    required this.title,
    required this.posterPath,
    required this.at,
    this.season,
    this.episode,
  });
}

class RatedFilm {
  final int id;
  final String title;
  final String? posterPath;
  final double rating;
  const RatedFilm({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.rating,
  });
}

class FilmFact {
  final int id;
  final String title;
  final String? posterPath;

  /// Runtime in minutes (longest film) or watch count (most rewatched).
  final int value;
  const FilmFact({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.value,
  });
}

class ShowSummary {
  final int id;
  final String name;
  final String? posterPath;
  final int episodes;
  final int minutes;
  const ShowSummary({
    required this.id,
    required this.name,
    required this.posterPath,
    required this.episodes,
    required this.minutes,
  });
}

class BusiestDay {
  final DateTime day;
  final int films;
  final int episodes;
  const BusiestDay({
    required this.day,
    required this.films,
    required this.episodes,
  });
  int get total => films + episodes;
}

class YearInReview {
  final int year;

  /// True when [year] is the current year (the review is "so far").
  final bool isPartial;

  final int filmWatches;
  final int distinctFilms;
  final int episodes;
  final int showsWatched;
  final int filmMinutes;
  final int episodeMinutes;

  /// Watches whose minutes are unknown (contribute 0 to the totals).
  final int filmsWithoutRuntime;
  final int episodesWithoutRuntime;

  /// Episodes whose minutes came from the show's average episode length.
  final int episodesWithEstimatedRuntime;

  /// Genre → minutes, highest first.
  final List<MapEntry<String, int>> topGenres;

  /// 12 values (Jan..Dec) and 7 values (Mon..Sun), in minutes — or in watch
  /// counts when [activityInMinutes] is false (no runtime known at all).
  final List<int> byMonth;
  final List<int> byWeekday;
  final bool activityInMinutes;

  final List<RatedFilm> topRatedFilms;
  final double? averageFilmRating;
  final int ratedFilms;
  final ShowSummary? topShow;
  final YearWatch? firstWatch;
  final YearWatch? latestWatch;
  final FilmFact? longestFilm;
  final FilmFact? mostRewatchedFilm;
  final BusiestDay? busiestDay;

  const YearInReview({
    required this.year,
    required this.isPartial,
    required this.filmWatches,
    required this.distinctFilms,
    required this.episodes,
    required this.showsWatched,
    required this.filmMinutes,
    required this.episodeMinutes,
    required this.filmsWithoutRuntime,
    required this.episodesWithoutRuntime,
    required this.episodesWithEstimatedRuntime,
    required this.topGenres,
    required this.byMonth,
    required this.byWeekday,
    required this.activityInMinutes,
    required this.topRatedFilms,
    required this.averageFilmRating,
    required this.ratedFilms,
    required this.topShow,
    required this.firstWatch,
    required this.latestWatch,
    required this.longestFilm,
    required this.mostRewatchedFilm,
    required this.busiestDay,
  });

  int get totalMinutes => filmMinutes + episodeMinutes;
  bool get isEmpty => filmWatches == 0 && episodes == 0;

  /// Repeat watches of a film within this year (watches − distinct films).
  int get repeatWatches => filmWatches - distinctFilms;

  /// Index (0 = January) of the month with the most activity, or null.
  int? get busiestMonth => _argMax(byMonth);

  /// Index (0 = Monday) of the weekday with the most activity, or null.
  int? get favouriteWeekday => _argMax(byWeekday);
}

int? _argMax(List<int> values) {
  int? best;
  for (var i = 0; i < values.length; i++) {
    if (values[i] <= 0) continue;
    if (best == null || values[i] > values[best]) best = i;
  }
  return best;
}

int? _int(Object? v) => v is num ? v.toInt() : null;
double? _double(Object? v) => v is num ? v.toDouble() : null;
DateTime? _date(Object? v) => v is DateTime ? v : null;
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
List<String> _genres(Object? v) =>
    v is List ? v.whereType<String>().toList() : const [];

bool _inYear(DateTime d, int year) => d.year == year;

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

class _FilmWatch {
  final int id;
  final DateTime at;
  final double? rating; // rating on this diary entry, if any
  _FilmWatch(this.id, this.at, this.rating);
}

/// Years the picker should offer: every year with a dated film watch or in
/// which a tracked show was added/updated (episodes are only loaded per
/// year, so a show's add→update span is the best cheap hint), plus the
/// current year. Newest first.
List<int> yearsWithData(YearInReviewInput input, {required DateTime now}) {
  final years = <int>{now.year};
  for (final e in input.diaryEntries) {
    final d = _date(e['watchedOn']);
    if (d != null) years.add(d.year);
  }
  for (final m in input.movies) {
    if (m['status'] != 'watched') continue;
    final d = _date(m['watchedAt']);
    if (d != null) years.add(d.year);
  }
  for (final s in input.shows) {
    if ((_int(s['watchedCount']) ?? 0) <= 0) continue;
    final from = _date(s['addedAt']);
    final to = _date(s['updatedAt']);
    if (from != null && to != null && !to.isBefore(from)) {
      for (var y = from.year; y <= to.year; y++) {
        years.add(y);
      }
    } else if (to != null) {
      years.add(to.year);
    }
  }
  final list = years.where((y) => y <= now.year).toList()
    ..sort((a, b) => b.compareTo(a));
  return list;
}

YearInReview computeYearInReview(
  YearInReviewInput input,
  int year, {
  required DateTime now,
}) {
  Map<int, Map<String, dynamic>> byId(List<Map<String, dynamic>> docs) {
    final out = <int, Map<String, dynamic>>{};
    for (final d in docs) {
      final id = _int(d['id']);
      if (id != null) out[id] = d;
    }
    return out;
  }

  final moviesById = byId(input.movies);
  final showsById = byId(input.shows);
  // Fallback title/poster for films only known from diary entries (e.g. the
  // movie doc was removed from the library after logging).
  final diaryMeta = <int, Map<String, dynamic>>{};

  // ------------------------------------------------------------ film watches
  final filmWatches = <_FilmWatch>[];
  final diaryDays = <String>{}; // "id|yyyy-mm-dd" of every diary entry
  for (final e in input.diaryEntries) {
    if (e['mediaType'] != null && e['mediaType'] != 'movie') continue;
    final id = _int(e['id']);
    final at = _date(e['watchedOn']);
    if (id == null || at == null) continue;
    diaryDays.add('$id|${_dayOf(at)}');
    diaryMeta[id] ??= e;
    if (!_inYear(at, year)) continue;
    final r = _double(e['rating']);
    filmWatches.add(_FilmWatch(id, at, r != null && r > 0 ? r : null));
  }
  for (final m in input.movies) {
    if (m['status'] != 'watched') continue;
    final id = _int(m['id']);
    final at = _date(m['watchedAt']);
    if (id == null || at == null || !_inYear(at, year)) continue;
    if (diaryDays.contains('$id|${_dayOf(at)}')) continue;
    filmWatches.add(_FilmWatch(id, at, null));
  }

  String filmTitle(int id) =>
      _str(moviesById[id]?['title']) ?? _str(diaryMeta[id]?['title']) ?? '';
  String? filmPoster(int id) =>
      _str(moviesById[id]?['posterPath']) ?? _str(diaryMeta[id]?['posterPath']);
  int filmRuntime(int id) => _int(moviesById[id]?['runtime']) ?? 0;

  // --------------------------------------------------------- episode watches
  final episodes = input.episodes.where((e) => _inYear(e.watchedAt, year));
  final episodeList = episodes.toList();

  int? showAverage(int showId) {
    final s = showsById[showId];
    final minutes = _int(s?['watchedMinutes']) ?? 0;
    final count = _int(s?['watchedCount']) ?? 0;
    if (minutes <= 0 || count <= 0) return null;
    return (minutes / count).round();
  }

  // ------------------------------------------------------------- aggregation
  final byMonthMin = List<int>.filled(12, 0);
  final byWeekdayMin = List<int>.filled(7, 0);
  final byMonthCount = List<int>.filled(12, 0);
  final byWeekdayCount = List<int>.filled(7, 0);
  final genreMinutes = <String, int>{};
  final perDayFilms = <DateTime, int>{};
  final perDayEpisodes = <DateTime, int>{};

  void addActivity(DateTime at, int minutes, List<String> genres) {
    byMonthMin[at.month - 1] += minutes;
    byWeekdayMin[at.weekday - 1] += minutes;
    byMonthCount[at.month - 1]++;
    byWeekdayCount[at.weekday - 1]++;
    if (minutes > 0) {
      for (final g in genres.toSet()) {
        genreMinutes[g] = (genreMinutes[g] ?? 0) + minutes;
      }
    }
  }

  var filmMinutes = 0;
  var filmsWithoutRuntime = 0;
  final watchCountById = <int, int>{};
  for (final w in filmWatches) {
    final runtime = filmRuntime(w.id);
    if (runtime > 0) {
      filmMinutes += runtime;
    } else {
      filmsWithoutRuntime++;
    }
    addActivity(w.at, runtime, _genres(moviesById[w.id]?['genres']));
    watchCountById[w.id] = (watchCountById[w.id] ?? 0) + 1;
    final day = _dayOf(w.at);
    perDayFilms[day] = (perDayFilms[day] ?? 0) + 1;
  }

  var episodeMinutes = 0;
  var episodesWithoutRuntime = 0;
  var episodesEstimated = 0;
  final showEpisodes = <int, int>{};
  final showMinutes = <int, int>{};
  final showLatest = <int, DateTime>{};
  for (final e in episodeList) {
    var minutes = input.episodeRuntimes[episodeRuntimeKey(e.showId, e.key)];
    if (minutes == null || minutes <= 0) {
      minutes = showAverage(e.showId);
      if (minutes != null) episodesEstimated++;
    }
    if (minutes == null || minutes <= 0) {
      minutes = 0;
      episodesWithoutRuntime++;
    }
    episodeMinutes += minutes;
    addActivity(e.watchedAt, minutes, _genres(showsById[e.showId]?['genres']));
    showEpisodes[e.showId] = (showEpisodes[e.showId] ?? 0) + 1;
    showMinutes[e.showId] = (showMinutes[e.showId] ?? 0) + minutes;
    final prev = showLatest[e.showId];
    if (prev == null || e.watchedAt.isAfter(prev)) {
      showLatest[e.showId] = e.watchedAt;
    }
    final day = _dayOf(e.watchedAt);
    perDayEpisodes[day] = (perDayEpisodes[day] ?? 0) + 1;
  }

  final totalMinutes = filmMinutes + episodeMinutes;
  final inMinutes = totalMinutes > 0;

  final topGenres = genreMinutes.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });

  // ---------------------------------------------------------------- ratings
  // Latest in-year diary rating per film, else the movie doc's rating.
  final yearRating = <int, double>{};
  final latestRatedAt = <int, DateTime>{};
  final latestWatchAt = <int, DateTime>{};
  for (final w in filmWatches) {
    final prevAt = latestWatchAt[w.id];
    if (prevAt == null || w.at.isAfter(prevAt)) latestWatchAt[w.id] = w.at;
    if (w.rating == null) continue;
    final prev = latestRatedAt[w.id];
    if (prev == null || w.at.isAfter(prev)) {
      latestRatedAt[w.id] = w.at;
      yearRating[w.id] = w.rating!;
    }
  }
  for (final id in watchCountById.keys) {
    if (yearRating.containsKey(id)) continue;
    final r = _double(moviesById[id]?['rating']);
    if (r != null && r > 0) yearRating[id] = r;
  }
  final ratedIds = yearRating.keys.toList()
    ..sort((a, b) {
      final c = yearRating[b]!.compareTo(yearRating[a]!);
      if (c != 0) return c;
      return latestWatchAt[b]!.compareTo(latestWatchAt[a]!);
    });
  final topRated = [
    for (final id in ratedIds.take(10))
      RatedFilm(
        id: id,
        title: filmTitle(id),
        posterPath: filmPoster(id),
        rating: yearRating[id]!,
      ),
  ];
  final avgRating = yearRating.isEmpty
      ? null
      : yearRating.values.reduce((a, b) => a + b) / yearRating.length;

  // --------------------------------------------------------------- top show
  ShowSummary? topShow;
  if (showEpisodes.isNotEmpty) {
    final ids = showEpisodes.keys.toList()
      ..sort((a, b) {
        var c = showEpisodes[b]!.compareTo(showEpisodes[a]!);
        if (c != 0) return c;
        c = showMinutes[b]!.compareTo(showMinutes[a]!);
        if (c != 0) return c;
        return showLatest[b]!.compareTo(showLatest[a]!);
      });
    final id = ids.first;
    final s = showsById[id];
    topShow = ShowSummary(
      id: id,
      name: _str(s?['name']) ?? '',
      posterPath: _str(s?['posterPath']),
      episodes: showEpisodes[id]!,
      minutes: showMinutes[id]!,
    );
  }

  // -------------------------------------------------------- first / latest
  final allWatches = <YearWatch>[
    for (final w in filmWatches)
      YearWatch(
        kind: WatchKind.film,
        id: w.id,
        title: filmTitle(w.id),
        posterPath: filmPoster(w.id),
        at: w.at,
      ),
    for (final e in episodeList)
      YearWatch(
        kind: WatchKind.episode,
        id: e.showId,
        title: _str(showsById[e.showId]?['name']) ?? '',
        posterPath: _str(showsById[e.showId]?['posterPath']),
        at: e.watchedAt,
        season: e.season,
        episode: e.episode,
      ),
  ];
  YearWatch? first;
  YearWatch? latest;
  for (final w in allWatches) {
    if (first == null || w.at.isBefore(first.at)) first = w;
    if (latest == null || w.at.isAfter(latest.at)) latest = w;
  }

  // ------------------------------------------------------------- fun facts
  FilmFact? longest;
  for (final id in watchCountById.keys) {
    final runtime = filmRuntime(id);
    if (runtime <= 0) continue;
    if (longest == null || runtime > longest.value) {
      longest = FilmFact(
        id: id,
        title: filmTitle(id),
        posterPath: filmPoster(id),
        value: runtime,
      );
    }
  }
  FilmFact? mostRewatched;
  for (final entry in watchCountById.entries) {
    if (entry.value < 2) continue;
    final better =
        mostRewatched == null ||
        entry.value > mostRewatched.value ||
        (entry.value == mostRewatched.value &&
            latestWatchAt[entry.key]!.isAfter(
              latestWatchAt[mostRewatched.id]!,
            ));
    if (better) {
      mostRewatched = FilmFact(
        id: entry.key,
        title: filmTitle(entry.key),
        posterPath: filmPoster(entry.key),
        value: entry.value,
      );
    }
  }
  BusiestDay? busiest;
  for (final day in {...perDayFilms.keys, ...perDayEpisodes.keys}) {
    final d = BusiestDay(
      day: day,
      films: perDayFilms[day] ?? 0,
      episodes: perDayEpisodes[day] ?? 0,
    );
    if (busiest == null ||
        d.total > busiest.total ||
        (d.total == busiest.total && d.day.isBefore(busiest.day))) {
      busiest = d;
    }
  }
  // A "busiest day" of one watch isn't a fact worth a card.
  if (busiest != null && busiest.total < 2) busiest = null;

  return YearInReview(
    year: year,
    isPartial: year == now.year,
    filmWatches: filmWatches.length,
    distinctFilms: watchCountById.length,
    episodes: episodeList.length,
    showsWatched: showEpisodes.length,
    filmMinutes: filmMinutes,
    episodeMinutes: episodeMinutes,
    filmsWithoutRuntime: filmsWithoutRuntime,
    episodesWithoutRuntime: episodesWithoutRuntime,
    episodesWithEstimatedRuntime: episodesEstimated,
    topGenres: topGenres,
    byMonth: inMinutes ? byMonthMin : byMonthCount,
    byWeekday: inMinutes ? byWeekdayMin : byWeekdayCount,
    activityInMinutes: inMinutes,
    topRatedFilms: topRated,
    averageFilmRating: avgRating,
    ratedFilms: yearRating.length,
    topShow: topShow,
    firstWatch: first,
    latestWatch: latest,
    longestFilm: longest,
    mostRewatchedFilm: mostRewatched,
    busiestDay: busiest,
  );
}
