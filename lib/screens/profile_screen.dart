import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/follow_list_screen.dart';
import 'package:watch_verse/screens/up_next_screen.dart';
import 'package:watch_verse/screens/watch_stats_screen.dart';
import 'package:watch_verse/screens/watched_movies_screen.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/theme/avatar_backgrounds.dart';
import 'package:watch_verse/utils/duration_format.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    _backfillTimeStatsOnce();
  }

  /// Movies/episodes watched before the time-spent stat (or its genre data)
  /// existed have no `runtime`/`watchedMinutes`/`genres` recorded. Runs the
  /// backfill once per account (flagged on the user doc) so those older
  /// watches count too, without re-fetching from TMDB on every profile
  /// visit. Bumped to V2 to re-run once for accounts that already completed
  /// the runtime-only V1 backfill, so genres get filled in too.
  Future<void> _backfillTimeStatsOnce() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await userRef.get();
    if (snap.data()?['timeStatsBackfilledV2'] == true) return;
    await Future.wait([
      MovieService.instance.backfillDetails(),
      TvTrackingService.instance.backfillAllShowDetails(),
    ]);
    await userRef.set({'timeStatsBackfilledV2': true}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text(l10n.profileSignInPrompt)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        child: Column(
          children: [
            // Kept deliberately tight: the header is not the content, and
            // every pixel it gives back is another row of posters above the
            // fold. Live-streamed (not a one-time fetch) because this tab
            // stays mounted in the bottom nav's IndexedStack — edits made on
            // EditProfileScreen (name/photo/background/character quote)
            // wouldn't otherwise show up here until the app restarted.
            _header(user, l10n),
            const SizedBox(height: 12),
            _followCounts(),
            const SizedBox(height: 16),
            _favoritesShowcase(),
            const SizedBox(height: 16),
            _statsRail(),
            const SizedBox(height: 16),
            _recentTrays(),
          ],
        ),
      ),
    );
  }


  Widget _header(User user, AppLocalizations l10n) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final displayName = (data?['name'] ?? '') as String;
        final photoURL = (data?['photoURL'] ?? '') as String;
        final characterQuote = (data?['characterQuote'] ?? '') as String;
        final avatarBg = ((data?['avatarBg'] ?? 0) as num).toInt();
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: avatarBackgroundFor(avatarBg),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: context.colors.surfaceAlt,
                backgroundImage:
                    photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                child: photoURL.isEmpty
                    ? Text(
                        (user.email ?? '?').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              displayName.isEmpty ? l10n.profileAddYourName : displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (characterQuote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                characterQuote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _followCounts() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: SocialService.instance.myStream(),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final followers =
            (snap.data?['followers'] as List?)?.cast<String>() ?? const [];
        final following =
            (snap.data?['following'] as List?)?.cast<String>() ?? const [];
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _countButton(l10n.profileFollowers, followers),
            Container(
                width: 1,
                height: 28,
                color: Colors.white12,
                margin: const EdgeInsets.symmetric(horizontal: 24)),
            _countButton(l10n.profileFollowing, following),
          ],
        );
      },
    );
  }

  Widget _countButton(String label, List<String> uids) {
    return GestureDetector(
      onTap: uids.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        FollowListScreen(title: label, userIds: uids)),
              ),
      child: Column(
        children: [
          Text('${uids.length}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  TextStyle(color: context.colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  // Films watched + episodes watched + movie/show time-spent, as one
  // horizontally scrollable rail instead of a fixed row — keeps the "watched
  // shows" count off the profile entirely (redundant with episodes/films)
  // and stops every stat from fighting for space on one line. Movie minutes
  // come from the per-watched-movie `runtime` field (resolved lazily the
  // first time each movie is logged, see MovieService/_openLogSheet); show
  // minutes come from the denormalized `watchedMinutes` counter
  // TvTrackingService maintains alongside `watchedCount`. Both are
  // best-effort: episodes/movies logged before this field existed, or
  // missing runtime data from TMDB, simply don't contribute. The two
  // time tiles open WatchStatsScreen (genre/type breakdown + charts) —
  // they're the "headline number", the stats screen is the drill-down.
  Widget _statsRail() {
    final l10n = AppLocalizations.of(context)!;
    void openStats() => Navigator.push(
        context, MaterialPageRoute(builder: (_) => const WatchStatsScreen()));
    return SizedBox(
      height: 116,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(
            width: 108,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: MovieService.instance.watchedStream(),
              builder: (context, snap) => _statTile(
                  Icons.movie_rounded, '${(snap.data ?? const []).length}',
                  l10n.profileFilms),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 108,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: TvTrackingService.instance.trackedShowsStream(),
              builder: (context, snap) {
                final eps = (snap.data ?? const []).fold<int>(
                    0, (acc, s) => acc + ((s['watchedCount'] ?? 0) as int));
                return _statTile(
                    Icons.check_circle_rounded, '$eps', l10n.profileEpisodes);
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 108,
            child: GestureDetector(
              onTap: openStats,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: MovieService.instance.watchedStream(),
                builder: (context, snap) {
                  final minutes = (snap.data ?? const []).fold<int>(0,
                      (acc, m) => acc + ((m['runtime'] ?? 0) as num).toInt());
                  return _statTile(
                      Icons.movie_filter_rounded,
                      formatWatchDuration(context, minutes),
                      l10n.profileMovieTimeSpent);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 108,
            child: GestureDetector(
              onTap: openStats,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: TvTrackingService.instance.trackedShowsStream(),
                builder: (context, snap) {
                  final minutes = (snap.data ?? const []).fold<int>(
                      0,
                      (acc, s) =>
                          acc + ((s['watchedMinutes'] ?? 0) as num).toInt());
                  return _statTile(Icons.timer_rounded,
                      formatWatchDuration(context, minutes),
                      l10n.profileShowTimeSpent);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.colors.primary, size: 20),
          const SizedBox(height: 5),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: context.colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  // Letterboxd-style "vitrine": exactly 3 favorite-film slots, always shown
  // near the top of the profile (right under the follow counts) so it's the
  // first thing a visitor's eye lands on. Which favorites fill the 3 slots
  // is chosen by the user (tap an empty slot to pick, long-press a filled
  // one to remove) rather than auto-filled by favoriting order.
  Widget _favoritesShowcase() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MovieService.instance.showcaseStream(),
      builder: (context, snap) {
        final items = snap.data ?? const <Map<String, dynamic>>[];
        final bySlot = List<Map<String, dynamic>?>.filled(
            MovieService.showcaseSlots, null);
        for (final m in items) {
          final slot = (m['showcaseSlot'] as num?)?.toInt();
          if (slot != null && slot >= 0 && slot < bySlot.length) {
            bySlot[slot] = m;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
                title: AppLocalizations.of(context)!.profileFavoritesTitle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(bySlot.length, (i) {
                  final isLast = i == bySlot.length - 1;
                  final movie = bySlot[i];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: isLast ? 0 : 10),
                      child: movie != null
                          ? _favSlot(movie, i)
                          : _emptyFavSlot(i),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _favSlot(Map<String, dynamic> m, int slot) {
    final id = (m['id'] ?? 0) as int;
    return GestureDetector(
      onTap: () => openMedia(
        context,
        MediaItem(
          id: id,
          title: (m['title'] ?? '') as String,
          overview: '',
          posterPath: (m['posterPath'] ?? '') as String,
          backdropPath: (m['backdropPath'] ?? '') as String,
          date: (m['releaseDate'] ?? '') as String,
          voteAverage: ((m['voteAverage'] ?? 0) as num).toDouble(),
          mediaType: MediaType.movie,
        ),
      ),
      onLongPress: () => _confirmRemoveFromShowcase(id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 96 / 130,
              child: TmdbImage(
                url: Tmdb.poster((m['posterPath'] ?? '') as String,
                    size: 'w185'),
                placeholderIcon: Icons.movie_rounded,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text((m['title'] ?? '') as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _emptyFavSlot(int slot) {
    return GestureDetector(
      onTap: () => _showShowcasePicker(slot),
      child: AspectRatio(
        aspectRatio: 96 / 130,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
                color: context.colors.textMuted.withValues(alpha: 0.4),
                width: 1.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border_rounded,
                    color: context.colors.textMuted, size: 22),
                const SizedBox(height: 6),
                Text('${slot + 1}',
                    style: TextStyle(
                        color: context.colors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemoveFromShowcase(int movieId) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.close_rounded),
          title: Text(l10n.profileShowcaseRemove),
          onTap: () {
            Navigator.pop(ctx);
            MovieService.instance.setShowcaseSlot(movieId, null);
          },
        ),
      ),
    );
  }

  // Picker for an empty showcase slot: lets the user choose from their
  // favorited-but-not-yet-showcased films.
  void _showShowcasePicker(int slot) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
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
                const SizedBox(height: 16),
                Text(l10n.profileShowcasePickerTitle,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Flexible(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: MovieService.instance.favoritesStream(),
                    builder: (context, snap) {
                      final pickable = (snap.data ?? const [])
                          .where((m) => m['showcaseSlot'] == null)
                          .toList();
                      if (pickable.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(l10n.profileFavoritesEmptyHint,
                              style:
                                  TextStyle(color: context.colors.textMuted)),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: pickable.length,
                        itemBuilder: (context, i) {
                          final m = pickable[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 40,
                                height: 56,
                                child: TmdbImage(
                                  url: Tmdb.poster(
                                      (m['posterPath'] ?? '') as String,
                                      size: 'w185'),
                                  placeholderIcon: Icons.movie_rounded,
                                ),
                              ),
                            ),
                            title: Text((m['title'] ?? '') as String,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              Navigator.pop(ctx);
                              MovieService.instance.setShowcaseSlot(
                                  (m['id'] as num).toInt(), slot);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TV Time-style recent watches, split into two glanceable poster trays:
  // "Movies" and "Series" (shows are de-duplicated to the latest episode each).
  Widget _recentTrays() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: TvTrackingService.instance.activityStream(limit: 60),
      builder: (context, snap) {
        final items = snap.data ?? const <Map<String, dynamic>>[];
        final movies =
            items.where((a) => a['kind'] == 'movie').toList();
        final series = <Map<String, dynamic>>[];
        final seenShows = <int>{};
        for (final a in items) {
          if (a['kind'] == 'episode' || a['kind'] == 'season') {
            if (seenShows.add((a['showId'] ?? 0) as int)) series.add(a);
          }
        }
        if (movies.isEmpty && series.isEmpty) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (movies.isNotEmpty)
              _recentTray(
                l10n.profileMoviesTitle,
                movies,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WatchedMoviesScreen())),
              ),
            if (series.isNotEmpty)
              _recentTray(
                l10n.profileSeriesTitle,
                series,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UpNextScreen(initialTab: 1))),
              ),
          ],
        );
      },
    );
  }

  Widget _recentTray(
      String title, List<Map<String, dynamic>> items, VoidCallback onSeeAll) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          trailing: GestureDetector(
            onTap: onSeeAll,
            child: Text(l10n.profileSeeAll,
                style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ),
        GridView.count(
          crossAxisCount: _gridColumns,
          shrinkWrap: true,
          // The page already scrolls; let the grid size itself to its content.
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          // Real poster art is 2:3 — the old 96x120 tile cropped every one.
          childAspectRatio: 2 / 3,
          children: [
            for (final item in items.take(_gridColumns * _gridRows))
              _recentPoster(item),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// A profile is a showcase, not a browser: a Letterboxd-style grid shows the
  /// whole recent run at a glance where a horizontal rail hid all but the
  /// first three behind a swipe nobody makes. Titles are dropped because the
  /// poster is already the identifier — that is what buys the density — so the
  /// name moves to a [Semantics] label to keep screen readers working.
  static const _gridColumns = 4;
  static const _gridRows = 2;

  Widget _recentPoster(Map<String, dynamic> a) {
    final l10n = AppLocalizations.of(context)!;
    final kind = a['kind'] as String?;
    final isMovie = kind == 'movie';
    final title = ((isMovie ? a['title'] : a['showName']) ?? '') as String;
    final sub = isMovie
        ? l10n.profileMovieLabel
        : kind == 'season'
            ? l10n.profileSeasonLabel('${a['season'] ?? ''}')
            : l10n.profileEpisodeLabel('${a['season'] ?? ''}', '${a['episode'] ?? ''}');
    return Semantics(
      label: '$title, $sub',
      button: true,
      child: GestureDetector(
        onTap: () => _openActivity(a),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: TmdbImage(
            url: Tmdb.poster((a['posterPath'] ?? '') as String, size: 'w185'),
            placeholderIcon: isMovie ? Icons.movie_rounded : Icons.tv_rounded,
          ),
        ),
      ),
    );
  }

  void _openActivity(Map<String, dynamic> a) {
    final isMovie = a['kind'] == 'movie';
    final item = MediaItem(
      id: ((isMovie ? a['movieId'] : a['showId']) ?? 0) as int,
      title: ((isMovie ? a['title'] : a['showName']) ?? '') as String,
      overview: '',
      posterPath: (a['posterPath'] ?? '') as String,
      backdropPath: '',
      date: '',
      voteAverage: 0,
      mediaType: isMovie ? MediaType.movie : MediaType.tv,
    );
    openMedia(context, item);
  }
}
