import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/pro_service.dart';
import 'package:watch_verse/screens/year_in_review_screen.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/duration_format.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/paywall_sheet.dart';

/// Drill-down from the profile's time-spent tiles: how watch time breaks
/// down by type (movie/show) and genre, plus how it's trended over the last
/// 8 weeks and across the days of the week. Everything here is derived from
/// data already stored for the profile stat tiles — no new Firestore reads
/// beyond a wider activity-history window for the two trend charts. That
/// window (up to 500 docs) is read once (not a live listener, see
/// [TvTrackingService.activityOnce]) — this screen is a point-in-time
/// report, not a dashboard that needs to reflect a watch marked while it's
/// open.
class WatchStatsScreen extends StatefulWidget {
  const WatchStatsScreen({super.key});

  @override
  State<WatchStatsScreen> createState() => _WatchStatsScreenState();
}

class _WatchStatsScreenState extends State<WatchStatsScreen> {
  static const _weeksShown = 8;

  late final Future<List<Map<String, dynamic>>> _activityFuture =
      TvTrackingService.instance.activityOnce(limit: 500);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsScreenTitle),
        actions: [
          IconButton(
            tooltip: l10n.yirTitle,
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const YearInReviewScreen())),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: MovieService.instance.watchedStream(),
        builder: (context, movieSnap) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: TvTrackingService.instance.trackedShowsStream(),
            builder: (context, showSnap) {
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _activityFuture,
                builder: (context, activitySnap) {
                  final movies =
                      movieSnap.data ?? const <Map<String, dynamic>>[];
                  final shows = showSnap.data ?? const <Map<String, dynamic>>[];
                  final activity =
                      activitySnap.data ?? const <Map<String, dynamic>>[];

                  final movieMinutes = movies.fold<int>(
                      0, (a, m) => a + ((m['runtime'] ?? 0) as num).toInt());
                  final showMinutes = shows.fold<int>(
                      0,
                      (a, s) =>
                          a + ((s['watchedMinutes'] ?? 0) as num).toInt());

                  if (movieMinutes == 0 && showMinutes == 0) {
                    return _empty(context, l10n);
                  }

                  final genreMinutes = _genreBreakdown(movies, shows);
                  final weekly = _weeklyMinutes(activity);
                  final byWeekday = _weekdayMinutes(activity);

                  return StreamBuilder<bool>(
                    stream: ProService.instance.isProStream,
                    initialData: ProService.instance.isPro,
                    builder: (context, proSnap) {
                      final isPro = proSnap.data ?? false;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [
                          _typeSection(context, l10n, movieMinutes, showMinutes),
                          const SizedBox(height: 28),
                          if (genreMinutes.isNotEmpty) ...[
                            _proGated(context, l10n, isPro,
                                _genreSection(context, l10n, genreMinutes)),
                            const SizedBox(height: 28),
                          ],
                          _proGated(context, l10n, isPro,
                              _weeklySection(context, l10n, weekly)),
                          const SizedBox(height: 28),
                          _proGated(context, l10n, isPro,
                              _weekdaySection(context, l10n, byWeekday)),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ aggregation

  /// Minutes per genre: a title's whole runtime/watched-minutes is counted
  /// under every genre it belongs to (the standard way to build a
  /// genre-time breakdown when titles have multiple genres).
  Map<String, int> _genreBreakdown(
      List<Map<String, dynamic>> movies, List<Map<String, dynamic>> shows) {
    final totals = <String, int>{};
    for (final m in movies) {
      final runtime = ((m['runtime'] ?? 0) as num).toInt();
      if (runtime <= 0) continue;
      for (final g in ((m['genres'] as List?) ?? const []).cast<String>()) {
        totals[g] = (totals[g] ?? 0) + runtime;
      }
    }
    for (final s in shows) {
      final minutes = ((s['watchedMinutes'] ?? 0) as num).toInt();
      if (minutes <= 0) continue;
      for (final g in ((s['genres'] as List?) ?? const []).cast<String>()) {
        totals[g] = (totals[g] ?? 0) + minutes;
      }
    }
    return totals;
  }

  DateTime _startOfWeek(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Total minutes watched per week for the last [_weeksShown] weeks
  /// (oldest first, last entry is the current week), from activity entries
  /// that carry a `runtime`.
  List<int> _weeklyMinutes(List<Map<String, dynamic>> activity) {
    final thisWeek = _startOfWeek(DateTime.now());
    final weekStarts = List.generate(_weeksShown,
        (i) => thisWeek.subtract(Duration(days: 7 * (_weeksShown - 1 - i))));
    final totals = List<int>.filled(_weeksShown, 0);
    for (final a in activity) {
      final runtime = ((a['runtime'] ?? 0) as num).toInt();
      final ts = a['at'];
      if (runtime <= 0 || ts is! Timestamp) continue;
      final week = _startOfWeek(ts.toDate());
      final idx = weekStarts.indexWhere((w) => w == week);
      if (idx != -1) totals[idx] += runtime;
    }
    return totals;
  }

  /// Total minutes watched per weekday (index 0 = Monday .. 6 = Sunday),
  /// summed across all fetched activity.
  List<int> _weekdayMinutes(List<Map<String, dynamic>> activity) {
    final totals = List<int>.filled(7, 0);
    for (final a in activity) {
      final runtime = ((a['runtime'] ?? 0) as num).toInt();
      final ts = a['at'];
      if (runtime <= 0 || ts is! Timestamp) continue;
      totals[ts.toDate().weekday - 1] += runtime;
    }
    return totals;
  }

  List<Color> _palette(BuildContext context) => [
        context.colors.primary,
        context.colors.info,
        context.colors.accent,
        context.colors.success,
        context.colors.primaryDark,
        Colors.purpleAccent,
        Colors.teal,
        Colors.pinkAccent,
      ];

  // ------------------------------------------------------------------- UI --

  Widget _empty(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.statsEmptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary)),
      ),
    );
  }

  /// Wraps a Pro-only chart section: shown normally when [isPro], otherwise
  /// blurred with an "Unlock with Pro" overlay that opens the paywall. The
  /// real widget tree (and its data) is always built — only the pixels are
  /// hidden — since blurring is far cheaper than maintaining a second,
  /// data-free placeholder layout in sync with the real one.
  Widget _proGated(
      BuildContext context, AppLocalizations l10n, bool isPro, Widget child) {
    if (isPro) return child;
    return Stack(
      children: [
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: child,
          ),
        ),
        Positioned.fill(
          child: Center(
            child: ElevatedButton.icon(
              onPressed: () => showPaywallSheet(context),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text(l10n.proUnlockStats),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendRow(BuildContext context, Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
        ),
      ],
    );
  }

  Widget _typeSection(BuildContext context, AppLocalizations l10n,
      int movieMinutes, int showMinutes) {
    final total = movieMinutes + showMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.statsTypeBreakdownTitle),
        SizedBox(
          height: 170,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: [
                    PieChartSectionData(
                      value: movieMinutes > 0 ? movieMinutes.toDouble() : 0.001,
                      color: context.colors.primary,
                      title: total == 0
                          ? ''
                          : '${(movieMinutes / total * 100).round()}%',
                      radius: 44,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                    PieChartSectionData(
                      value: showMinutes > 0 ? showMinutes.toDouble() : 0.001,
                      color: context.colors.info,
                      title: total == 0
                          ? ''
                          : '${(showMinutes / total * 100).round()}%',
                      radius: 44,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                )),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow(context, context.colors.primary,
                        '${l10n.profileMovieTimeSpent} · ${formatWatchDuration(context, movieMinutes)}'),
                    const SizedBox(height: 12),
                    _legendRow(context, context.colors.info,
                        '${l10n.profileShowTimeSpent} · ${formatWatchDuration(context, showMinutes)}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _genreSection(BuildContext context, AppLocalizations l10n,
      Map<String, int> genreMinutes) {
    final sorted = genreMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const maxSlices = 6;
    final top = sorted.take(maxSlices).toList();
    final otherMinutes =
        sorted.skip(maxSlices).fold<int>(0, (acc, e) => acc + e.value);
    final slices = <MapEntry<String, int>>[
      ...top,
      if (otherMinutes > 0) MapEntry(l10n.statsOtherGenres, otherMinutes),
    ];
    final total = slices.fold<int>(0, (a, e) => a + e.value);
    final palette = _palette(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.statsGenreBreakdownTitle),
        SizedBox(
          height: 190,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 28,
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].value.toDouble(),
                        color: palette[i % palette.length],
                        title: total == 0
                            ? ''
                            : '${(slices[i].value / total * 100).round()}%',
                        radius: 40,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10),
                      ),
                  ],
                )),
              ),
              Expanded(
                flex: 6,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: slices.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _legendRow(context, palette[i % palette.length],
                        slices[i].key),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _barChart(BuildContext context, List<int> values,
      Widget Function(int index) labelBuilder, Color color) {
    final maxValue =
        values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    return BarChart(BarChartData(
      maxY: maxValue <= 0 ? 60 : maxValue * 1.2,
      alignment: BarChartAlignment.spaceAround,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(enabled: false),
      titlesData: FlTitlesData(
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: labelBuilder(value.toInt()),
            ),
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < values.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: values[i].toDouble(),
              color: color,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ]),
      ],
    ));
  }

  Widget _weeklySection(
      BuildContext context, AppLocalizations l10n, List<int> weekly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.statsWeeklyTitle),
        SizedBox(
          height: 190,
          child: _barChart(
            context,
            weekly,
            (i) {
              final weeksAgo = _weeksShown - 1 - i;
              final label =
                  weeksAgo == 0 ? l10n.statsThisWeek : '-$weeksAgo';
              return Text(label,
                  style:
                      TextStyle(fontSize: 10, color: context.colors.textMuted));
            },
            context.colors.primary,
          ),
        ),
      ],
    );
  }

  Widget _weekdaySection(
      BuildContext context, AppLocalizations l10n, List<int> byWeekday) {
    final labels = [
      l10n.statsDayMon,
      l10n.statsDayTue,
      l10n.statsDayWed,
      l10n.statsDayThu,
      l10n.statsDayFri,
      l10n.statsDaySat,
      l10n.statsDaySun,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.statsWeekdayTitle),
        SizedBox(
          height: 190,
          child: _barChart(
            context,
            byWeekday,
            (i) => Text(labels[i.clamp(0, 6)],
                style:
                    TextStyle(fontSize: 11, color: context.colors.textMuted)),
            context.colors.info,
          ),
        ),
      ],
    );
  }
}
