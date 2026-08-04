import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/episode_detail_screen.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// A tracked show with its full ordered episode list, plus watch-progress
/// bookkeeping used to order the feed: how many aired episodes are watched,
/// and when the most recent one was marked watched.
class _ShowBundle {
  final TvShow show;
  final List<Episode> flat;
  final int watchedAiredCount;
  final DateTime? lastWatchedAt;
  _ShowBundle(this.show, this.flat, this.watchedAiredCount, this.lastWatchedAt);
}

/// One row on the Upcoming tab: a show's next episode to air, or a
/// watchlisted movie's release — whichever has a future-or-today date.
class _UpcomingItem {
  final DateTime date;
  final String title;
  final String posterPath;
  final String? subtitle;
  final bool isMovie;
  final VoidCallback onTap;
  _UpcomingItem({
    required this.date,
    required this.title,
    required this.posterPath,
    required this.subtitle,
    required this.isMovie,
    required this.onTap,
  });
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

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  final APIservices _api = APIservices();
  late int _tab = widget.initialTab;
  int _myShowsFilter = 0;

  // Shows the user just swiped away to "stop watching". Hidden locally the
  // instant the swipe is confirmed so the card doesn't reappear while the
  // Firestore delete + tracked-shows stream round-trip catches up.
  final Set<int> _hiddenShowIds = {};

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
        final watchedAiredCount =
            flat.where((e) => e.hasAired && watched.contains(e.key)).length;
        final lastWatchedAt =
            await TvTrackingService.instance.lastWatchedAt(id);
        return _ShowBundle(show, flat, watchedAiredCount, lastWatchedAt);
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
              labels: [
                l10n.upNextTitle,
                l10n.upNextMyShowsLabel,
                l10n.upNextUpcomingLabel,
              ],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: _tab == 2
                ? _upcomingView()
                : StreamListView<Map<String, dynamic>>(
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
        .where((id) => id != 0 && !_hiddenShowIds.contains(id))
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
          // Most recently watched episode first; shows with some watch
          // progress before shows that were added but never started, which
          // sink to the bottom in their tracked-list order.
          final order = {for (int i = 0; i < ids.length; i++) ids[i]: i};
          bundles.sort((a, b) {
            final aStarted = a.watchedAiredCount > 0;
            final bStarted = b.watchedAiredCount > 0;
            if (aStarted != bStarted) return aStarted ? -1 : 1;
            if (aStarted) {
              final at = a.lastWatchedAt;
              final bt = b.lastWatchedAt;
              if (at != null && bt != null) return bt.compareTo(at);
              if (at != null) return -1;
              if (bt != null) return 1;
            }
            return (order[a.show.id] ?? 999).compareTo(order[b.show.id] ?? 999);
          });
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              for (final b in bundles)
                _NextUpCard(
                  bundle: b,
                  onStoppedWatching: () =>
                      setState(() => _hiddenShowIds.add(b.show.id)),
                ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- Upcoming ----

  /// New episodes of tracked shows and release dates of watchlisted movies,
  /// merged into one date-sorted feed with day headers (Today / Tomorrow /
  /// weekday). Reuses the same bundle future as the Up Next tab, so switching
  /// tabs doesn't re-fetch every show's episodes.
  Widget _upcomingView() {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: TvTrackingService.instance.trackedShowsStream(),
      builder: (context, showsSnap) {
        final shows = showsSnap.data ?? const <Map<String, dynamic>>[];
        final ids = shows
            .map((s) => (s['id'] ?? 0) as int)
            .where((id) => id != 0 && !_hiddenShowIds.contains(id))
            .toList();
        return FutureBuilder<List<_ShowBundle>>(
          future: _futureFor(ids),
          builder: (context, bundleSnap) {
            final bundles = bundleSnap.data ?? const <_ShowBundle>[];
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: MovieService.instance.toWatchStream(),
              builder: (context, movieSnap) {
                final movies =
                    movieSnap.data ?? const <Map<String, dynamic>>[];
                final items = _upcomingItems(bundles, movies);
                if (items.isEmpty) {
                  return _empty(
                    Icons.event_available_rounded,
                    l10n.upNextUpcomingEmptyTitle,
                    l10n.upNextUpcomingEmptySubtitle,
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  children: _upcomingChildren(items),
                );
              },
            );
          },
        );
      },
    );
  }

  List<_UpcomingItem> _upcomingItems(
      List<_ShowBundle> bundles, List<Map<String, dynamic>> movies) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = <_UpcomingItem>[];

    for (final b in bundles) {
      final next = b.show.nextEpisodeToAir;
      if (next == null) continue;
      final date = DateTime.tryParse(next.airDate);
      if (date == null || date.isBefore(today)) continue;
      items.add(_UpcomingItem(
        date: date,
        title: b.show.name,
        posterPath: b.show.posterPath,
        subtitle: AppLocalizations.of(context)!
            .upNextSeasonEpisode(next.seasonNumber, next.episodeNumber),
        isMovie: false,
        onTap: () => openMedia(context, b.show.toMediaItem()),
      ));
    }

    for (final m in movies) {
      final date = DateTime.tryParse((m['releaseDate'] ?? '') as String);
      if (date == null || date.isBefore(today)) continue;
      final title = (m['title'] ?? '') as String;
      final posterPath = (m['posterPath'] ?? '') as String;
      items.add(_UpcomingItem(
        date: date,
        title: title,
        posterPath: posterPath,
        subtitle: null,
        isMovie: true,
        onTap: () => openMedia(
          context,
          MediaItem(
            id: (m['id'] ?? 0) as int,
            title: title,
            overview: '',
            posterPath: posterPath,
            backdropPath: (m['backdropPath'] ?? '') as String,
            date: (m['releaseDate'] ?? '') as String,
            voteAverage: ((m['voteAverage'] ?? 0) as num).toDouble(),
            mediaType: MediaType.movie,
          ),
        ),
      ));
    }

    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  List<Widget> _upcomingChildren(List<_UpcomingItem> items) {
    final children = <Widget>[];
    DateTime? lastHeader;
    for (final item in items) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      if (lastHeader != day) {
        children.add(_upcomingDateHeader(day));
        lastHeader = day;
      }
      children.add(_upcomingRow(item));
    }
    return children;
  }

  Widget _upcomingDateHeader(DateTime day) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    late final String label;
    if (day == today) {
      label = l10n.upNextUpcomingToday;
    } else if (day == today.add(const Duration(days: 1))) {
      label = l10n.upNextUpcomingTomorrow;
    } else {
      label = '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: context.colors.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              letterSpacing: 0.6)),
    );
  }

  Widget _upcomingRow(_UpcomingItem item) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                child: TmdbImage(
                  url: Tmdb.poster(item.posterPath, size: 'w185'),
                  placeholderIcon: item.isMovie
                      ? Icons.movie_creation_outlined
                      : Icons.tv_rounded,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 6),
                  if (item.isMovie)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(l10n.upNextUpcomingMovieTag,
                          style: TextStyle(
                              color: context.colors.primary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800)),
                    )
                  else if (item.subtitle != null)
                    Text(item.subtitle!,
                        style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
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

/// One TV Time-style watch-list row: poster thumbnail + show badge + next
/// episode, matching the reference layout (assets/tvshowtime-4.jpg).
/// Reactive: it listens to the show's watched-episode set, so marking the
/// shown episode advances it to the next one automatically. Falls back to a
/// compact "caught up" row when there's nothing left aired, and hides
/// entirely when the show is finished.
///
/// Three ways to mark the shown episode watched, all wired to the same
/// [_markWatched]: tapping the row opens the episode detail page, swiping
/// the row right marks it directly, and the checkmark button on the right
/// does the same without leaving the list. Swiping the row left opens a
/// confirmation sheet to stop tracking the show entirely.
class _NextUpCard extends StatelessWidget {
  final _ShowBundle bundle;
  final VoidCallback onStoppedWatching;
  const _NextUpCard({required this.bundle, required this.onStoppedWatching});

  // Fixed brand-independent colors: these signal a specific swipe action,
  // not the app's accent.
  static const _stopColor = Color(0xFFEF4444);

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
    final isPremiere = ep.seasonNumber == 1 && ep.episodeNumber == 1;
    final backlog = airedTotal - watchedAired - 1;

    return Dismissible(
      key: ValueKey('nextup-${show.id}'),
      direction: DismissDirection.horizontal,
      background: _swipeBackground(
        context,
        color: context.colors.success,
        icon: Icons.check_circle_rounded,
        label: l10n.upNextMarkWatched,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBackground(
        context,
        color: _stopColor,
        icon: Icons.remove_circle_rounded,
        label: l10n.upNextSwipeStopLabel,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _markWatched(context, show, ep, watchedAired, airedTotal);
          return false; // stays put; the row updates via the watched stream.
        }
        return _confirmStopWatching(context, show);
      },
      onDismissed: (_) {
        // Only reached for a confirmed left swipe (endToStart).
        TvTrackingService.instance.removeShow(show.id);
        onStoppedWatching();
      },
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EpisodeDetailScreen(show: show, episode: ep)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 96,
                  child: TmdbImage(
                    url: Tmdb.poster(show.posterPath, size: 'w185'),
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
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => openMedia(context, show.toMediaItem()),
                      child: _showBadge(context, show.name),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                            l10n.upNextSeasonEpisode(
                                ep.seasonNumber, ep.episodeNumber),
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: context.colors.textSecondary)),
                        if (backlog > 0)
                          _tag(
                              context,
                              '+$backlog',
                              context.colors.textMuted.withValues(alpha: 0.16),
                              context.colors.textSecondary),
                        if (isPremiere)
                          _tag(
                              context,
                              l10n.upNextPremiereTag,
                              context.colors.primary.withValues(alpha: 0.16),
                              context.colors.primary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                        ep.name.isEmpty
                            ? l10n.upNextEpisodeFallbackName(ep.episodeNumber)
                            : ep.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: context.colors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _checkButton(context,
                  () => _markWatched(context, show, ep, watchedAired, airedTotal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _showBadge(BuildContext context, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 0.3)),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 14, color: context.colors.textMuted),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, String text, Color background, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }

  Widget _checkButton(BuildContext context, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: context.colors.brandGradient,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _swipeBackground(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    final leftAligned = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            leftAligned ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _markWatched(BuildContext context, TvShow show, Episode ep,
      int watchedAired, int airedTotal) async {
    HapticFeedback.lightImpact();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final primary = context.colors.primary;
    await TvTrackingService.instance.setEpisodeWatched(show, ep, true);
    if (watchedAired + 1 >= airedTotal) {
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.upNextAllCaughtUpSnackbar(show.name),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: primary,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  /// Bottom sheet asking whether to stop tracking [show]. Returns true only
  /// when the user confirms; the actual removal happens in the caller's
  /// `onDismissed`, once the swipe-away animation finishes.
  Future<bool> _confirmStopWatching(BuildContext context, TvShow show) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: _stopColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.remove_circle_outline_rounded,
                    color: _stopColor, size: 28),
              ),
              const SizedBox(height: 14),
              Text(l10n.upNextStopWatchingTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(l10n.upNextStopWatchingContent(show.name),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13.5,
                      height: 1.4)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _stopColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.upNextStopWatchingConfirm,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.upNextStopWatchingCancel,
                      style: TextStyle(
                          color: context.colors.textSecondary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Widget _caughtUp(BuildContext context, TvShow show, Episode upcoming) {
    final l10n = AppLocalizations.of(context)!;
    final today = _isToday(upcoming.airDate);
    return Dismissible(
      key: ValueKey('caughtup-${show.id}'),
      direction: DismissDirection.endToStart,
      secondaryBackground: _swipeBackground(
        context,
        color: _stopColor,
        icon: Icons.remove_circle_rounded,
        label: l10n.upNextSwipeStopLabel,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (_) => _confirmStopWatching(context, show),
      onDismissed: (_) {
        TvTrackingService.instance.removeShow(show.id);
        onStoppedWatching();
      },
      child: GestureDetector(
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
                          : l10n.upNextNextEpisodeOn(_friendlyDate(upcoming.airDate)),
                      style: TextStyle(
                          color: today
                              ? context.colors.primaryDark
                              : context.colors.textMuted,
                          fontSize: 12,
                          fontWeight: today ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
