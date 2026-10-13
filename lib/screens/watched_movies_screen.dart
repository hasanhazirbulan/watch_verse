import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

enum _SortOrder { dateAdded, ratingHighToLow }

/// Every movie the user has marked watched, as a 3-per-row poster grid —
/// the "see all" destination for the Movies tray on the profile screen.
class WatchedMoviesScreen extends StatefulWidget {
  const WatchedMoviesScreen({super.key});

  @override
  State<WatchedMoviesScreen> createState() => _WatchedMoviesScreenState();
}

class _WatchedMoviesScreenState extends State<WatchedMoviesScreen> {
  _SortOrder _sort = _SortOrder.dateAdded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileMoviesTitle),
        actions: [
          PopupMenuButton<_SortOrder>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: l10n.watchedMoviesSortTooltip,
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SortOrder.dateAdded,
                child: Text(l10n.watchedMoviesSortByDate),
              ),
              PopupMenuItem(
                value: _SortOrder.ratingHighToLow,
                child: Text(l10n.watchedMoviesSortByRating),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: MovieService.instance.watchedStream(),
        builder: (context, snap) {
          // Loading / failure used to fall straight through to the empty
          // message, so the grid briefly (or, on error, permanently) claimed
          // the user had no watched movies.
          if (snap.hasError) return asyncErrorView(context, snap.error!);
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return asyncLoadingIndicator();
          }
          final movies = [...snap.data ?? const <Map<String, dynamic>>[]];
          if (movies.isEmpty) {
            return Center(
              child: Text(
                l10n.watchlistEmptyMessage(l10n.watchlistCategoryWatched),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary),
              ),
            );
          }
          if (_sort == _SortOrder.ratingHighToLow) {
            movies.sort((a, b) => ((b['rating'] ?? 0) as num)
                .compareTo((a['rating'] ?? 0) as num));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.52,
            ),
            itemCount: movies.length,
            itemBuilder: (context, i) => _tile(context, movies[i]),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> m) {
    final rating = ((m['rating'] ?? 0) as num).toDouble();
    return GestureDetector(
      onTap: () => openMedia(
        context,
        MediaItem(
          id: (m['id'] ?? 0) as int,
          title: (m['title'] ?? '') as String,
          overview: '',
          posterPath: (m['posterPath'] ?? '') as String,
          backdropPath: (m['backdropPath'] ?? '') as String,
          date: (m['releaseDate'] ?? '') as String,
          voteAverage: ((m['voteAverage'] ?? 0) as num).toDouble(),
          mediaType: MediaType.movie,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 96 / 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TmdbImage(
                    url: Tmdb.poster((m['posterPath'] ?? '') as String,
                        size: 'w185'),
                    placeholderIcon: Icons.movie_rounded,
                  ),
                  if (rating > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: UserRatingBadge(rating: rating, compact: true),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text((m['title'] ?? '') as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
