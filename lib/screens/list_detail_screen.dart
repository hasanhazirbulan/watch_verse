import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/list_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/text_prompt.dart';

/// One custom list, its titles in a grid. Doubles as two screens in one:
///   • [ownerUid] null  → your own list — rename / delete / make public,
///     per-item removal.
///   • [ownerUid] set   → someone else's *public* list, read-only, with a
///     Follow/Unfollow action instead of the edit menu.
class ListDetailScreen extends StatelessWidget {
  final String listId;
  final String name;
  final String? ownerUid;
  final String? ownerName;
  const ListDetailScreen({
    super.key,
    required this.listId,
    required this.name,
    this.ownerUid,
    this.ownerName,
  });

  bool get _isOwnList => ownerUid == null;

  Stream<Map<String, dynamic>?> _stream() => _isOwnList
      ? ListService.instance.listStream(listId)
      : ListService.instance.publicListStream(ownerUid!, listId);

  Future<void> _rename(BuildContext context, String current) async {
    final l10n = AppLocalizations.of(context)!;
    final n = await promptForText(
      context,
      title: l10n.listDetailRenameTitle,
      initial: current,
      actionLabel: l10n.save,
    );
    if (n != null && n.isNotEmpty) {
      await ListService.instance.renameList(listId, n);
    }
  }

  Future<void> _togglePublic(BuildContext context, bool currentlyPublic) async {
    await ListService.instance.setPublic(listId, !currentlyPublic);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(currentlyPublic
          ? l10n.listDetailMadePrivate
          : l10n.listDetailMadePublic),
    ));
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final nav = Navigator.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.listDetailDeleteTitle),
        content: Text(l10n.listDetailDeleteContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.listDetailDeleteConfirm)),
        ],
      ),
    );
    if (yes == true) {
      await ListService.instance.deleteList(listId);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _stream(),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final list = snap.data;
        final title = (list?['name'] ?? name) as String;
        final isPublic = list?['public'] == true;
        final items = ListService.itemsFrom(list);
        return Scaffold(
          appBar: AppBar(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (_isOwnList)
                PopupMenuButton<String>(
                  color: context.colors.surfaceAlt,
                  onSelected: (v) {
                    switch (v) {
                      case 'rename':
                        _rename(context, title);
                      case 'public':
                        _togglePublic(context, isPublic);
                      case 'delete':
                        _delete(context);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'rename',
                        child: Text(l10n.listDetailRenameMenuItem)),
                    PopupMenuItem(
                        value: 'public',
                        child: Text(isPublic
                            ? l10n.listDetailMakePrivateMenuItem
                            : l10n.listDetailMakePublicMenuItem)),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.listDetailDeleteMenuItem)),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _FollowListButton(
                    ownerUid: ownerUid!,
                    listId: listId,
                    ownerName: ownerName ?? '',
                    listName: title,
                    coverPosterPath:
                        items.isNotEmpty ? items.first.posterPath : '',
                  ),
                ),
            ],
          ),
          // Loading and failures (e.g. a followed list its owner has since
          // made private → permission-denied) used to render as "This list
          // is empty".
          body: snap.hasError
              ? asyncErrorView(context, snap.error!)
              : snap.connectionState == ConnectionState.waiting && !snap.hasData
              ? asyncLoadingIndicator()
              : items.isEmpty
              ? _empty(context)
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.52,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _poster(context, items[i]),
                ),
        );
      },
    );
  }

  Widget _poster(BuildContext context, MediaItem item) {
    return Stack(
      children: [
        PosterCard(
          item: item,
          width: double.infinity,
          onTap: () => openMedia(context, item),
        ),
        if (_isOwnList)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => ListService.instance
                  .removeFromList(listId, ListService.keyFor(item)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 15, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_filter_outlined,
                size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(l10n.listDetailEmptyTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l10n.listDetailEmptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _FollowListButton extends StatelessWidget {
  final String ownerUid;
  final String listId;
  final String ownerName;
  final String listName;
  final String coverPosterPath;
  const _FollowListButton({
    required this.ownerUid,
    required this.listId,
    required this.ownerName,
    required this.listName,
    required this.coverPosterPath,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<bool>(
      stream: ListService.instance.isFollowingListStream(ownerUid, listId),
      builder: (context, snap) {
        final following = snap.data ?? false;
        return TextButton.icon(
          onPressed: () => following
              ? ListService.instance.unfollowList(ownerUid, listId)
              : ListService.instance.followList(
                  ownerUid: ownerUid,
                  listId: listId,
                  ownerName: ownerName,
                  listName: listName,
                  coverPosterPath: coverPosterPath,
                ),
          icon: Icon(
              following ? Icons.check_rounded : Icons.add_rounded,
              size: 18,
              color: following ? context.colors.success : context.colors.primary),
          label: Text(
            following ? l10n.listDetailFollowing : l10n.listDetailFollow,
            style: TextStyle(
                color:
                    following ? context.colors.success : context.colors.primary,
                fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}
