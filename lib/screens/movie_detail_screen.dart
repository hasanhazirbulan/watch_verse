import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/poll_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/add_to_list_sheet.dart';
import 'package:watch_verse/widgets/comment_widgets.dart';
import 'package:watch_verse/widgets/detail_sections.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/poll_widgets.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;
  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final APIservices _api = APIservices();
  final MovieService _movies = MovieService.instance;

  late final Future<List<CastMember>> _cast;
  late final Future<List<MediaItem>> _recs;
  late final Future<List<WatchProvider>> _providers;
  late final Future<List<String>> _genres;

  // Starts as the seed the caller passed in, then gets its blank fields
  // filled from the user's stored movie doc (see [movieWithStoredMeta]).
  late Movie _movie = widget.movie;
  Movie get movie => _movie;

  /// [movie] with blank metadata backfilled from the live stored doc [data] —
  /// every write below goes through this so a sparse seed can never blank out
  /// what's already saved.
  Movie _withStored(Map<String, dynamic>? data) =>
      movieWithStoredMeta(movie, data);

  MediaItem _asMediaItem() => MediaItem(
        id: movie.id,
        title: movie.title,
        overview: movie.overview,
        posterPath: movie.posterPath,
        backdropPath: movie.backDropPath,
        date: movie.releaseDate,
        voteAverage: movie.voteAverage,
        mediaType: MediaType.movie,
      );

  @override
  void initState() {
    super.initState();
    final id = movie.id;
    // History, friends' activity and the watched-movies grid open this
    // screen with a sparse seed (no overview/backdrop/release date/score).
    // Fill those from the user's stored doc so the header isn't blank.
    _movies.movieStream(id).first.then((data) {
      if (!mounted || data == null) return;
      setState(() => _movie = movieWithStoredMeta(_movie, data));
    }).catchError((Object _) {});
    _cast =
        _api.getCredits(MediaType.movie, id).catchError((_) => <CastMember>[]);
    _recs = _api
        .getRecommendations(MediaType.movie, id)
        .catchError((_) => <MediaItem>[]);
    final region =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? 'US';
    _providers = _api
        .getWatchProviders(MediaType.movie, id, region)
        .catchError((_) => <WatchProvider>[]);
    // Genre tag row under the title: MediaItem.toMovie() never carries
    // genres (only the detail endpoint has them), so fetch it here rather
    // than waiting for the log-sheet's lazy backfill to happen to populate it.
    _genres = movie.genres.isNotEmpty
        ? Future.value(movie.genres)
        : _api
            .getMovieDetailExtras(id)
            .then((e) => e.genres)
            .catchError((_) => <String>[]);
  }

  /// Opens the log sheet. When [rewatch] is true the fields start empty so the
  /// user can record a fresh watch on a chosen date (adds a new diary entry).
  /// The first time a movie is logged as watched, follows up with the
  /// "how was it?" poll.
  Future<void> _openLogSheet(BuildContext context, Map<String, dynamic>? data,
      {bool rewatch = false}) async {
    final wasWatched = data?['status'] == 'watched';
    final saved = await showMovieLogSheet(
      context,
      _withStored(data),
      rewatch: rewatch,
      initialRating: rewatch ? 0 : ((data?['rating'] ?? 0) as num).toDouble(),
      initialNote: rewatch ? '' : (data?['note'] ?? '') as String,
    );
    if (saved == true && !wasWatched && context.mounted) {
      _showPoll(context);
    }
  }

  void _showPoll(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: FutureBuilder<List<CastMember>>(
            future: _cast,
            builder: (context, snap) => FutureBuilder<List<WatchProvider>>(
              future: _providers,
              builder: (context, provSnap) => PollCard(
                pollId: PollService.instance.moviePollId(movie.id),
                cast: snap.data ?? const [],
                providers: provSnap.data ?? const [],
                isMovie: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final year =
        movie.releaseDate.length >= 4 ? movie.releaseDate.substring(0, 4) : '';
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
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
                    tooltip: l10n.movieAddToList,
                    onPressed: () => showAddToListSheet(context, _asMediaItem()),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  TmdbImage(
                      url: Tmdb.backdrop(movie.backDropPath, size: 'w1280')),
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
                            child:
                                TmdbImage(url: Tmdb.poster(movie.posterPath)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(movie.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 8)
                                    ],
                                  )),
                              const SizedBox(height: 6),
                              RatingBadge(rating: movie.voteAverage),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (year.isNotEmpty) _pill(context, year),
                    _pill(context, l10n.movieTypeLabel, accent: true),
                    FutureBuilder<List<String>>(
                      future: _genres,
                      builder: (context, snap) {
                        final genres = snap.data ?? const <String>[];
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final g in genres) _pill(context, g),
                          ],
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _libraryControls(),
                  if (!movie.hasReleased) _unreleasedNotice(context, l10n),
                  const SizedBox(height: 18),
                  _ratingSection(),
                  TrailerButton(type: MediaType.movie, id: movie.id),
                  if (movie.overview.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(l10n.movieOverview,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(movie.overview,
                        style: TextStyle(
                            color: context.colors.textSecondary, height: 1.45)),
                  ],
                  FutureBuilder<List<WatchProvider>>(
                    future: _providers,
                    builder: (context, snap) {
                      final provs = snap.data ?? const <WatchProvider>[];
                      if (provs.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: WatchProvidersSection(providers: provs),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<List<CastMember>>(
                    future: _cast,
                    builder: (context, snap) =>
                        CastStrip(cast: snap.data ?? const []),
                  ),
                  const SizedBox(height: 22),
                  _diarySection(),
                  const SizedBox(height: 22),
                  _pollSection(),
                  const SizedBox(height: 26),
                  FutureBuilder<List<MediaItem>>(
                    future: _recs,
                    builder: (context, snap) => MediaRail(
                        title: l10n.movieMoreLikeThis,
                        items: snap.data ?? const []),
                  ),
                  const SizedBox(height: 20),
                  CommentsButton(
                    mediaType: MediaType.movie,
                    mediaId: movie.id,
                    title: movie.title,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Status (To Watch / Watched) + favorite, all driven by the live movie doc.
  Widget _libraryControls() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _movies.movieStream(movie.id),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final data = snap.data;
        final status = data?['status'] as String?;
        final favorite = data?['favorite'] == true;
        // Already-watched movies stay toggleable (so a mistaken mark can
        // still be undone) even if the release date somehow looks future.
        final canMarkWatched = status == 'watched' || movie.hasReleased;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _statusPill(
                    context: context,
                    label: l10n.movieToWatch,
                    icon: Icons.bookmark_add_rounded,
                    selected: status == 'watchlist',
                    onTap: () => status == 'watchlist'
                        ? _movies.remove(movie.id)
                        : _movies.setStatus(_withStored(data), 'watchlist'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statusPill(
                    context: context,
                    // No label at all until it's actually marked — any text
                    // here ("Watched", "Mark watched", ...) kept reading as
                    // a status claim to first-time users. A bare checkbox
                    // can't be misread; the word only appears once it's true.
                    label: status == 'watched' ? l10n.movieWatched : null,
                    icon: status == 'watched'
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    selected: status == 'watched',
                    dimmed: !canMarkWatched,
                    // Tap toggles: log it when new, remove it when already
                    // watched — so the same button clears it, no extra link.
                    // Unreleased movies can't be logged watched (rating/
                    // comments stay available via _ratingSection + comments).
                    onTap: () {
                      if (!canMarkWatched) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text(l10n.movieCannotMarkUnreleased)));
                        return;
                      }
                      status == 'watched'
                          ? _movies.remove(movie.id)
                          : _openLogSheet(context, data);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _favPill(context, favorite,
                    () => _toggleFavorite(_withStored(data), favorite)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _unreleasedNotice(BuildContext context, AppLocalizations l10n) {
    final date = movie.releaseDate;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.event_rounded, size: 14, color: context.colors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              date.isNotEmpty
                  ? l10n.movieReleasesOn(date)
                  : l10n.movieNotYetReleased,
              style: TextStyle(color: context.colors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Standalone star rating, independent of watched-status (mirrors the TV
  // detail screen's rating section) — so unreleased movies can still be
  // rated even though they can't be marked watched yet.
  Widget _ratingSection() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _movies.movieStream(movie.id),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final current = ((snap.data?['rating'] ?? 0) as num).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.movieYourRating,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (current > 0)
                  Text(current.toStringAsFixed(1),
                      style: TextStyle(
                          color: context.colors.accent,
                          fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
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
                onRatingUpdate: (rating) =>
                    _movies.setRating(_withStored(snap.data), rating),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleFavorite(Movie m, bool currentlyFavorite) async {
    await _movies.setFavorite(m, !currentlyFavorite);
  }

  Widget _statusPill({
    required BuildContext context,
    String? label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool dimmed = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? context.colors.brandGradient : null,
            color: selected ? null : context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color:
                      selected ? Colors.white : context.colors.textSecondary),
              if (label != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: selected
                            ? Colors.white
                            : context.colors.textSecondary,
                        fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _favPill(BuildContext context, bool favorite, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
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

  // Dated diary of watches + rewatches, with quick "Log again" + per-entry
  // delete. Mirrors TV Time's "logs" but stays private to the user.
  Widget _diarySection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _movies.diaryStream(movie.id),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final entries = snap.data ?? const <Map<String, dynamic>>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.movieYourDiary,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      _openLogSheet(context, null, rewatch: entries.isNotEmpty),
                  child: Row(
                    children: [
                      Icon(
                          entries.isEmpty
                              ? Icons.add_rounded
                              : Icons.replay_rounded,
                          size: 16,
                          color: context.colors.primary),
                      const SizedBox(width: 4),
                      Text(entries.isEmpty
                              ? l10n.movieLogAction
                              : l10n.movieLogAgainAction,
                          style: TextStyle(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (entries.isEmpty)
              Text(
                l10n.movieDiaryEmpty,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13, height: 1.4),
              )
            else
              ...entries.map((e) => _diaryTile(context, e)),
          ],
        );
      },
    );
  }

  // "How was it?" poll — visible once the movie has been logged as watched,
  // so users can answer/revisit it without waiting for the auto-popup.
  Widget _pollSection() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _movies.movieStream(movie.id),
      builder: (context, snap) {
        if (snap.data?['status'] != 'watched') return const SizedBox.shrink();
        return FutureBuilder<List<CastMember>>(
          future: _cast,
          builder: (context, castSnap) => FutureBuilder<List<WatchProvider>>(
            future: _providers,
            builder: (context, provSnap) => PollCard(
              pollId: PollService.instance.moviePollId(movie.id),
              cast: castSnap.data ?? const [],
              providers: provSnap.data ?? const [],
              isMovie: true,
            ),
          ),
        );
      },
    );
  }

  Widget _diaryTile(BuildContext context, Map<String, dynamic> e) {
    final rating = ((e['rating'] ?? 0) as num).toDouble();
    final note = (e['note'] ?? '') as String;
    final when = e['watchedOn'];
    final date = when is Timestamp
        ? MaterialLocalizations.of(context).formatShortDate(when.toDate())
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_rounded,
                  size: 16, color: context.colors.textMuted),
              const SizedBox(width: 6),
              Text(date,
                  style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (rating > 0) ...[
                Icon(Icons.star_rounded,
                    size: 15, color: context.colors.accent),
                const SizedBox(width: 2),
                Text(rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => _movies.deleteDiaryEntry(e['entryId'] as String),
                child: Icon(Icons.delete_outline_rounded,
                    size: 18, color: context.colors.textMuted),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note,
                style: TextStyle(
                    color: context.colors.textSecondary, height: 1.4, fontSize: 13)),
          ],
        ],
      ),
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
      child: Text(text,
          style: TextStyle(
              color: accent ? context.colors.primary : context.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

/// Returns [m] with any blank metadata (overview, backdrop, release date,
/// score, runtime, genres…) filled in from [stored], the user's own movie doc
/// as streamed by [MovieService.movieStream]. Several entry points (history,
/// friends' activity, watched-movies grid, friend posters) only know a
/// title + poster, and every [MovieService] write merges the movie's full
/// metadata into that doc — so writing the sparse seed as-is would blank out
/// the stored overview/release date/backdrop the first time the user rated
/// or re-statused the movie from one of those screens.
Movie movieWithStoredMeta(Movie m, Map<String, dynamic>? stored) {
  if (stored == null) return m;
  final s = Movie.fromMap(stored);
  return Movie(
    id: m.id,
    title: m.title.isNotEmpty ? m.title : s.title,
    overview: m.overview.isNotEmpty ? m.overview : s.overview,
    posterPath: m.posterPath.isNotEmpty ? m.posterPath : s.posterPath,
    backDropPath: m.backDropPath.isNotEmpty ? m.backDropPath : s.backDropPath,
    releaseDate: m.releaseDate.isNotEmpty ? m.releaseDate : s.releaseDate,
    voteAverage: m.voteAverage > 0 ? m.voteAverage : s.voteAverage,
    runtime: m.runtime > 0 ? m.runtime : s.runtime,
    genres: m.genres.isNotEmpty ? m.genres : s.genres,
  );
}

/// Diary bottom sheet — owns its own controller (disposed here, not by the
/// caller) and scrolls so the keyboard never overflows it. Includes a watch
/// date so users can back-date logs and record rewatches.
/// Opens the "review or log" diary sheet for [movie] and, on save, marks it
/// watched with the given rating/note/date (resolving runtime lazily first
/// so the profile's time-spent stat stays accurate). Shared between this
/// screen's own diary section and the poster long-press quick-add sheet, so
/// both offer the exact same review flow. Callers are responsible for
/// checking [Movie.hasReleased] before invoking this — it always logs a
/// watch unconditionally once opened.
Future<bool?> showMovieLogSheet(BuildContext context, Movie movie,
    {bool rewatch = false, double initialRating = 0, String initialNote = ''}) {
  final api = APIservices();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _DiarySheet(
      movieTitle: movie.title,
      rewatch: rewatch,
      initialRating: initialRating,
      initialNote: initialNote,
      onSave: (rating, note, date) async {
        var withDetails = movie;
        if (movie.runtime <= 0 || movie.genres.isEmpty) {
          final extras = await api
              .getMovieDetailExtras(movie.id)
              .catchError((_) => (runtime: 0, genres: <String>[]));
          withDetails = movie.withDetails(
              runtime: extras.runtime, genres: extras.genres);
        }
        await MovieService.instance.logWatch(withDetails,
            rating: rating, note: note, watchedOn: date);
        // The poll's star row is a read-only mirror of this score, so the
        // user never gets asked to rate the same film a second time.
        await PollService.instance
            .syncRating(PollService.instance.moviePollId(movie.id), rating);
      },
    ),
  );
}

class _DiarySheet extends StatefulWidget {
  final String movieTitle;
  final bool rewatch;
  final double initialRating;
  final String initialNote;
  final Future<void> Function(double rating, String note, DateTime date) onSave;

  const _DiarySheet({
    required this.movieTitle,
    required this.rewatch,
    required this.initialRating,
    required this.initialNote,
    required this.onSave,
  });

  @override
  State<_DiarySheet> createState() => _DiarySheetState();
}

class _DiarySheetState extends State<_DiarySheet> {
  late double _rating = widget.initialRating;
  DateTime _date = DateTime.now();
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.initialNote);
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      await widget.onSave(_rating, _noteCtrl.text.trim(), _date);
      nav.pop(true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLabel = MaterialLocalizations.of(context).formatShortDate(_date);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.textMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(
                      widget.rewatch
                          ? Icons.replay_rounded
                          : Icons.check_circle_rounded,
                      color: context.colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        l10n.movieLogSheetTitle(
                            widget.rewatch
                                ? l10n.movieRewatchAction
                                : l10n.movieLogAction,
                            widget.movieTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(l10n.movieWatchedOn,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 16, color: context.colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Icon(Icons.edit_rounded,
                          size: 15, color: context.colors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(l10n.movieYourRating,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              RatingBar.builder(
                initialRating: _rating,
                minRating: 0,
                allowHalfRating: true,
                itemCount: 5,
                glowColor: context.colors.accent,
                itemBuilder: (context, _) =>
                    Icon(Icons.star_rounded, color: context.colors.accent),
                onRatingUpdate: (r) => _rating = r,
              ),
              const SizedBox(height: 18),
              Text(l10n.movieDiaryNote,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(hintText: l10n.movieDiaryNoteHint),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(widget.rewatch
                      ? l10n.movieSaveRewatch
                      : l10n.movieSaveToDiary),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
