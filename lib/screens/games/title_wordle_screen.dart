import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/games/game_common_widgets.dart';
import 'package:watch_verse/services/games/game_day.dart';
import 'package:watch_verse/services/games/game_play_store.dart';
import 'package:watch_verse/services/games/pools/title_wordle_pools.g.dart';
import 'package:watch_verse/services/games/title_wordle_logic.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/utils/responsive.dart';

/// Daily "Title Wordle": guess a well-known movie or TV show title letter by
/// letter with Wordle feedback, in [titleWordleMaxGuesses] tries. Titles are
/// normalized to A–Z (5–8 letters); multi-word titles show the word breaks
/// as gaps and the player types letters only. Movie and TV each have their
/// own daily answer from the bundled pools (`pools/title_wordle_pools.g.dart`).
class TitleWordleScreen extends StatefulWidget {
  const TitleWordleScreen({super.key, this.store});

  /// Test seam; production uses [GamePlayStore.instance].
  @visibleForTesting
  final GamePlayStore? store;

  @override
  State<TitleWordleScreen> createState() => _TitleWordleScreenState();
}

class _TitleWordleScreenState extends State<TitleWordleScreen> {
  MediaType _mode = MediaType.movie;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.titleWordleTitle)),
      // Games keep a phone-width column on wide windows (iPhone Duo
      // unfolded, landscape) rather than stretching edge to edge.
      body: ReadableWidth(child: SafeArea(
        top: false,
        child: Column(
          children: [
            GameModeToggle(
              mode: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
            Expanded(
              child: GameModeStack(
                mode: _mode,
                builder: (m) => _WordleBoard(
                  mode: m,
                  active: m == _mode,
                  store: widget.store,
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}

class _WordleBoard extends StatefulWidget {
  final MediaType mode;

  /// Only the visible board listens to the hardware keyboard.
  final bool active;
  final GamePlayStore? store;
  const _WordleBoard({required this.mode, required this.active, this.store});

  @override
  State<_WordleBoard> createState() => _WordleBoardState();
}

class _WordleBoardState extends State<_WordleBoard> {
  late final _store = widget.store ?? GamePlayStore.instance;
  final _focus = FocusNode();

  late final int _puzzleNumber;
  late final DateTime _date;
  late final String _docId;
  late final WordlePoolEntry _entry;

  TitleWordleState? _state;
  bool _loading = true;
  bool _failed = false;
  String _input = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _puzzleNumber = gamePuzzleNumber(now);
    _date = gameEstDate(now);
    _docId = gamePlayDocId('titleWordle', widget.mode, gameDateKey(now));
    _entry = dailyPoolEntry(
      widget.mode == MediaType.movie ? titleWordleMoviePool : titleWordleTvPool,
      _puzzleNumber,
    );
    _load();
  }

  @override
  void didUpdateWidget(covariant _WordleBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await _store.load(_docId);
      if (!mounted) return;
      setState(() {
        _state = TitleWordleState.fromMap(_entry.letters, data);
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('TitleWordle: failed to load progress: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  // -------------------------------------------------------------- input ---

  // Not gated on the save: Firestore only completes a write once the server
  // acks it, so the keyboard used to go dead after every guess until then
  // (dropping the first letters of the next guess, and for good while
  // offline). The state is already updated locally and every save writes
  // the whole state, so an overlapping save can't lose anything.
  bool get _canType => _state != null && !_state!.finished;

  void _type(String letter) {
    if (!_canType || _input.length >= _entry.letters.length) return;
    setState(() => _input += letter);
  }

  void _backspace() {
    if (!_canType || _input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _enter() async {
    final state = _state;
    if (state == null || !_canType) return;
    if (_input.length < _entry.letters.length) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.titleWordleNotEnoughLetters,
            ),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      return;
    }
    final next = state.submit(_input);
    if (next == null) return;
    setState(() {
      _state = next;
      _input = '';
    });
    try {
      await _store.save(_docId, next.toMap(_entry.id));
    } catch (e) {
      debugPrint('TitleWordle: save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.gamesCommonSaveFailed),
          ),
        );
      }
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.active || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _enter();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final ch = event.character?.toUpperCase();
    if (ch != null && ch.length == 1 && RegExp('[A-Z]').hasMatch(ch)) {
      _type(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _share() {
    final state = _state;
    if (state == null) return;
    SharePlus.instance.share(
      ShareParams(
        text: titleWordleShareText(
          puzzleNumber: _puzzleNumber,
          mode: widget.mode,
          entry: _entry,
          guesses: state.guesses,
        ),
      ),
    );
  }

  void _openDetails() {
    openMedia(
      context,
      MediaItem(
        id: _entry.id,
        title: _entry.title,
        overview: '',
        posterPath: _entry.posterPath,
        backdropPath: '',
        date: '',
        voteAverage: 0,
        mediaType: widget.mode,
      ),
    );
  }

  // -------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    if (_loading) return const GameLoading();
    final state = _state;
    if (_failed || state == null) return GameLoadError(onRetry: _load);
    final l10n = AppLocalizations.of(context)!;
    final isMovie = widget.mode == MediaType.movie;
    final pips = [
      for (final g in state.guesses)
        g == _entry.letters ? GamePip.correct : GamePip.wrong,
    ];

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: GameHeader(
        title: l10n.gamesCommonPuzzleNumber('$_puzzleNumber'),
        subtitle:
            '${gameDateLabel(context, _date)} · '
            '${l10n.titleWordleLetterCount('${_entry.letters.length}')}',
        pips: pips,
        total: titleWordleMaxGuesses,
        finished: state.finished,
        status: state.finished
            ? null
            : l10n.gamesCommonGuessesLeft(
                '${titleWordleMaxGuesses - state.guesses.length}',
              ),
      ),
    );

    return Focus(
      focusNode: _focus,
      autofocus: widget.active,
      onKeyEvent: _onKey,
      child: state.finished
          // Finished: board + result card scroll together, so the taller
          // result card fits on an iPhone SE.
          ? ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _board(context, state),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GameResultPanel(
                    won: state.won,
                    guessCount: state.guesses.length,
                    maxGuesses: titleWordleMaxGuesses,
                    title: _entry.title,
                    year: _entry.year,
                    posterPath: _entry.posterPath,
                    onShare: _share,
                    onDetails: _openDetails,
                  ),
                ),
                if (!_store.isSignedIn)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: GameGuestNote(),
                  ),
              ],
            )
          // A short, wide window (a landscape phone) can't stack header,
          // board and keyboard; put the keyboard beside the board instead.
          : LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxHeight < 440 && constraints.maxWidth >= 600
                  ? _sideBySide(context, l10n, state, header)
                  : Column(
                    children: [
                      header,
                      if (state.guesses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: GameIntro(
                            isMovie
                                ? l10n.titleWordleIntroMovie
                                : l10n.titleWordleIntroTv,
                          ),
                        )
                      // The color key costs a row the board can't spare on an
                      // iPhone SE.
                      else if (MediaQuery.sizeOf(context).height >=
                          GameHeader.compactHeight)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: _legend(context, l10n),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: _board(context, state),
                        ),
                      ),
                      _keyboard(context, l10n, state),
                      if (!_store.isSignedIn)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: GameGuestNote(),
                        ),
                    ],
                  ),
            ),
    );
  }

  /// In-progress layout for short, wide windows: header + board on the
  /// left, intro/legend + keyboard on the right.
  Widget _sideBySide(
    BuildContext context,
    AppLocalizations l10n,
    TitleWordleState state,
    Widget header,
  ) {
    final isMovie = widget.mode == MediaType.movie;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              header,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _board(context, state),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: state.guesses.isEmpty
                        ? GameIntro(
                            isMovie
                                ? l10n.titleWordleIntroMovie
                                : l10n.titleWordleIntroTv,
                          )
                        : _legend(context, l10n),
                  ),
                  _keyboard(context, l10n, state),
                  if (!_store.isSignedIn)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: GameGuestNote(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Color key for the tiles, shown once the first guess is scored.
  Widget _legend(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    Widget item(LetterResult r, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _fill(r),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        item(LetterResult.correct, l10n.titleWordleLegendCorrect),
        item(LetterResult.present, l10n.titleWordleLegendPresent),
        item(LetterResult.absent, l10n.titleWordleLegendAbsent),
      ],
    );
  }

  // -------------------------------------------------------------- board ---

  Color _fill(LetterResult r) => switch (r) {
    LetterResult.correct => context.colors.success,
    LetterResult.present => context.colors.accent,
    LetterResult.absent => context.colors.textMuted,
  };

  Widget _board(BuildContext context, TitleWordleState state) {
    final words = _entry.wordLengths;
    final letters = _entry.letters.length;
    const spacing = 5.0;
    return LayoutBuilder(
      builder: (context, c) {
        // Word gaps are 0.5 of a tile wide.
        final gapUnits = (words.length - 1) * 0.5;
        final byWidth =
            (c.maxWidth - spacing * (letters - 1)) / (letters + gapUnits);
        final byHeight =
            (c.maxHeight - spacing * (titleWordleMaxGuesses - 1)) /
            titleWordleMaxGuesses;
        final tile = math.max(
          16.0,
          math.min(56.0, math.min(byWidth, byHeight)),
        );
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < titleWordleMaxGuesses; row++) ...[
                if (row > 0) const SizedBox(height: spacing),
                _row(context, state, row, tile, spacing, words),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    TitleWordleState state,
    int row,
    double tile,
    double spacing,
    List<int> words,
  ) {
    final colors = context.colors;
    final submitted = row < state.guesses.length;
    final text = submitted
        ? state.guesses[row]
        : (row == state.guesses.length && !state.finished ? _input : '');
    final scores = submitted
        ? scoreGuess(text, _entry.letters)
        : const <LetterResult>[];
    final children = <Widget>[];
    var i = 0;
    for (var w = 0; w < words.length; w++) {
      if (w > 0) children.add(SizedBox(width: tile * 0.5 + spacing));
      for (var j = 0; j < words[w]; j++, i++) {
        if (j > 0) children.add(SizedBox(width: spacing));
        final letter = i < text.length ? text[i] : '';
        final fill = submitted ? _fill(scores[i]) : Colors.transparent;
        children.add(
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: tile,
            height: tile,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: submitted
                    ? fill
                    : (letter.isNotEmpty
                          ? colors.textSecondary
                          : colors.surfaceAlt),
                width: 2,
              ),
            ),
            child: Text(
              letter,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: tile * 0.5,
                fontWeight: FontWeight.w800,
                color: submitted ? gameOnFill(fill) : colors.textPrimary,
              ),
            ),
          ),
        );
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  // ----------------------------------------------------------- keyboard ---

  static const _rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

  Widget _keyboard(
    BuildContext context,
    AppLocalizations l10n,
    TitleWordleState state,
  ) {
    final states = keyboardStates(state.guesses, _entry.letters);
    final height = MediaQuery.sizeOf(context).height < 640 ? 42.0 : 50.0;
    Widget key(
      String label, {
      VoidCallback? onTap,
      int flex = 2,
      Widget? child,
      String? semantics,
    }) {
      final s = states[label];
      final bg = s == null ? context.colors.surfaceAlt : _fill(s);
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
          child: Semantics(
            button: true,
            label: semantics ?? label,
            excludeSemantics: true,
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onTap,
                child: SizedBox(
                  height: height,
                  child: Center(
                    child:
                        child ??
                        Text(
                          label,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: s == null
                                ? context.colors.textPrimary
                                : gameOnFill(bg),
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < _rows.length; r++)
            Row(
              children: [
                if (r == 1) const Spacer(),
                if (r == 2)
                  key(
                    'ENTER',
                    flex: 3,
                    onTap: _enter,
                    semantics: l10n.titleWordleSubmit,
                    child: const Icon(Icons.keyboard_return_rounded, size: 20),
                  ),
                for (final ch in _rows[r].split(''))
                  key(ch, onTap: () => _type(ch)),
                if (r == 2)
                  key(
                    'DEL',
                    flex: 3,
                    onTap: _backspace,
                    semantics: l10n.titleWordleDelete,
                    child: const Icon(Icons.backspace_outlined, size: 20),
                  ),
                if (r == 1) const Spacer(),
              ],
            ),
        ],
      ),
    );
  }
}
