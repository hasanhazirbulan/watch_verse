import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/game_clue_movie.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/daily_game_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/clue_tile.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// One tile's worth of comparison result: what to show on the clue tile, and
/// how it matched the mystery movie.
class _Clue {
  final String label;
  final String value;
  final ClueMatch match;
  const _Clue(this.label, this.value, this.match);
}

/// WatchVerse Pro's daily "guess the movie" game (spotle.movie-style): 10
/// guesses, 8 clue tiles per guess, two hints that unlock after guess 5 and
/// 8. See `DailyGameService` for how the mystery movie is picked and how
/// progress/streaks are stored.
class DailyGameScreen extends StatefulWidget {
  const DailyGameScreen({super.key});

  @override
  State<DailyGameScreen> createState() => _DailyGameScreenState();
}

class _DailyGameScreenState extends State<DailyGameScreen> {
  final _api = APIservices();
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<MediaItem> _searchResults = [];
  bool _searching = false;

  int _daysAgo = 0;
  GameClueMovie? _mystery;
  bool _loadingMystery = true;
  final Map<int, GameClueMovie> _guessCache = {};

  @override
  void initState() {
    super.initState();
    _loadMystery();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMystery() async {
    setState(() {
      _loadingMystery = true;
      _mystery = null;
    });
    final m = await DailyGameService.instance.mysteryMovieForDaysAgo(_daysAgo);
    if (!mounted) return;
    setState(() {
      _mystery = m;
      _loadingMystery = false;
    });
  }

  void _selectDay(int daysAgo) {
    if (daysAgo == _daysAgo) return;
    setState(() {
      _daysAgo = daysAgo;
      _searchController.clear();
      _searchResults = [];
    });
    _loadMystery();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await _api.searchMovies(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results.take(10).toList();
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _guess(MediaItem item, List<int> alreadyGuessed) async {
    if (alreadyGuessed.contains(item.id)) return;
    final mystery = _mystery;
    if (mystery == null) return;
    setState(() {
      _searchController.clear();
      _searchResults = [];
    });
    final clue = await _api.getGameClueData(item.id);
    if (!mounted) return;
    setState(() => _guessCache[item.id] = clue);

    final newGuessCount = alreadyGuessed.length + 1;
    final won = item.id == mystery.id;
    final finished = won || newGuessCount >= dailyGameMaxGuesses;
    await DailyGameService.instance.recordGuess(
      daysAgo: _daysAgo,
      guessedMovieId: item.id,
      won: won,
      finished: finished,
    );
  }

  // ------------------------------------------------------------- clues -----

  List<_Clue> _compare(GameClueMovie guess, GameClueMovie mystery, AppLocalizations l10n) {
    ClueMatch yearMatch() {
      if (guess.releaseYear == 0 || mystery.releaseYear == 0) return ClueMatch.none;
      if (guess.releaseYear == mystery.releaseYear) return ClueMatch.exact;
      return (guess.releaseYear - mystery.releaseYear).abs() <= 5
          ? ClueMatch.close
          : ClueMatch.none;
    }

    ClueMatch revenueMatch() {
      if (guess.revenue <= 0 || mystery.revenue <= 0) return ClueMatch.none;
      final diff = (guess.revenue - mystery.revenue).abs() / mystery.revenue;
      if (diff <= 0.1) return ClueMatch.exact;
      return diff <= 0.5 ? ClueMatch.close : ClueMatch.none;
    }

    ClueMatch ratingMatch() {
      final diff = (guess.voteAverage - mystery.voteAverage).abs();
      if (diff <= 0.3) return ClueMatch.exact;
      return diff <= 1.0 ? ClueMatch.close : ClueMatch.none;
    }

    ClueMatch genreMatch() {
      if (guess.genres.isEmpty || mystery.genres.isEmpty) return ClueMatch.none;
      final a = guess.genres.toSet();
      final b = mystery.genres.toSet();
      if (a.length == b.length && a.containsAll(b)) return ClueMatch.exact;
      return a.intersection(b).isNotEmpty ? ClueMatch.close : ClueMatch.none;
    }

    ClueMatch castMatch() {
      if (guess.id == mystery.id) return ClueMatch.exact;
      final shared = guess.cast.toSet().intersection(mystery.cast.toSet());
      return shared.isNotEmpty ? ClueMatch.close : ClueMatch.none;
    }

    bool exactStr(String a, String b) => a.isNotEmpty && a == b;

    return [
      _Clue(l10n.dailyGameClueDirector, guess.director,
          exactStr(guess.director, mystery.director) ? ClueMatch.exact : ClueMatch.none),
      _Clue(l10n.dailyGameClueStudio, guess.productionCompany,
          exactStr(guess.productionCompany, mystery.productionCompany)
              ? ClueMatch.exact
              : ClueMatch.none),
      _Clue(l10n.dailyGameClueYear,
          guess.releaseYear == 0 ? '' : '${guess.releaseYear}', yearMatch()),
      _Clue(l10n.dailyGameClueRevenue, _formatRevenue(guess.revenue), revenueMatch()),
      _Clue(l10n.dailyGameClueRating, guess.voteAverage.toStringAsFixed(1), ratingMatch()),
      _Clue(l10n.dailyGameClueCertification, guess.certification, exactStr(
          guess.certification, mystery.certification) ? ClueMatch.exact : ClueMatch.none),
      _Clue(l10n.dailyGameClueCast, guess.cast.take(2).join(', '), castMatch()),
      _Clue(l10n.dailyGameClueGenres, guess.genres.take(2).join(', '), genreMatch()),
    ];
  }

  String _formatRevenue(int revenue) {
    if (revenue <= 0) return 'N/A';
    if (revenue >= 1000000000) {
      return '\$${(revenue / 1000000000).toStringAsFixed(1)}B';
    }
    if (revenue >= 1000000) return '\$${(revenue / 1000000).toStringAsFixed(0)}M';
    return '\$${(revenue / 1000).toStringAsFixed(0)}K';
  }

  String _buildShareText(List<int> guessedIds, bool won, AppLocalizations l10n) {
    final buffer = StringBuffer();
    buffer.writeln('WatchVerse ${l10n.dailyGameTitle} — '
        '${won ? "${guessedIds.length}/10" : "X/10"}');
    for (final id in guessedIds) {
      final guess = _guessCache[id];
      final mystery = _mystery;
      if (guess == null || mystery == null) continue;
      final clues = _compare(guess, mystery, l10n);
      buffer.writeln(clues.map((c) {
        switch (c.match) {
          case ClueMatch.exact:
            return '🟩';
          case ClueMatch.close:
            return '🟨';
          case ClueMatch.none:
            return '⬜';
        }
      }).join());
    }
    return buffer.toString();
  }

  // --------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyGameTitle),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: l10n.dailyGamePickAnotherDay,
            onSelected: _selectDay,
            itemBuilder: (context) => [
              for (var i = 0; i < dailyGameRewatchDays; i++)
                PopupMenuItem(
                  value: i,
                  child: Text(i == 0
                      ? l10n.dailyGameTitle
                      : DailyGameService.instance.dateKeyForDaysAgo(i)),
                ),
            ],
          ),
        ],
      ),
      body: _loadingMystery
          ? const Center(child: CircularProgressIndicator())
          : _mystery == null
              ? _emptyPool(context, l10n)
              : _game(context, l10n, _mystery!),
    );
  }

  Widget _emptyPool(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.dailyGameNoPool,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary)),
      ),
    );
  }

  Widget _game(BuildContext context, AppLocalizations l10n, GameClueMovie mystery) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: DailyGameService.instance.progressStream(_daysAgo),
      builder: (context, snap) {
        final data = snap.data;
        final guessedIds =
            ((data?['guessedIds'] as List?) ?? const []).cast<int>();
        final won = data?['won'] == true;
        final finished = data?['finished'] == true;
        final hintsUsed = ((data?['hintsUsed'] ?? 0) as num).toInt();

        for (final id in guessedIds) {
          if (!_guessCache.containsKey(id)) {
            _api.getGameClueData(id).then((clue) {
              if (mounted) setState(() => _guessCache[id] = clue);
            });
          }
        }

        return Column(
          children: [
            _statusBar(context, l10n, guessedIds.length, finished, won),
            if (!finished) _searchBar(context, l10n, guessedIds),
            if (!finished &&
                dailyGameHintUnlockGuesses.contains(guessedIds.length) &&
                hintsUsed < dailyGameHintUnlockGuesses.indexOf(guessedIds.length) + 1)
              _hintBanner(context, l10n, mystery, hintsUsed),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: guessedIds.length,
                itemBuilder: (context, i) {
                  final id = guessedIds[i];
                  final guess = _guessCache[id];
                  if (guess == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: LinearProgressIndicator(),
                    );
                  }
                  return _guessRow(context, guess, mystery, l10n, i);
                },
              ),
            ),
            if (finished) _resultPanel(context, l10n, mystery, guessedIds, won),
          ],
        );
      },
    );
  }

  Widget _statusBar(BuildContext context, AppLocalizations l10n, int guessCount,
      bool finished, bool won) {
    final left = dailyGameMaxGuesses - guessCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            finished
                ? (won ? l10n.dailyGameWinTitle : l10n.dailyGameLoseTitle)
                : l10n.dailyGameGuessesLeft('$left'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          StreamBuilder<(int, int)>(
            stream: DailyGameService.instance.streakStream(),
            builder: (context, snap) {
              final streak = snap.data ?? (0, 0);
              return Text(
                '${l10n.dailyGameStreak('${streak.$1}')} · ${l10n.dailyGameBestStreak('${streak.$2}')}',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _searchBar(
      BuildContext context, AppLocalizations l10n, List<int> guessedIds) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: l10n.dailyGameSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          if (_searchResults.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, i) {
                  final item = _searchResults[i];
                  final already = guessedIds.contains(item.id);
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 36,
                        height: 50,
                        child: TmdbImage(url: Tmdb.poster(item.posterPath, size: 'w92')),
                      ),
                    ),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.year),
                    trailing: already
                        ? Text(l10n.dailyGameGuessedAlready,
                            style: TextStyle(color: context.colors.textMuted, fontSize: 12))
                        : null,
                    enabled: !already,
                    onTap: already ? null : () => _guess(item, guessedIds),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _hintBanner(BuildContext context, AppLocalizations l10n,
      GameClueMovie mystery, int hintsUsed) {
    final nextHintIndex = hintsUsed; // 0 or 1
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(Icons.lightbulb_rounded, color: context.colors.accent),
          title: Text(l10n.dailyGameHintUnlocked,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: TextButton(
            onPressed: () => DailyGameService.instance
                .useHint(_daysAgo, hintsUsed + 1),
            child: Text(l10n.dailyGameShowHint),
          ),
          subtitle: hintsUsed > nextHintIndex
              ? null
              : Text(
                  nextHintIndex == 0
                      ? '${l10n.dailyGameClueYear}: ${mystery.releaseYear}'
                      : '${l10n.dailyGameClueGenres}: ${mystery.genres.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }

  Widget _guessRow(BuildContext context, GameClueMovie guess, GameClueMovie mystery,
      AppLocalizations l10n, int index) {
    final clues = _compare(guess, mystery, l10n);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(guess.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.3,
            children: [
              for (var i = 0; i < clues.length; i++)
                ClueTile(
                  label: clues[i].label,
                  value: clues[i].value,
                  match: clues[i].match,
                  index: i,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultPanel(BuildContext context, AppLocalizations l10n,
      GameClueMovie mystery, List<int> guessedIds, bool won) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.surfaceAlt)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(won ? l10n.dailyGameWinTitle : l10n.dailyGameLoseTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          if (!won)
            Text(l10n.dailyGameLoseSubtitle(mystery.title),
                style: TextStyle(color: context.colors.textSecondary)),
          const SizedBox(height: 4),
          Text(l10n.dailyGamePlayAgainTomorrow,
              style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: context.colors.brandGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Share.share(_buildShareText(guessedIds, won, l10n)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(l10n.dailyGameShareResult,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
