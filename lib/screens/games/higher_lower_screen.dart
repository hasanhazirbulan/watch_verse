import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/games/higher_lower_logic.dart';
import 'package:watch_verse/services/games/higher_lower_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/utils/responsive.dart';

/// Endless "Higher or Lower": the top title shows its value, guess whether
/// the bottom one's is higher or lower. A right call moves the bottom title
/// up and deals a new one; a wrong call ends the run. Runs entirely from the
/// shipped pool (see [HigherLowerService]) — only images hit the network.
class HigherLowerScreen extends StatefulWidget {
  const HigherLowerScreen({super.key, this.service});

  /// Injectable for tests; defaults to [HigherLowerService.instance].
  final HigherLowerService? service;

  @override
  State<HigherLowerScreen> createState() => _HigherLowerScreenState();
}

class _HigherLowerScreenState extends State<HigherLowerScreen> {
  HigherLowerService get _service =>
      widget.service ?? HigherLowerService.instance;

  late Future<Map<HigherLowerCategory, List<HigherLowerItem>>> _poolFuture;
  Map<HigherLowerCategory, int> _best = const {};

  HigherLowerCategory? _category;
  HigherLowerDeck? _deck;
  HigherLowerItem? _left;
  HigherLowerItem? _right;
  HigherLowerItem? _upNext;
  int _score = 0;

  /// Result of the pending guess while the bottom value is revealed; null
  /// while waiting for a guess.
  bool? _lastCorrect;
  bool _gameOver = false;
  bool _newBest = false;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  void _load() {
    _poolFuture = _service.pool();
    _refreshBest();
  }

  Future<void> _refreshBest() async {
    try {
      final best = await _service.bestScores();
      if (mounted) setState(() => _best = best);
    } catch (e) {
      // A missing best score is cosmetic — never block the game on it.
      debugPrint('HigherLower: best scores unavailable: $e');
    }
  }

  void _start(HigherLowerCategory category, List<HigherLowerItem> items) {
    _advanceTimer?.cancel();
    final deck = HigherLowerDeck(items);
    final left = deck.next();
    final right = deck.next(avoid: left);
    setState(() {
      _category = category;
      _deck = deck;
      _left = left;
      _right = right;
      _upNext = deck.next(avoid: right);
      _score = 0;
      _lastCorrect = null;
      _gameOver = false;
      _newBest = false;
    });
    _precache(_upNext);
  }

  void _precache(HigherLowerItem? item) {
    final url = item == null ? null : _imageUrl(item);
    if (url == null) return;
    precacheImage(CachedNetworkImageProvider(url), context)
        .catchError((Object _) {});
  }

  static String? _imageUrl(HigherLowerItem item) =>
      Tmdb.backdrop(item.backdropPath, size: 'w780') ??
      Tmdb.poster(item.posterPath, size: 'w500');

  void _guess(HigherLowerGuess guess) {
    final left = _left, right = _right, category = _category;
    if (_lastCorrect != null || _gameOver || left == null || right == null ||
        category == null) {
      return;
    }
    final correct =
        higherLowerCallIsCorrect(category, left.value, right.value, guess);
    setState(() {
      _lastCorrect = correct;
      if (correct) _score++;
    });
    // Saved now, not after the reveal delay: leaving (or changing category)
    // during the reveal cancels the timer, which used to drop a new best.
    final previousBest = _best[category] ?? 0;
    final bestFuture = correct
        ? null
        : _service.submitScore(category, _score).catchError((Object e) {
            debugPrint('HigherLower: saving best score failed: $e');
            return previousBest;
          }).then((best) {
            if (mounted) setState(() => _best = {..._best, category: best});
            return best;
          });
    _advanceTimer = Timer(Duration(milliseconds: correct ? 1000 : 900), () async {
      if (!mounted) return;
      if (correct) {
        final deck = _deck!;
        setState(() {
          _left = right;
          _right = _upNext;
          _upNext = deck.next(avoid: _right);
          _lastCorrect = null;
        });
        _precache(_upNext);
        return;
      }
      final deck = _deck;
      final best = await bestFuture!;
      // Left for the category list (or a new run) meanwhile: not this run.
      if (!mounted || _deck != deck) return;
      setState(() {
        _gameOver = true;
        _newBest = _score > previousBest;
        _best = {..._best, category: best};
      });
    });
  }

  void _backToCategories() {
    _advanceTimer?.cancel();
    setState(() {
      _category = null;
      _deck = null;
      _left = _right = _upNext = null;
      _lastCorrect = null;
      _gameOver = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.higherLowerTitle),
        leading: _category == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: l10n.higherLowerChangeCategory,
                onPressed: _backToCategories,
              ),
      ),
      // Games keep a phone-width column on wide windows (iPhone Duo
      // unfolded, landscape) rather than stretching edge to edge.
      body: ReadableWidth(child: FutureBuilder<Map<HigherLowerCategory, List<HigherLowerItem>>>(
        future: _poolFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return asyncLoadingIndicator();
          }
          if (snap.hasError) {
            return _errorView(context, l10n, snap.error!);
          }
          final pool = snap.data!;
          if (_category == null || _left == null || _right == null) {
            return _categoryPicker(context, l10n, pool);
          }
          return _game(context, l10n, _category!, _left!, _right!);
        },
      )),
    );
  }

  Widget _errorView(BuildContext context, AppLocalizations l10n, Object error) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        asyncErrorView(context, error),
        TextButton.icon(
          onPressed: () => setState(_load),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.retryAction),
        ),
      ],
    );
  }

  // ------------------------------------------------------ category pick ---

  String _categoryName(AppLocalizations l10n, HigherLowerCategory c) =>
      switch (c) {
        HigherLowerCategory.movieRating => l10n.higherLowerCategoryMovieRating,
        HigherLowerCategory.movieRevenue => l10n.higherLowerCategoryBoxOffice,
        HigherLowerCategory.tvRating => l10n.higherLowerCategoryTvRating,
      };

  Widget _categoryPicker(BuildContext context, AppLocalizations l10n,
      Map<HigherLowerCategory, List<HigherLowerItem>> pool) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(l10n.higherLowerIntro,
            style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        const SizedBox(height: 4),
        Text(l10n.higherLowerTiesNote,
            style: TextStyle(color: colors.textMuted, fontSize: 12)),
        const SizedBox(height: 20),
        Text(l10n.higherLowerPickCategory,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        for (final c in HigherLowerCategory.values)
          if ((pool[c]?.length ?? 0) >= 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _start(c, pool[c]!),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: colors.brandGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            switch (c) {
                              HigherLowerCategory.movieRating =>
                                Icons.star_rounded,
                              HigherLowerCategory.movieRevenue =>
                                Icons.attach_money_rounded,
                              HigherLowerCategory.tvRating => Icons.tv_rounded,
                            },
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_categoryName(l10n, c),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(
                                c == HigherLowerCategory.movieRevenue
                                    ? l10n.higherLowerCategoryBoxOfficeDesc
                                    : l10n.higherLowerCategoryRatingDesc,
                                style: TextStyle(
                                    color: colors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.higherLowerBest(_best[c] ?? 0),
                            style: TextStyle(
                                color: colors.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        Icon(Icons.chevron_right_rounded,
                            color: colors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  // --------------------------------------------------------------- game ---

  Widget _game(BuildContext context, AppLocalizations l10n,
      HigherLowerCategory category, HigherLowerItem left, HigherLowerItem right) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_categoryName(l10n, category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700)),
                ),
                Text(l10n.higherLowerScore(_score),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(width: 12),
                Text(l10n.higherLowerBest(_best[category] ?? 0),
                    style: TextStyle(color: colors.textMuted, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                            begin: const Offset(0, 0.25), end: Offset.zero)
                        .animate(animation),
                    child: child,
                  ),
                ),
                child: Stack(
                  key: ValueKey('${left.id}-${right.id}'),
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: _TitleCard(
                            item: left,
                            imageUrl: _imageUrl(left),
                            footer: (_) => _valueText(category, left.value),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _TitleCard(
                            item: right,
                            imageUrl: _imageUrl(right),
                            footer: (compact) => _lastCorrect == null
                                ? _guessButtons(l10n, left, compact)
                                : _revealed(l10n, category, right),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surfaceAlt, width: 3),
                      ),
                      child: Text('VS',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: colors.textPrimary,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            if (_gameOver) _gameOverPanel(context, l10n, category),
          ],
        ),
      ),
    );
  }

  Widget _valueText(HigherLowerCategory c, num value) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          formatHigherLowerValue(c, value),
          style: const TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
        ),
      );

  Widget _revealed(
      AppLocalizations l10n, HigherLowerCategory c, HigherLowerItem item) {
    final correct = _lastCorrect == true;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _valueText(c, item.value),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: correct
                    ? context.colors.success
                    : Theme.of(context).colorScheme.error,
                size: 20),
            const SizedBox(width: 6),
            Text(correct ? l10n.higherLowerCorrect : l10n.higherLowerWrong,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }

  Widget _guessButtons(
      AppLocalizations l10n, HigherLowerItem left, bool compact) {
    Widget button(HigherLowerGuess g, IconData icon, String label) => Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.92),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _guess(g),
            icon: Icon(icon, size: 20),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dropped on short cards (iPhone SE, big text) — the buttons matter.
        if (!compact) ...[
          Text(
            l10n.higherLowerPrompt(left.title),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            button(HigherLowerGuess.higher, Icons.arrow_upward_rounded,
                l10n.higherLowerHigher),
            const SizedBox(width: 10),
            button(HigherLowerGuess.lower, Icons.arrow_downward_rounded,
                l10n.higherLowerLower),
          ],
        ),
      ],
    );
  }

  Widget _gameOverPanel(BuildContext context, AppLocalizations l10n,
      HigherLowerCategory category) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.higherLowerGameOver,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            _newBest
                ? '${l10n.higherLowerFinalScore(_score)} · ${l10n.higherLowerNewBest}'
                : l10n.higherLowerFinalScore(_score),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _newBest ? colors.accent : colors.textSecondary,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _backToCategories,
                  child: Text(l10n.higherLowerChangeCategory,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    final pool = await _poolFuture;
                    if (!mounted) return;
                    _start(category, pool[category]!);
                  },
                  child: Text(l10n.higherLowerPlayAgain,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One title: backdrop (poster fallback) under a dark scrim, with title,
/// year and a [footer] (value, guess buttons or result).
class _TitleCard extends StatelessWidget {
  const _TitleCard(
      {required this.item, required this.imageUrl, required this.footer});

  final HigherLowerItem item;
  final String? imageUrl;

  /// Built with `compact: true` when the card is short.
  final Widget Function(bool compact) footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) =>
            _build(context, constraints.maxHeight < 210));
  }

  Widget _build(BuildContext context, bool compact) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          TmdbImage(url: imageUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0xD9000000)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 16 : 19,
                        fontWeight: FontWeight.w800,
                        height: 1.15),
                  ),
                ),
                if (item.year > 0)
                  Text('${item.year}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: compact ? 4 : 8),
                footer(compact),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
