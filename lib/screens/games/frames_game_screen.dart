import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/games/game_common_widgets.dart';
import 'package:watch_verse/services/games/frames_logic.dart';
import 'package:watch_verse/services/games/game_day.dart';
import 'package:watch_verse/services/games/game_play_store.dart';
import 'package:watch_verse/services/games/games_tmdb.dart';
import 'package:watch_verse/services/games/pools/frames_pools.g.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// Daily "Frames" game (Framed-style): name today's movie or TV show from
/// its stills. One still to start; every wrong guess or skip reveals the
/// next, up to [framesMaxStills]. Movie and TV each have their own daily
/// puzzle from the bundled pools (`pools/frames_pools.g.dart`).
class FramesGameScreen extends StatefulWidget {
  const FramesGameScreen({super.key, this.store, this.tmdb});

  /// Test seams; production uses [GamePlayStore.instance] and a real client.
  @visibleForTesting
  final GamePlayStore? store;
  @visibleForTesting
  final GamesTmdb? tmdb;

  @override
  State<FramesGameScreen> createState() => _FramesGameScreenState();
}

class _FramesGameScreenState extends State<FramesGameScreen> {
  MediaType _mode = MediaType.movie;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.framesGameTitle)),
      body: Column(
        children: [
          GameModeToggle(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          Expanded(
            child: GameModeStack(
              mode: _mode,
              builder: (m) =>
                  _FramesBoard(mode: m, store: widget.store, tmdb: widget.tmdb),
            ),
          ),
        ],
      ),
    );
  }
}

class _FramesBoard extends StatefulWidget {
  final MediaType mode;
  final GamePlayStore? store;
  final GamesTmdb? tmdb;
  const _FramesBoard({required this.mode, this.store, this.tmdb});

  @override
  State<_FramesBoard> createState() => _FramesBoardState();
}

class _FramesBoardState extends State<_FramesBoard> {
  late final _tmdb = widget.tmdb ?? GamesTmdb();
  late final _store = widget.store ?? GamePlayStore.instance;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _searchFieldKey = GlobalKey();
  Timer? _debounce;

  late final int _puzzleNumber;
  late final String _docId;
  late final int _answerId;

  FramesPuzzle? _puzzle;
  FramesState? _state;
  bool _loading = true;
  bool _failed = false;
  int _viewIndex = 0;

  List<MediaItem> _results = const [];
  bool _searching = false;
  bool _searchFailed = false;
  int _searchRequest = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _puzzleNumber = gamePuzzleNumber(now);
    _docId = gamePlayDocId('frames', widget.mode, gameDateKey(now));
    _answerId = dailyPoolEntry(
      widget.mode == MediaType.movie ? framesMoviePool : framesTvPool,
      _puzzleNumber,
    );
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    if (widget.tmdb == null) _tmdb.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait([
        _tmdb.framesPuzzle(widget.mode, _answerId),
        _store.load(_docId),
      ]);
      if (!mounted) return;
      final state = FramesState.fromMap(
        _answerId,
        results[1] as Map<String, dynamic>?,
      );
      setState(() {
        _puzzle = results[0] as FramesPuzzle;
        _state = state;
        _viewIndex = state.finished ? 0 : state.stillsUnlocked - 1;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Frames: failed to load puzzle: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  // ------------------------------------------------------------- search ---

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    final request = ++_searchRequest;
    if (query.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _searchFailed = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await _tmdb.search(widget.mode, query);
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _results = results;
        _searching = false;
        _searchFailed = false;
      });
      _revealSearchField();
    } catch (e) {
      debugPrint('Frames: search failed: $e');
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  /// Scrolls the search field to the top so its results sit above the
  /// keyboard instead of under it (matters on an iPhone SE).
  void _revealSearchField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _searchFieldKey.currentContext;
      if (ctx == null || !_searchFocus.hasFocus) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 200),
        alignment: 0.05,
      );
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchRequest++;
    _searchController.clear();
    _results = const [];
    _searching = false;
    _searchFailed = false;
  }

  // -------------------------------------------------------------- moves ---

  Future<void> _submit(FramesGuess guess) async {
    final state = _state;
    if (state == null || _saving) return;
    final next = state.submit(guess);
    if (next == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _clearSearch();
      _state = next;
      _viewIndex = next.finished ? _viewIndex : next.stillsUnlocked - 1;
      _saving = true;
    });
    try {
      await _store.save(_docId, next.toMap());
    } catch (e) {
      debugPrint('Frames: save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.gamesCommonSaveFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _share() {
    final state = _state;
    if (state == null) return;
    SharePlus.instance.share(
      ShareParams(
        text: framesShareText(
          puzzleNumber: _puzzleNumber,
          mode: widget.mode,
          state: state,
        ),
      ),
    );
  }

  // -------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final puzzle = _puzzle;
    final state = _state;
    if (_failed || puzzle == null || state == null) {
      return GameLoadError(onRetry: _load);
    }
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final isMovie = widget.mode == MediaType.movie;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Wrap, not Row: long translations / large text wrap to a second
        // line instead of overflowing on an iPhone SE.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 2,
          children: [
            Text(
              l10n.gamesCommonPuzzleNumber('$_puzzleNumber'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (!state.finished)
              Text(
                l10n.gamesCommonGuessesLeft(
                  '${framesMaxStills - state.guesses.length}',
                ),
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
          ],
        ),
        if (state.guesses.isEmpty) ...[
          const SizedBox(height: 4),
          Text(
            isMovie ? l10n.framesGameIntroMovie : l10n.framesGameIntroTv,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ],
        const SizedBox(height: 10),
        _still(context, puzzle),
        const SizedBox(height: 10),
        _frameSelector(context, state),
        const SizedBox(height: 14),
        if (!state.finished) ...[
          _searchRow(context, l10n, isMovie),
          _searchResults(context, l10n, state),
        ] else
          GameResultPanel(
            won: state.won,
            guessCount: state.guesses.length,
            maxGuesses: framesMaxStills,
            title: puzzle.item.title,
            year: puzzle.item.year,
            posterPath: puzzle.item.posterPath,
            onShare: _share,
            onDetails: () => openMedia(context, puzzle.item),
          ),
        if (state.guesses.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final g in state.guesses) _guessTile(context, l10n, state, g),
        ],
        if (!_store.isSignedIn) ...[
          const SizedBox(height: 16),
          const GameGuestNote(),
        ],
      ],
    );
  }

  Widget _still(BuildContext context, FramesPuzzle puzzle) {
    final index = _viewIndex.clamp(0, puzzle.stills.length - 1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: TmdbImage(
            key: ValueKey(puzzle.stills[index]),
            url: Tmdb.backdrop(puzzle.stills[index]),
          ),
        ),
      ),
    );
  }

  Widget _frameSelector(BuildContext context, FramesState state) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        for (var i = 0; i < framesMaxStills; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Builder(
              builder: (context) {
                final unlocked = i < state.stillsUnlocked;
                final selected = i == _viewIndex;
                final guess = i < state.guesses.length
                    ? state.guesses[i]
                    : null;
                final Color fill = guess == null
                    ? colors.surfaceAlt
                    : guess.isSkip
                    ? colors.textMuted
                    : guess.id == state.answerId
                    ? colors.success
                    : colors.primaryDark;
                return Semantics(
                  button: unlocked,
                  label: l10n.framesGameFrameLabel('${i + 1}'),
                  child: Material(
                    color: fill.withValues(alpha: guess == null ? 1 : 0.85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selected
                            ? colors.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: unlocked
                          ? () => setState(() => _viewIndex = i)
                          : null,
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        child: unlocked
                            ? Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  // Dark theme's green is light: white
                                  // on it was barely readable.
                                  color: guess == null
                                      ? colors.textPrimary
                                      : fill.computeLuminance() > 0.4
                                      ? Colors.black87
                                      : Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: colors.textMuted,
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _searchRow(BuildContext context, AppLocalizations l10n, bool isMovie) {
    return Row(
      key: _searchFieldKey,
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              isDense: true,
              hintText: isMovie
                  ? l10n.framesGameSearchHintMovie
                  : l10n.framesGameSearchHintTv,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _saving ? null : () => _submit(const FramesGuess.skip()),
          child: Text(l10n.framesGameSkip),
        ),
      ],
    );
  }

  Widget _searchResults(
    BuildContext context,
    AppLocalizations l10n,
    FramesState state,
  ) {
    final colors = context.colors;
    if (_searchFailed) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _runSearch(_searchController.text),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.gamesCommonRetry),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      final noMatches =
          !_searching &&
          _searchController.text.trim().isNotEmpty &&
          _debounce?.isActive != true;
      return noMatches
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                l10n.framesGameNoResults,
                style: TextStyle(color: colors.textMuted),
              ),
            )
          : const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.surfaceAlt),
        ),
        child: Column(
          children: [
            for (final item in _results)
              Builder(
                builder: (context) {
                  final already = state.hasGuessed(item.id);
                  return ListTile(
                    dense: true,
                    enabled: !already && !_saving,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 32,
                        height: 48,
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
                            l10n.framesGameAlreadyGuessed,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    onTap: () => _submit(FramesGuess(item.id, item.title)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _guessTile(
    BuildContext context,
    AppLocalizations l10n,
    FramesState state,
    FramesGuess g,
  ) {
    final colors = context.colors;
    final correct = g.id == state.answerId;
    final IconData icon;
    final Color color;
    if (g.isSkip) {
      icon = Icons.skip_next_rounded;
      color = colors.textMuted;
    } else if (correct) {
      icon = Icons.check_circle_rounded;
      color = colors.success;
    } else {
      icon = Icons.cancel_rounded;
      color = colors.primaryDark;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              g.isSkip ? l10n.framesGameSkipped : g.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: g.isSkip ? colors.textMuted : colors.textPrimary,
                fontWeight: correct ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
