import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// The user's movie library. TV shows now live in the Up Next tab ("My Shows"),
/// so this screen is focused on movies only: To Watch / Watched / Favorites.
class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  int _category = 0;

  Stream<List<Map<String, dynamic>>> _streamFor(int index) {
    final svc = MovieService.instance;
    switch (index) {
      case 1:
        return svc.watchedStream();
      case 2:
        return svc.favoritesStream();
      default:
        return svc.toWatchStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = [
      l10n.watchlistCategoryToWatch,
      l10n.watchlistCategoryWatched,
      l10n.watchlistCategoryFavorites,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.watchlistTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedTabs(
              labels: categories,
              selected: _category,
              onChanged: (i) => setState(() => _category = i),
            ),
          ),
          Expanded(
            child: StreamListView<Map<String, dynamic>>(
              stream: _streamFor(_category),
              emptyBuilder: (context) => _empty(context, Icons.movie_outlined,
                  l10n.watchlistEmptyMessage(categories[_category])),
              builder: (context, movies) => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: movies.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 84),
                itemBuilder: (context, index) => _movieTile(context, movies[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _movieTile(BuildContext context, Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final rating = ((data['rating'] ?? 0) as num).toDouble();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 84,
          child: TmdbImage(
              url: Tmdb.poster((data['posterPath'] ?? '') as String,
                  size: 'w185')),
        ),
      ),
      title: Text((data['title'] ?? l10n.watchlistUntitled) as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: rating > 0
            ? Row(children: [
                Icon(Icons.star_rounded,
                    size: 14, color: context.colors.accent),
                const SizedBox(width: 3),
                Text(l10n.watchlistYourRating(rating.toStringAsFixed(1)),
                    style: TextStyle(
                        color: context.colors.textMuted, fontSize: 12)),
              ])
            : Text(
                l10n.watchlistReleaseDate(
                    (data['releaseDate'] ?? '—') as String),
                style:
                    TextStyle(color: context.colors.textMuted, fontSize: 12)),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => MovieDetailsScreen(movie: Movie.fromMap(data))),
      ),
    );
  }

  Widget _empty(BuildContext context, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: context.colors.textMuted),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary)),
        ],
      ),
    );
  }
}
