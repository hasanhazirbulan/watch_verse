import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/games/plot_guess_logic.dart';
import 'package:watch_verse/services/games/plot_guess_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/utils/genre_names.dart';

/// Daily "Plot" game: guess today's movie (or show) from its TMDB overview
/// with names redacted. Every wrong guess or skip unlocks the next clue
/// (rest of the plot → year → genres → top-billed actor → tagline), up to
/// [plotGameMaxAttempts] attempts. See [PlotGuessService] for where puzzles
/// come from and how progress is stored.
class PlotGuessScreen extends StatefulWidget {
  const PlotGuessScreen(
      {super.key, this.initialMode = PlotGameMode.movie, this.service});

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
      PlotGameMode mode, List<PlotAttempt> remote) {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.errorGeneric)));
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedTabs(
              labels: [
                for (final m in PlotGameMode.values) _modeLabel(l10n, m),
              ],
              selected: _mode.index,
              onChanged: _selectMode,
            ),
          ),
          Expanded(
            child: _isGuest
                ? _message(context, l10n.plotGameSignInPrompt)
                : _modeBody(context, l10n),
          ),
        ],
      ),
    );
  }

  Widget _message(BuildContext context, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary)),
        ),
      );

  Widget _modeBody(BuildContext context, AppLocalizations l10n) {
    final mode = _mode;
    return FutureBuilder<PlotPuzzle?>(
      key: ValueKey(mode),
      future: _puzzle(mode),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return asyncLoadingIndicator();
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
              return asyncLoadingIndicator();
            }
            final attempts =
                _effectiveAttempts(mode, attemptsSnap.data ?? const []);
            return _game(context, l10n, puzzle, attempts);
          },
        );
      },
    );
  }

  Widget _game(BuildContext context, AppLocalizations l10n, PlotPuzzle puzzle,
      List<PlotAttempt> attempts) {
    final colors = context.colors;
    final progress = plotGameProgress(attempts, puzzle.id);
    final order = plotClueOrder(puzzle);
    final revealed =
        plotRevealedClues(puzzle, progress.missed, finished: progress.finished);
    final locked = order.skip(revealed.length).toList();
    final split = plotOpeningSplit(puzzle.redactedOverview);
    final showRest =
        revealed.contains(PlotClueKind.plotRest) && split.rest.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // Finished: the answer goes first — no scrolling past the
              // clues to find out what it was.
              if (progress.finished) ...[
                _resultPanel(context, l10n, puzzle, progress),
                const SizedBox(height: 12),
              ],
              if (progress.attempts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(l10n.plotGameIntro,
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 13)),
                ),
              if (!progress.finished)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l10n.plotGameAttemptsLeft(progress.attemptsLeft),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              _card(
                context,
                label: l10n.plotGameCluePlot,
                icon: Icons.menu_book_rounded,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: split.opening),
                    if (showRest) TextSpan(text: ' ${split.rest}'),
                  ]),
                  style: TextStyle(
                      color: colors.textPrimary, fontSize: 15, height: 1.4),
                ),
              ),
              for (final kind in revealed)
                if (kind != PlotClueKind.plotRest)
                  _card(context,
                      label: _clueLabel(l10n, kind),
                      icon: _clueIcon(kind),
                      child: Text(_clueValue(puzzle, kind),
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontStyle: kind == PlotClueKind.tagline
                                  ? FontStyle.italic
                                  : FontStyle.normal))),
              for (var i = 0; i < locked.length; i++)
                _lockedTile(context, l10n, locked[i], first: i == 0),
              if (progress.attempts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < progress.attempts.length; i++)
                      _attemptChip(context, l10n, progress.attempts[i],
                          correct: progress.won &&
                              i == progress.attempts.length - 1),
                  ],
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
        PlotClueKind.genres => localizedGenreText(
            p.genres.join(', '), Localizations.localeOf(context).languageCode),
        PlotClueKind.actor => p.cast.isNotEmpty ? p.cast.first : '',
        PlotClueKind.tagline => '“${p.tagline}”',
        PlotClueKind.secondActor => p.cast.length > 1 ? p.cast[1] : '',
      };

  Widget _card(BuildContext context,
      {required String label, required IconData icon, required Widget child}) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colors.accent),
              const SizedBox(width: 6),
              Text(label.toUpperCase(),
                  style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _lockedTile(BuildContext context, AppLocalizations l10n,
      PlotClueKind kind,
      {required bool first}) {
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
            child: Text(_clueLabel(l10n, kind),
                style: TextStyle(
                    color: colors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          if (first)
            Flexible(
              child: Text(l10n.plotGameNextClueLocked,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: colors.textMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _attemptChip(
      BuildContext context, AppLocalizations l10n, PlotAttempt a,
      {required bool correct}) {
    final colors = context.colors;
    final error = Theme.of(context).colorScheme.error;
    final color =
        correct ? colors.success : (a.isSkip ? colors.textMuted : error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              correct
                  ? Icons.check_rounded
                  : (a.isSkip ? Icons.redo_rounded : Icons.close_rounded),
              size: 14,
              color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(a.isSkip ? l10n.plotGameSkipped : a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _guessBar(BuildContext context, AppLocalizations l10n,
      PlotPuzzle puzzle, List<PlotAttempt> attempts) {
    final colors = context.colors;
    final query = _searchController.text.trim();
    // Room for results above the field without pushing it off-screen when
    // the keyboard is up on a small phone.
    final maxResultsHeight =
        math.min(240.0, MediaQuery.sizeOf(context).height * 0.28);
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
                      style: TextStyle(color: colors.textMuted, fontSize: 12)),
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
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 32,
                            height: 46,
                            child: TmdbImage(
                                url: Tmdb.poster(item.posterPath, size: 'w92')),
                          ),
                        ),
                        title: Text(item.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: item.year.isEmpty ? null : Text(item.year),
                        trailing: already
                            ? Text(l10n.plotGameAlreadyGuessed,
                                style: TextStyle(
                                    color: colors.textMuted, fontSize: 12))
                            : null,
                        enabled: !already,
                        onTap: already
                            ? null
                            : () => _submit(puzzle, attempts,
                                PlotAttempt(id: item.id, title: item.title)),
                      );
                    },
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: _mode == PlotGameMode.movie
                            ? l10n.plotGameSearchMovieHint
                            : l10n.plotGameSearchTvHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        _submit(puzzle, attempts, const PlotAttempt.skip()),
                    child: Text(l10n.plotGameSkip),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultPanel(BuildContext context, AppLocalizations l10n,
      PlotPuzzle puzzle, PlotGameProgress progress) {
    final colors = context.colors;
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(progress.won ? l10n.plotGameWinTitle : l10n.plotGameLoseTitle,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          if (progress.won)
            Text(
                l10n.plotGameSolvedIn(
                    progress.attempts.length, plotGameMaxAttempts),
                style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => openMedia(context, item),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 90,
                    child: TmdbImage(
                        url: Tmdb.poster(puzzle.posterPath, size: 'w185')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(puzzle.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      if (puzzle.year > 0)
                        Text('${puzzle.year}',
                            style: TextStyle(color: colors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(l10n.plotGameViewDetails,
                          style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () =>
                  SharePlus.instance.share(ShareParams(text: share)),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(l10n.plotGameShare,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.plotGameComeBack,
              style: TextStyle(color: colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
