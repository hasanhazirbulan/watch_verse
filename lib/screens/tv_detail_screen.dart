import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/episode_detail_screen.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/add_to_list_sheet.dart';
import 'package:watch_verse/widgets/comment_widgets.dart';
import 'package:watch_verse/widgets/detail_sections.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// Bundle of everything the detail screen needs after the network round-trips:
/// full show details plus every episode grouped by season.
class _TvData {
  final TvShow show;
  final Map<int, List<Episode>> episodesBySeason;
  final List<CastMember> cast;
  final List<MediaItem> recommendations;
  final List<WatchProvider> providers;
  /// Seasons whose episode fetch failed — shown empty with a per-season
  /// retry instead of failing the whole show page.
  final Set<int> failedSeasons;
  late List<Episode> flat; // all trackable episodes, season/episode order

  _TvData(this.show, this.episodesBySeason, this.cast, this.recommendations,
      this.providers, this.failedSeasons) {
    rebuildFlat();
  }

  void rebuildFlat() {
    flat = [
      for (final season in show.seasons)
        ...(episodesBySeason[season.seasonNumber] ?? const []),
    ];
  }

  int get total => flat.length;
}

class TvDetailScreen extends StatefulWidget {
  final MediaItem seed;
  const TvDetailScreen({super.key, required this.seed});

  @override
  State<TvDetailScreen> createState() => _TvDetailScreenState();
}

class _TvDetailScreenState extends State<TvDetailScreen> {
  final APIservices _api = APIservices();
  late final Stream<StreamingPrefs> _streamingPrefs =
      StreamingDeps.instance.prefs.watch();
  final TvTrackingService _tracking = TvTrackingService.instance;
  late Future<_TvData> _future;
  final Set<int> _retryingSeasons = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TvData> _load() async {
    final show = await _api.getTvDetails(widget.seed.id);
    // Fetch episodes + secondary sections in parallel; secondary calls degrade
    // to empty lists so a single failure never blocks the whole screen.
    // A failed season degrades to empty (with a per-season retry, like Up
    // Next tolerates per-show failures) instead of failing the whole page.
    final failedSeasons = <int>{};
    final seasonsF = Future.wait(show.seasons.map((s) async {
      try {
        final eps = await _api.getSeasonEpisodes(show.id, s.seasonNumber);
        return MapEntry(s.seasonNumber, eps);
      } catch (_) {
        failedSeasons.add(s.seasonNumber);
        return MapEntry(s.seasonNumber, const <Episode>[]);
      }
    }));
    final castF = _api
        .getCredits(MediaType.tv, show.id)
        .catchError((_) => <CastMember>[]);
    final recsF = _api
        .getRecommendations(MediaType.tv, show.id)
        .catchError((_) => <MediaItem>[]);
    // The region chosen in Settings → My streaming services, else device's.
    final providersF = StreamingDeps.instance
        .resolveRegion()
        .then((region) => _api.getWatchProviders(MediaType.tv, show.id, region))
        .catchError((_) => <WatchProvider>[]);

    final entries = await seasonsF;
    return _TvData(
      show,
      Map.fromEntries(entries),
      await castF,
      await recsF,
      await providersF,
      failedSeasons,
    );
  }

  Future<void> _retrySeason(_TvData data, int seasonNumber) async {
    setState(() => _retryingSeasons.add(seasonNumber));
    try {
      final eps = await _api.getSeasonEpisodes(data.show.id, seasonNumber);
      data.episodesBySeason[seasonNumber] = eps;
      data.failedSeasons.remove(seasonNumber);
      data.rebuildFlat();
    } catch (_) {
      // Still failing — keep the retry row.
    }
    if (mounted) setState(() => _retryingSeasons.remove(seasonNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_TvData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingHero();
          }
          if (snapshot.hasError) {
            return _errorState(context, '${snapshot.error}');
          }
          final data = snapshot.data!;
          return StreamBuilder<Set<String>>(
            stream: _tracking.watchedKeysStream(data.show.id),
            builder: (context, watchedSnap) {
              final watched = watchedSnap.data ?? <String>{};
              return _content(context, data, watched);
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- states --

  Widget _loadingHero() {
    return Stack(
      fit: StackFit.expand,
      children: [
        TmdbImage(url: Tmdb.backdrop(widget.seed.backdropPath)),
        Container(color: Colors.black.withValues(alpha: 0.55)),
        const Center(child: CircularProgressIndicator()),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: BackButton(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _errorState(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.tvErrorLoadingShow(message),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary)),
              const SizedBox(height: 12),
              // Without this, a transient TMDB/network failure meant backing
              // out and re-opening the show — the future was never retried.
              TextButton(
                onPressed: () => setState(() => _future = _load()),
                child: Text(l10n.homeRetryAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- content --

  Widget _content(BuildContext context, _TvData data, Set<String> watched) {
    final l10n = AppLocalizations.of(context)!;
    final show = data.show;
    final watchedCount = data.flat.where((e) => watched.contains(e.key)).length;
    final progress = data.total == 0 ? 0.0 : watchedCount / data.total;
    final upNext = _nextEpisode(data, watched);
    final hasUnwatchedAired =
        data.flat.any((e) => e.hasAired && !watched.contains(e.key));

    return CustomScrollView(
      slivers: [
        _heroAppBar(context, show),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaRow(context, show),
                const SizedBox(height: 16),
                _trackingButton(show),
                TrailerButton(type: MediaType.tv, id: show.id),
                if (data.total > 0) ...[
                  const SizedBox(height: 18),
                  _progressCard(context, watchedCount, data.total, progress),
                  if (hasUnwatchedAired) ...[
                    const SizedBox(height: 10),
                    _markAllSeasonsButton(context, data, watched),
                  ],
                ],
                if (upNext != null) ...[
                  const SizedBox(height: 16),
                  _upNextCard(context, data, upNext, watched),
                ],
                if (show.overview.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(l10n.tvOverviewTitle,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(show.overview,
                      style: TextStyle(
                          color: context.colors.textSecondary, height: 1.45)),
                ],
                const SizedBox(height: 20),
                _ratingSection(show),
                if (data.providers.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  StreamBuilder<StreamingPrefs>(
                    stream: _streamingPrefs,
                    builder: (context, prefsSnap) => WatchProvidersSection(
                        providers: data.providers,
                        myProviderIds:
                            prefsSnap.data?.providerIds ?? const {}),
                  ),
                ],
                const SizedBox(height: 20),
                CastStrip(cast: data.cast),
                if (data.cast.isNotEmpty) const SizedBox(height: 20),
                if (show.seasons.isNotEmpty)
                  Text(l10n.tvSeasonsTitle,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        _seasonList(data, watched),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MediaRail(
                    title: l10n.tvMoreLikeThisTitle, items: data.recommendations),
                if (data.recommendations.isNotEmpty)
                  const SizedBox(height: 12),
                CommentsButton(
                  mediaType: MediaType.tv,
                  mediaId: show.id,
                  title: show.name,
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// First aired, unwatched episode in season/episode order.
  Episode? _nextEpisode(_TvData data, Set<String> watched) {
    for (final ep in data.flat) {
      if (ep.hasAired && !watched.contains(ep.key)) return ep;
    }
    return null;
  }

  Widget _heroAppBar(BuildContext context, TvShow show) {
    final l10n = AppLocalizations.of(context)!;
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: context.colors.background,
      leading: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle),
          child: const BackButton(color: Colors.white),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.playlist_add_rounded,
                  color: Colors.white),
              tooltip: l10n.tvAddToListTooltip,
              onPressed: () =>
                  showAddToListSheet(context, show.toMediaItem()),
            ),
          ),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // Only show the compact app-bar title once the header has collapsed,
          // so it never overlaps the large hero title in the background.
          final collapsed = constraints.biggest.height <=
              kToolbarHeight + MediaQuery.of(context).padding.top + 8;
          return FlexibleSpaceBar(
            centerTitle: true,
            titlePadding:
                const EdgeInsets.only(left: 48, right: 48, bottom: 16),
            title: collapsed
                ? Text(
                    show.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  )
                : null,
            background: Stack(
              fit: StackFit.expand,
              children: [
                TmdbImage(url: Tmdb.backdrop(show.backdropPath, size: 'w1280')),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, context.colors.background],
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  right: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 92,
                          height: 138,
                          child: TmdbImage(url: Tmdb.poster(show.posterPath)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              show.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 8)
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            RatingBadge(rating: show.voteAverage),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metaRow(BuildContext context, TvShow show) {
    final l10n = AppLocalizations.of(context)!;
    final bits = <String>[
      if (show.year.isNotEmpty) show.year,
      if (show.numberOfSeasons > 0)
        (show.numberOfSeasons == 1
            ? l10n.tvSeasonCountSingular(show.numberOfSeasons.toString())
            : l10n.tvSeasonCountPlural(show.numberOfSeasons.toString())),
      if (show.status.isNotEmpty) show.status,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final b in bits) _pill(context, b),
        for (final g in show.genres.take(3)) _pill(context, g, accent: true),
      ],
    );
  }

  Widget _pill(BuildContext context, String text, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent
            ? context.colors.primary.withValues(alpha: 0.14)
            : context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent ? context.colors.primary : context.colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _trackingButton(TvShow show) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _tracking.showStream(show.id),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final data = snap.data;
        final tracked = data != null;
        final status = (data?['status'] ?? '') as String;
        final label = !tracked
            ? l10n.tvAddToMyShows
            : status == 'completed'
                ? l10n.tvStatusCompleted
                : status == 'watching'
                    ? l10n.tvStatusWatching
                    : l10n.tvInMyShows;
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => tracked
                    ? _confirmRemove(show)
                    : _tracking.addShow(show),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: tracked ? null : context.colors.brandGradient,
                    color: tracked ? context.colors.surfaceAlt : null,
                    borderRadius: BorderRadius.circular(14),
                    border: tracked
                        ? Border.all(color: context.colors.primary, width: 1.2)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tracked ? Icons.check_rounded : Icons.add_rounded,
                        color: tracked ? context.colors.primary : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                tracked ? context.colors.primary : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _favButton(context, show, data?['favorite'] == true),
          ],
        );
      },
    );
  }

  Widget _favButton(BuildContext context, TvShow show, bool favorite) {
    return GestureDetector(
      onTap: () => _tracking.setFavorite(show, !favorite),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: favorite
              ? context.colors.primaryDark.withValues(alpha: 0.18)
              : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: favorite
              ? Border.all(color: context.colors.primaryDark, width: 1.3)
              : null,
        ),
        child: Icon(
          favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: favorite ? context.colors.primaryDark : context.colors.textSecondary,
        ),
      ),
    );
  }

  /// Marks/unmarks an episode; when marking one ahead of unwatched earlier
  /// episodes, offers to catch those up too (TV-Time style). Refuses to mark
  /// an episode watched before it has aired (rating/notes stay unrestricted).
  Future<void> _onEpisodeTap(
      _TvData data, Set<String> watched, Episode ep, bool nowWatched) async {
    final l10n = AppLocalizations.of(context)!;
    if (nowWatched && !ep.hasAired) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tvCannotMarkUnaired)));
      return;
    }
    if (nowWatched) HapticFeedback.lightImpact();
    await _tracking.setEpisodeWatched(data.show, ep, nowWatched);
    if (!nowWatched || !mounted) return;

    // Offer to catch up any earlier unwatched aired episodes.
    final idx = data.flat.indexWhere((e) => e.key == ep.key);
    final earlier = idx <= 0
        ? const <Episode>[]
        : data.flat
            .take(idx)
            .where((e) => e.hasAired && !watched.contains(e.key))
            .toList();
    await _offerCatchUp(data, earlier);
    if (!mounted) return;
    await _celebrateIfComplete(data, seasonNumber: ep.seasonNumber);
  }

  /// Offers to mark [earlier] episodes watched too (TV-Time style catch-up).
  /// No-op when [earlier] is empty. Shared by single-episode and
  /// whole-season "mark watched" actions so both cascade the same way.
  Future<void> _offerCatchUp(_TvData data, List<Episode> earlier) async {
    if (earlier.isEmpty || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final n = earlier.length;
    final episodesPhrase = n == 1
        ? l10n.tvEpisodeCountSingular(n.toString())
        : l10n.tvEpisodeCountPlural(n.toString());
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tvMarkPreviousTitle),
        content: Text(l10n.tvMarkPreviousQuestion(episodesPhrase)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.tvNo)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.tvYesMarkAll)),
        ],
      ),
    );
    if (yes == true) await _tracking.markEpisodesWatched(data.show, earlier);
  }

  /// Celebrates finishing a season (when [seasonNumber] is given) or the
  /// whole show, if that just became fully watched.
  Future<void> _celebrateIfComplete(_TvData data, {int? seasonNumber}) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final fresh = await _tracking.watchedKeys(data.show.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final total = data.show.numberOfEpisodes;
    if (total > 0 && fresh.length >= total) {
      HapticFeedback.mediumImpact();
      _celebrate(context, messenger, l10n.tvFinishedShow(data.show.name));
      return;
    }
    if (seasonNumber == null) return;
    final seasonKeys =
        (data.episodesBySeason[seasonNumber] ?? const <Episode>[])
            .map((e) => e.key)
            .toSet();
    if (seasonKeys.isNotEmpty && seasonKeys.every(fresh.contains)) {
      HapticFeedback.mediumImpact();
      _celebrate(
          context, messenger, l10n.tvSeasonComplete(seasonNumber.toString()));
    }
  }

  /// Marks/unmarks a whole season watched (bug fix: previously this never
  /// checked earlier seasons for unwatched aired episodes, unlike tapping a
  /// single episode, which already offers to catch those up).
  Future<void> _onSeasonMarkTap(_TvData data, Set<String> watched,
      SeasonSummary season, List<Episode> eps, List<Episode> airedEps,
      bool allWatched) async {
    final markWatched = !allWatched;
    await _tracking.setSeasonWatched(
        data.show, markWatched ? airedEps : eps, markWatched);
    if (!markWatched || !mounted) return;

    final earlier = data.flat
        .where((e) =>
            e.seasonNumber < season.seasonNumber &&
            e.hasAired &&
            !watched.contains(e.key))
        .toList();
    await _offerCatchUp(data, earlier);
    if (!mounted) return;
    await _celebrateIfComplete(data, seasonNumber: season.seasonNumber);
  }

  /// Marks every aired-but-unwatched episode across the whole show watched
  /// in one batch (unaired episodes are left alone, same as the per-season
  /// action already does).
  Future<void> _onMarkAllSeasonsTap(_TvData data, Set<String> watched) async {
    final l10n = AppLocalizations.of(context)!;
    final toMark = data.flat
        .where((e) => e.hasAired && !watched.contains(e.key))
        .toList();
    if (toMark.isEmpty) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tvMarkAllSeasonsTitle),
        content: Text(l10n.tvMarkAllSeasonsQuestion(data.show.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.tvNo)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.tvYesMarkAll)),
        ],
      ),
    );
    if (yes != true) return;
    await _tracking.markEpisodesWatched(data.show, toMark);
    if (!mounted) return;
    await _celebrateIfComplete(data);
  }

  Widget _markAllSeasonsButton(
      BuildContext context, _TvData data, Set<String> watched) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _onMarkAllSeasonsTap(data, watched),
        icon: const Icon(Icons.done_all_rounded, size: 18),
        label: Text(l10n.tvMarkAllSeasonsButton),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.primary,
          side: BorderSide(color: context.colors.primary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  /// TMDB `status` values that mean the show is still producing new
  /// episodes (as opposed to `Ended`/`Canceled`).
  static const _ongoingStatuses = {
    'Returning Series',
    'In Production',
    'Planned',
  };

  Widget _moreEpisodesBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.live_tv_rounded,
                size: 16, color: context.colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.tvMoreEpisodesComing,
                  style: TextStyle(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  void _celebrate(
      BuildContext context, ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: context.colors.primary,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _confirmRemove(TvShow show) async {
    final l10n = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.tvRemoveShowTitle),
        content: Text(l10n.tvRemoveShowContent(show.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.tvRemoveButton)),
        ],
      ),
    );
    if (yes == true) await _tracking.removeShow(show.id);
  }

  Widget _progressCard(
      BuildContext context, int watched, int total, double progress) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.tvYourProgress,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(l10n.tvProgressFraction(watched.toString(), total.toString()),
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ProgressPill(value: progress, height: 8),
          const SizedBox(height: 8),
          Text(l10n.tvPercentWatched((progress * 100).round().toString()),
              style: TextStyle(
                  color: context.colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _ratingSection(TvShow show) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _tracking.showStream(show.id),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final current = ((snap.data?['userRating'] ?? 0) as num).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.tvYourRating,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (current > 0)
                  Text(current.toStringAsFixed(1),
                      style: TextStyle(
                          color: context.colors.accent, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            // KeyedSubtree forces the bar to rebuild (and re-seed its initial
            // rating) whenever the stored rating changes; RatingBar.builder
            // itself doesn't accept a key.
            KeyedSubtree(
              key: ValueKey(current),
              child: RatingBar.builder(
                initialRating: current,
                minRating: 0,
                allowHalfRating: true,
                itemCount: 5,
                glowColor: context.colors.accent,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (context, _) =>
                    Icon(Icons.star_rounded, color: context.colors.accent),
                onRatingUpdate: (rating) => _tracking.setRating(show, rating),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _upNextCard(
      BuildContext context, _TvData data, Episode ep, Set<String> watched) {
    final l10n = AppLocalizations.of(context)!;
    final isWatched = watched.contains(ep.key);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary.withValues(alpha: 0.18),
            context.colors.primaryDark.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: context.colors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 108,
              height: 66,
              child: TmdbImage(
                url: Tmdb.still(ep.stillPath),
                placeholderIcon: Icons.tv_rounded,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.tvUpNextLabel,
                    style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
                const SizedBox(height: 3),
                Text(
                    l10n.tvUpNextEpisodeLabel(ep.seasonNumber.toString(),
                        ep.episodeNumber.toString(), ep.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EpisodeCheck(
            watched: isWatched,
            onTap: () => _onEpisodeTap(data, watched, ep, !isWatched),
          ),
        ],
      ),
    );
  }

  Widget _seasonList(_TvData data, Set<String> watched) {
    final show = data.show;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final l10n = AppLocalizations.of(context)!;
          final season = show.seasons[index];
          final List<Episode> eps =
              data.episodesBySeason[season.seasonNumber] ?? const [];
          final airedEps = eps.where((e) => e.hasAired).toList();
          final seasonWatched =
              airedEps.where((e) => watched.contains(e.key)).length;
          final allWatched =
              airedEps.isNotEmpty && seasonWatched == airedEps.length;
          final isLastSeason = index == show.seasons.length - 1;
          final showsMoreComing = isLastSeason &&
              allWatched &&
              _ongoingStatuses.contains(show.status);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ExpansionTile(
                  backgroundColor: context.colors.surface,
                  collapsedBackgroundColor: context.colors.surface,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Text(l10n.tvSeasonNumberLabel(season.seasonNumber.toString()),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Text(
                            l10n.tvSeasonFraction(
                                seasonWatched.toString(), eps.length.toString()),
                            style: TextStyle(
                                color: context.colors.textMuted, fontSize: 12)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ProgressPill(
                            value: eps.isEmpty
                                ? 0
                                : seasonWatched / eps.length,
                            height: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    if (airedEps.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _onSeasonMarkTap(
                              data, watched, season, eps, airedEps, allWatched),
                          icon: Icon(
                              allWatched
                                  ? Icons.remove_done_rounded
                                  : Icons.done_all_rounded,
                              size: 18),
                          label: Text(allWatched
                              ? l10n.tvUnmarkSeason
                              : l10n.tvMarkSeasonWatched),
                        ),
                      ),
                    if (data.failedSeasons.contains(season.seasonNumber))
                      _seasonRetryRow(context, data, season.seasonNumber),
                    if (showsMoreComing) _moreEpisodesBanner(context),
                    ...eps.map((ep) => _episodeTile(context, data, ep, watched)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: show.seasons.length,
      ),
    );
  }

  Widget _seasonRetryRow(BuildContext context, _TvData data, int seasonNumber) {
    final l10n = AppLocalizations.of(context)!;
    final retrying = _retryingSeasons.contains(seasonNumber);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(l10n.tvSeasonLoadFailed,
                style:
                    TextStyle(color: context.colors.textMuted, fontSize: 12.5)),
          ),
          TextButton(
            onPressed: retrying ? null : () => _retrySeason(data, seasonNumber),
            child: retrying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.retryAction),
          ),
        ],
      ),
    );
  }

  Widget _episodeTile(
      BuildContext context, _TvData data, Episode ep, Set<String> watched) {
    final l10n = AppLocalizations.of(context)!;
    final show = data.show;
    final isWatched = watched.contains(ep.key);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EpisodeDetailScreen(
                show: show, episode: ep, openedFromShow: true)),
      ),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 84,
              height: 50,
              child: TmdbImage(
                url: Tmdb.still(ep.stillPath),
                placeholderIcon: Icons.tv_rounded,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    l10n.tvEpisodeNumberLabel(
                        ep.episodeNumber.toString(), ep.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(
                  [
                    if (ep.airDate.isNotEmpty) formatTmdbDate(context, ep.airDate),
                    if (ep.runtime > 0) l10n.tvRuntimeMinutes(ep.runtime.toString()),
                    if (!ep.hasAired) l10n.tvNotAired,
                  ].join('  •  '),
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EpisodeCheck(
            watched: isWatched,
            onTap: () => _onEpisodeTap(data, watched, ep, !isWatched),
          ),
        ],
      ),
      ),
    );
  }
}

/// Circular watched/unwatched toggle used on episode rows.
class _EpisodeCheck extends StatelessWidget {
  final bool watched;
  final VoidCallback onTap;
  const _EpisodeCheck({required this.watched, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: watched ? context.colors.brandGradient : null,
          color: watched ? null : Colors.transparent,
          shape: BoxShape.circle,
          border: watched
              ? null
              : Border.all(color: context.colors.textMuted, width: 1.6),
        ),
        child: Icon(
          Icons.check_rounded,
          size: 18,
          color: watched ? Colors.white : context.colors.textMuted,
        ),
      ),
    );
  }
}
