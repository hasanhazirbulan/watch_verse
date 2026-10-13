import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/follow_list_screen.dart';
import 'package:watch_verse/screens/list_detail_screen.dart';
import 'package:watch_verse/services/list_service.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/detail_sections.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/social_widgets.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String name;
  const PublicProfileScreen(
      {super.key, required this.userId, required this.name});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _social = SocialService.instance;
  late final Future<List<MediaItem>> _favorites = _social
      .userFavoriteMovies(widget.userId)
      .then((list) => list.map(_movieItem).toList());
  late final Future<List<MediaItem>> _movies = _social
      .userWatchedMovies(widget.userId)
      .then((list) => list.map(_movieItem).toList());
  late final Future<List<MediaItem>> _shows = _social
      .userShows(widget.userId)
      .then((list) => list.map(_showItem).toList());
  late final Future<List<Map<String, dynamic>>> _publicLists =
      ListService.instance.publicListsFor(widget.userId);

  MediaItem _movieItem(Map<String, dynamic> d) => MediaItem(
        id: (d['id'] ?? 0) as int,
        title: (d['title'] ?? '') as String,
        overview: '',
        posterPath: (d['posterPath'] ?? '') as String,
        backdropPath: (d['backdropPath'] ?? '') as String,
        date: (d['releaseDate'] ?? '') as String,
        voteAverage: ((d['voteAverage'] ?? 0) as num).toDouble(),
        mediaType: MediaType.movie,
      );

  MediaItem _showItem(Map<String, dynamic> d) => MediaItem(
        id: (d['id'] ?? 0) as int,
        title: (d['name'] ?? '') as String,
        overview: '',
        posterPath: (d['posterPath'] ?? '') as String,
        backdropPath: (d['backdropPath'] ?? '') as String,
        date: (d['firstAirDate'] ?? '') as String,
        voteAverage: ((d['voteAverage'] ?? 0) as num).toDouble(),
        mediaType: MediaType.tv,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 8),
            _rail(l10n.pubProfileFavoriteFilms, _favorites),
            _addableMoviesRail(l10n.pubProfileWatchedMovies, _movies),
            _rail(l10n.pubProfileShows, _shows),
            _listsSection(l10n),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _social.userStream(widget.userId),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final data = snap.data;
        final name = (data?['name'] ?? widget.name) as String;
        final photo = data?['photoURL'] as String?;
        final followers =
            (data?['followers'] as List?)?.cast<String>() ?? const <String>[];
        final following =
            (data?['following'] as List?)?.cast<String>() ?? const <String>[];
        return Column(
          children: [
            // Gradient hero banner with avatar + name.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              decoration: BoxDecoration(gradient: context.colors.brandGradient),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white),
                    child: UserAvatar(
                        photoURL: photo, name: name, radius: 42),
                  ),
                  const SizedBox(height: 12),
                  Text(name.isEmpty ? l10n.pubProfileDefaultUserName : name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: Colors.black26, blurRadius: 6)
                          ])),
                  const SizedBox(height: 3),
                  Text(l10n.pubProfileMemberLabel,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _statFuture(l10n.pubProfileFilms, _movies),
                  _statDivider(),
                  _statFuture(l10n.pubProfileShows, _shows),
                  _statDivider(),
                  _stat(
                      '${followers.length}',
                      l10n.pubProfileFollowers,
                      followers.isEmpty
                          ? null
                          : () => _openFollowList(
                              l10n.pubProfileFollowers, followers)),
                  _statDivider(),
                  _stat(
                      '${following.length}',
                      l10n.pubProfileFollowing,
                      following.isEmpty
                          ? null
                          : () => _openFollowList(
                              l10n.pubProfileFollowing, following)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(child: FollowButton(targetUid: widget.userId)),
          ],
        );
      },
    );
  }

  Widget _statFuture(String label, Future<List<MediaItem>> future) {
    return Expanded(
      child: FutureBuilder<List<MediaItem>>(
        future: future,
        builder: (context, snap) =>
            _statColumn('${snap.data?.length ?? 0}', label, null),
      ),
    );
  }

  Widget _stat(String value, String label, VoidCallback? onTap) {
    return Expanded(child: _statColumn(value, label, onTap));
  }

  Widget _statColumn(String value, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(color: context.colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 28, color: Colors.white12);

  void _openFollowList(String title, List<String> uids) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => FollowListScreen(title: title, userIds: uids)),
    );
  }

  Widget _rail(String title, Future<List<MediaItem>> future) {
    return FutureBuilder<List<MediaItem>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: MediaRail(title: title, items: snap.data!),
        );
      },
    );
  }

  // This user's public lists — private ones never show up here (see the
  // `public`-gated Firestore read rule in ListService.publicListsFor).
  Widget _listsSection(AppLocalizations l10n) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _publicLists,
      builder: (context, snap) {
        final lists = snap.data ?? const <Map<String, dynamic>>[];
        if (lists.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pubProfileLists,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (final list in lists) _listTile(list),
            ],
          ),
        );
      },
    );
  }

  Widget _listTile(Map<String, dynamic> list) {
    final l10n = AppLocalizations.of(context)!;
    final name = (list['name'] ?? l10n.listsUntitled) as String;
    final cover = ListService.itemsFrom(list);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListDetailScreen(
            listId: list['id'] as String,
            name: name,
            ownerUid: widget.userId,
            ownerName: widget.name,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
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
                  width: 40,
                  height: 56,
                  child: cover.isEmpty
                      ? Container(
                          color: context.colors.surfaceAlt,
                          child: Icon(Icons.playlist_play_rounded,
                              color: context.colors.textMuted))
                      : TmdbImage(
                          url: Tmdb.poster(cover.first.posterPath,
                              size: 'w185')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // Like [_rail] but each poster carries a quick "+ add to my list" button so
  // you can grab a friend's picks without opening every title.
  Widget _addableMoviesRail(String title, Future<List<MediaItem>> future) {
    return FutureBuilder<List<MediaItem>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        final items = snap.data!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                // 170 poster + 6 gap, plus room for the title/year lines that
                // grows with the text scale (fixed 214 overflowed with large
                // accessibility text).
                height: 176 + MediaQuery.textScalerOf(context).scale(38),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _AddablePoster(item: items[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A friend's movie poster with a one-tap "add to my watchlist" affordance.
class _AddablePoster extends StatefulWidget {
  final MediaItem item;
  const _AddablePoster({required this.item});

  @override
  State<_AddablePoster> createState() => _AddablePosterState();
}

class _AddablePosterState extends State<_AddablePoster> {
  bool _added = false;
  bool _busy = false;

  Future<void> _add() async {
    if (_added || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await MovieService.instance
          .setStatus(widget.item.toMovie(), 'watchlist');
      if (!mounted) return;
      setState(() {
        _added = true;
        _busy = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.pubProfileAddedToList)),
      );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTap: () => openMedia(context, item),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  SizedBox(
                    width: 120,
                    height: 170,
                    child: TmdbImage(url: Tmdb.poster(item.posterPath)),
                  ),
                  // Hidden for guests: MovieService.setStatus silently no-ops
                  // without a signed-in user, so a guest used to get the
                  // "added" check + snackbar for a write that never happened.
                  if (FirebaseAuth.instance.currentUser != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: _add,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: _added
                                ? context.colors.success
                                : Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _added ? Icons.check_rounded : Icons.add_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            if (item.year.isNotEmpty)
              Text(item.year,
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
