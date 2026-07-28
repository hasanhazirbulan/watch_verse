import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/episode_detail_screen.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// A tracked show with its full ordered episode list, plus whether it currently
/// has an unwatched aired episode (used to order the feed on load).
class _ShowBundle {
  final TvShow show;
  final List<Episode> flat;
  final bool hasNext;
  _ShowBundle(this.show, this.flat, this.hasNext);
}

/// TV Time-style hub with a top toggle:
///   • Up Next  — one card per show showing the next episode *to watch*
///                (advances when you mark it), TV-Time style.
///   • My Shows — every show you track, with progress.
class UpNextScreen extends StatefulWidget {
  final int initialTab; // 0 = Up Next, 1 = My Shows
  const UpNextScreen({super.key, this.initialTab = 0});

  @override
  State<UpNextScreen> createState() => _UpNextScreenState();
}

class _UpNextScreenState extends State<UpNextScreen> {
  // TV Time marks a fully-finished show with a solid purple bar under its
  // poster; kept as a fixed brand-independent color (not a theme token)
  // since it signals a specific status, not the app's accent.
  static const _finishedLineColor = Color(0xFF8B5CF6);

  final APIservices _api = APIservices();
  late int _tab = widget.initialTab;
  int _myShowsFilter = 0;

  List<String> get _showFilters {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.upNextFilterAll,
      l10n.upNextStatusWatching,
      l10n.upNextStatusWatchlist,
      l10n.upNextStatusCompleted,
      l10n.upNextFilterFavorites,
    ];
  }

  // Memoize the heavy per-show episode fetch so it only re-runs when the set of
  // tracked shows changes, not on every episode toggle.
  String _idsKey = '';
  Future<List<_ShowBundle>>? _future;

  Future<List<_ShowBundle>> _futureFor(List<int> ids) {
    final key = ids.join(',');
    if (_future == null || key != _idsKey) {
      _idsKey = key;
      _future = _load(ids);
    }
    return _future!;
  }

  Future<List<_ShowBundle>> _load(List<int> ids) async {
    final results = await Future.wait(ids.map((id) async {
      try {
        final show = await _api.getTvDetails(id);
        final seasonEps = await Future.wait(show.seasons.map((s) async {
          try {
            return await _api.getSeasonEpisodes(id, s.seasonNumber);
          } catch (_) {
            return <Episode>[];
          }
        }));
        final flat = [for (final eps in seasonEps) ...eps];
        final watched = await TvTrackingService.instance.watchedKeys(id);
        final hasNext =
            flat.any((e) => e.hasAired && !watched.contains(e.key));
        return _ShowBundle(show, flat, hasNext);
      } catch (_) {
        return null;
      }
    }));
    return results.whereType<_ShowBundle>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.upNextTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedTabs(
              labels: [l10n.upNextTitle, l10n.upNextMyShowsLabel],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: StreamListView<Map<String, dynamic>>(
              stream: TvTrackingService.instance.trackedShowsStream(),
              emptyBuilder: (_) => _empty(
                Icons.playlist_add_check_circle_outlined,
                l10n.upNextEmptyTitle,
                l10n.upNextEmptySubtitle,
              ),
              builder: (context, shows) =>
                  _tab == 0 ? _upNextView(shows) : _myShowsView(shows),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Up Next ----

  Widget _upNextView(List<Map<String, dynamic>> shows) {
    // Everything except fully-finished shows can have a next episode to watch
    // or an upcoming one.
    final ids = shows
        .map((s) => (s['id'] ?? 0) as int)
        .where((id) => id != 0)
        .toList();

    return RefreshIndicator(
      color: context.colors.primary,
      backgroundColor: context.colors.surfaceAlt,
      onRefresh: () async {
        setState(() {
          _idsKey = '';
          _future = null;
        });
        await _futureFor(ids);
      },
      child: FutureBuilder<List<_ShowBundle>>(
        future: _futureFor(ids),
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListView(
              children: const [
                SizedBox(height: 40),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          final bundles = [...snap.data!];
          // Actionable (has an unwatched aired episode) first, otherwise keep
          // the tracked order (recently updated first).
          final order = {for (int i = 0; i < ids.length; i++) ids[i]: i};
          bundles.sort((a, b) {
            if (a.hasNext != b.hasNext) return a.hasNext ? -1 : 1;
            return (order[a.show.id] ?? 999).compareTo(order[b.show.id] ?? 999);
          });
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              for (final b in bundles) _NextUpCard(bundle: b),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- My Shows ----

  Widget _myShowsView(List<Map<String, dynamic>> shows) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filterShows(shows);
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _showFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _filterChip(i),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? _empty(Icons.tv_off_rounded, l10n.upNextNoShowsTitle,
                  l10n.upNextNoShowsSubtitle(_showFilters[_myShowsFilter]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _showCard(filtered[index]),
                ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filterShows(List<Map<String, dynamic>> shows) {
    switch (_myShowsFilter) {
      case 1:
        return shows.where((s) => s['status'] == 'watching').toList();
      case 2:
        return shows.where((s) => s['status'] == 'watchlist').toList();
      case 3:
        return shows.where((s) => s['status'] == 'completed').toList();
      case 4:
        return shows.where((s) => s['favorite'] == true).toList();
      default:
        return shows;
    }
  }

  Widget _filterChip(int i) {
    final active = i == _myShowsFilter;
    return GestureDetector(
      onTap: () => setState(() => _myShowsFilter = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: active ? context.colors.brandGradient : null,
          color: active ? null : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: active ? null : Border.all(color: Colors.white12, width: 1),
        ),
        child: Text(_showFilters[i],
            style: TextStyle(
                color: active ? Colors.white : context.colors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    );
  }

  Widget _showCard(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final total = (data['totalEpisodes'] ?? 0) as int;
    final watched = (data['watchedCount'] ?? 0) as int;
    final progress = total == 0 ? 0.0 : watched / total;
    final status = (data['status'] ?? 'watchlist') as String;

    return GestureDetector(
      onTap: () => openMedia(context, _seed(data)),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 96,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TmdbImage(
                        url: Tmdb.poster((data['posterPath'] ?? '') as String,
                            size: 'w185')),
                  ),
                  if (status == 'completed')
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          color: _finishedLineColor,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                      ),
                    )
                  else if (status == 'watching' && progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            Container(height: 4, color: Colors.black38),
                            FractionallySizedBox(
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(
                                  height: 4, color: context.colors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text((data['name'] ?? '') as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (data['favorite'] == true)
                        Icon(Icons.favorite_rounded,
                            size: 15, color: context.colors.primaryDark),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _statusChip(status),
                  const SizedBox(height: 10),
                  ProgressPill(value: progress, height: 6),
                  const SizedBox(height: 6),
                  Text(l10n.upNextEpisodeProgress(watched, total),
                      style: TextStyle(
                          color: context.colors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final l10n = AppLocalizations.of(context)!;
    late final String label;
    late final Color color;
    switch (status) {
      case 'completed':
        label = l10n.upNextStatusCompleted;
        color = context.colors.success;
        break;
      case 'watching':
        label = l10n.upNextStatusWatching;
        color = context.colors.primary;
        break;
      default:
        label = l10n.upNextStatusWatchlist;
        color = context.colors.info;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  // ----------------------------------------------------------------- utils ---

  MediaItem _seed(Map<String, dynamic> data) => MediaItem(
        id: (data['id'] ?? 0) as int,
        title: (data['name'] ?? '') as String,
        overview: '',
        posterPath: (data['posterPath'] ?? '') as String,
        backdropPath: (data['backdropPath'] ?? '') as String,
        date: (data['firstAirDate'] ?? '') as String,
        voteAverage: ((data['voteAverage'] ?? 0) as num).toDouble(),
        mediaType: MediaType.tv,
      );

  Widget _empty(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// One TV-Time-style "next episode to watch" card. Reactive: it listens to the
/// show's watched-episode set, so marking the shown episode advances it to the
/// next one automatically. Falls back to a compact "caught up" row when there's
/// nothing left aired, and hides entirely when the show is finished.
class _NextUpCard extends StatelessWidget {
  final _ShowBundle bundle;
  const _NextUpCard({required this.bundle});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final show = bundle.show;
    return StreamBuilder<Set<String>>(
      stream: TvTrackingService.instance.watchedKeysStream(show.id),
      builder: (context, snap) {
        final watched = snap.data ?? const <String>{};
        final aired = bundle.flat.where((e) => e.hasAired).toList();
        final watchedAired =
            aired.where((e) => watched.contains(e.key)).length;

        Episode? next;
        for (final e in aired) {
          if (!watched.contains(e.key)) {
            next = e;
            break;
          }
        }

        if (next != null) {
          return _nextUp(context, show, next, watchedAired, aired.length);
        }
        final upcoming = show.nextEpisodeToAir;
        if (upcoming != null) return _caughtUp(context, show, upcoming);
        return const SizedBox.shrink();
      },
    );
  }

  Widget _nextUp(BuildContext context, TvShow show, Episode ep,
      int watchedAired, int airedTotal) {
    final l10n = AppLocalizations.of(context)!;
    final progress = airedTotal == 0 ? 0.0 : watchedAired / airedTotal;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EpisodeDetailScreen(show: show, episode: ep)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 168,
                  width: double.infinity,
                  child: TmdbImage(
                    url: Tmdb.still(ep.stillPath, size: 'w780') ??
                        Tmdb.backdrop(show.backdropPath),
                    placeholderIcon: Icons.tv_rounded,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(gradient: context.colors.posterScrim),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(show.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 8)
                            ],
                          )),
                      const SizedBox(height: 2),
                      Text(
                          AppLocalizations.of(context)!.upNextSeasonEpisode(
                              ep.seasonNumber, ep.episodeNumber),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            ep.name.isEmpty
                                ? l10n.upNextEpisodeFallbackName(
                                    ep.episodeNumber)
                                : ep.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 8),
                        ProgressPill(value: progress, height: 6),
                        const SizedBox(height: 5),
                        Text(l10n.upNextWatchedCount(watchedAired, airedTotal),
                            style: TextStyle(
                                color: context.colors.textMuted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _markButton(context, () async {
                    HapticFeedback.lightImpact();
                    final messenger = ScaffoldMessenger.of(context);
                    final primary = context.colors.primary;
                    await TvTrackingService.instance
                        .setEpisodeWatched(show, ep, true);
                    if (watchedAired + 1 >= airedTotal) {
                      HapticFeedback.mediumImpact();
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                            l10n.upNextAllCaughtUpSnackbar(show.name),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        backgroundColor: primary,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _markButton(BuildContext context, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: context.colors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context)!.upNextMarkWatched,
              style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _caughtUp(BuildContext context, TvShow show, Episode upcoming) {
    final l10n = AppLocalizations.of(context)!;
    final today = _isToday(upcoming.airDate);
    return GestureDetector(
      onTap: () => openMedia(context, show.toMediaItem()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 46,
                height: 68,
                child: TmdbImage(url: Tmdb.poster(show.posterPath)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(show.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 14, color: context.colors.success),
                      const SizedBox(width: 4),
                      Text(l10n.upNextAllCaughtUp,
                          style: TextStyle(
                              color: context.colors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    today
                        ? l10n.upNextNewEpisodeToday
                        : l10n.upNextNextEpisodeOn(
                            _friendlyDate(upcoming.airDate)),
                    style: TextStyle(
                        color: today
                            ? context.colors.primaryDark
                            : context.colors.textMuted,
                        fontSize: 12,
                        fontWeight:
                            today ? FontWeight.w700 : FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _friendlyDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_months[d.month - 1]} ${d.day}';
  }
}
