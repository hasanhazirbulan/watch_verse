import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/year_in_review.dart';
import 'package:watch_verse/services/year_in_review_source.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/duration_format.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// Letterboxd/Wrapped-style recap of one calendar year: a vertical stack of
/// bold cards, each shareable as a PNG. All numbers come from
/// [computeYearInReview] (see `lib/services/year_in_review.dart` for exactly
/// how each one is derived and what's approximated); this screen only lays
/// them out and skips any card whose section has no data.
class YearInReviewScreen extends StatefulWidget {
  const YearInReviewScreen({
    super.key,
    this.source,
    this.initialYear,
    this.clock,
  });

  /// Injected in tests; defaults to the signed-in user's Firestore data.
  final YearInReviewSource? source;

  /// Year to open on; defaults to the current year.
  final int? initialYear;

  /// "Now" (tests pin it); decides the current year and the "so far" label.
  final DateTime Function()? clock;

  @override
  State<YearInReviewScreen> createState() => _YearInReviewScreenState();
}

class _Loaded {
  final YearInReview review;
  final List<int> years;
  const _Loaded(this.review, this.years);
}

class _YearInReviewScreenState extends State<YearInReviewScreen> {
  late final YearInReviewSource _source =
      widget.source ?? FirestoreYearInReviewSource();
  late int _year = widget.initialYear ?? _now().year;
  late Future<_Loaded> _future = _load();

  /// Years offered by the picker — kept from the last successful load so the
  /// picker stays usable while the next year loads (or fails).
  List<int> _years = const [];

  DateTime _now() => (widget.clock ?? DateTime.now)();

  Future<_Loaded> _load() async {
    final year = _year;
    final now = _now();
    final input = await _source.load(year);
    final years = yearsWithData(input, now: now);
    if (!years.contains(year)) years.add(year);
    years.sort((a, b) => b.compareTo(a));
    final loaded = _Loaded(computeYearInReview(input, year, now: now), years);
    if (mounted) setState(() => _years = years);
    return loaded;
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _selectYear(int year) {
    if (year == _year) return;
    _year = year;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.yirTitle),
        actions: [
          if (_years.length > 1)
            PopupMenuButton<int>(
              tooltip: l10n.yirYearPickerTooltip,
              initialValue: _year,
              onSelected: _selectYear,
              itemBuilder: (_) => [
                for (final y in _years)
                  PopupMenuItem(value: y, child: Text('$y')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_year',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<_Loaded>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return asyncLoadingIndicator();
          }
          if (snap.hasError) {
            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    asyncErrorView(context, snap.error!),
                    FilledButton(
                      onPressed: _reload,
                      child: Text(l10n.retryAction),
                    ),
                  ],
                ),
              ),
            );
          }
          final review = snap.data!.review;
          if (review.isEmpty) return _empty(context, l10n, review.year);
          return _content(context, l10n, review);
        },
      ),
    );
  }

  Widget _empty(BuildContext context, AppLocalizations l10n, int year) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 48,
              color: colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.yirEmptyTitle('$year'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.yirEmptyBody('$year'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l10n, YearInReview r) {
    final colors = context.colors;
    final unknown = r.filmsWithoutRuntime + r.episodesWithoutRuntime;
    final notes = [
      if (unknown > 0) l10n.yirRuntimeUnknownNote(unknown),
      if (r.episodesWithEstimatedRuntime > 0)
        l10n.yirRuntimeEstimatedNote(r.episodesWithEstimatedRuntime),
    ];
    final cards = <Widget>[
      _ShareableCard(
        name: 'summary',
        year: r.year,
        gradient: true,
        child: _summary(context, l10n, r),
      ),
      if (notes.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text(
            notes.join(' '),
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ),
      if (r.topGenres.isNotEmpty)
        _ShareableCard(
          name: 'genres',
          year: r.year,
          child: _genres(context, l10n, r),
        ),
      if (r.busiestMonth != null)
        _ShareableCard(
          name: 'months',
          year: r.year,
          child: _months(context, l10n, r),
        ),
      if (r.topRatedFilms.isNotEmpty)
        _ShareableCard(
          name: 'top-rated',
          year: r.year,
          child: _topRated(context, l10n, r),
        ),
      if (r.topShow != null)
        _ShareableCard(
          name: 'top-show',
          year: r.year,
          child: _topShow(context, l10n, r.topShow!),
        ),
      if (r.firstWatch != null && r.latestWatch != null)
        _ShareableCard(
          name: 'bookends',
          year: r.year,
          child: _bookends(context, l10n, r),
        ),
      if (_facts(context, l10n, r).isNotEmpty)
        _ShareableCard(
          name: 'facts',
          year: r.year,
          child: _funFacts(context, l10n, r),
        ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, i) => cards[i],
    );
  }

  // ---------------------------------------------------------------- cards --

  static String _hours(int minutes) {
    final h = minutes / 60;
    if (h == 0) return '0';
    return h >= 10 ? h.round().toString() : h.toStringAsFixed(1);
  }

  Widget _cardTitle(BuildContext context, String title, {String? caption}) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, AppLocalizations l10n, YearInReview r) {
    const white = Colors.white;
    final days = r.totalMinutes / (60 * 24);
    Widget stat(String value, String label, [String? sub]) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: white,
                fontSize: 44,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sub != null)
            Text(
              sub,
              style: TextStyle(
                color: white.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 36),
          child: Text(
            r.isPartial
                ? l10n.yirHeroSoFar('${r.year}')
                : l10n.yirHeroFull('${r.year}'),
            style: const TextStyle(
              color: white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (r.filmWatches > 0)
          stat(
            '${r.filmWatches}',
            l10n.yirFilmWatches,
            l10n.yirDistinctFilms(r.distinctFilms),
          ),
        if (r.episodes > 0)
          stat(
            '${r.episodes}',
            l10n.yirEpisodes,
            l10n.yirShows(r.showsWatched),
          ),
        if (r.totalMinutes > 0)
          stat(
            _hours(r.totalMinutes),
            l10n.yirHoursWatched,
            days >= 1
                ? l10n.yirDaysEquivalent(
                    days >= 10
                        ? days.round().toString()
                        : days.toStringAsFixed(1),
                  )
                : null,
          ),
      ],
    );
  }

  List<Color> _palette(BuildContext context) => [
    context.colors.primary,
    context.colors.primaryDark,
    context.colors.accent,
    context.colors.info,
    context.colors.success,
  ];

  Widget _genres(BuildContext context, AppLocalizations l10n, YearInReview r) {
    final colors = context.colors;
    final top = r.topGenres.take(5).toList();
    final max = top.first.value;
    final palette = _palette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(
          context,
          l10n.yirTopGenres,
          caption: l10n.yirTopGenresCaption,
        ),
        for (var i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${i + 1}. ${top[i].key}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatWatchDuration(context, top[i].value),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : top[i].value / max,
                    minHeight: 8,
                    backgroundColor: colors.surfaceAlt,
                    color: palette[i % palette.length],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _weekdayName(AppLocalizations l10n, int index) => [
    l10n.yirDayMonday,
    l10n.yirDayTuesday,
    l10n.yirDayWednesday,
    l10n.yirDayThursday,
    l10n.yirDayFriday,
    l10n.yirDaySaturday,
    l10n.yirDaySunday,
  ][index];

  Widget _months(BuildContext context, AppLocalizations l10n, YearInReview r) {
    final colors = context.colors;
    final month = r.busiestMonth!;
    // "March 2025" from the platform localizations — no intl dependency.
    final monthName = MaterialLocalizations.of(
      context,
    ).formatMonthYear(DateTime(r.year, month + 1));
    final initials = l10n.yirMonthInitials.split('');
    final maxValue = r.byMonth.reduce((a, b) => a > b ? a : b);
    final weekday = r.favouriteWeekday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(
          context,
          l10n.yirBusiestMonth,
          caption: l10n.yirBusiestMonthValue(monthName),
        ),
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              maxY: maxValue <= 0 ? 1 : maxValue * 1.15,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt().clamp(0, 11);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          i < initials.length ? initials[i] : '${i + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: i == month
                                ? FontWeight.w800
                                : FontWeight.w400,
                            color: i == month
                                ? colors.textPrimary
                                : colors.textMuted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < 12; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: r.byMonth[i].toDouble(),
                        color: i == month ? colors.primary : colors.surfaceAlt,
                        width: 10,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          r.activityInMinutes
              ? l10n.yirChartMinutesCaption
              : l10n.yirChartCountCaption,
          style: TextStyle(fontSize: 11, color: colors.textMuted),
        ),
        if (weekday != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.yirFavouriteDay(_weekdayName(l10n, weekday)),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  Widget _poster(String? path, {double radius = 8}) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: AspectRatio(
      aspectRatio: 2 / 3,
      child: TmdbImage(url: Tmdb.poster(path, size: 'w185')),
    ),
  );

  Widget _topRated(
    BuildContext context,
    AppLocalizations l10n,
    YearInReview r,
  ) {
    final colors = context.colors;
    final films = r.topRatedFilms.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(
          context,
          l10n.yirTopRated,
          caption: l10n.yirTopRatedCaption(films.length),
        ),
        // A Wrap of fixed-width cells (not a GridView with a fixed aspect
        // ratio) so each cell takes its natural height — the rating/title
        // lines below the poster grow with the text scale.
        LayoutBuilder(
          builder: (context, constraints) {
            const columns = 4;
            const gap = 8.0;
            final cellWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 10,
              children: [
                for (final f in films)
                  SizedBox(
                    width: cellWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _poster(f.posterPath),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                f.rating == f.rating.roundToDouble()
                                    ? f.rating.toStringAsFixed(0)
                                    : f.rating.toStringAsFixed(1),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          f.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _topShow(
    BuildContext context,
    AppLocalizations l10n,
    ShowSummary show,
  ) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(context, l10n.yirTopShow),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 92, child: _poster(show.posterPath, radius: 10)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.yirEpisodeCount(show.episodes),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  if (show.minutes > 0)
                    Text(
                      formatWatchDuration(context, show.minutes),
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _watchRow(
    BuildContext context,
    AppLocalizations l10n,
    String label,
    YearWatch w,
  ) {
    final colors = context.colors;
    final date = MaterialLocalizations.of(context).formatMediumDate(w.at);
    final code = w.kind == WatchKind.episode && w.season != null
        ? l10n.yirEpisodeCode(w.season!, w.episode ?? 0)
        : null;
    return Row(
      children: [
        SizedBox(width: 52, child: _poster(w.posterPath, radius: 6)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                w.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                code == null ? date : '$code · $date',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bookends(
    BuildContext context,
    AppLocalizations l10n,
    YearInReview r,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(context, l10n.yirBookends),
        _watchRow(context, l10n, l10n.yirFirstWatch, r.firstWatch!),
        const SizedBox(height: 14),
        _watchRow(context, l10n, l10n.yirLatestWatch, r.latestWatch!),
      ],
    );
  }

  List<String> _facts(
    BuildContext context,
    AppLocalizations l10n,
    YearInReview r,
  ) {
    final longest = r.longestFilm;
    final rewatched = r.mostRewatchedFilm;
    final busiest = r.busiestDay;
    final avg = r.averageFilmRating;
    return [
      if (longest != null)
        l10n.yirFactLongest(
          longest.title,
          formatWatchDuration(context, longest.value),
        ),
      if (rewatched != null)
        l10n.yirFactRewatched(rewatched.title, rewatched.value),
      if (rewatched != null && r.repeatWatches > rewatched.value - 1)
        l10n.yirFactRepeatWatches(r.repeatWatches),
      if (busiest != null)
        l10n.yirFactBusiestDay(
          MaterialLocalizations.of(context).formatMediumDate(busiest.day),
          busiest.total,
        ),
      if (avg != null && r.ratedFilms >= 2)
        l10n.yirFactAverageRating(avg.toStringAsFixed(1), r.ratedFilms),
    ];
  }

  Widget _funFacts(
    BuildContext context,
    AppLocalizations l10n,
    YearInReview r,
  ) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(context, l10n.yirFunFacts),
        for (final fact in _facts(context, l10n, r))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fact,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Loads [providers] into the image cache before a card is captured, giving
/// up after [timeout] so a slow or dead connection can't hold the share
/// forever. Failed loads are swallowed: the card is shared anyway, with the
/// placeholder for that poster.
@visibleForTesting
Future<void> precacheForCapture(
  BuildContext context,
  Iterable<ImageProvider> providers, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final loads = [
    for (final p in providers)
      precacheImage(p, context, onError: (_, _) {}),
  ];
  if (loads.isEmpty) return;
  await Future.wait(loads).timeout(timeout, onTimeout: () => const []);
}

/// One recap card plus a share button. The card (not the button) sits in a
/// [RepaintBoundary] so it can be rendered to a PNG and handed to the system
/// share sheet; a small "WatchVerse · year" footer is drawn inside the card
/// so the image makes sense on its own.
class _ShareableCard extends StatefulWidget {
  const _ShareableCard({
    required this.name,
    required this.year,
    required this.child,
    this.gradient = false,
  });

  final String name;
  final int year;
  final Widget child;
  final bool gradient;

  @override
  State<_ShareableCard> createState() => _ShareableCardState();
}

class _ShareableCardState extends State<_ShareableCard> {
  final _boundaryKey = GlobalKey();
  bool _sharing = false;

  /// The images of every [TmdbImage] inside the card, as the same provider
  /// [TmdbImage]'s `CachedNetworkImage` resolves (equal providers share one
  /// image-cache entry, so precaching one also fills the card's poster).
  List<ImageProvider> _cardImages() {
    final urls = <String>{};
    void visit(Element e) {
      final w = e.widget;
      if (w is TmdbImage && w.url != null) urls.add(w.url!);
      e.visitChildElements(visit);
    }

    final root = _boundaryKey.currentContext;
    if (root is Element) visit(root);
    return [for (final url in urls) CachedNetworkImageProvider(url)];
  }

  /// Waits for the card's posters so the PNG doesn't show loading
  /// placeholders.
  Future<void> _waitForImages() async {
    final images = _cardImages();
    if (images.isEmpty) return;
    final cache = PaintingBinding.instance.imageCache;
    // A poster that only arrives now cross-fades in over the placeholder
    // (CachedNetworkImage's default fadeOutDuration is 1s); one that was
    // already loaded is drawn as is.
    final settled = images.every((p) {
      final status = cache.statusForKey(p);
      return status.tracked && !status.pending;
    });
    await precacheForCapture(context, images);
    if (!settled) await Future<void>.delayed(const Duration(seconds: 1));
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _share(BuildContext buttonContext) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    // iPad's share sheet is a popover and throws without an anchor rect.
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await _waitForImages();
      if (!mounted) return;
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('card not rendered');
      // 3x on a phone; capped at ~1440 px wide so a full-width card on an
      // iPad (1000+ pt) doesn't allocate a 50+ MB bitmap to encode.
      final width = boundary.size.width;
      final image = await boundary.toImage(
        pixelRatio: width > 0 ? math.min(3.0, 1440 / width) : 3.0,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('PNG encoding failed');
      final file = XFile.fromData(
        data.buffer.asUint8List(),
        mimeType: 'image/png',
        name: 'watchverse-${widget.year}-${widget.name}.png',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text: l10n.yirShareText('${widget.year}'),
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('YearInReview: share failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.yirShareFailed)));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final onGradient = widget.gradient;
    final footerColor = onGradient
        ? Colors.white.withValues(alpha: 0.8)
        : colors.textMuted;
    return Stack(
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          // Opaque backdrop so the PNG's rounded corners aren't transparent.
          child: ColoredBox(
            color: colors.background,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                gradient: onGradient ? colors.brandGradient : null,
                color: onGradient ? null : colors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.child,
                  const SizedBox(height: 14),
                  Text(
                    'WatchVerse · ${widget.year}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: footerColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Builder(
            builder: (buttonContext) => IconButton(
              tooltip: l10n.yirShare,
              onPressed: _sharing ? null : () => _share(buttonContext),
              // Posters can take a few seconds to load before the capture.
              icon: _sharing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: onGradient ? Colors.white : colors.primary,
                      ),
                    )
                  : Icon(
                      Icons.ios_share_rounded,
                      size: 20,
                      color: onGradient ? Colors.white : colors.textSecondary,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
