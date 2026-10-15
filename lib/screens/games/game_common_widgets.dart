import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

// Shared building blocks for the Games hub's daily games (Frames, Title
// Wordle, Plot, Who's the Actor?) and Higher or Lower, so every game has the
// same header, guess feedback, result card and empty/error states.

// ---------------------------------------------------------------- colors ---

/// Feedback colors shared by every game: right, wrong and skipped guesses.
extension GameColors on AppColors {
  Color get gameCorrect => success;
  Color get gameWrong => primaryDark;
  Color get gameSkipped => textMuted;
}

/// Readable text/icon color on a filled game color. The dark theme's green
/// and gold are light colors and white on them was barely readable.
Color gameOnFill(Color fill) =>
    fill.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;

// ------------------------------------------------------------ mode tabs ---

/// Pill segmented control used for every game's Movie / TV switch, with
/// icons, in the app's brand gradient (same look as `SegmentedTabs`).
class GameModeTabs extends StatelessWidget {
  final List<String> labels;
  final List<IconData> icons;
  final int selected;
  final ValueChanged<int> onChanged;
  const GameModeTabs({
    super.key,
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: colors.surfaceAlt),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        gradient: i == selected ? colors.brandGradient : null,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icons[i],
                            size: 17,
                            color: i == selected
                                ? Colors.white
                                : colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: i == selected
                                    ? Colors.white
                                    : colors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Movie / TV switch shown at the top of the bundled-pool games.
class GameModeToggle extends StatelessWidget {
  final MediaType mode;
  final ValueChanged<MediaType> onChanged;
  const GameModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GameModeTabs(
      labels: [l10n.gamesCommonMovies, l10n.gamesCommonTv],
      icons: const [Icons.movie_outlined, Icons.tv_rounded],
      selected: mode == MediaType.movie ? 0 : 1,
      onChanged: (i) => onChanged(i == 0 ? MediaType.movie : MediaType.tv),
    );
  }
}

/// Keeps one board per mode alive (so flipping Movie ↔ TV doesn't reload or
/// lose a half-typed guess) while only building a mode once it's first shown.
class GameModeStack extends StatefulWidget {
  final MediaType mode;
  final Widget Function(MediaType mode) builder;
  const GameModeStack({super.key, required this.mode, required this.builder});

  @override
  State<GameModeStack> createState() => _GameModeStackState();
}

class _GameModeStackState extends State<GameModeStack> {
  final Set<MediaType> _visited = {};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.mode);
    return IndexedStack(
      index: widget.mode.index,
      sizing: StackFit.expand,
      children: [
        for (final m in MediaType.values)
          _visited.contains(m)
              ? KeyedSubtree(key: ValueKey(m), child: widget.builder(m))
              : const SizedBox.shrink(),
      ],
    );
  }
}

// --------------------------------------------------------------- header ---

/// Outcome of one used attempt, as shown by [GameAttemptPips].
enum GamePip { correct, wrong, skipped }

/// One small square per attempt: filled (green / red / grey) for used ones,
/// an outlined "next" square while the game is on, and dim ones after that.
class GameAttemptPips extends StatelessWidget {
  final List<GamePip> used;
  final int total;
  final bool finished;
  final double size;
  const GameAttemptPips({
    super.key,
    required this.used,
    required this.total,
    this.finished = false,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) SizedBox(width: size * 0.3),
          _pip(colors, i),
        ],
      ],
    );
  }

  Widget _pip(AppColors colors, int i) {
    final pip = i < used.length ? used[i] : null;
    final isNext = pip == null && i == used.length && !finished;
    final fill = switch (pip) {
      GamePip.correct => colors.gameCorrect,
      GamePip.wrong => colors.gameWrong,
      GamePip.skipped => colors.gameSkipped,
      null => colors.surfaceAlt,
    };
    final icon = switch (pip) {
      GamePip.correct => Icons.check_rounded,
      GamePip.wrong => Icons.close_rounded,
      GamePip.skipped => Icons.remove_rounded,
      null => null,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isNext ? Colors.transparent : fill,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: isNext
            ? Border.all(color: colors.textSecondary, width: 1.5)
            : null,
      ),
      child: icon == null
          ? null
          : Icon(icon, size: size * 0.75, color: gameOnFill(fill)),
    );
  }
}

/// Top strip of a daily game: puzzle name + date on the left, attempt pips
/// and "N guesses left" on the right. Wraps under the title on a narrow
/// screen or with large text.
class GameHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<GamePip> pips;
  final int total;
  final bool finished;
  final String? status;
  const GameHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.pips,
    required this.total,
    required this.finished,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        GameAttemptPips(used: pips, total: total, finished: finished),
        if (status != null) ...[
          const SizedBox(height: 4),
          Text(
            status!,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.surfaceAlt),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [left, right],
      ),
    );
  }
}

/// "Wed, Oct 14" for a game's EST calendar date ([estDate] is UTC midnight).
String gameDateLabel(BuildContext context, DateTime estDate) =>
    MaterialLocalizations.of(context).formatMediumDate(estDate);

/// One-line "how to play" under a game's header.
class GameIntro extends StatelessWidget {
  final String text;
  const GameIntro(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: colors.accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                color: colors.textSecondary, fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------- guess feedback ---

/// One previous guess for [GameGuessList].
class GameGuessEntry {
  final String title;
  final GamePip outcome;
  const GameGuessEntry(this.title, this.outcome);
}

/// Card listing previous guesses, newest first, each with a colored marker
/// and a verdict ("Not it" / "Skipped" / "Correct"). New rows slide in.
class GameGuessList extends StatelessWidget {
  final List<GameGuessEntry> guesses;
  final String? skippedLabel;
  const GameGuessList({super.key, required this.guesses, this.skippedLabel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameSectionLabel(l10n.gamesCommonYourGuesses),
          const SizedBox(height: 6),
          for (var i = guesses.length - 1; i >= 0; i--)
            _GuessRow(
              key: ValueKey('guess-$i'),
              number: i + 1,
              entry: guesses[i],
              skippedLabel: skippedLabel ?? l10n.gamesCommonSkipped,
            ),
        ],
      ),
    );
  }
}

class _GuessRow extends StatelessWidget {
  final int number;
  final GameGuessEntry entry;
  final String skippedLabel;
  const _GuessRow({
    super.key,
    required this.number,
    required this.entry,
    required this.skippedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final (Color color, IconData icon, String verdict) = switch (
        entry.outcome) {
      GamePip.correct => (
          colors.gameCorrect,
          Icons.check_rounded,
          l10n.gamesCommonVerdictCorrect,
        ),
      GamePip.wrong => (
          colors.gameWrong,
          Icons.close_rounded,
          l10n.gamesCommonVerdictWrong,
        ),
      GamePip.skipped => (
          colors.gameSkipped,
          Icons.redo_rounded,
          l10n.gamesCommonVerdictSkipped,
        ),
    };
    final skipped = entry.outcome == GamePip.skipped;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -8),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: Text(
                '$number',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 15, color: gameOnFill(color)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                skipped ? skippedLabel : entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: skipped ? colors.textMuted : colors.textPrimary,
                  fontWeight: entry.outcome == GamePip.correct
                      ? FontWeight.w800
                      : FontWeight.w600,
                  fontStyle: skipped ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            if (!skipped) ...[
              const SizedBox(width: 8),
              Text(
                verdict,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small all-caps section label ("YOUR GUESSES", "CLUE 2 · FAMOUS ROLE").
class GameSectionLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  const GameSectionLabel(this.text, {super.key, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: color ?? colors.accent),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------- search bits ---

/// Rounded search field used by the guess-by-search games.
class GameSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final bool busy;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const GameSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hint,
    this.busy = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.surfaceAlt),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colors.surface,
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        suffixIcon: busy
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
    );
  }
}

/// Outlined "Skip" button that sits next to a [GameSearchField].
class GameSkipButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GameSkipButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.surfaceAlt, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.redo_rounded, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------- states ---

/// Centered error message + retry button.
class GameLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  const GameLoadError({super.key, required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GameMessage(
      icon: Icons.cloud_off_rounded,
      text: message ?? l10n.gamesCommonLoadError,
      action: FilledButton.tonalIcon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(l10n.gamesCommonRetry),
      ),
    );
  }
}

/// Centered icon + message (+ optional button): sign-in prompts, "no puzzle
/// today", errors.
class GameMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const GameMessage({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surfaceAlt, width: 2),
              ),
              child: Icon(icon, size: 34, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder for a game board.
class GameLoading extends StatelessWidget {
  const GameLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Small muted banner telling guests their results aren't saved.
class GameGuestNote extends StatelessWidget {
  const GameGuestNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: context.colors.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            AppLocalizations.of(context)!.gamesCommonGuestNote,
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- result ---

/// End-of-game card shared by every daily game: outcome badge + headline,
/// the attempt pips, the answer (poster, title, year, details link) and a
/// share button. Pops in when it first appears.
class GameResultPanel extends StatelessWidget {
  final bool won;
  final int guessCount;
  final int maxGuesses;
  final String title;
  final String year;
  final String posterPath;
  final VoidCallback onShare;
  final VoidCallback onDetails;

  /// Attempt outcomes for the pip row; omitted = no pip row.
  final List<GamePip>? pips;

  /// Overrides for games with their own wording / artwork (e.g. the actor
  /// game's profile photo and "View filmography").
  final String? headline;
  final String? summary;
  final String? detailsLabel;
  final Widget? image;
  final String? comeBackText;

  const GameResultPanel({
    super.key,
    required this.won,
    required this.guessCount,
    required this.maxGuesses,
    required this.title,
    required this.year,
    required this.posterPath,
    required this.onShare,
    required this.onDetails,
    this.pips,
    this.headline,
    this.summary,
    this.detailsLabel,
    this.image,
    this.comeBackText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final tone = won ? colors.gameCorrect : colors.gameWrong;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withValues(alpha: 0.55), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Outcome band.
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tone.withValues(alpha: 0.22),
                    tone.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                        BoxDecoration(color: tone, shape: BoxShape.circle),
                    child: Icon(
                      won
                          ? Icons.emoji_events_rounded
                          : Icons.sentiment_dissatisfied_rounded,
                      color: gameOnFill(tone),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline ??
                              (won ? l10n.gamesCommonWin : l10n.gamesCommonLose),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary ??
                              (won
                                  ? l10n.gamesCommonSolvedIn(
                                      '$guessCount',
                                      '$maxGuesses',
                                    )
                                  : l10n.gamesCommonAnswerWas(title)),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (pips != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GameAttemptPips(
                    used: pips!,
                    total: maxGuesses,
                    finished: true,
                    size: 20,
                  ),
                ),
              ),
            // The answer.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onDetails,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 64,
                          height: 96,
                          child: image ??
                              TmdbImage(
                                url: Tmdb.poster(posterPath, size: 'w185'),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                height: 1.2,
                              ),
                            ),
                            if (year.isNotEmpty)
                              Text(
                                year,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              detailsLabel ?? l10n.gamesCommonViewDetails,
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: colors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GameGradientButton(
                    icon: Icons.ios_share_rounded,
                    label: l10n.gamesCommonShare,
                    onPressed: onShare,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: colors.textMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          comeBackText ?? l10n.gamesCommonComeBackTomorrow,
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: colors.textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width brand-gradient button (Share, Play again).
class GameGradientButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  const GameGradientButton({
    super.key,
    this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: context.colors.brandGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 19),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
