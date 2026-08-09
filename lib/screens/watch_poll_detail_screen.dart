import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/watch_poll_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// One "what should we watch?" poll: options as vote bars (tap to vote),
/// live as members vote. The creator can close it (locking in the current
/// leader) or delete it entirely.
class WatchPollDetailScreen extends StatelessWidget {
  final String pollId;
  const WatchPollDetailScreen({super.key, required this.pollId});

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _closePoll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.watchPollCloseTitle),
        content: Text(l10n.watchPollCloseContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.watchPollCloseConfirm)),
        ],
      ),
    );
    if (yes == true) await WatchPollService.instance.closePoll(pollId);
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final nav = Navigator.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.watchPollDeleteTitle),
        content: Text(l10n.watchPollDeleteContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.watchPollDeleteConfirm)),
        ],
      ),
    );
    if (yes == true) {
      await WatchPollService.instance.deletePoll(pollId);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: WatchPollService.instance.pollStream(pollId),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final poll = snap.data;
        if (poll == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
                child: Text(l10n.watchPollNotFound,
                    style: TextStyle(color: context.colors.textSecondary))),
          );
        }

        final title = (poll['title'] as String?)?.trim().isNotEmpty == true
            ? poll['title'] as String
            : l10n.watchPollDefaultTitle;
        final isCreator = poll['creatorUid'] == _uid;
        final closed = poll['status'] == 'closed';
        final options =
            (poll['options'] as Map? ?? const {}).entries.toList();
        final totalVotes = options.fold<int>(
            0,
            (acc, e) =>
                acc + (((e.value as Map)['votes'] as List?) ?? const []).length);
        final myVoteKey = options
            .cast<MapEntry<dynamic, dynamic>?>()
            .firstWhere(
              (e) => (((e!.value as Map)['votes'] as List?) ?? const [])
                  .contains(_uid),
              orElse: () => null,
            )
            ?.key as String?;
        // Highest vote count, for the leader/winner crown once votes exist.
        final maxVotes = options.fold<int>(
            0,
            (acc, e) => (((e.value as Map)['votes'] as List?) ?? const [])
                    .length >
                acc
                ? (((e.value as Map)['votes'] as List?) ?? const []).length
                : acc);

        return Scaffold(
          appBar: AppBar(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (isCreator)
                PopupMenuButton<String>(
                  color: context.colors.surfaceAlt,
                  onSelected: (v) =>
                      v == 'close' ? _closePoll(context) : _delete(context),
                  itemBuilder: (_) => [
                    if (!closed)
                      PopupMenuItem(
                          value: 'close',
                          child: Text(l10n.watchPollCloseMenuItem)),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.watchPollDeleteMenuItem)),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (closed)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          color: context.colors.success),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(l10n.watchPollClosedBanner,
                              style: TextStyle(
                                  color: context.colors.success,
                                  fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
              Text(
                  totalVotes == 1
                      ? l10n.watchPollVoteCountSingular(totalVotes.toString())
                      : l10n.watchPollVoteCountPlural(totalVotes.toString()),
                  style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
              const SizedBox(height: 14),
              for (final entry in options)
                _optionRow(
                  context,
                  l10n,
                  key: entry.key as String,
                  option: entry.value as Map,
                  totalVotes: totalVotes,
                  isLeader: !closed &&
                      totalVotes > 0 &&
                      (((entry.value as Map)['votes'] as List?) ?? const [])
                              .length ==
                          maxVotes,
                  isMine: entry.key == myVoteKey,
                  votingEnabled: !closed,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _optionRow(
    BuildContext context,
    AppLocalizations l10n, {
    required String key,
    required Map option,
    required int totalVotes,
    required bool isLeader,
    required bool isMine,
    required bool votingEnabled,
  }) {
    final votes = ((option['votes'] as List?) ?? const []).length;
    final fraction = totalVotes == 0 ? 0.0 : votes / totalVotes;
    return GestureDetector(
      onTap: votingEnabled ? () => WatchPollService.instance.vote(pollId, key) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: isMine
              ? Border.all(color: context.colors.primary, width: 1.4)
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 46,
                height: 68,
                child: TmdbImage(
                    url: Tmdb.poster((option['posterPath'] ?? '') as String,
                        size: 'w185')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text((option['title'] ?? '') as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      if (isLeader)
                        Icon(Icons.emoji_events_rounded,
                            size: 16, color: context.colors.accent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressPill(value: fraction, height: 6),
                  const SizedBox(height: 6),
                  Text(
                      votes == 1
                          ? l10n.watchPollOptionVotesSingular(votes.toString())
                          : l10n.watchPollOptionVotesPlural(votes.toString()),
                      style:
                          TextStyle(color: context.colors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isMine ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isMine ? context.colors.primary : context.colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
