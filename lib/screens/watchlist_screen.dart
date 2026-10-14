import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart';
import 'package:watch_verse/screens/streaming_services_screen.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/streaming_widgets.dart';

/// The user's movie library. TV shows now live in the Up Next tab ("My Shows"),
/// so this screen is focused on movies only: To Watch / Watched / Favorites.
class WatchlistScreen extends StatefulWidget {
  /// Test seams: the category streams (0 To Watch, 1 Watched, 2 Favorites)
  /// and the streaming-services dependencies. Default to the real services.
  final Stream<List<Map<String, dynamic>>> Function(int category)? streamFor;
  final StreamingDeps? streamingDeps;

  const WatchlistScreen({super.key, this.streamFor, this.streamingDeps});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  int _category = 0;
  bool _onMyServices = false;

  late final StreamingDeps _streaming =
      widget.streamingDeps ?? StreamingDeps.instance;
  late final AvailabilityChecker _checker = AvailabilityChecker(
    source: _streaming.source,
    cache: _streaming.cache,
  );

  // Created once per category: a new stream per build would make
  // StreamBuilder resubscribe (and flash a spinner) on every filter tap or
  // availability progress update.
  int? _streamCategory;
  late Stream<List<Map<String, dynamic>>> _stream;

  Stream<List<Map<String, dynamic>>> _currentStream() {
    if (_streamCategory != _category) {
      _streamCategory = _category;
      _stream = _streamFor(_category);
    }
    return _stream;
  }

  // Held as a subscription: the list below remounts on category switches,
  // and a single-subscription profile stream can't be listened to twice.
  StreamSubscription<StreamingPrefs>? _prefsSub;
  StreamingPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _prefsSub = _streaming.prefs.watch().listen(
      (p) {
        if (mounted) setState(() => _prefs = p);
      },
      onError: (Object e) {
        debugPrint('Watchlist: streaming prefs failed: $e');
        if (mounted) setState(() => _prefs ??= StreamingPrefs.empty);
      },
    );
  }

  @override
  void dispose() {
    _prefsSub?.cancel();
    _checker.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _streamFor(int index) {
    final custom = widget.streamFor;
    if (custom != null) return custom(index);
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
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              _streaming.prefs.canSave ? 10 : 16,
            ),
            child: SegmentedTabs(
              labels: categories,
              selected: _category,
              onChanged: (i) => setState(() => _category = i),
            ),
          ),
          if (_streaming.prefs.canSave)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StreamingFilterChip(
                  active: _onMyServices,
                  onTap: () => setState(() => _onMyServices = !_onMyServices),
                ),
              ),
            ),
          Expanded(
            child: StreamListView<Map<String, dynamic>>(
              stream: _currentStream(),
              emptyBuilder: (context) => _empty(
                context,
                Icons.movie_outlined,
                l10n.watchlistEmptyMessage(categories[_category]),
              ),
              builder: (context, movies) => _filtered(context, movies),
            ),
          ),
        ],
      ),
    );
  }

  /// Applies the "On my services" filter (and poster badges) on top of the
  /// category's movies.
  Widget _filtered(BuildContext context, List<Map<String, dynamic>> movies) {
    final prefs = _prefs;
    if (prefs == null && _onMyServices) return asyncLoadingIndicator();
    final p = prefs ?? StreamingPrefs.empty;
    return StreamingFilterView<Map<String, dynamic>>(
      items: movies,
      refOf: (m) => TitleRef(MediaType.movie, ((m['id'] ?? 0) as num).toInt()),
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
      builder: (context, visible, matchesOf) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
        itemBuilder: (context, index) =>
            _movieTile(context, visible[index], matchesOf(visible[index])),
      ),
    );
  }

  Widget _movieTile(
    BuildContext context,
    Map<String, dynamic> data,
    List<WatchProvider> onMyServices,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final rating = ((data['rating'] ?? 0) as num).toDouble();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: SizedBox(
        width: 56,
        height: 84,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TmdbImage(
                url: Tmdb.poster(
                  (data['posterPath'] ?? '') as String,
                  size: 'w185',
                ),
              ),
            ),
            if (onMyServices.isNotEmpty)
              Positioned(
                right: 2,
                bottom: 2,
                child: StreamingBadge(providers: onMyServices),
              ),
          ],
        ),
      ),
      title: Text(
        (data['title'] ?? l10n.watchlistUntitled) as String,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: rating > 0
            ? Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: context.colors.accent,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    l10n.watchlistYourRating(rating.toStringAsFixed(1)),
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            : Text(
                l10n.watchlistReleaseDate(
                  (data['releaseDate'] ?? '—') as String,
                ),
                style: TextStyle(color: context.colors.textMuted, fontSize: 12),
              ),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailsScreen(movie: Movie.fromMap(data)),
        ),
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
