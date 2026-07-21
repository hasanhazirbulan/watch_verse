import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/blocked_users_screen.dart';
import 'package:watch_verse/screens/follow_list_screen.dart';
import 'package:watch_verse/screens/friends_activity_screen.dart';
import 'package:watch_verse/screens/history_screen.dart';
import 'package:watch_verse/screens/settings_screen.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/notification_service.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/text_prompt.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = '';
  String _photoURL = '';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _displayName = (doc.data()?['name'] ?? '') as String;
        _photoURL = (doc.data()?['photoURL'] ?? '') as String;
      });
    } catch (_) {/* keep defaults */}
  }

  Future<void> _changePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _uploading = true);
      final ref =
          FirebaseStorage.instance.ref('profile_images/${user.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'photoURL': url}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _photoURL = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdatePhotoError(e.toString()))),
      );
    }
  }

  Future<void> _editName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final l10n = AppLocalizations.of(context)!;
    final newName = await promptForText(
      context,
      title: l10n.profileEditNameTitle,
      hint: l10n.profileYourNameHint,
      initial: _displayName,
      actionLabel: l10n.save,
    );
    if (newName == null || newName.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'name': newName}, SetOptions(merge: true));
    if (!mounted) return;
    setState(() => _displayName = newName);
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
            _avatar(user.email),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _displayName.isEmpty ? l10n.profileAddYourName : _displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _editName,
                  child: Icon(Icons.edit_rounded,
                      size: 18, color: context.colors.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(user.email ?? '',
                style: TextStyle(color: context.colors.textSecondary)),
            const SizedBox(height: 16),
            _followCounts(),
            const SizedBox(height: 20),
            _statsRow(),
            const SizedBox(height: 20),
            _thisYearCard(),
            const SizedBox(height: 20),
            _favoritesShowcase(),
            _recentTrays(),
            _tile(
              icon: Icons.people_alt_rounded,
              label: l10n.profileFriendsActivity,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FriendsActivityScreen())),
            ),
            const SizedBox(height: 12),
            _tile(
              icon: Icons.settings_rounded,
              label: l10n.profileSettings,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const SizedBox(height: 12),
            _tile(
              icon: Icons.block_rounded,
              label: l10n.profileBlockedUsers,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen())),
            ),
            const SizedBox(height: 12),
            _tile(
              icon: Icons.logout_rounded,
              label: l10n.profileSignOut,
              danger: true,
              onTap: () async {
                final nav = Navigator.of(context, rootNavigator: true);
                final messenger = ScaffoldMessenger.of(context);
                final uid = FirebaseAuth.instance.currentUser?.uid;
                try {
                  if (uid != null) {
                    await NotificationService.instance.clearToken(uid);
                  }
                  await FirebaseAuth.instance.signOut();
                  nav.pushNamedAndRemoveUntil('/login', (r) => false);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.profileSignOutFailed(e.toString()))),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String? email) {
    return GestureDetector(
      onTap: _uploading ? null : _changePhoto,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.colors.brandGradient,
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: context.colors.surfaceAlt,
              backgroundImage:
                  _photoURL.isNotEmpty ? NetworkImage(_photoURL) : null,
              child: _uploading
                  ? const CircularProgressIndicator()
                  : (_photoURL.isEmpty
                      ? Text(
                          (email ?? '?').substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.bold),
                        )
                      : null),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: context.colors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.background, width: 2.5),
            ),
            child: const Icon(Icons.camera_alt_rounded,
                size: 15, color: Colors.white),
          ),
        ],
      ),
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

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: MovieService.instance.watchedStream(),
            builder: (context, snap) => _statTile(
                Icons.movie_rounded, '${(snap.data ?? const []).length}',
                AppLocalizations.of(context)!.profileFilms),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: TvTrackingService.instance.trackedShowsStream(),
            builder: (context, snap) => _statTile(Icons.live_tv_rounded,
                '${(snap.data ?? const []).length}',
                AppLocalizations.of(context)!.profileShows),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: TvTrackingService.instance.trackedShowsStream(),
            builder: (context, snap) {
              final eps = (snap.data ?? const []).fold<int>(
                  0, (acc, s) => acc + ((s['watchedCount'] ?? 0) as int));
              return _statTile(Icons.check_circle_rounded, '$eps',
                  AppLocalizations.of(context)!.profileEpisodes);
            },
          ),
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: context.colors.primary, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(color: context.colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  // A bold "year in review" card summarizing this year's activity, derived
  // entirely from the activity timeline (runtimes are estimated: ~115m/film,
  // ~42m/episode) so it needs no extra data.
  Widget _thisYearCard() {
    final year = DateTime.now().year;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: TvTrackingService.instance.activityStream(limit: 500),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final items = snap.data ?? const <Map<String, dynamic>>[];
        int films = 0;
        int episodes = 0;
        for (final a in items) {
          final at = a['at'];
          if (at is! Timestamp || at.toDate().year != year) continue;
          switch (a['kind']) {
            case 'movie':
              films++;
              break;
            case 'episode':
              episodes++;
              break;
            case 'season':
              episodes += ((a['count'] ?? 0) as num).toInt();
              break;
          }
        }
        final hours = ((films * 115 + episodes * 42) / 60).round();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: context.colors.brandGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.profileYourYear(year.toString()),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _yearStat('$films', l10n.profileFilms),
                  _yearDivider(),
                  _yearStat('$episodes', l10n.profileEpisodes),
                  _yearDivider(),
                  _yearStat('~${hours}h', l10n.profileWatched),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _yearStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _yearDivider() => Container(
      width: 1, height: 34, color: Colors.white24);

  // Showcase of the user's favorite movies (their "pinned" picks).
  Widget _favoritesShowcase() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MovieService.instance.favoritesStream(),
      builder: (context, snap) {
        final items = snap.data ?? const <Map<String, dynamic>>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: AppLocalizations.of(context)!.profileFavoritesTitle),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _favPoster(items[i]),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _favPoster(Map<String, dynamic> m) {
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
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96,
                height: 120,
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
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
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
            if (movies.isNotEmpty) _recentTray(l10n.profileMoviesTitle, movies),
            if (series.isNotEmpty) _recentTray(l10n.profileSeriesTitle, series),
          ],
        );
      },
    );
  }

  Widget _recentTray(String title, List<Map<String, dynamic>> items) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          trailing: GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
            child: Text(l10n.profileSeeAll,
                style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _recentPoster(items[i]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

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
    return GestureDetector(
      onTap: () => _openActivity(a),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96,
                height: 120,
                child: TmdbImage(
                  url: Tmdb.poster((a['posterPath'] ?? '') as String,
                      size: 'w185'),
                  placeholderIcon:
                      isMovie ? Icons.movie_rounded : Icons.tv_rounded,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: context.colors.textMuted, fontSize: 11)),
          ],
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

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color =
        danger ? context.colors.primaryDark : context.colors.textPrimary;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: color),
        title: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: context.colors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
