import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/game_clue_movie.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/daily_game_clues.dart';
import 'package:watch_verse/services/daily_game_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/clue_tile.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// Today's status line for the Games hub card — one Firestore doc listener;
/// nothing for guests (they can't play).
Stream<String?> dailyGameTodayStatus(AppLocalizations l10n) {
  if (FirebaseAuth.instance.currentUser == null) return Stream.value(null);
  final svc = DailyGameService.instance;
  return svc.progressStream(svc.todayIndex).map((play) {
    if (play.finished) {
      return play.won ? l10n.gamesHubStatusSolved : l10n.gamesHubStatusMissed;
    }
    return play.guessedIds.isEmpty
        ? l10n.gamesHubStatusNotPlayed
        : l10n.gamesHubStatusInProgress;
  }).handleError((Object e) => debugPrint('DailyGame: status failed: $e'));
}

/// WatchVerse's daily "guess the movie" game (spotle.movie-style): 10
/// guesses, 8 clue tiles per guess, two hints that unlock after guess 5 and
/// 8. Free for everyone signed in. See `DailyGameService` for how the
/// mystery movie is picked and how progress is stored, and
/// `daily_game_clues.dart` for the comparison rules.
class DailyGameScreen extends StatefulWidget {
  const DailyGameScreen({super.key});

  @override
  State<DailyGameScreen> createState() => _DailyGameScreenState();
}

class _DailyGameScreenState extends State<DailyGameScreen> {
  static const _howToSeenPrefsKey = 'dailyGameHowToSeen';

  final _svc = DailyGameService.instance;
  final _api = APIservices();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  List<MediaItem> _searchResults = [];
  bool _searching = false;
  bool _searchFailed = false;

  // Guests have no Firebase account, and both the movie pool
  // (gameConfig) and progress (gamePlays) are sign-in-only in
  // firestore.rules — loading would just fail with permission-denied.
  final bool _isGuest = FirebaseAuth.instance.currentUser == null;

  /// Absolute puzzle index being played (see `DailyGameService.todayIndex`)
  /// — pinned when chosen, so leaving the screen open past midnight can't
  /// mix two days' puzzles.
  late int _day = _svc.todayIndex;
  GameClueMovie? _mystery;
  bool _loadingMystery = true;
  bool _mysteryFailed = false;
  final Map<int, GameClueMovie> _guessCache = {};
  // Clue fetches already in flight / that failed, so build() doesn't fire a
  // fresh request for the same id on every rebuild, and a failed fetch
  // shows a retry instead of an endless progress bar.
  final Set<int> _guessFetching = {};
  final Set<int> _guessFetchFailed = {};
  // Only the guess just made flips in; older rows (and every row when
  // revisiting a day) render revealed instead of replaying the animation.
  int? _animateGuessId;
  // Bumped on every _loadMystery() so a slow response for a previously
  // selected day can't overwrite the mystery of the day now selected.
  int _mysteryRequest = 0;
  // Blocks a second guess while the first one's clue fetch + write is still
  // in flight (both would otherwise compute the same guess count).
  bool _submittingGuess = false;
  // One Firestore listener per selected day instead of a fresh subscription
  // on every rebuild (every search keystroke rebuilds this screen).
  int? _progressDay;
  Stream<DailyGamePlay>? _progress;

  @override
  void initState() {
    super.initState();
    if (!_isGuest) {
      _loadMystery();
      _maybeShowHowToPlay();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Shows the rules once, on the first ever visit — the tiles' colors and
  /// arrows aren't self-explanatory to someone who hasn't played Spotle.
  Future<void> _maybeShowHowToPlay() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(_howToSeenPrefsKey) ?? false)) return;
    await prefs.setBool(_howToSeenPrefsKey, true);
    if (mounted) _showHowToPlay();
  }

  Future<void> _loadMystery() async {
    final request = ++_mysteryRequest;
    setState(() {
      _loadingMystery = true;
      _mysteryFailed = false;
      _mystery = null;
    });
    try {
      final m = await _svc.mysteryMovieForDay(_day);
      if (!mounted || request != _mysteryRequest) return;
      setState(() {
        _mystery = m;
        _loadingMystery = false;
      });
    } catch (e, st) {
      // Without this the screen sat on an endless blank/loading state with no
      // hint why (pool doc unreadable, TMDB down, offline...).
      debugPrint('DailyGame: failed to load mystery movie: $e\n$st');
      if (!mounted || request != _mysteryRequest) return;
      setState(() {
        _loadingMystery = false;
        _mysteryFailed = true;
      });
    }
  }

  void _selectDay(int day) {
    if (day == _day) return;
    _debounce?.cancel();
    setState(() {
      _day = day;
      _animateGuessId = null;
      _clearSearch();
    });
    _loadMystery();
  }

  /// Call inside setState.
  void _clearSearch() {
    _searchController.clear();
    _searchResults = [];
    _searching = false;
    _searchFailed = false;
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(_clearSearch);
      return;
    }
    // Spinner straight away, so the debounce gap doesn't flash "No matching
    // movies".
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    try {
      final results = await _api.searchGameMovies(query);
      // A slower response for an older query (or one that resolves after a
      // guess cleared the field) must not overwrite the current results.
      if (!mounted || _searchController.text != query) return;
      setState(() {
        _searchResults = results.take(12).toList();
        _searching = false;
      });
    } catch (e) {
      debugPrint('DailyGame: search failed: $e');
      if (!mounted || _searchController.text != query) return;
      setState(() {
        _searchResults = [];
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  Future<void> _guess(MediaItem item, DailyGamePlay play) async {
    final mystery = _mystery;
    if (_submittingGuess ||
        mystery == null ||
        play.finished ||
        play.guessedIds.contains(item.id)) {
      return;
    }
    // Captured up front: the user can switch days from the app bar while the
    // clue fetch below is in flight, and the guess belongs to *this* day.
    final day = _day;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    _debounce?.cancel();
    // Drop the keyboard so the new row's reveal is actually visible.
    _searchFocus.unfocus();
    setState(() {
      _submittingGuess = true;
      _clearSearch();
    });
    try {
      final GameClueMovie clue;
      try {
        clue = await _svc.clueData(item.id);
      } catch (e) {
        debugPrint('DailyGame: clue fetch for guess ${item.id} failed: $e');
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.dailyGameGuessFailed)));
        return;
      }
      if (!mounted) return;
      setState(() {
        _guessCache[item.id] = clue;
        _guessFetchFailed.remove(item.id);
        if (day == _day) _animateGuessId = item.id;
      });

      final newGuessCount = play.guessedIds.length + 1;
      final won = item.id == mystery.id;
      final finished = won || newGuessCount >= dailyGameMaxGuesses;
      await _svc.recordGuess(
        day: day,
        guessedMovieId: item.id,
        won: won,
        finished: finished,
      );
    } catch (e, st) {
      debugPrint('DailyGame: guess failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    } finally {
      if (mounted) setState(() => _submittingGuess = false);
    }
  }

  void _fetchGuessClue(int id) {
    if (_guessCache.containsKey(id) || _guessFetching.contains(id)) return;
    _guessFetching.add(id);
    _svc.clueData(id).then((clue) {
      _guessFetching.remove(id);
      if (mounted) {
        setState(() {
          _guessCache[id] = clue;
          _guessFetchFailed.remove(id);
        });
      }
    }, onError: (Object e, StackTrace st) {
      debugPrint('DailyGame: clue fetch for $id failed: $e\n$st');
      _guessFetching.remove(id);
      if (mounted) setState(() => _guessFetchFailed.add(id));
    });
  }

  Stream<DailyGamePlay> _progressStream() {
    if (_progress == null || _progressDay != _day) {
      _progressDay = _day;
      _progress = _svc.progressStream(_day);
    }
    return _progress!;
  }

  bool get _isToday => _day == _svc.todayIndex;

  String _dayLabel(BuildContext context, int day) =>
      MaterialLocalizations.of(context)
          .formatMediumDate(_svc.dateForDay(day));

  String _clueLabel(AppLocalizations l10n, ClueKind kind) => switch (kind) {
        ClueKind.director => l10n.dailyGameClueDirector,
        ClueKind.studio => l10n.dailyGameClueStudio,
        ClueKind.year => l10n.dailyGameClueYear,
        ClueKind.revenue => l10n.dailyGameClueRevenue,
        ClueKind.rating => l10n.dailyGameClueRating,
        ClueKind.certification => l10n.dailyGameClueCertification,
        ClueKind.cast => l10n.dailyGameClueCast,
        ClueKind.genres => l10n.dailyGameClueGenres,
      };

  // --------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyGameTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: l10n.dailyGameHowToPlay,
            onPressed: _showHowToPlay,
          ),
          if (!_isGuest)
            PopupMenuButton<int>(
              icon: const Icon(Icons.calendar_month_rounded),
              tooltip: l10n.dailyGamePickAnotherDay,
              onSelected: _selectDay,
              itemBuilder: (context) {
                // Re-read on every open, so after midnight "Today" really
                // is the new day.
                final today = _svc.todayIndex;
                return [
                  for (var i = 0; i < dailyGameRewatchDays; i++)
                    PopupMenuItem(
                      value: today - i,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: today - i == _day
                                ? Icon(Icons.check_rounded,
                                    size: 18, color: context.colors.primary)
                                : null,
                          ),
                          Text(i == 0
                              ? l10n.dailyGameToday
                              : _dayLabel(context, today - i)),
                        ],
                      ),
                    ),
                ];
              },
            ),
        ],
      ),
      body: _isGuest
          ? _message(context, l10n.dailyGameSignInPrompt)
          : _loadingMystery
              ? asyncLoadingIndicator()
              : _mysteryFailed
                  ? _loadError(context, l10n, _loadMystery)
                  : _mystery == null
                      ? _message(context, l10n.dailyGameNoPool)
                      : _game(context, l10n, _mystery!),
    );
  }

  Widget _message(BuildContext context, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary)),
      ),
    );
  }

  Widget _loadError(
      BuildContext context, AppLocalizations l10n, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.errorGeneric,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.dailyGameRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _game(
      BuildContext context, AppLocalizations l10n, GameClueMovie mystery) {
    return StreamBuilder<DailyGamePlay>(
      stream: _progressStream(),
      builder: (context, snap) {
        // Until progress is known, don't offer the search box: a guess made
        // against a not-yet-loaded (empty) guess list would be counted
        // wrong, and a failed read used to look like a fresh, unplayed day.
        if (snap.hasError) {
          return _loadError(
              context, l10n, () => setState(() => _progress = null));
        }
        final play = snap.data;
        if (play == null) return asyncLoadingIndicator();

        for (final id in play.guessedIds) {
          if (!_guessFetchFailed.contains(id)) _fetchGuessClue(id);
        }
        final hintsUnlocked = dailyGameHintsUnlocked(play.guessedIds.length);
        final showSearchPanel =
            !play.finished && _searchController.text.trim().isNotEmpty;
        // Newest guess first, like Spotle — the latest reveal is the one
        // the player needs to see, and on a small phone the 10th guess
        // used to be far below the fold.
        final newestFirst = play.guessedIds.reversed.toList();

        return Column(
          children: [
            _statusBar(context, l10n, play),
            if (!play.finished) _searchField(context, l10n),
            Expanded(
              child: showSearchPanel
                  ? _searchPanel(context, l10n, play)
                  : ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(16, 8, 16,
                          16 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        if (play.finished)
                          _resultCard(context, l10n, mystery, play),
                        if (!play.finished && hintsUnlocked > 0)
                          _hintBanner(context, l10n, mystery, play.hintsUsed,
                              hintsUnlocked),
                        for (final id in newestFirst)
                          _guessRowFor(context, l10n, mystery, id,
                              play.guessedIds.indexOf(id) + 1),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusBar(
      BuildContext context, AppLocalizations l10n, DailyGamePlay play) {
    final left = dailyGameMaxGuesses - play.guessedIds.length;
    final nextHint = dailyGameHintUnlockGuesses
        .where((g) => g > play.guessedIds.length)
        .firstOrNull;
    final secondary = !_isToday
        ? l10n.dailyGamePuzzleFor(_dayLabel(context, _day))
        : (!play.finished && nextHint != null)
            ? l10n.dailyGameNextHint('$nextHint')
            : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          // Flexible: two unconstrained texts overflowed this Row on narrow
          // phones (iPhone SE) / with larger text or longer translations.
          Flexible(
            child: Text(
              play.finished
                  ? (play.won ? l10n.dailyGameWinTitle : l10n.dailyGameLoseTitle)
                  : l10n.dailyGameGuessesLeft('$left'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                secondary,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        enabled: !_submittingGuess,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.dailyGameSearchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searching || _submittingGuess
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip:
                          MaterialLocalizations.of(context).deleteButtonTooltip,
                      onPressed: () {
                        _debounce?.cancel();
                        setState(_clearSearch);
                      },
                    )
                  : null,
        ),
      ),
    );
  }

  /// Takes the whole area below the search box (instead of a fixed-height
  /// dropdown above the guesses), so with the keyboard up on an iPhone SE
  /// the results are still visible and the Column can't overflow.
  Widget _searchPanel(
      BuildContext context, AppLocalizations l10n, DailyGamePlay play) {
    if (_searchResults.isEmpty) {
      if (_searching) return const SizedBox.shrink();
      return _message(context,
          _searchFailed ? l10n.dailyGameSearchFailed : l10n.dailyGameNoResults);
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final item = _searchResults[i];
        final already = play.guessedIds.contains(item.id);
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 36,
              height: 54,
              child: TmdbImage(url: Tmdb.poster(item.posterPath, size: 'w92')),
            ),
          ),
          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(item.year),
          trailing: already
              ? Text(l10n.dailyGameGuessedAlready,
                  style: TextStyle(color: context.colors.textMuted, fontSize: 12))
              : null,
          enabled: !already && !_submittingGuess,
          onTap: () => _guess(item, play),
        );
      },
    );
  }

  Widget _hintBanner(BuildContext context, AppLocalizations l10n,
      GameClueMovie mystery, int hintsUsed, int hintsUnlocked) {
    // Hint 1: genres. Hint 2 (after guess 8): the top-billed actor — strong
    // on purpose, by then the player needs it. Falls back to the year if
    // TMDB has nothing for either.
    String hintText(int i) {
      final yearHint = '${l10n.dailyGameClueYear}: ${mystery.releaseYear}';
      if (i == 0) {
        return mystery.genres.isEmpty
            ? yearHint
            : '${l10n.dailyGameClueGenres}: ${mystery.genres.join(', ')}';
      }
      return mystery.cast.isEmpty
          ? yearHint
          : l10n.dailyGameHintTopBilled(mystery.cast.first);
    }

    final revealed = hintsUsed.clamp(0, hintsUnlocked);
    final canReveal = hintsUsed < hintsUnlocked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(Icons.lightbulb_rounded, color: context.colors.accent),
          title: Text(
              canReveal ? l10n.dailyGameHintUnlocked : l10n.dailyGameHints,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: canReveal
              ? TextButton(
                  onPressed: () => _svc
                      .useHint(_day, hintsUsed + 1)
                      .catchError((Object e) {
                    debugPrint('DailyGame: useHint failed: $e');
                  }),
                  child: Text(l10n.dailyGameShowHint),
                )
              : null,
          subtitle: revealed == 0
              ? null
              : Text(
                  [for (var i = 0; i < revealed; i++) hintText(i)].join('\n'),
                  style: TextStyle(color: context.colors.textPrimary),
                ),
        ),
      ),
    );
  }

  Widget _guessRowFor(BuildContext context, AppLocalizations l10n,
      GameClueMovie mystery, int id, int number) {
    final guess = _guessCache[id];
    if (guess == null && _guessFetchFailed.contains(id)) {
      return Padding(
        key: ValueKey('failed-$id'),
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(l10n.dailyGameRowFailed,
                  style: TextStyle(color: context.colors.textSecondary)),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() => _guessFetchFailed.remove(id));
                _fetchGuessClue(id);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.dailyGameRetry),
            ),
          ],
        ),
      );
    }
    if (guess == null) {
      return Padding(
        key: ValueKey('loading-$id'),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: const LinearProgressIndicator(),
      );
    }
    return _guessRow(context, l10n, guess, mystery, number);
  }

  Widget _guessRow(BuildContext context, AppLocalizations l10n,
      GameClueMovie guess, GameClueMovie mystery, int number) {
    final clues = compareGameClues(guess, mystery);
    final year = guess.releaseYear > 0 ? ' (${guess.releaseYear})' : '';
    return Padding(
      // Keyed by movie so a new guess inserted at the top doesn't hand the
      // older rows' tile states to different movies.
      key: ValueKey('guess-${guess.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('$number. ${guess.title}$year',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Fixed row height (growing with text scale) instead of an
            // aspect ratio: on an iPhone SE a 1.3 ratio made tiles ~52pt
            // tall and two-line values overflowed them.
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              mainAxisExtent: 12 + MediaQuery.textScalerOf(context).scale(52),
            ),
            children: [
              for (var i = 0; i < clues.length; i++)
                ClueTile(
                  label: _clueLabel(l10n, clues[i].kind),
                  value: clues[i].value,
                  match: clues[i].match,
                  direction: clues[i].direction,
                  index: i,
                  animate: guess.id == _animateGuessId,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context, AppLocalizations l10n,
      GameClueMovie mystery, DailyGamePlay play) {
    final year = mystery.releaseYear > 0 ? ' (${mystery.releaseYear})' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: play.won ? context.colors.success : context.colors.surfaceAlt,
            width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 108,
                  child: TmdbImage(
                      url: Tmdb.poster(mystery.posterPath, size: 'w185')),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        play.won
                            ? l10n.dailyGameSolvedIn(play.guessedIds.length)
                            : l10n.dailyGameAnswerWas,
                        style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${mystery.title}$year',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    if (mystery.directors.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(mystery.directors.join(', '),
                          style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12)),
                    ],
                    if (_isToday) ...[
                      const SizedBox(height: 8),
                      Text(l10n.dailyGamePlayAgainTomorrow,
                          style: TextStyle(
                              color: context.colors.textMuted, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MovieDetailsScreen(
                        // Sparse seed — the detail screen fills in overview,
                        // backdrop etc. itself.
                        movie: Movie(
                          id: mystery.id,
                          title: mystery.title,
                          overview: '',
                          posterPath: mystery.posterPath,
                          backDropPath: '',
                          releaseDate: '',
                          voteAverage: mystery.voteAverage,
                          genres: mystery.genres,
                        ),
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(l10n.dailyGameViewMovie,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _shareButton(context, l10n, mystery, play)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shareButton(BuildContext context, AppLocalizations l10n,
      GameClueMovie mystery, DailyGamePlay play) {
    return Builder(builder: (buttonContext) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: context.colors.brandGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _share(buttonContext, l10n, mystery, play),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.ios_share_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(l10n.dailyGameShareResult,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _share(BuildContext buttonContext, AppLocalizations l10n,
      GameClueMovie mystery, DailyGamePlay play) async {
    // iPad's share sheet is a popover and throws without an anchor rect.
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final dateLabel = _svc.dateKeyForDay(_day);
    // Every guess's clues, not just the rows loaded so far: sharing right
    // after reopening a finished day used to drop the still-loading rows
    // and report the wrong score (the score is the row count).
    final rows = <List<GameClue>>[];
    try {
      for (final id in play.guessedIds) {
        final guess = _guessCache[id] ?? await _svc.clueData(id);
        rows.add(compareGameClues(guess, mystery));
      }
    } catch (e) {
      debugPrint('DailyGame: share failed to load guesses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      }
      return;
    }
    final text = buildDailyGameShareText(
      gameTitle: l10n.dailyGameTitle,
      dateLabel: dateLabel,
      rows: rows,
      won: play.won,
    );
    try {
      await SharePlus.instance
          .share(ShareParams(text: text, sharePositionOrigin: origin));
    } catch (e) {
      debugPrint('DailyGame: share failed: $e');
    }
  }

  // -------------------------------------------------------- how to play ---

  void _showHowToPlay() {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    Widget swatch(Color color, {String text = '', BoxBorder? border}) =>
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color,
              border: border,
              borderRadius: BorderRadius.circular(6)),
          child: Text(text,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        );
    Widget rule(Widget lead, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              lead,
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.dailyGameHowToPlay,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 10),
              Text(l10n.dailyGameHowToIntro('$dailyGameMaxGuesses'),
                  style: TextStyle(color: colors.textSecondary)),
              const SizedBox(height: 16),
              rule(swatch(colors.success), l10n.dailyGameHowToGreen),
              rule(swatch(colors.accent), l10n.dailyGameHowToGold),
              rule(
                  swatch(colors.surfaceAlt,
                      text: '?',
                      border: Border.all(
                          color: colors.textMuted.withValues(alpha: 0.5))),
                  l10n.dailyGameHowToGray),
              rule(swatch(colors.surfaceAlt, text: '↑'),
                  l10n.dailyGameHowToArrows),
              rule(Icon(Icons.group_rounded, color: colors.accent, size: 26),
                  l10n.dailyGameHowToShared),
              rule(
                  Icon(Icons.lightbulb_rounded,
                      color: colors.accent, size: 26),
                  l10n.dailyGameHowToHints('${dailyGameHintUnlockGuesses[0]}',
                      '${dailyGameHintUnlockGuesses[1]}')),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.dailyGameGotIt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
