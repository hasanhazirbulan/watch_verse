import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/games/game_common_widgets.dart';
import 'package:watch_verse/screens/games/game_registry.dart';
import 'package:watch_verse/services/games/game_day.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// Lists the app's games (see [gameRegistry]): today's daily puzzles with
/// their status, then the play-anytime games.
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daily = [for (final g in gameRegistry) if (g.daily) g];
    final endless = [for (final g in gameRegistry) if (!g.daily) g];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gamesHubTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          const _TodayBanner(),
          const SizedBox(height: 18),
          GameSectionLabel(l10n.gamesHubDailySection,
              icon: Icons.calendar_today_rounded),
          const SizedBox(height: 10),
          for (final g in daily) ...[
            _GameCard(entry: g),
            const SizedBox(height: 10),
          ],
          if (endless.isNotEmpty) ...[
            const SizedBox(height: 8),
            GameSectionLabel(l10n.gamesHubEndlessSection,
                icon: Icons.all_inclusive_rounded),
            const SizedBox(height: 10),
            for (final g in endless) ...[
              _GameCard(entry: g),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _TodayBanner extends StatelessWidget {
  const _TodayBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final today = gameEstDate(DateTime.now().toUtc());
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.28),
            colors.primaryDark.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: colors.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.sports_esports_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gamesHubToday(gameDateLabel(context, today)),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.gamesCommonPuzzleNumber('${gamePuzzleNumber(DateTime.now().toUtc())}')}'
                  ' · ${l10n.gamesHubResetNote}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  final GameEntry entry;
  const _GameCard({required this.entry});

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  // Created once (not per build) so a rebuild doesn't resubscribe; renewed
  // after coming back from the game so the card shows what just happened.
  Stream<List<GameStatusChip>>? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _status ??= _subscribe();
  }

  Stream<List<GameStatusChip>>? _subscribe() =>
      widget.entry.todayStatus?.call(AppLocalizations.of(context)!);

  Future<void> _open() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: widget.entry.builder));
    if (mounted) setState(() => _status = _subscribe());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final entry = widget.entry;
    final status = _status;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.surfaceAlt),
      ),
      child: InkWell(
        onTap: _open,
        child: Stack(
          children: [
            // Faint oversized icon as card art.
            Positioned(
              right: -18,
              bottom: -22,
              child: Icon(entry.icon,
                  size: 110, color: entry.art.first.withValues(alpha: 0.07)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: entry.art,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: entry.art.last.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(entry.icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title(l10n),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(entry.subtitle(l10n),
                            style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.3)),
                        if (status != null)
                          StreamBuilder<List<GameStatusChip>>(
                            stream: status,
                            builder: (context, snap) {
                              final chips = snap.data ?? const [];
                              if (chips.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final c in chips) _StatusChip(c),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final GameStatusChip chip;
  const _StatusChip(this.chip);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (chip.tone) {
      GameStatusTone.done => colors.success,
      GameStatusTone.progress => colors.accent,
      GameStatusTone.missed => colors.textSecondary,
      GameStatusTone.neutral => colors.textSecondary,
    };
    final icon = chip.tone == GameStatusTone.done && chip.icon == null
        ? Icons.check_circle_rounded
        : chip.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              chip.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (chip.tone == GameStatusTone.done && chip.icon != null) ...[
            const SizedBox(width: 3),
            Icon(Icons.check_rounded, size: 13, color: color),
          ],
        ],
      ),
    );
  }
}
