import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/games/game_common_widgets.dart';
import 'package:watch_verse/screens/person_screen.dart';
import 'package:watch_verse/services/actor_guess_logic.dart';
import 'package:watch_verse/services/actor_guess_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/services/app_firebase.dart';
import 'package:watch_verse/utils/responsive.dart';

/// Daily "Who's the Actor?": name the mystery actor in up to
/// [actorGuessMaxAttempts] guesses. One clue is shown up front and each wrong
/// guess reveals the next, hardest first (see [ActorGuessClue]). The puzzle
/// comes from the bundled pool via [ActorGuessService]; progress is saved per
/// day so reopening the screen resumes where the player left off.
class ActorGuessScreen extends StatefulWidget {
  const ActorGuessScreen({super.key, this.service, this.signedIn});

  /// Test hooks: a service backed by fake Firestore/Auth, and whether to
  /// treat the user as signed in. Production passes neither.
  @visibleForTesting
  final ActorGuessService? service;
  @visibleForTesting
  final bool? signedIn;

  @override
  State<ActorGuessScreen> createState() => _ActorGuessScreenState();
}

class _ActorGuessScreenState extends State<ActorGuessScreen> {
  late final ActorGuessService _service =
      widget.service ?? ActorGuessService.instance;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  // Guests have no Firebase account to save progress under (gamePlays is
  // owner-only in firestore.rules), same as the daily movie game.
  late final bool _isGuest =
      !(widget.signedIn ?? AppFirebase.auth.currentUser != null);

  // Captured once: a game started at 23:59 EST keeps its puzzle and progress
  // doc instead of flipping to tomorrow's mid-game.
  final DateTime _now = DateTime.now().toUtc();

  ActorGuessPuzzle? _puzzle;
  bool _loading = true;
  bool _loadFailed = false;
  Stream<ActorGuessProgress>? _progress;

  List<ActorGuessCandidate> _results = [];
  bool _searching = false;
  bool _searchFailed = false;
  String _lastQuery = '';
  // The guess just written, until the progress stream shows it. Firestore
  // applies a write to its local cache (and fires the listener) right away,
  // but the write's future only completes once the server acks it — waiting
  // for that paused guessing on a slow network and locked it for good
  // offline. Waiting for the local snapshot instead still guarantees the
  // next guess is counted against a list that already holds this one.
  int? _pendingGuessId;

  @override
  void initState() {
    super.initState();
    if (!_isGuest) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final puzzle = await _service.puzzleFor(_now);
      if (!mounted) return;
      setState(() {
        _puzzle = puzzle;
        _progress = _service.progressStream(_now);
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('ActorGuess: failed to load puzzle: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _retryProgress() =>
      setState(() => _progress = _service.progressStream(_now));

  // ------------------------------------------------------------ search ---

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    _lastQuery = q;
    if (q.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _searchFailed = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final results = await _service.searchActors(q);
      // A slower response for an older query must not overwrite newer ones.
      if (!mounted || _lastQuery != q) return;
      setState(() {
        _results = results.take(8).toList();
        _searching = false;
      });
    } catch (e) {
      debugPrint('ActorGuess: search failed: $e');
      if (!mounted || _lastQuery != q) return;
      setState(() {
        _results = [];
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _lastQuery = '';
    _results = [];
    _searching = false;
    _searchFailed = false;
  }

  /// Whether a guess is still waiting to show up in [progress].
  bool _awaitingGuess(ActorGuessProgress progress) {
    final pending = _pendingGuessId;
    return pending != null && !progress.guesses.any((g) => g.id == pending);
  }

  Future<void> _guess(
    ActorGuessCandidate candidate,
    ActorGuessProgress progress,
  ) async {
    final puzzle = _puzzle;
    if (puzzle == null || _awaitingGuess(progress) || progress.finished) {
      return;
    }
    if (progress.guesses.any((g) => g.id == candidate.id)) return;
    _searchFocus.unfocus();
    setState(() {
      _pendingGuessId = candidate.id;
      _clearSearch();
    });
    final won = isActorGuessCorrect(
      guessId: candidate.id,
      guessName: candidate.name,
      puzzle: puzzle,
    );
    final finished =
        won || progress.guesses.length + 1 >= actorGuessMaxAttempts;
    try {
      await _service.recordGuess(
        utcNow: _now,
        guess: ActorGuessEntry(candidate.id, candidate.name),
        won: won,
        finished: finished,
      );
    } catch (e, st) {
      // Firestore rolls the rejected write back out of its cache, so the
      // stream drops the guess again; just unlock and say so.
      debugPrint('ActorGuess: saving guess failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)),
        );
      }
    } finally {
      // Acked (or failed): nothing left to wait for, even if no snapshot
      // with the guess ever arrived.
      if (mounted && _pendingGuessId == candidate.id) {
        setState(() => _pendingGuessId = null);
      }
    }
  }

  // ------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final puzzle = _puzzle;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.actorGuessTitle)),
      // Games keep a phone-width column on wide windows (iPhone Duo
      // unfolded, landscape) rather than stretching edge to edge.
      body: ReadableWidth(child: SafeArea(
        top: false,
        child: _isGuest
            ? _message(context, l10n.actorGuessSignInPrompt)
            : _loading
            ? asyncLoadingIndicator()
            : _loadFailed
            ? _error(context, l10n.actorGuessLoadError, _load)
            : puzzle == null
            ? _message(context, l10n.actorGuessNoPool)
            : _gameStream(context, l10n, puzzle),
      )),
    );
  }

  Widget _message(BuildContext context, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.textSecondary),
      ),
    ),
  );

  Widget _error(BuildContext context, String text, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)!.actorGuessRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameStream(
    BuildContext context,
    AppLocalizations l10n,
    ActorGuessPuzzle puzzle,
  ) {
    return StreamBuilder<ActorGuessProgress>(
      stream: _progress,
      builder: (context, snap) {
        if (snap.hasError) {
          return _error(context, l10n.actorGuessLoadError, _retryProgress);
        }
        final progress = snap.data;
        if (progress == null) return asyncLoadingIndicator();
        return _game(context, l10n, puzzle, progress);
      },
    );
  }

  Widget _game(
    BuildContext context,
    AppLocalizations l10n,
    ActorGuessPuzzle puzzle,
    ActorGuessProgress progress,
  ) {
    final finished = progress.finished;
    final visible = actorGuessCluesVisible(
      progress.wrongGuesses,
      finished: finished,
    );
    final wrong = [
      for (final g in progress.guesses)
        if (!isActorGuessCorrect(
          guessId: g.id,
          guessName: g.name,
          puzzle: puzzle,
        ))
          g,
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (!finished)
            _searchArea(
              context,
              l10n,
              progress,
              // Whatever the header + field (~110pt) leave over, minus a
              // strip of clues, so the open keyboard on an iPhone SE squeezes
              // the result list rather than overflowing the column.
              maxResultsHeight: (constraints.maxHeight - 170).clamp(
                56.0,
                260.0,
              ),
            ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (finished) _resultPanel(context, l10n, puzzle, progress),
                if (wrong.isNotEmpty) _guessChips(context, l10n, wrong),
                // Newest clue first, so a wrong guess shows its reveal without
                // the player having to scroll.
                for (var i = visible - 1; i >= 0; i--)
                  _clueCard(
                    context,
                    l10n,
                    puzzle,
                    ActorGuessClue.values[i],
                    i,
                    finished,
                  ),
                if (!finished)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.actorGuessNextClueHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchArea(
    BuildContext context,
    AppLocalizations l10n,
    ActorGuessProgress progress, {
    required double maxResultsHeight,
  }) {
    final left = actorGuessMaxAttempts - progress.guesses.length;
    final submitting = _awaitingGuess(progress);
    final showPanel = _lastQuery.length >= 2 && !_searching;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.actorGuessGuessesLeft('$left'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            enabled: !submitting,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.actorGuessSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching || submitting
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
          if (showPanel && _searchFailed)
            _searchNote(
              context,
              l10n.actorGuessSearchFailed,
              onRetry: () => _runSearch(_searchController.text),
            )
          else if (showPanel && _results.isEmpty)
            _searchNote(context, l10n.actorGuessNoResults)
          else if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxResultsHeight),
              child: Material(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  itemBuilder: (context, i) =>
                      _resultTile(context, l10n, _results[i], progress),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchNote(
    BuildContext context,
    String text, {
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              tooltip: AppLocalizations.of(context)!.actorGuessRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }

  Widget _resultTile(
    BuildContext context,
    AppLocalizations l10n,
    ActorGuessCandidate c,
    ActorGuessProgress progress,
  ) {
    final already = progress.guesses.any((g) => g.id == c.id);
    return ListTile(
      dense: true,
      enabled: !already && !_awaitingGuess(progress),
      onTap: already ? null : () => _guess(c, progress),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 34,
          height: 48,
          child: TmdbImage(
            url: Tmdb.poster(c.profilePath, size: 'w92'),
            placeholderIcon: Icons.person_rounded,
          ),
        ),
      ),
      title: Text(
        c.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: c.knownFor.isEmpty
          ? null
          : Text(
              c.knownFor.take(2).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: already
          ? Text(
              l10n.actorGuessAlreadyGuessed,
              style: TextStyle(color: context.colors.textMuted, fontSize: 12),
            )
          : null,
    );
  }

  Widget _guessChips(
    BuildContext context,
    AppLocalizations l10n,
    List<ActorGuessEntry> wrong,
  ) {
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.actorGuessYourGuesses,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in wrong)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(Icons.close_rounded, size: 16, color: error),
                  label: Text(g.name, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- clues ---

  String _clueLabel(AppLocalizations l10n, ActorGuessClue clue) =>
      switch (clue) {
        ActorGuessClue.origin => l10n.actorGuessClueOrigin,
        ActorGuessClue.deepCuts => l10n.actorGuessClueDeepCuts,
        ActorGuessClue.knownTitles => l10n.actorGuessClueKnownTitles,
        ActorGuessClue.character => l10n.actorGuessClueCharacter,
        ActorGuessClue.topTitles => l10n.actorGuessClueTopTitles,
        ActorGuessClue.photo => l10n.actorGuessCluePhoto,
      };

  Widget _clueCard(
    BuildContext context,
    AppLocalizations l10n,
    ActorGuessPuzzle puzzle,
    ActorGuessClue clue,
    int index,
    bool finished,
  ) {
    final Widget body = switch (clue) {
      ActorGuessClue.origin => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (puzzle.debutYear > 0)
            _factLine(
              context,
              Icons.movie_outlined,
              l10n.actorGuessFirstMovie('${puzzle.debutYear}'),
            ),
          if (puzzle.country.isNotEmpty)
            _factLine(
              context,
              Icons.public_rounded,
              l10n.actorGuessBornIn(puzzle.country),
            ),
        ],
      ),
      ActorGuessClue.deepCuts => _posterRow(
        context,
        puzzle.deepCutTitles,
        finished,
      ),
      ActorGuessClue.knownTitles => _posterRow(
        context,
        puzzle.knownTitles,
        finished,
      ),
      ActorGuessClue.character => Text(
        l10n.actorGuessCharacterIn(puzzle.characterName, puzzle.characterTitle),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      ActorGuessClue.topTitles => _posterRow(
        context,
        puzzle.topTitles,
        finished,
      ),
      ActorGuessClue.photo => Center(
        child: _profilePhoto(context, puzzle, blurred: !finished),
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.actorGuessClueNumber('${index + 1}')} · '
            '${_clueLabel(l10n, clue)}',
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }

  Widget _factLine(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Up to three posters with captions. Only tappable once the game is over —
  /// a title's detail page lists its cast, which would give the answer away.
  Widget _posterRow(
    BuildContext context,
    List<ActorGuessTitle> titles,
    bool tappable,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: i < titles.length
                ? _posterTile(context, titles[i], tappable)
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  Widget _posterTile(BuildContext context, ActorGuessTitle t, bool tappable) {
    final tile = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TmdbImage(url: Tmdb.poster(t.posterPath, size: 'w185')),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        if (t.year > 0)
          Text(
            '${t.year}',
            style: TextStyle(fontSize: 11, color: context.colors.textMuted),
          ),
      ],
    );
    if (!tappable) return tile;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openMedia(
        context,
        MediaItem(
          id: t.id,
          title: t.title,
          overview: '',
          posterPath: t.posterPath,
          backdropPath: '',
          date: t.year > 0 ? '${t.year}' : '',
          voteAverage: 0,
          mediaType: t.isTv ? MediaType.tv : MediaType.movie,
        ),
      ),
      child: tile,
    );
  }

  Widget _profilePhoto(
    BuildContext context,
    ActorGuessPuzzle puzzle, {
    required bool blurred,
    double width = 120,
  }) {
    final image = TmdbImage(
      url: Tmdb.poster(puzzle.profilePath, size: 'w185'),
      placeholderIcon: Icons.person_rounded,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: width * 1.5,
        child: blurred
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: 14,
                  sigmaY: 14,
                  tileMode: TileMode.decal,
                ),
                child: image,
              )
            : image,
      ),
    );
  }

  // ------------------------------------------------------------ result ---

  Widget _resultPanel(
    BuildContext context,
    AppLocalizations l10n,
    ActorGuessPuzzle puzzle,
    ActorGuessProgress progress,
  ) {
    final won = progress.won;
    final count = progress.guesses.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GameResultPanel(
        won: won,
        guessCount: count,
        maxGuesses: actorGuessMaxAttempts,
        title: puzzle.name,
        year: '',
        posterPath: puzzle.profilePath,
        pips: [
          for (var i = 0; i < count; i++)
            won && i == count - 1 ? GamePip.correct : GamePip.wrong,
        ],
        headline: won ? l10n.actorGuessWinTitle : l10n.actorGuessLoseTitle,
        summary: won
            ? l10n.actorGuessWinSubtitle('$count', '$actorGuessMaxAttempts')
            : l10n.actorGuessAnswerWas(puzzle.name),
        detailsLabel: l10n.actorGuessViewFilmography,
        comeBackText: l10n.actorGuessComeBackTomorrow,
        image: TmdbImage(
          url: Tmdb.poster(puzzle.profilePath, size: 'w185'),
          placeholderIcon: Icons.person_rounded,
        ),
        onShare: () => SharePlus.instance.share(
          ShareParams(
            text: actorGuessShareText(
              gameTitle: l10n.actorGuessTitle,
              dateKey: actorGuessDateKey(_now),
              guessCount: count,
              won: won,
            ),
          ),
        ),
        onDetails: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PersonScreen(personId: puzzle.id, name: puzzle.name),
          ),
        ),
      ),
    );
  }
}
