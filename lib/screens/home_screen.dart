import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/blocked_users_screen.dart';
import 'package:watch_verse/screens/discover_screen.dart';
import 'package:watch_verse/screens/friends_activity_screen.dart';
import 'package:watch_verse/screens/history_screen.dart';
import 'package:watch_verse/screens/lists_screen.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/notification_service.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/friend_poster_card.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/quick_add_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final APIservices _api = APIservices();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _tab = 0; // 0 = Movies, 1 = TV Shows

  // Movie rails
  late Future<List<MediaItem>> _nowPlaying;
  late Future<List<MediaItem>> _trendingMovies;
  late Future<List<MediaItem>> _upcoming;
  late Future<List<MediaItem>> _popularMovies;
  late Future<List<MediaItem>> _topMovies;

  // TV rails
  late Future<List<MediaItem>> _trendingTv;
  late Future<List<MediaItem>> _popularTv;
  late Future<List<MediaItem>> _airingToday;
  late Future<List<MediaItem>> _onTheAir;
  late Future<List<MediaItem>> _topTv;

  // Null unless one of the current tab's fetches failed — drives the retry
  // banner (see _firstFailure).
  late Future<Object?> _movieFailure;
  late Future<Object?> _tvFailure;

  // Genre chips (fetched once; don't reset on pull-to-refresh)
  late final Future<List<Genre>> _movieGenres = _api.getGenres(MediaType.movie);
  late final Future<List<Genre>> _tvGenres = _api.getGenres(MediaType.tv);

  // "Because you watched X" — memoized per seed id so we don't refetch on
  // every stream tick.
  int? _becauseMovieId;
  Future<List<MediaItem>>? _becauseMovieRecs;
  int? _becauseTvId;
  Future<List<MediaItem>>? _becauseTvRecs;

  // "Your Friends Also Watched" — memoized per following-list snapshot, same
  // reasoning as the "because you watched" futures above.
  String? _friendsKey;
  Future<List<Map<String, dynamic>>>? _friendsMoviesFuture;
  Future<List<Map<String, dynamic>>>? _friendsShowsFuture;

  @override
  void initState() {
    super.initState();
    _initFutures();
  }

  void _initFutures() {
    _nowPlaying = _api.getNowPlayingMovies();
    _trendingMovies = _api.getTrendingMovies();
    _upcoming = _api.getUpcomingMovies();
    _popularMovies = _api.getPopularMovies();
    _topMovies = _api.getTopRatedMovies();

    _trendingTv = _api.getTrendingTv();
    _popularTv = _api.getPopularTv();
    _airingToday = _api.getAiringTodayTv();
    _onTheAir = _api.getOnTheAirTv();
    _topTv = _api.getTopRatedTv();

    _movieFailure = _firstFailure(
        [_nowPlaying, _trendingMovies, _upcoming, _popularMovies, _topMovies]);
    _tvFailure = _firstFailure(
        [_trendingTv, _popularTv, _airingToday, _onTheAir, _topTv]);
  }

  /// Resolves to the first error among [futures], or null if they all
  /// succeeded. Every rail on this screen renders `snapshot.data ?? []`, so a
  /// failed fetch is indistinguishable from an empty one and shows as a
  /// skeleton that never fills in. Watching the futures once, here, lets the
  /// screen show a single banner instead of an error box inside every rail.
  Future<Object?> _firstFailure(List<Future<List<MediaItem>>> futures) async {
    Object? failure;
    await Future.wait(futures.map((f) async {
      try {
        await f;
      } catch (e) {
        // Catching these is what lets the banner replace five dead rails, but
        // it also stops them reaching the console as unhandled errors — and a
        // missing API key then looks exactly like a flaky network. Log it so
        // the cause stays visible.
        debugPrint('WatchVerse: home fetch failed → $e');
        failure ??= e;
      }
    }));
    return failure;
  }

  Future<void> _refresh() async {
    setState(_initFutures);
    try {
      await Future.wait([
        _nowPlaying, _trendingMovies, _upcoming, _popularMovies, _topMovies,
        _trendingTv, _popularTv, _airingToday, _onTheAir, _topTv,
      ]);
    } catch (_) {
      // Individual rails surface their own errors; ignore here so the
      // refresh indicator always dismisses.
    }
  }

  Widget _buildDrawer() {
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      backgroundColor: context.colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
              decoration: BoxDecoration(gradient: context.colors.brandGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.homeAppTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _drawerItem(Icons.bookmarks_rounded, l10n.homeMyLists, () {
              _scaffoldKey.currentState?.closeDrawer();
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ListsScreen()));
            }),
            _drawerItem(Icons.people_alt_rounded, l10n.homeFriendsActivity,
                () {
              _scaffoldKey.currentState?.closeDrawer();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FriendsActivityScreen()));
            }),
            _drawerItem(Icons.history_rounded, l10n.homeWatchHistory, () {
              _scaffoldKey.currentState?.closeDrawer();
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()));
            }),
            _drawerItem(Icons.block_rounded, l10n.profileBlockedUsers, () {
              _scaffoldKey.currentState?.closeDrawer();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen()));
            }),
            _drawerItem(Icons.settings_rounded, l10n.homeSettingsLabel, () {
              _scaffoldKey.currentState?.closeDrawer();
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/settings');
            }),
            const Spacer(),
            const Divider(color: Colors.white12, height: 1),
            _drawerItem(Icons.logout_rounded, l10n.homeSignOut, () async {
              _scaffoldKey.currentState?.closeDrawer();
              final rootNav = Navigator.of(context, rootNavigator: true);
              final messenger = ScaffoldMessenger.of(context);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              try {
                if (uid != null) {
                  await NotificationService.instance.clearToken(uid);
                }
                await FirebaseAuth.instance.signOut();
                rootNav.pushNamedAndRemoveUntil('/login', (r) => false);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.profileSignOutFailed(e.toString()))),
                );
              }
            }, danger: true),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final color =
        danger ? context.colors.primaryDark : context.colors.textPrimary;
    return ListTile(
      leading: Icon(icon,
          color: danger ? context.colors.primaryDark : context.colors.primary),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.colors.primary,
          backgroundColor: context.colors.surfaceAlt,
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SegmentedTabs(
                    labels: [l10n.homeTabMovies, l10n.homeTabTvShows],
                    selected: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
              ),
              _genreChips(),
              _loadFailureBanner(),
              ..._tab == 0 ? _movieSlivers() : _tvSlivers(),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const Spacer(),
          ShaderMask(
            shaderCallback: (bounds) =>
                context.colors.brandGradient.createShader(bounds),
            child: Text(
              l10n.homeAppTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Spacer(),
          // Balances the leading menu button so the wordmark stays centered.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // One banner for the whole tab when its fetches failed, so a dead network
  // reads as an error with a way out instead of an app full of empty rails.
  Widget _loadFailureBanner() {
    return SliverToBoxAdapter(
      child: FutureBuilder<Object?>(
        future: _tab == 0 ? _movieFailure : _tvFailure,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done ||
              snap.data == null) {
            return const SizedBox.shrink();
          }
          final l10n = AppLocalizations.of(context)!;
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded,
                    color: context.colors.textMuted, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.homeLoadFailedTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(l10n.homeLoadFailedBody,
                          style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12.5)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_initFutures),
                  child: Text(l10n.homeRetryAction,
                      style: TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Horizontal genre chips under the Movies/TV toggle → browse-by-genre.
  Widget _genreChips() {
    final future = _tab == 0 ? _movieGenres : _tvGenres;
    final type = _tab == 0 ? MediaType.movie : MediaType.tv;
    return SliverToBoxAdapter(
      child: FutureBuilder<List<Genre>>(
        future: future,
        builder: (context, snap) {
          final genres = snap.data ?? const <Genre>[];
          if (genres.isEmpty) return const SizedBox.shrink();
          return SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _genreChip(type, genres[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _genreChip(MediaType type, Genre g) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DiscoverScreen(type: type, genre: g)),
      ),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Text(g.name,
            style: TextStyle(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }

  List<Widget> _movieSlivers() {
    final l10n = AppLocalizations.of(context)!;
    return [
      _spotlight(_nowPlaying),
      _becauseYouWatchedMovie(),
      _friendsSlider(isMovie: true),
      _rail(l10n.homeTrendingThisWeek, _trendingMovies),
      _rail(l10n.homeComingSoon, _upcoming),
      _rail(l10n.homePopular, _popularMovies),
      _rail(l10n.homeTopRated, _topMovies),
    ];
  }

  List<Widget> _tvSlivers() {
    final l10n = AppLocalizations.of(context)!;
    return [
      _spotlight(_trendingTv),
      _becauseYouWatchedTv(),
      _friendsSlider(isMovie: false),
      _rail(l10n.homeAiringToday, _airingToday),
      _rail(l10n.homeOnTheAir, _onTheAir),
      _rail(l10n.homePopularShows, _popularTv),
      _rail(l10n.homeTopRated, _topTv),
    ];
  }

  // "Your Friends Also Watched" — a per-friend fan-out (SocialService) of
  // raw watched movie/show docs, rendered as friend-tagged poster cards with
  // long-press quick-add, matching the Letterboxd "New from friends" rail
  // this feature was modeled on.
  Widget _friendsSlider({required bool isMovie}) {
    return SliverToBoxAdapter(
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: SocialService.instance.myStream(),
        builder: (context, snap) {
          final following =
              ((snap.data?['following'] as List?) ?? const []).cast<String>();
          if (following.isEmpty) return const SizedBox.shrink();
          final key = following.join(',');
          if (_friendsKey != key) {
            _friendsKey = key;
            _friendsMoviesFuture =
                SocialService.instance.friendsWatchedMovies(following);
            _friendsShowsFuture =
                SocialService.instance.friendsWatchedShows(following);
          }
          final future = isMovie ? _friendsMoviesFuture! : _friendsShowsFuture!;
          final l10n = AppLocalizations.of(context)!;
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snap) {
              final items = snap.data ?? const <Map<String, dynamic>>[];
              if (items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  SectionHeader(title: l10n.homeFriendsAlsoWatched),
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) =>
                          _friendPoster(items[i], isMovie),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _friendPoster(Map<String, dynamic> m, bool isMovie) {
    final item = isMovie
        ? MediaItem(
            id: (m['id'] ?? 0) as int,
            title: (m['title'] ?? '') as String,
            overview: '',
            posterPath: (m['posterPath'] ?? '') as String,
            backdropPath: (m['backdropPath'] ?? '') as String,
            date: (m['releaseDate'] ?? '') as String,
            voteAverage: ((m['voteAverage'] ?? 0) as num).toDouble(),
            mediaType: MediaType.movie,
          )
        : MediaItem(
            id: (m['id'] ?? 0) as int,
            title: (m['name'] ?? '') as String,
            overview: '',
            posterPath: (m['posterPath'] ?? '') as String,
            backdropPath: (m['backdropPath'] ?? '') as String,
            date: (m['firstAirDate'] ?? '') as String,
            voteAverage: ((m['voteAverage'] ?? 0) as num).toDouble(),
            mediaType: MediaType.tv,
          );
    final rating =
        (((isMovie ? m['rating'] : m['userRating']) ?? 0) as num).toDouble();
    return FriendPosterCard(
      item: item,
      friendName: (m['actorName'] ?? '') as String,
      friendPhoto: (m['actorPhoto'] ?? '') as String,
      rating: rating,
    );
  }

  // Personalized rail seeded from the most recent thing you watched.
  Widget _becauseYouWatchedMovie() {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: MovieService.instance.watchedStream(),
        builder: (context, snap) {
          final l10n = AppLocalizations.of(context)!;
          final watched = snap.data ?? const <Map<String, dynamic>>[];
          if (watched.isEmpty) return const SizedBox.shrink();
          final sorted = [...watched]
            ..sort((a, b) {
              final ta = a['watchedAt'];
              final tb = b['watchedAt'];
              if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
              return 0;
            });
          final recent = sorted.first;
          final id = (recent['id'] ?? 0) as int;
          if (id == 0) return const SizedBox.shrink();
          if (_becauseMovieId != id) {
            _becauseMovieId = id;
            _becauseMovieRecs = _api
                .getRecommendations(MediaType.movie, id)
                .catchError((_) => <MediaItem>[]);
          }
          return _becauseRail(
              l10n.homeBecauseYouWatched((recent['title'] ?? '') as String),
              _becauseMovieRecs!);
        },
      ),
    );
  }

  Widget _becauseYouWatchedTv() {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: TvTrackingService.instance.trackedShowsStream(),
        builder: (context, snap) {
          final l10n = AppLocalizations.of(context)!;
          final shows = (snap.data ?? const <Map<String, dynamic>>[])
              .where((s) => ((s['watchedCount'] ?? 0) as int) > 0)
              .toList();
          if (shows.isEmpty) return const SizedBox.shrink();
          final recent = shows.first; // stream is ordered by updatedAt desc
          final id = (recent['id'] ?? 0) as int;
          if (id == 0) return const SizedBox.shrink();
          if (_becauseTvId != id) {
            _becauseTvId = id;
            _becauseTvRecs = _api
                .getRecommendations(MediaType.tv, id)
                .catchError((_) => <MediaItem>[]);
          }
          return _becauseRail(
              l10n.homeBecauseYouWatched((recent['name'] ?? '') as String),
              _becauseTvRecs!);
        },
      ),
    );
  }

  Widget _becauseRail(String title, Future<List<MediaItem>> future) {
    return FutureBuilder<List<MediaItem>>(
      future: future,
      builder: (context, snap) {
        final items = snap.data ?? const <MediaItem>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            SectionHeader(title: title),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => PosterCard(
                  item: items[i],
                  onTap: () => openMedia(context, items[i]),
                  onLongPress: () => showQuickAddSheet(context, items[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // A full-width hero carousel driven by [future].
  Widget _spotlight(Future<List<MediaItem>> future) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<MediaItem>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SkeletonBox(height: 200, radius: 20),
            );
          }
          final items = snapshot.data!.take(8).toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CarouselSlider.builder(
              itemCount: items.length,
              itemBuilder: (context, index, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: BackdropCard(item: items[index]),
              ),
              options: CarouselOptions(
                height: 200,
                autoPlay: true,
                enlargeCenterPage: true,
                viewportFraction: 0.88,
                autoPlayInterval: const Duration(seconds: 6),
              ),
            ),
          );
        },
      ),
    );
  }

  // A titled horizontal rail of poster cards driven by [future].
  Widget _rail(String title, Future<List<MediaItem>> future) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          SectionHeader(title: title),
          SizedBox(
            height: 250,
            child: FutureBuilder<List<MediaItem>>(
              future: future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const RailSkeleton(itemWidth: 130);
                }
                final items = snapshot.data!;
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => PosterCard(
                    item: items[index],
                    onTap: () => openMedia(context, items[index]),
                    onLongPress: () =>
                        showQuickAddSheet(context, items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
