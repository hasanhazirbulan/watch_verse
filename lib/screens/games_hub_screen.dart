import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/games/game_registry.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// Lists the app's games (see [gameRegistry]) as tappable cards.
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gamesHubTitle)),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
        itemCount: gameRegistry.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _GameCard(entry: gameRegistry[i]),
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
  // Created once (not per build) so a rebuild doesn't resubscribe.
  Stream<String?>? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _status ??= widget.entry.todayStatus?.call(AppLocalizations.of(context)!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final entry = widget.entry;
    final status = _status;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: entry.builder)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: colors.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(entry.icon, color: Colors.white, size: 28),
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
                            color: colors.textSecondary, fontSize: 13)),
                    if (status != null)
                      StreamBuilder<String?>(
                        stream: status,
                        builder: (context, snap) {
                          final text = snap.data;
                          if (text == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(text,
                                style: TextStyle(
                                    color: colors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          );
                        },
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
