import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart';
import 'package:watch_verse/screens/tv_detail_screen.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/social_widgets.dart';

class FriendsActivityScreen extends StatefulWidget {
  const FriendsActivityScreen({super.key});

  @override
  State<FriendsActivityScreen> createState() => _FriendsActivityScreenState();
}

class _FriendsActivityScreenState extends State<FriendsActivityScreen> {
  final _social = SocialService.instance;
  String _key = '';
  Future<List<Map<String, dynamic>>>? _future;

  Future<List<Map<String, dynamic>>> _futureFor(List<String> ids) {
    final k = ids.join(',');
    if (_future == null || k != _key) {
      _key = k;
      _future = _social.friendsActivity(ids);
    }
    return _future!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsActivityTitle)),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _social.myStream(),
        builder: (context, meSnap) {
          // Without this, every open flashed "No friends yet" until the
          // profile doc arrived — even for accounts following people.
          if (meSnap.connectionState == ConnectionState.waiting &&
              !meSnap.hasData) {
            return asyncLoadingIndicator();
          }
          final following = (meSnap.data?['following'] as List?)
                  ?.cast<String>() ??
              const <String>[];
          if (following.isEmpty) {
            return _empty(context, l10n.friendsNoFriendsTitle,
                l10n.friendsNoFriendsSubtitle);
          }
          return FutureListView<Map<String, dynamic>>(
            future: _futureFor(following),
            emptyBuilder: (context) => _empty(
                context, l10n.friendsQuietTitle, l10n.friendsQuietSubtitle),
            builder: (context, items) => ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _tile(context, items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> a) {
    final l10n = AppLocalizations.of(context)!;
    final kind = a['kind'] as String?;
    final isMovie = kind == 'movie';
    final isSeason = kind == 'season';
    final actor = (a['actorName'] ?? l10n.friendsSomeoneFallback) as String;
    final season = (a['season'] ?? 0) as int;
    final action = isMovie
        ? l10n.friendsActionWatchedMovie((a['title'] ?? '') as String)
        : isSeason
            ? l10n.friendsActionFinishedSeason(
                season, (a['showName'] ?? '') as String)
            : l10n.friendsActionWatchedEpisode(season,
                (a['episode'] ?? 0) as int, (a['showName'] ?? '') as String);

    return GestureDetector(
      onTap: () => _open(a),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            UserAvatar(
                photoURL: a['actorPhoto'] as String?, name: actor, radius: 18),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 38,
                height: 57,
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
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                      height: 1.35),
                  children: [
                    TextSpan(
                        text: actor,
                        style: TextStyle(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w700)),
                    TextSpan(text: ' $action'),
                  ],
                ),
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

  void _open(Map<String, dynamic> a) {
    if (a['kind'] == 'movie') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailsScreen(
            movie: Movie(
              id: (a['movieId'] ?? 0) as int,
              title: (a['title'] ?? '') as String,
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TvDetailScreen(
            seed: MediaItem(
              id: (a['showId'] ?? 0) as int,
              title: (a['showName'] ?? '') as String,
              overview: '',
              posterPath: (a['posterPath'] ?? '') as String,
              backdropPath: '',
              date: '',
              voteAverage: 0,
              mediaType: MediaType.tv,
            ),
          ),
        ),
      );
    }
  }

  Widget _empty(BuildContext context, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_alt_outlined,
                size: 56, color: context.colors.textMuted),
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

  String _ago(AppLocalizations l10n, dynamic at) {
    if (at is! Timestamp) return '';
    final diff = DateTime.now().difference(at.toDate());
    if (diff.inMinutes < 1) return l10n.friendsAgoNow;
    if (diff.inMinutes < 60) return l10n.friendsAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.friendsAgoHours(diff.inHours);
    if (diff.inDays < 7) return l10n.friendsAgoDays(diff.inDays);
    return l10n.friendsAgoWeeks(diff.inDays ~/ 7);
  }
}
