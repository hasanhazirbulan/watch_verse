import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/create_watch_poll_screen.dart';
import 'package:watch_verse/screens/watch_poll_detail_screen.dart';
import 'package:watch_verse/services/watch_poll_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/responsive.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// "What should we watch?" group polls this user created or was invited to.
/// Reached from the Home drawer.
class WatchPollsScreen extends StatelessWidget {
  const WatchPollsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.watchPollsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CreateWatchPollScreen())),
          ),
        ],
      ),
      body: StreamListView<Map<String, dynamic>>(
        stream: WatchPollService.instance.myPollsStream(),
        emptyBuilder: (context) => _empty(context, l10n),
        builder: (context, polls) => ReadableListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: polls.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _card(context, l10n, polls[i]),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, AppLocalizations l10n, Map<String, dynamic> poll) {
    final title = (poll['title'] as String?)?.trim().isNotEmpty == true
        ? poll['title'] as String
        : l10n.watchPollDefaultTitle;
    final options =
        (poll['options'] as Map?)?.values.whereType<Map>().toList() ??
            const [];
    final totalVotes = options.fold<int>(
        0, (acc, o) => acc + (((o['votes'] as List?) ?? const []).length));
    final closed = poll['status'] == 'closed';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => WatchPollDetailScreen(pollId: poll['id'] as String)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                if (closed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.textMuted.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(l10n.watchPollClosedLabel,
                        style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                totalVotes == 1
                    ? l10n.watchPollVoteCountSingular(totalVotes.toString())
                    : l10n.watchPollVoteCountPlural(totalVotes.toString()),
                style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
            if (options.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 66,
                child: Row(
                  children: [
                    for (final o in options.take(6))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 44,
                            height: 66,
                            child: TmdbImage(
                                url: Tmdb.poster(
                                    (o['posterPath'] ?? '') as String,
                                    size: 'w185')),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_vote_outlined,
                size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(l10n.watchPollsEmptyTitle,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l10n.watchPollsEmptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
