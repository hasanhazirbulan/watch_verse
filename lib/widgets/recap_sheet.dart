import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/recap_logic.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/detail_sections.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// Loads watched episode key → when it was marked watched.
typedef RecapHistoryLoader = Future<Map<String, DateTime?>> Function(int showId);

/// Loads the cast credited on one episode.
typedef RecapCastLoader = Future<List<CastMember>> Function(
    int showId, int seasonNumber, int episodeNumber);

/// Opens the "Where you left off" recap for [show]. [flat] is the show's
/// episodes in airing order (Up Next already has them in memory, so stills
/// and overviews need no extra TMDB call).
Future<void> showRecapSheet(
    BuildContext context, TvShow show, List<Episode> flat) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => RecapSheet(
        show: show,
        flat: flat,
        scrollController: scrollController,
      ),
    ),
  );
}

/// Recap of the last episodes the user marked watched (still, SxEy, title,
/// TMDB overview, watch date) plus the cast of the latest one. Spoiler-safe
/// by construction: episodes come only from the watched set (see
/// [recapEpisodes]) and the cast is that watched episode's credits, not the
/// show's (which follow the newest season).
class RecapSheet extends StatefulWidget {
  final TvShow show;
  final List<Episode> flat;
  final ScrollController? scrollController;
  final RecapHistoryLoader? loadHistory;
  final RecapCastLoader? loadCast;

  const RecapSheet({
    super.key,
    required this.show,
    required this.flat,
    this.scrollController,
    this.loadHistory,
    this.loadCast,
  });

  @override
  State<RecapSheet> createState() => _RecapSheetState();
}

class _RecapSheetState extends State<RecapSheet> {
  // Session cache of episode casts (credits don't change), so reopening a
  // recap doesn't re-hit TMDB. Failures aren't cached.
  static final _castCache = <String, Future<List<CastMember>>>{};

  late final Future<List<RecapEpisode>> _episodes =
      (widget.loadHistory ?? TvTrackingService.instance.watchedAtByKey)(
              widget.show.id)
          .then((watched) => recapEpisodes(widget.flat, watched));

  // Cast of the latest watched episode; empty (section hidden) when there's
  // none or it can't be loaded (offline).
  late final Future<List<CastMember>> _cast = _loadCast();

  Future<List<CastMember>> _loadCast() async {
    try {
      final eps = await _episodes;
      if (eps.isEmpty) return const [];
      return await _castFor(eps.last.episode);
    } catch (_) {
      return const [];
    }
  }

  Future<List<CastMember>> _castFor(Episode ep) async {
    final injected = widget.loadCast;
    if (injected != null) {
      return injected(widget.show.id, ep.seasonNumber, ep.episodeNumber);
    }
    final key = '${widget.show.id}-${ep.key}';
    final future = _castCache.putIfAbsent(
        key,
        () => APIservices()
            .getEpisodeCast(widget.show.id, ep.seasonNumber, ep.episodeNumber));
    try {
      return await future;
    } catch (_) {
      _castCache.remove(key);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Icon(Icons.history_rounded,
                color: context.colors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.recapTitle,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(l10n.recapSubtitle(widget.show.name),
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13.5,
                height: 1.4)),
        const SizedBox(height: 18),
        FutureBuilder<List<RecapEpisode>>(
          future: _episodes,
          builder: (context, snap) {
            if (snap.hasError) {
              return _message(context, Icons.cloud_off_rounded,
                  l10n.recapLoadFailed);
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final eps = snap.data!;
            if (eps.isEmpty) {
              return _message(
                  context, Icons.history_toggle_off_rounded, l10n.recapEmpty);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in eps) _episodeCard(context, e),
                const SizedBox(height: 8),
                FutureBuilder<List<CastMember>>(
                  future: _cast,
                  builder: (context, castSnap) => CastStrip(
                      cast: (castSnap.data ?? const <CastMember>[])
                          .take(12)
                          .toList()),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _message(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: context.colors.textMuted),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 13.5)),
        ],
      ),
    );
  }

  Widget _episodeCard(BuildContext context, RecapEpisode r) {
    final l10n = AppLocalizations.of(context)!;
    final ep = r.episode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: TmdbImage(
              url: Tmdb.still(ep.stillPath, size: 'w780'),
              placeholderIcon: Icons.tv_rounded,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                        l10n.upNextSeasonEpisode(
                            ep.seasonNumber, ep.episodeNumber),
                        style: TextStyle(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                    const Spacer(),
                    if (r.watchedAt != null)
                      Text(l10n.recapWatchedOn(r.watchedAt!.toLocal()),
                          style: TextStyle(
                              color: context.colors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    ep.name.isEmpty
                        ? l10n.upNextEpisodeFallbackName(ep.episodeNumber)
                        : ep.name,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                    ep.overview.isEmpty ? l10n.recapNoOverview : ep.overview,
                    style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13.5,
                        height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
