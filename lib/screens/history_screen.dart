import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart';
import 'package:watch_verse/screens/tv_detail_screen.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// TV Time-style watch history: a reverse-chronological feed of episodes and
/// seasons you've marked watched.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: StreamListView<Map<String, dynamic>>(
        stream: TvTrackingService.instance.activityStream(),
        emptyBuilder: (context) => _empty(context),
        builder: (context, items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _tile(context, items[index]),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> a) {
    final l10n = AppLocalizations.of(context)!;
    final kind = a['kind'] as String?;
    final isMovie = kind == 'movie';
    final isSeason = kind == 'season';
    final season = (a['season'] ?? 0) as int;
    final rating = ((a['rating'] ?? 0) as num).toDouble();
    final title = isMovie
        ? (a['title'] ?? '') as String
        : (a['showName'] ?? '') as String;
    final line = isMovie
        ? (rating > 0
            ? l10n.historyWatchedRating(rating.toStringAsFixed(1))
            : l10n.historyWatchedLabel)
        : isSeason
            ? l10n.historyFinishedSeason(season, (a['count'] ?? 0) as int)
            : l10n.historyEpisodeLine(season, (a['episode'] ?? 0) as int,
                (a['episodeName'] ?? '') as String);
    final accent = isMovie
        ? context.colors.info
        : (isSeason ? context.colors.success : context.colors.primary);

    return GestureDetector(
      onTap: () {
        if (isMovie) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailsScreen(
                movie: Movie(
                  id: (a['movieId'] ?? 0) as int,
                  title: title,
                  overview: '',
                  posterPath: (a['posterPath'] ?? '') as String,
                  backDropPath: '',
                  releaseDate: '',
                  voteAverage: 0,
                ),
              ),
            ),
          );
        } else {
          final seed = MediaItem(
            id: (a['showId'] ?? 0) as int,
            title: title,
            overview: '',
            posterPath: (a['posterPath'] ?? '') as String,
            backdropPath: '',
            date: '',
            voteAverage: 0,
            mediaType: MediaType.tv,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TvDetailScreen(seed: seed)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMovie
                    ? Icons.movie_rounded
                    : (isSeason
                        ? Icons.done_all_rounded
                        : Icons.check_rounded),
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 60,
                child: TmdbImage(
                  url: Tmdb.poster((a['posterPath'] ?? '') as String,
                      size: 'w185'),
                  placeholderIcon:
                      isMovie ? Icons.movie_rounded : Icons.tv_rounded,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.colors.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_ago(l10n, a['at']),
                style: TextStyle(
                    color: context.colors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(l10n.historyEmptyTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l10n.historyEmptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }

  String _ago(AppLocalizations l10n, dynamic at) {
    if (at is! Timestamp) return l10n.historyAgoNow;
    final diff = DateTime.now().difference(at.toDate());
    if (diff.inMinutes < 1) return l10n.historyAgoNow;
    if (diff.inMinutes < 60) return l10n.historyAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.historyAgoHours(diff.inHours);
    if (diff.inDays < 7) return l10n.historyAgoDays(diff.inDays);
    return l10n.historyAgoWeeks(diff.inDays ~/ 7);
  }
}
