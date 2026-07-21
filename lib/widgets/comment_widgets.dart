import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/comments_screen.dart';
import 'package:watch_verse/services/comment_service.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/social_widgets.dart';

/// A tappable "Comments" row shown on a detail screen. Because comments can
/// contain spoilers, they live behind this button on their own screen rather
/// than inline. Shows a live count.
class CommentsButton extends StatelessWidget {
  final MediaType mediaType;
  final int mediaId;
  final String title;
  const CommentsButton({
    super.key,
    required this.mediaType,
    required this.mediaId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Comment>>(
      stream: CommentService.instance.stream(mediaType, mediaId),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final count = snap.data?.length ?? 0;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommentsScreen(
                  mediaType: mediaType, mediaId: mediaId, title: title),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.forum_rounded, color: context.colors.primary),
                const SizedBox(width: 12),
                Text(l10n.commentWCommentsLabel,
                    style:
                        const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (count > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$count',
                        style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                const Spacer(),
                Text(l10n.commentWSpoilersHint,
                    style: TextStyle(
                        color: context.colors.textMuted, fontSize: 11.5)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    color: context.colors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One comment: author, text, optional image/GIF, like toggle and an overflow
/// menu (delete own / report others).
class CommentCard extends StatelessWidget {
  final Comment comment;
  const CommentCard({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final svc = CommentService.instance;
    final me = svc.uid;
    final liked = comment.likedBy(me);
    final mine = me != null && me == comment.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                  photoURL: comment.photoURL, name: comment.name, radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(comment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(_ago(context, comment.createdAt),
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 11)),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded,
                    color: context.colors.textMuted, size: 20),
                color: context.colors.surfaceAlt,
                onSelected: (v) => _onMenu(context, v),
                itemBuilder: (_) => [
                  if (mine)
                    PopupMenuItem(
                        value: 'delete', child: Text(l10n.commentWDelete))
                  else ...[
                    PopupMenuItem(
                        value: 'report', child: Text(l10n.commentWReport)),
                    PopupMenuItem(
                        value: 'block',
                        child: Text(l10n.commentWBlockUser)),
                  ],
                ],
              ),
            ],
          ),
          if (comment.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment.text,
                style: TextStyle(
                    color: context.colors.textPrimary, height: 1.4, fontSize: 14)),
          ],
          if (comment.imageUrl != null && comment.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: Image.network(
                  comment.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => svc.toggleLike(comment),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 18,
                  color: liked
                      ? context.colors.primaryDark
                      : context.colors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  comment.likes.isEmpty
                      ? l10n.commentWLike
                      : '${comment.likes.length}',
                  style: TextStyle(
                    color: liked
                        ? context.colors.primaryDark
                        : context.colors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String value) async {
    final l10n = AppLocalizations.of(context)!;
    final svc = CommentService.instance;
    final messenger = ScaffoldMessenger.of(context);
    if (value == 'delete') {
      await svc.delete(comment.id);
    } else if (value == 'report') {
      await svc.report(comment.id);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.commentWReportedSnackbar)),
      );
    } else if (value == 'block') {
      await SocialService.instance.block(comment.uid);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.commentWBlockedSnackbar)),
      );
    }
  }

  String _ago(BuildContext context, DateTime? at) {
    if (at == null) return '';
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return l10n.commentWJustNow;
    if (diff.inMinutes < 60) return l10n.commentWMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.commentWHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.commentWDaysAgo(diff.inDays);
    return l10n.commentWWeeksAgo(diff.inDays ~/ 7);
  }
}
