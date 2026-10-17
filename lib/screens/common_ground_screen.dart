import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/create_watch_poll_screen.dart';
import 'package:watch_verse/services/common_ground.dart';
import 'package:watch_verse/services/common_ground_source.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/responsive.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/streaming_widgets.dart';
import 'package:watch_verse/services/app_firebase.dart';

/// What the viewer and another user have in common: titles on both their
/// watchlists (streamable-on-my-services first, when services are set up),
/// how often their film ratings agree, and a shortcut to a watch poll.
class CommonGroundScreen extends StatefulWidget {
  final String userId;
  final String name;

  /// Test seams; default to Firestore / the signed-in user / app streaming.
  final CommonGroundSource? source;
  final String? myUid;
  final StreamingDeps? streamingDeps;

  const CommonGroundScreen({
    super.key,
    required this.userId,
    required this.name,
    this.source,
    this.myUid,
    this.streamingDeps,
  });

  @override
  State<CommonGroundScreen> createState() => _CommonGroundScreenState();
}

class _Result {
  final List<MediaItem> shared;
  final TasteAgreement agreement;
  const _Result(this.shared, this.agreement);
}

class _CommonGroundScreenState extends State<CommonGroundScreen> {
  late final StreamingDeps _streaming =
      widget.streamingDeps ?? StreamingDeps.instance;
  late final AvailabilityChecker _checker = AvailabilityChecker(
    source: _streaming.source,
    cache: _streaming.cache,
  )..addListener(_onAvailability);
  late Future<_Result> _future = _load();
  StreamingPrefs _prefs = StreamingPrefs.empty;
  String? _region;

  @override
  void dispose() {
    _checker
      ..removeListener(_onAvailability)
      ..dispose();
    super.dispose();
  }

  void _onAvailability() {
    if (mounted) setState(() {});
  }

  Future<_Result> _load() async {
    final me = widget.myUid ?? AppFirebase.auth.currentUser?.uid;
    if (me == null) throw StateError('Not signed in');
    final source = widget.source ?? FirestoreCommonGroundSource();
    final data = await source.load(myUid: me, theirUid: widget.userId);
    final shared = sharedWatchlist(
      theirMovies: data.theirWatchlistMovies,
      myMoviesById: data.myMoviesById,
      theirShows: data.theirWatchlistShows,
      myShowsById: data.myShowsById,
    );
    final agreement = computeAgreement(
      theirRated: data.theirRatedMovies,
      myMoviesById: data.myMoviesById,
    );
    unawaited(_checkAvailability(shared));
    return _Result(shared, agreement);
  }

  /// Optional: only when the viewer picked services. TMDB lookups go through
  /// the shared per-title cache, so reopening costs no requests.
  Future<void> _checkAvailability(List<MediaItem> shared) async {
    if (shared.isEmpty) return;
    try {
      final prefs = await _streaming.prefs
          .watch()
          .first
          .timeout(const Duration(seconds: 3));
      if (!mounted || prefs.providerIds.isEmpty) return;
      final region = prefs.effectiveRegion(_streaming.deviceCountry());
      setState(() {
        _prefs = prefs;
        _region = region;
      });
      await _checker.check(
          [for (final m in shared) TitleRef(m.mediaType, m.id)], region);
    } catch (e) {
      debugPrint('CommonGround: availability skipped: $e');
    }
  }

  List<WatchProvider> _myProvidersFor(MediaItem item) => matchUserServices(
        _checker.availabilityFor(TitleRef(item.mediaType, item.id)) ??
            const [],
        _prefs.providerIds,
      );

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonGroundTitle(widget.name))),
      body: FutureBuilder<_Result>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return asyncErrorView(context, snap.error!, onRetry: _retry);
          }
          if (!snap.hasData) return asyncLoadingIndicator();
          final result = snap.data!;
          final ranked = _region == null
              ? result.shared
              : rankByAvailability(
                  result.shared, (m) => _myProvidersFor(m).isNotEmpty);
          return ReadableListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _sharedSection(context, l10n, ranked),
              const SizedBox(height: 28),
              _tasteSection(context, l10n, result.agreement),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ watchlist --

  Widget _sharedSection(
      BuildContext context, AppLocalizations l10n, List<MediaItem> shared) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.commonGroundSharedHeader,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            if (shared.isNotEmpty)
              TextButton.icon(
                key: const ValueKey('common-ground-start-poll'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateWatchPollScreen(
                        initialOptions: pollCandidates(shared)),
                  ),
                ),
                icon: const Icon(Icons.how_to_vote_rounded, size: 18),
                label: Text(l10n.commonGroundStartPoll),
              ),
          ],
        ),
        if (shared.isEmpty)
          _emptyNote(context, l10n.commonGroundSharedEmpty)
        else ...[
          if (_region != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(l10n.commonGroundServicesFirst,
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 12.5)),
            )
          else
            const SizedBox(height: 6),
          SizedBox(
            height: 156 + MediaQuery.textScalerOf(context).scale(38),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shared.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _poster(context, shared[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _poster(BuildContext context, MediaItem item) {
    final providers = _region == null ? const <WatchProvider>[] : _myProvidersFor(item);
    return GestureDetector(
      onTap: () => openMedia(context, item),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  SizedBox(
                    width: 100,
                    height: 150,
                    child: TmdbImage(
                        url: Tmdb.poster(item.posterPath, size: 'w185')),
                  ),
                  if (providers.isNotEmpty)
                    Positioned(
                        top: 5,
                        left: 5,
                        child: StreamingBadge(providers: providers)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (item.year.isNotEmpty)
              Text(item.year,
                  style:
                      TextStyle(color: context.colors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- taste --

  Widget _tasteSection(
      BuildContext context, AppLocalizations l10n, TasteAgreement agreement) {
    final header = Text(l10n.commonGroundTasteHeader,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700));
    if (agreement.total == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, _emptyNote(context, l10n.commonGroundTasteEmpty)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  l10n.commonGroundAgreeSummary(
                      agreement.agreed, agreement.total),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: agreement.ratio ?? 0,
                  minHeight: 6,
                  backgroundColor: context.colors.surfaceAlt,
                ),
              ),
              const SizedBox(height: 10),
              Text(l10n.commonGroundAgreeDefinition(agreement.total),
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 12.5)),
            ],
          ),
        ),
        if (agreement.topAgreements.isNotEmpty) ...[
          const SizedBox(height: 18),
          _subheader(context, l10n.commonGroundMostInSync),
          for (final p in agreement.topAgreements) _pairTile(context, l10n, p),
        ],
        if (agreement.topDisagreements.isNotEmpty) ...[
          const SizedBox(height: 18),
          _subheader(context, l10n.commonGroundBiggestSplits),
          for (final p in agreement.topDisagreements)
            _pairTile(context, l10n, p),
        ],
      ],
    );
  }

  Widget _subheader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.textSecondary)),
      );

  static String _stars(double r) =>
      '★${r == r.roundToDouble() ? r.toInt() : r.toStringAsFixed(1)}';

  Widget _pairTile(BuildContext context, AppLocalizations l10n, RatedPair p) {
    final name = widget.name.trim().isEmpty
        ? l10n.commonGroundThem
        : widget.name.trim().split(RegExp(r'\s+')).first;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => openMedia(context, p.item),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 56,
          child: TmdbImage(url: Tmdb.poster(p.item.posterPath, size: 'w185')),
        ),
      ),
      title: Text(p.item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(l10n.commonGroundRatingsLine(
          _stars(p.myRating), name, _stars(p.theirRating))),
    );
  }

  Widget _emptyNote(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(text,
              style: TextStyle(color: context.colors.textSecondary)),
        ),
      );
}
