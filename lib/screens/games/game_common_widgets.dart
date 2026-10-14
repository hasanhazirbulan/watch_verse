import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// Movie / TV segmented control shown at the top of the bundled-pool games.
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<MediaType>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: MediaType.movie,
              icon: const Icon(Icons.movie_outlined, size: 18),
              label: Text(l10n.gamesCommonMovies),
            ),
            ButtonSegment(
              value: MediaType.tv,
              icon: const Icon(Icons.tv_rounded, size: 18),
              label: Text(l10n.gamesCommonTv),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
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

/// Centered error message + retry button.
class GameLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const GameLoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.gamesCommonLoadError,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.gamesCommonRetry),
            ),
          ],
        ),
      ),
    );
  }
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

/// End-of-game card: poster, title, outcome line, share + details buttons.
class GameResultPanel extends StatelessWidget {
  final bool won;
  final int guessCount;
  final int maxGuesses;
  final String title;
  final String year;
  final String posterPath;
  final VoidCallback onShare;
  final VoidCallback onDetails;

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
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceAlt),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onDetails,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 84,
                    child: TmdbImage(
                      url: Tmdb.poster(posterPath, size: 'w154'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      won ? l10n.gamesCommonWin : l10n.gamesCommonLose,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: won ? colors.success : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      won
                          ? l10n.gamesCommonSolvedIn(
                              '$guessCount',
                              '$maxGuesses',
                            )
                          : l10n.gamesCommonAnswerWas(title),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      year.isEmpty ? title : '$title ($year)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: Text(
                    l10n.gamesCommonViewDetails,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(
                    l10n.gamesCommonShare,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.gamesCommonComeBackTomorrow,
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
