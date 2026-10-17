import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/games/game_common_widgets.dart';
import 'package:watch_verse/services/games/game_day.dart';
import 'package:watch_verse/services/games/plot_guess_logic.dart';
import 'package:watch_verse/services/games/plot_guess_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/utils/responsive.dart';

/// Daily "Plot" game: guess today's movie (or show) from its TMDB overview
/// with names redacted. Every wrong guess or skip unlocks the next clue
/// (rest of the plot → year → genres → top-billed actor → tagline), up to
/// [plotGameMaxAttempts] attempts. See [PlotGuessService] for where puzzles
/// come from and how progress is stored.
class PlotGuessScreen extends StatefulWidget {
  const PlotGuessScreen({
    super.key,
    this.initialMode = PlotGameMode.movie,
    this.service,
  });

  final PlotGameMode initialMode;

  /// Injectable for tests; defaults to [PlotGuessService.instance].
  final PlotGuessService? service;

  @override
  State<PlotGuessScreen> createState() => _PlotGuessScreenState();
}

class _PlotGuessScreenState extends State<PlotGuessScreen> {
  late final PlotGuessService _service =
      widget.service ?? PlotGuessService.instance;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  // Same as the daily movie game: progress lives in the owner-only
  // `gamePlays` collection, so guests get a sign-in prompt.
  late final bool _isGuest = !_service.isSignedIn;

  /// Pinned when the screen opens, so a puzzle in progress doesn't swap
  /// under the player at midnight EST.
  final DateTime _now = DateTime.now();

  late PlotGameMode _mode = widget.initialMode;
  final Map<PlotGameMode, Future<PlotPuzzle?>> _puzzles = {};
  final Map<PlotGameMode, Stream<List<PlotAttempt>>> _attemptStreams = {};

  /// Attempts written locally but maybe not yet echoed by Firestore — the UI
  /// never waits on a server round trip (or hangs offline) to show a guess.
  final Map<PlotGameMode, List<PlotAttempt>> _localAttempts = {};

  List<MediaItem> _results = [];
  bool _searching = false;
  bool _searchFailed = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<PlotPuzzle?> _puzzle(PlotGameMode mode) =>
      _puzzles[mode] ??= _service.puzzleFor(mode, _now);

  Stream<List<PlotAttempt>> _attempts(PlotGameMode mode) =>
      _attemptStreams[mode] ??= _service.attemptsStream(mode, _now);

  void _selectMode(int index) {
    final mode = PlotGameMode.values[index];
    if (mode == _mode) return;
    _debounce?.cancel();
    setState(() {
      // Firestore snapshot streams are single-subscription: the mode we come
      // back to gets a fresh one rather than re-listening to a used stream.
      _attemptStreams.clear();
      _mode = mode;
      _searchController.clear();
      _results = [];
      _searchFailed = false;
      _searching = false;
    });
  }

  // ------------------------------------------------------------- search ---

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String query) async {
    _lastQuery = query;
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
        _searchFailed = false;
      });
      return;
    }
    final mode = _mode;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final results = await _service.search(mode, query);
      // A slower response for an older query or another mode must not
      // overwrite what's on screen now.
      if (!mounted || query != _lastQuery || mode != _mode) return;
      setState(() {
        _results = results.take(8).toList();
        _searching = false;
      });
    } catch (e) {
      debugPrint('PlotGame: search failed: $e');
      if (!mounted || query != _lastQuery) return;
      setState(() {
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  // ------------------------------------------------------------ attempts ---

  List<PlotAttempt> _effectiveAttempts(
    PlotGameMode mode,
    List<PlotAttempt> remote,
  ) {
    final local = _localAttempts[mode];
    return local != null && local.length >= remote.length ? local : remote;
  }

  void _submit(PlotPuzzle puzzle, List<PlotAttempt> current, PlotAttempt a) {
    final mode = _mode;
    final before = plotGameProgress(current, puzzle.id);
    if (before.finished) return;
    if (!a.isSkip && current.any((e) => e.id == a.id)) return;
    final next = [...before.attempts, a];
    final progress = plotGameProgress(next, puzzle.id);
    _debounce?.cancel();
    setState(() {
      _localAttempts[mode] = next;
      _searchController.clear();
      _results = [];
      _lastQuery = '';
    });
    if (progress.finished) _searchFocus.unfocus();
    _service
        .saveAttempts(mode: mode, now: _now, attempts: next, progress: progress)
        .catchError((Object e) {
          debugPrint('PlotGame: saving attempt failed: $e');
          if (!mounted) return;
          setState(() => _localAttempts[mode] = current);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)),
          );
        });
  }

  // --------------------------------------------------------------- build ---

  String _modeLabel(AppLocalizations l10n, PlotGameMode m) =>
      m == PlotGameMode.movie ? l10n.plotGameModeMovie : l10n.plotGameModeTv;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.plotGameTitle)),
      // Games keep a phone-width column on wide windows (iPhone Duo
      // unfolded, landscape) rather than stretching edge to edge.
      body: ReadableWidth(child: Column(
        children: [
          GameModeTabs(
            labels: [for (final m in PlotGameMode.values) _modeLabel(l10n, m)],
            icons: const [Icons.movie_outlined, Icons.tv_rounded],
            selected: _mode.index,
            onChanged: _selectMode,
          ),
          Expanded(
            child: _isGuest
                ? _message(context, l10n.plotGameSignInPrompt)
                : _modeBody(context, l10n),
          ),
        ],
      )),
    );
  }

  Widget _message(BuildContext context, String text) => GameMessage(
    icon: _isGuest ? Icons.lock_outline_rounded : Icons.hourglass_empty_rounded,
    text: text,
  );

  Widget _modeBody(BuildContext context, AppLocalizations l10n) {
    final mode = _mode;
    return FutureBuilder<PlotPuzzle?>(
      key: ValueKey(mode),
      future: _puzzle(mode),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const GameLoading();
        }
        if (snap.hasError) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              asyncErrorView(context, snap.error!),
              TextButton.icon(
                onPressed: () => setState(() => _puzzles.remove(mode)),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retryAction),
              ),
            ],
          );
        }
        final puzzle = snap.data;
        if (puzzle == null) return _message(context, l10n.plotGameNoPuzzle);
        return StreamBuilder<List<PlotAttempt>>(
          stream: _attempts(mode),
          builder: (context, attemptsSnap) {
            if (attemptsSnap.hasError) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  asyncErrorView(context, attemptsSnap.error!),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _attemptStreams.remove(mode)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retryAction),
                  ),
                ],
              );
            }
            if (!attemptsSnap.hasData && _localAttempts[mode] == null) {
              return const GameLoading();
            }
            final attempts = _effectiveAttempts(
              mode,
              attemptsSnap.data ?? const [],
            );
            return _game(context, l10n, puzzle, attempts);
          },
        );
      },
    );
  }

  Widget _game(
    BuildContext context,
    AppLocalizations l10n,
    PlotPuzzle puzzle,
    List<PlotAttempt> attempts,
  ) {
    final colors = context.colors;
    final progress = plotGameProgress(attempts, puzzle.id);
    final order = plotClueOrder(puzzle);
    final revealed = plotRevealedClues(
      puzzle,
      progress.missed,
      finished: progress.finished,
    );
    final locked = order.skip(revealed.length).toList();
    final split = plotOpeningSplit(puzzle.redactedOverview);
    final showRest =
        revealed.contains(PlotClueKind.plotRest) && split.rest.isNotEmpty;
    final pips = [
      for (var i = 0; i < progress.attempts.length; i++) _pip(progress, i),
    ];
    // The clue the last miss unlocked gets a "New clue" tag.
    final newest =
        !progress.finished && progress.missed > 0 && revealed.isNotEmpty
        ? revealed.last
        : null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              GameHeader(
                title: l10n.gamesCommonPuzzleNumber(
                  '${gamePuzzleNumber(_now.toUtc())}',
                ),
                subtitle: gameDateLabel(context, gameEstDate(_now.toUtc())),
                pips: pips,
                total: plotGameMaxAttempts,
                finished: progress.finished,
                status: progress.finished
                    ? null
                    : l10n.plotGameAttemptsLeft(progress.attemptsLeft),
              ),
              const SizedBox(height: 12),
              // Finished: the answer goes first — no scrolling past the
              // clues to find out what it was.
              if (progress.finished) ...[
                _resultPanel(context, l10n, puzzle, progress),
                const SizedBox(height: 12),
              ],
              if (progress.attempts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GameIntro(l10n.plotGameIntro),
                ),
              _card(
                context,
                label: l10n.plotGameCluePlot,
                icon: Icons.menu_book_rounded,
                isNew: newest == PlotClueKind.plotRest,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: split.opening),
                      if (showRest) TextSpan(text: ' ${split.rest}'),
                    ],
                  ),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              for (final kind in revealed)
                if (kind != PlotClueKind.plotRest)
                  _card(
                    context,
                    label: _clueLabel(l10n, kind),
                    icon: _clueIcon(kind),
                    isNew: newest == kind,
                    child: Text(
                      _clueValue(puzzle, kind),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontStyle: kind == PlotClueKind.tagline
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
              for (var i = 0; i < locked.length; i++)
                _lockedTile(context, l10n, locked[i], first: i == 0),
              if (progress.attempts.isNotEmpty) ...[
                const SizedBox(height: 8),
                GameGuessList(
                  guesses: [
                    for (var i = 0; i < progress.attempts.length; i++)
                      GameGuessEntry(progress.attempts[i].title, pips[i]),
                  ],
                  skippedLabel: l10n.plotGameSkipped,
                ),
              ],
            ],
          ),
        ),
        if (!progress.finished)
          _guessBar(context, l10n, puzzle, progress.attempts),
      ],
    );
  }

  static GamePip _pip(PlotGameProgress progress, int i) {
    if (progress.won && i == progress.attempts.length - 1) {
      return GamePip.correct;
    }
    return progress.attempts[i].isSkip ? GamePip.skipped : GamePip.wrong;
  }

  String _clueLabel(AppLocalizations l10n, PlotClueKind k) => switch (k) {
    PlotClueKind.plotRest => l10n.plotGameClueMorePlot,
    PlotClueKind.year => l10n.plotGameClueYear,
    PlotClueKind.genres => l10n.plotGameClueGenres,
    PlotClueKind.actor => l10n.plotGameClueActor,
    PlotClueKind.tagline => l10n.plotGameClueTagline,
    PlotClueKind.secondActor => l10n.plotGameClueSecondActor,
  };

  IconData _clueIcon(PlotClueKind k) => switch (k) {
    PlotClueKind.plotRest => Icons.notes_rounded,
    PlotClueKind.year => Icons.event_rounded,
    PlotClueKind.genres => Icons.theater_comedy_rounded,
    PlotClueKind.actor => Icons.person_rounded,
    PlotClueKind.tagline => Icons.format_quote_rounded,
    PlotClueKind.secondActor => Icons.people_alt_rounded,
  };

  String _clueValue(PlotPuzzle p, PlotClueKind k) => switch (k) {
    PlotClueKind.plotRest => plotOpeningSplit(p.redactedOverview).rest,
    PlotClueKind.year => '${p.year}',
    PlotClueKind.genres => p.genres.join(', '),
    PlotClueKind.actor => p.cast.isNotEmpty ? p.cast.first : '',
    PlotClueKind.tagline => '“${p.tagline}”',
    PlotClueKind.secondActor => p.cast.length > 1 ? p.cast[1] : '',
  };

  Widget _card(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Widget child,
    bool isNew = false,
  }) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNew
              ? colors.accent.withValues(alpha: 0.6)
              : colors.surfaceAlt,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: GameSectionLabel(label, icon: icon)),
              if (isNew)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.plotGameNewClue,
                    style: TextStyle(
                      color: gameOnFill(colors.accent),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _lockedTile(
    BuildContext context,
    AppLocalizations l10n,
    PlotClueKind kind, {
    required bool first,
  }) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: colors.surfaceAlt),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 16, color: colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _clueLabel(l10n, kind),
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (first)
            Flexible(
              child: Text(
                l10n.plotGameNextClueLocked,
                textAlign: TextAlign.end,
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _guessBar(
    BuildContext context,
    AppLocalizations l10n,
    PlotPuzzle puzzle,
    List<PlotAttempt> attempts,
  ) {
    final colors = context.colors;
    final query = _searchController.text.trim();
    // Room for results above the field without pushing it off-screen when
    // the keyboard is up on a small phone.
    final maxResultsHeight = math.min(
      240.0,
      MediaQuery.sizeOf(context).height * 0.28,
    );
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Only once the debounced search for this exact text is back —
              // not while the player is still typing.
              if (query.isNotEmpty &&
                  _lastQuery.trim() == query &&
                  !_searching &&
                  _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _searchFailed ? l10n.errorGeneric : l10n.plotGameNoResults,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ),
              if (_results.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxResultsHeight),
                  child: ListView.builder(
                    shrinkWrap: true,
                    reverse: true, // closest match sits right above the field
                    padding: EdgeInsets.zero,
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final item = _results[i];
                      final already = attempts.any((a) => a.id == item.id);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 32,
                            height: 46,
                            child: TmdbImage(
                              url: Tmdb.poster(item.posterPath, size: 'w92'),
                            ),
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: item.year.isEmpty ? null : Text(item.year),
                        trailing: already
                            ? Text(
                                l10n.plotGameAlreadyGuessed,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        enabled: !already,
                        onTap: already
                            ? null
                            : () => _submit(
                                puzzle,
                                attempts,
                                PlotAttempt(id: item.id, title: item.title),
                              ),
                      );
                    },
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: GameSearchField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onQueryChanged,
                      onSubmitted: _search,
                      busy: _searching,
                      hint: _mode == PlotGameMode.movie
                          ? l10n.plotGameSearchMovieHint
                          : l10n.plotGameSearchTvHint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GameSkipButton(
                    label: l10n.plotGameSkip,
                    onPressed: () =>
                        _submit(puzzle, attempts, const PlotAttempt.skip()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultPanel(
    BuildContext context,
    AppLocalizations l10n,
    PlotPuzzle puzzle,
    PlotGameProgress progress,
  ) {
    final item = MediaItem(
      id: puzzle.id,
      title: puzzle.title,
      overview: '',
      posterPath: puzzle.posterPath,
      backdropPath: '',
      date: puzzle.year > 0 ? '${puzzle.year}' : '',
      voteAverage: 0,
      mediaType: _mode == PlotGameMode.tv ? MediaType.tv : MediaType.movie,
    );
    final share = plotGameShareText(
      header: 'WatchVerse ${l10n.plotGameTitle} · ${_modeLabel(l10n, _mode)}',
      dateKey: plotGameDateKey(_now),
      progress: progress,
    );
    return GameResultPanel(
      won: progress.won,
      guessCount: progress.attempts.length,
      maxGuesses: plotGameMaxAttempts,
      title: puzzle.title,
      year: puzzle.year > 0 ? '${puzzle.year}' : '',
      posterPath: puzzle.posterPath,
      headline: progress.won ? l10n.plotGameWinTitle : l10n.plotGameLoseTitle,
      summary: progress.won
          ? l10n.plotGameSolvedIn(progress.attempts.length, plotGameMaxAttempts)
          : null,
      detailsLabel: l10n.plotGameViewDetails,
      comeBackText: l10n.plotGameComeBack,
      onShare: () => SharePlus.instance.share(ShareParams(text: share)),
      onDetails: () => openMedia(context, item),
    );
  }
}
