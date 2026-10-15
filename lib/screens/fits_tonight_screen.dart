import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/screens/episode_detail_screen.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart';
import 'package:watch_verse/screens/streaming_services_screen.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/fits_tonight_logic.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/streaming_widgets.dart';

/// A tracked show plus its aired, unwatched episodes in watch order — the
/// screen-side payload behind a [FitsShowCandidate].
class FitsTonightShow {
  final TvShow show;
  final List<Episode> unwatched;
  const FitsTonightShow(this.show, this.unwatched);
}

typedef FitsMovie = FitsMovieCandidate<Map<String, dynamic>>;
typedef FitsShow = FitsShowCandidate<FitsTonightShow>;

/// Everything "Fits tonight" picks from: the To Watch movies and the
/// tracked shows that still have aired episodes left.
class FitsTonightData {
  final List<FitsMovie> movies;
  final List<FitsShow> shows;

  /// Tracked shows TMDB couldn't return (offline, removed title…).
  final int failedShows;
  const FitsTonightData({
    required this.movies,
    required this.shows,
    this.failedShows = 0,
  });

  bool get isEmpty => movies.isEmpty && shows.isEmpty;
}

/// Loads [FitsTonightData] from the user's library: watchlist movies (with
/// missing runtimes resolved from TMDB and cached on device — read-only, no
/// Firestore writes) and each tracked show's next unwatched episodes, using
/// the same "next episode" rule as Up Next.
class FitsTonightLoader {
  FitsTonightLoader._();

  static const _runtimeCacheKey = 'fits_tonight_movie_runtimes_v1';
  static const _concurrency = 6;

  // Session caches. Show/episode lists rarely change mid-session; failures
  // are evicted so a retry really retries.
  static final Map<int, Future<({TvShow show, List<Episode> flat})>> _tv = {};
  static Map<int, int>? _runtimes;

  static Future<FitsTonightData> load() async {
    final results = await Future.wait([_loadMovies(), _loadShows()]);
    final movies = results[0] as List<FitsMovie>;
    final shows = results[1] as ({List<FitsShow> shows, int failed});
    if (movies.isEmpty && shows.shows.isEmpty && shows.failed > 0) {
      throw StateError('Couldn\'t load your shows');
    }
    return FitsTonightData(
      movies: movies,
      shows: shows.shows,
      failedShows: shows.failed,
    );
  }

  static Future<Map<int, int>> _runtimeCache() async {
    final cached = _runtimes;
    if (cached != null) return cached;
    final map = <int, int>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_runtimeCacheKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          final id = int.tryParse('$k');
          if (id != null && v is int && v > 0) map[id] = v;
        });
      }
    } catch (e) {
      debugPrint('FitsTonight: runtime cache read failed: $e');
    }
    return _runtimes = map;
  }

  static Future<void> _saveRuntimeCache(Map<int, int> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _runtimeCacheKey,
        jsonEncode(map.map((k, v) => MapEntry('$k', v))),
      );
    } catch (e) {
      debugPrint('FitsTonight: runtime cache write failed: $e');
    }
  }

  static Future<List<FitsMovie>> _loadMovies() async {
    final docs = await MovieService.instance.toWatchStream().first;
    final cache = await _runtimeCache();
    final missing = <int>[
      for (final d in docs)
        if (((d['runtime'] ?? 0) as num).toInt() <= 0 &&
            !cache.containsKey(((d['id'] ?? 0) as num).toInt()))
          ((d['id'] ?? 0) as num).toInt(),
    ]..removeWhere((id) => id == 0);
    if (missing.isNotEmpty) {
      final api = APIservices();
      var added = false;
      for (var i = 0; i < missing.length; i += _concurrency) {
        await Future.wait(
          missing.skip(i).take(_concurrency).map((id) async {
            try {
              final extras = await api.getMovieDetailExtras(id);
              if (extras.runtime > 0) {
                cache[id] = extras.runtime;
                added = true;
              }
            } catch (_) {
              // Stays "runtime unknown"; retried next time.
            }
          }),
        );
      }
      if (added) await _saveRuntimeCache(cache);
    }
    return [
      for (final d in docs)
        if (((d['id'] ?? 0) as num).toInt() != 0)
          _movieCandidate(d, cache[((d['id'] ?? 0) as num).toInt()] ?? 0),
    ];
  }

  static FitsMovie _movieCandidate(Map<String, dynamic> d, int cached) {
    final stored = ((d['runtime'] ?? 0) as num).toInt();
    return FitsMovie(
      id: ((d['id'] ?? 0) as num).toInt(),
      title: (d['title'] ?? '') as String,
      runtime: stored > 0 ? stored : cached,
      voteAverage: ((d['voteAverage'] ?? 0) as num).toDouble(),
      payload: d,
    );
  }

  static Future<({TvShow show, List<Episode> flat})> _tmdb(int id) {
    return _tv.putIfAbsent(id, () async {
      try {
        final api = APIservices();
        final show = await api.getTvDetails(id);
        final seasons = await Future.wait(
          show.seasons.map((s) async {
            try {
              return await api.getSeasonEpisodes(id, s.seasonNumber);
            } catch (_) {
              return <Episode>[];
            }
          }),
        );
        return (show: show, flat: [for (final eps in seasons) ...eps]);
      } catch (_) {
        _tv.remove(id);
        rethrow;
      }
    });
  }

  static Future<({List<FitsShow> shows, int failed})> _loadShows() async {
    final tracking = TvTrackingService.instance;
    final docs = await tracking.allShowsOnce();
    var failed = 0;
    final shows = await Future.wait(
      docs.map((d) async {
        final id = ((d['id'] ?? 0) as num).toInt();
        if (id == 0) return null;
        try {
          final tmdb = await _tmdb(id);
          final watched = await tracking.watchedKeys(id);
          final unwatched = unwatchedAiredInOrder<Episode>(
            tmdb.flat,
            hasAired: (e) => e.hasAired,
            isWatched: (e) => watched.contains(e.key),
          );
          if (unwatched.isEmpty) return null;
          final lastWatchedAt = await tracking.lastWatchedAt(id);
          return FitsShow(
            id: id,
            name: tmdb.show.name,
            unwatched: [
              for (final e in unwatched)
                FitsEpisode(
                  season: e.seasonNumber,
                  episode: e.episodeNumber,
                  runtime: e.runtime,
                ),
            ],
            fallbackRuntime: typicalRuntime(tmdb.flat.map((e) => e.runtime)),
            lastWatchedAt: lastWatchedAt,
            payload: FitsTonightShow(tmdb.show, unwatched),
          );
        } catch (e) {
          debugPrint('FitsTonight: show $id failed: $e');
          failed++;
          return null;
        }
      }),
    );
    return (shows: shows.whereType<FitsShow>().toList(), failed: failed);
  }
}

/// "We have 90 minutes, what do we watch?" — picks from the user's own
/// watchlist movies and the next unwatched episodes of their tracked shows,
/// whatever fits a chosen time budget. No recommendations: only their lists.
class FitsTonightScreen extends StatefulWidget {
  /// Test seams; default to the real Firestore/TMDB-backed loader, auth
  /// state and streaming services.
  final Future<FitsTonightData> Function()? load;
  final bool Function()? isSignedIn;
  final StreamingDeps? streamingDeps;
  final int initialBudget;

  const FitsTonightScreen({
    super.key,
    this.load,
    this.isSignedIn,
    this.streamingDeps,
    this.initialBudget = fitsTonightDefaultBudget,
  });

  @override
  State<FitsTonightScreen> createState() => _FitsTonightScreenState();
}

class _FitsTonightScreenState extends State<FitsTonightScreen> {
  static const _presets = [60, 90, 120, 180];

  late int _budget = widget.initialBudget
      .clamp(fitsTonightMinBudget, fitsTonightMaxBudget)
      .toInt();
  bool _onMyServices = false;

  late final StreamingDeps _streaming =
      widget.streamingDeps ?? StreamingDeps.instance;
  late final AvailabilityChecker _checker = AvailabilityChecker(
    source: _streaming.source,
    cache: _streaming.cache,
  );
  StreamSubscription<StreamingPrefs>? _prefsSub;
  StreamingPrefs? _prefs;

  late final bool _signedIn =
      (widget.isSignedIn ?? () => FirebaseAuth.instance.currentUser != null)();
  Future<FitsTonightData>? _future;

  @override
  void initState() {
    super.initState();
    if (!_signedIn) return;
    _future = _load();
    _prefsSub = _streaming.prefs.watch().listen(
      (p) {
        if (mounted) setState(() => _prefs = p);
      },
      onError: (Object e) {
        debugPrint('FitsTonight: streaming prefs failed: $e');
        if (mounted) setState(() => _prefs ??= StreamingPrefs.empty);
      },
    );
  }

  Future<FitsTonightData> _load() => (widget.load ?? FitsTonightLoader.load)();

  @override
  void dispose() {
    _prefsSub?.cancel();
    _checker.dispose();
    super.dispose();
  }

  String _duration(int minutes) {
    final l10n = AppLocalizations.of(context)!;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return l10n.fitsTonightMinutes(m);
    if (m == 0) return l10n.fitsTonightHours(h);
    return l10n.fitsTonightHoursMinutes(h, m);
  }

  void _setBudget(int minutes) {
    final snapped =
        ((minutes / fitsTonightBudgetStep).round() * fitsTonightBudgetStep)
            .clamp(fitsTonightMinBudget, fitsTonightMaxBudget)
            .toInt();
    if (snapped != _budget) setState(() => _budget = snapped);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fitsTonightTitle)),
      body: !_signedIn
          ? _message(
              Icons.timer_outlined,
              l10n.fitsTonightTitle,
              l10n.fitsTonightGuestBody,
            )
          : Column(
              children: [
                _budgetPanel(),
                if (_streaming.prefs.canSave)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StreamingFilterChip(
                        active: _onMyServices,
                        onTap: () =>
                            setState(() => _onMyServices = !_onMyServices),
                      ),
                    ),
                  ),
                Expanded(child: _body()),
              ],
            ),
    );
  }

  Widget _budgetPanel() {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: colors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.fitsTonightBudgetLabel,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ),
              Text(
                _duration(_budget),
                key: const ValueKey('fits-budget'),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: _budget.toDouble(),
            min: fitsTonightMinBudget.toDouble(),
            max: fitsTonightMaxBudget.toDouble(),
            divisions:
                (fitsTonightMaxBudget - fitsTonightMinBudget) ~/
                fitsTonightBudgetStep,
            label: _duration(_budget),
            onChanged: (v) => _setBudget(v.round()),
          ),
          Row(
            children: [
              for (final p in _presets) ...[
                if (p != _presets.first) const SizedBox(width: 8),
                Expanded(child: _presetPill(p)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetPill(int minutes) {
    final colors = context.colors;
    final active = minutes == _budget;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: () => _setBudget(minutes),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? colors.brandGradient : null,
            color: active ? null : colors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _duration(minutes),
            style: TextStyle(
              color: active ? Colors.white : colors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<FitsTonightData>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError && snap.connectionState == ConnectionState.done) {
          return asyncErrorView(
            context,
            snap.error!,
            onRetry: () => setState(() => _future = _load()),
          );
        }
        final data = snap.data;
        if (data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                Text(
                  l10n.fitsTonightLoading,
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ],
            ),
          );
        }
        if (data.isEmpty) {
          return _message(
            Icons.timer_outlined,
            l10n.fitsTonightEmptyTitle,
            l10n.fitsTonightEmptyBody,
          );
        }
        return _withServices(data);
      },
    );
  }

  /// Runs the "On my services" check over every candidate (cache first,
  /// bounded concurrency — the same checker as the watchlist), then packs
  /// only the ones it lets through.
  Widget _withServices(FitsTonightData data) {
    final prefs = _prefs;
    if (prefs == null && _onMyServices) return asyncLoadingIndicator();
    final p = prefs ?? StreamingPrefs.empty;
    final refs = [
      for (final m in data.movies) TitleRef(MediaType.movie, m.id),
      for (final s in data.shows) TitleRef(MediaType.tv, s.id),
    ];
    return StreamingFilterView<TitleRef>(
      items: refs,
      refOf: (r) => r,
      active: _onMyServices,
      prefs: p,
      region: p.effectiveRegion(_streaming.deviceCountry()),
      checker: _checker,
      onSetUp: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StreamingServicesScreen(deps: _streaming),
        ),
      ),
      builder: (context, visible, matchesOf) {
        final allowed = visible.toSet();
        final result = computeFitsTonight<Object?>(
          budget: _budget,
          movies: data.movies,
          shows: data.shows,
          include: (kind, id) => allowed.contains(
            TitleRef(
              kind == FitsKind.movie ? MediaType.movie : MediaType.tv,
              id,
            ),
          ),
        );
        return _results(data, result, matchesOf);
      },
    );
  }

  Widget _results(
    FitsTonightData data,
    FitsTonightResult<Object?> result,
    List<WatchProvider> Function(TitleRef) matchesOf,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[
      if (data.failedShows > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.fitsTonightShowsFailed(data.failedShows),
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ),
      if (!result.hasFits) _nothingFits(result.shortest),
      if (result.episodeRuns.isNotEmpty) ...[
        SectionHeader(title: l10n.fitsTonightEpisodesSection),
        for (final run in result.episodeRuns)
          _runCard(run, matchesOf(TitleRef(MediaType.tv, run.id))),
      ],
      if (result.movies.isNotEmpty) ...[
        SectionHeader(title: l10n.fitsTonightMoviesSection),
        for (final fit in result.movies)
          _movieCard(fit, matchesOf(TitleRef(MediaType.movie, fit.id))),
      ],
      if (result.unknownMovies.isNotEmpty ||
          result.unknownShows.isNotEmpty) ...[
        SectionHeader(title: l10n.fitsTonightUnknownSection),
        for (final s in result.unknownShows) _unknownShowTile(s),
        for (final m in result.unknownMovies) _unknownMovieTile(m),
      ],
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: children,
    );
  }

  Widget _nothingFits(int? shortest) {
    final l10n = AppLocalizations.of(context)!;
    final canStretch = shortest != null && shortest <= fitsTonightMaxBudget;
    final target = shortest == null
        ? null
        : ((shortest + fitsTonightBudgetStep - 1) ~/ fitsTonightBudgetStep) *
              fitsTonightBudgetStep;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 48,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.fitsTonightNothingFitsTitle(_duration(_budget)),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (shortest != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.fitsTonightNothingFitsBody(_duration(shortest)),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ],
          if (canStretch && target != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _setBudget(target),
              child: Text(l10n.fitsTonightNothingFitsAction(_duration(target))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({
    required Key key,
    required String posterPath,
    required IconData placeholder,
    required List<WatchProvider> providers,
    required String title,
    required String line1,
    String? line2,
    required int minutes,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 78,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TmdbImage(
                      url: Tmdb.poster(posterPath, size: 'w185'),
                      placeholderIcon: placeholder,
                    ),
                  ),
                  if (providers.isNotEmpty)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: StreamingBadge(providers: providers),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    line1,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (line2 != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      line2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _sparePill(_budget - minutes),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _sparePill(int spare) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final exact = spare < fitsTonightSlackBand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: exact
            ? colors.success.withValues(alpha: 0.16)
            : colors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        exact
            ? l10n.fitsTonightExactFit
            : l10n.fitsTonightSpare(_duration(spare)),
        style: TextStyle(
          color: exact ? colors.success : colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _runCard(EpisodeRunFit<Object?> run, List<WatchProvider> providers) {
    final l10n = AppLocalizations.of(context)!;
    final payload = run.show.payload as FitsTonightShow;
    final total = _duration(run.minutes);
    return _card(
      key: ValueKey('fits-show-${run.id}'),
      posterPath: payload.show.posterPath,
      placeholder: Icons.tv_rounded,
      providers: providers,
      title: run.title,
      line1: l10n.fitsTonightEpisodeRun(
        run.episodes.length,
        run.isEstimated ? l10n.fitsTonightApprox(total) : total,
      ),
      line2: episodeRangeLabel(run.first, run.last),
      minutes: run.minutes,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpisodeDetailScreen(
            show: payload.show,
            episode: payload.unwatched.first,
          ),
        ),
      ),
    );
  }

  Widget _movieCard(MovieFit<Object?> fit, List<WatchProvider> providers) {
    final data = fit.movie.payload as Map<String, dynamic>;
    final year = ((data['releaseDate'] ?? '') as String);
    return _card(
      key: ValueKey('fits-movie-${fit.id}'),
      posterPath: (data['posterPath'] ?? '') as String,
      placeholder: Icons.movie_creation_outlined,
      providers: providers,
      title: fit.title,
      line1: _duration(fit.minutes),
      line2: year.length >= 4 ? year.substring(0, 4) : null,
      minutes: fit.minutes,
      onTap: () => _openMovie(data, fit.minutes),
    );
  }

  void _openMovie(Map<String, dynamic> data, int runtime) {
    final movie = Movie.fromMap(data);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailsScreen(
          movie: runtime > 0 ? movie.withDetails(runtime: runtime) : movie,
        ),
      ),
    );
  }

  Widget _unknownTile({
    required String posterPath,
    required IconData placeholder,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 36,
          height: 54,
          child: TmdbImage(
            url: Tmdb.poster(posterPath, size: 'w185'),
            placeholderIcon: placeholder,
          ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.colors.textMuted, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _unknownShowTile(FitsShowCandidate<Object?> s) {
    final l10n = AppLocalizations.of(context)!;
    final payload = s.payload as FitsTonightShow;
    final next = s.unwatched.first;
    return _unknownTile(
      posterPath: payload.show.posterPath,
      placeholder: Icons.tv_rounded,
      title: s.name,
      subtitle: l10n.fitsTonightUnknownShow(episodeRangeLabel(next, next)),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpisodeDetailScreen(
            show: payload.show,
            episode: payload.unwatched.first,
          ),
        ),
      ),
    );
  }

  Widget _unknownMovieTile(FitsMovieCandidate<Object?> m) {
    final l10n = AppLocalizations.of(context)!;
    final data = m.payload as Map<String, dynamic>;
    return _unknownTile(
      posterPath: (data['posterPath'] ?? '') as String,
      placeholder: Icons.movie_creation_outlined,
      title: m.title,
      subtitle: l10n.fitsTonightUnknownMovie,
      onTap: () => _openMovie(data, 0),
    );
  }

  Widget _message(IconData icon, String title, String body) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
