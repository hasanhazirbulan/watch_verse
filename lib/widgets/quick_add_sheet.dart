import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart'
    show movieWithStoredMeta, showMovieLogSheet;
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/add_to_list_sheet.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// Letterboxd-style long-press quick actions for a poster: Watch/Like/
/// Watchlist, a star rating, "Review or log" (movies), "Add to lists" and
/// "Go to [title]" — all wired to this app's existing per-user services, no
/// new Firestore schema. Works for both movies (no extra fetch — a
/// [MediaItem] already carries everything [Movie] needs) and shows (fetches
/// full [TvShow] details once, since [TvTrackingService] writes need the
/// full show metadata).
Future<void> showQuickAddSheet(BuildContext context, MediaItem item) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    // The sheet lives on the root navigator, so its own context would push
    // "Go to …" onto the root too — above the tab bar, unlike a normal poster
    // tap. Navigate from the caller's context instead.
    builder: (_) => _QuickAddSheet(item: item, host: context),
  );
}

class _QuickAddSheet extends StatelessWidget {
  final MediaItem item;
  final BuildContext host;
  const _QuickAddSheet({required this.item, required this.host});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(context),
            const SizedBox(height: 14),
            _header(context),
            const SizedBox(height: 18),
            if (item.mediaType == MediaType.movie)
              _MovieQuickActions(item: item, host: host)
            else
              _ShowQuickActions(item: item, host: host),
          ],
        ),
      ),
    );
  }

  Widget _handle(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.textMuted,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  Widget _header(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44,
            height: 62,
            child: TmdbImage(url: Tmdb.poster(item.posterPath, size: 'w185')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ],
    );
  }
}

/// Small square icon button used for the Watch/Like/Watchlist row.
class _IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool dimmed;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? context.colors.primary : context.colors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Marks [movie] watched, resolving runtime/genres first when unknown —
/// mirrors [showMovieLogSheet]'s resolution so a quick "Watch" tap here
/// contributes to the profile's time-spent/genre stats exactly like logging
/// through the full diary sheet does.
Future<void> _markMovieWatched(Movie movie) async {
  var withDetails = movie;
  if (movie.runtime <= 0 || movie.genres.isEmpty) {
    final extras = await APIservices()
        .getMovieDetailExtras(movie.id)
        .catchError((_) => (runtime: 0, genres: <String>[]));
    withDetails =
        movie.withDetails(runtime: extras.runtime, genres: extras.genres);
  }
  await MovieService.instance.setStatus(withDetails, 'watched');
}

Widget _ratingRow(BuildContext context, AppLocalizations l10n, double rating,
    ValueChanged<double> onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l10n.quickAddRate,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: ValueKey(rating),
        child: RatingBar.builder(
          initialRating: rating,
          minRating: 0,
          allowHalfRating: true,
          itemCount: 5,
          itemSize: 28,
          glowColor: context.colors.accent,
          itemPadding: const EdgeInsets.symmetric(horizontal: 3),
          itemBuilder: (context, _) =>
              Icon(Icons.star_rounded, color: context.colors.accent),
          onRatingUpdate: onChanged,
        ),
      ),
    ],
  );
}

Widget _sheetRow(BuildContext context,
    {required IconData icon, required String label, required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.textSecondary),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    ),
  );
}

class _MovieQuickActions extends StatelessWidget {
  final MediaItem item;
  final BuildContext host;
  const _MovieQuickActions({required this.item, required this.host});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: MovieService.instance.movieStream(item.id),
      builder: (context, snap) {
        final data = snap.data;
        // Friend-poster items carry no overview; backfill from the stored doc
        // so these writes don't blank it out (see movieWithStoredMeta).
        final movie = movieWithStoredMeta(item.toMovie(), data);
        final status = data?['status'] as String?;
        final favorite = data?['favorite'] == true;
        final rating = ((data?['rating'] ?? 0) as num).toDouble();
        final canWatch = status == 'watched' || movie.hasReleased;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _IconAction(
                    icon: status == 'watched'
                        ? Icons.check_circle_rounded
                        : Icons.visibility_outlined,
                    label: l10n.quickAddWatch,
                    active: status == 'watched',
                    dimmed: !canWatch,
                    onTap: () {
                      if (!canWatch) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(l10n.movieCannotMarkUnreleased)));
                        return;
                      }
                      status == 'watched'
                          ? MovieService.instance.remove(movie.id)
                          : _markMovieWatched(movie);
                    },
                  ),
                ),
                Expanded(
                  child: _IconAction(
                    icon: favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: l10n.quickAddLike,
                    active: favorite,
                    onTap: () =>
                        MovieService.instance.setFavorite(movie, !favorite),
                  ),
                ),
                Expanded(
                  child: _IconAction(
                    icon: status == 'watchlist'
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                    label: l10n.quickAddWatchlist,
                    active: status == 'watchlist',
                    onTap: () => status == 'watchlist'
                        ? MovieService.instance.remove(movie.id)
                        : MovieService.instance.setStatus(movie, 'watchlist'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ratingRow(context, l10n, rating,
                (r) => MovieService.instance.setRating(movie, r)),
            const Divider(height: 30),
            _sheetRow(context,
                icon: Icons.edit_note_rounded,
                label: l10n.quickAddReviewOrLog,
                onTap: () {
                  Navigator.pop(context);
                  if (!host.mounted) return;
                  if (!canWatch) {
                    // Used to close the sheet and silently do nothing.
                    ScaffoldMessenger.of(host).showSnackBar(SnackBar(
                        content: Text(l10n.movieCannotMarkUnreleased)));
                    return;
                  }
                  showMovieLogSheet(host, movie);
                }),
            _sheetRow(context,
                icon: Icons.playlist_add_rounded,
                label: l10n.quickAddAddToList,
                onTap: () {
                  Navigator.pop(context);
                  if (host.mounted) showAddToListSheet(host, item);
                }),
            _sheetRow(context,
                icon: Icons.open_in_new_rounded,
                label: l10n.quickAddGoTo(item.title),
                onTap: () {
                  Navigator.pop(context);
                  if (host.mounted) openMedia(host, item);
                }),
          ],
        );
      },
    );
  }
}

class _ShowQuickActions extends StatefulWidget {
  final MediaItem item;
  final BuildContext host;
  const _ShowQuickActions({required this.item, required this.host});

  @override
  State<_ShowQuickActions> createState() => _ShowQuickActionsState();
}

class _ShowQuickActionsState extends State<_ShowQuickActions> {
  late final Future<TvShow> _show =
      APIservices().getTvDetails(widget.item.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<TvShow>(
      future: _show,
      builder: (context, snap) {
        if (snap.hasError) {
          // Used to spin forever when the show-details fetch failed; show the
          // error and keep "Go to …" so the sheet isn't a dead end.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              asyncErrorView(context, snap.error!),
              _sheetRow(context,
                  icon: Icons.open_in_new_rounded,
                  label: l10n.quickAddGoTo(widget.item.title),
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.host.mounted) {
                      openMedia(widget.host, widget.item);
                    }
                  }),
            ],
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final show = snap.data!;
        return StreamBuilder<Map<String, dynamic>?>(
          stream: TvTrackingService.instance.showStream(show.id),
          builder: (context, snap) {
            final data = snap.data;
            final tracked = data != null;
            final favorite = data?['favorite'] == true;
            final rating = ((data?['userRating'] ?? 0) as num).toDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _IconAction(
                        icon: tracked
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        label: l10n.quickAddTrack,
                        active: tracked,
                        onTap: () => TvTrackingService.instance.addShow(show),
                      ),
                    ),
                    Expanded(
                      child: _IconAction(
                        icon: favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: l10n.quickAddLike,
                        active: favorite,
                        onTap: () => TvTrackingService.instance
                            .setFavorite(show, !favorite),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ratingRow(context, l10n, rating,
                    (r) => TvTrackingService.instance.setRating(show, r)),
                const Divider(height: 30),
                _sheetRow(context,
                    icon: Icons.playlist_add_rounded,
                    label: l10n.quickAddAddToList,
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.host.mounted) {
                        showAddToListSheet(widget.host, show.toMediaItem());
                      }
                    }),
                _sheetRow(context,
                    icon: Icons.open_in_new_rounded,
                    label: l10n.quickAddGoTo(show.name),
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.host.mounted) {
                        openMedia(widget.host, widget.item);
                      }
                    }),
              ],
            );
          },
        );
      },
    );
  }
}
