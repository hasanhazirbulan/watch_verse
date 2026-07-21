import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/list_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/text_prompt.dart';

/// Opens the "Add to list" picker for [item] — toggle membership across the
/// user's custom lists or create a new one on the spot.
Future<void> showAddToListSheet(BuildContext context, MediaItem item) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _AddToListSheet(item: item),
  );
}

class _AddToListSheet extends StatelessWidget {
  final MediaItem item;
  const _AddToListSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final signedIn = FirebaseAuth.instance.currentUser != null;
    final key = ListService.keyFor(item);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.textMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.addToListTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                if (signedIn)
                  TextButton.icon(
                    onPressed: () => _createAndAdd(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(l10n.addToListNewListButton),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!signedIn)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(l10n.addToListSignInMessage,
                      style: TextStyle(color: context.colors.textSecondary)),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ListService.instance.listsStream(),
                  builder: (context, snap) {
                    final lists = snap.data ?? const [];
                    if (lists.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                              l10n.addToListEmptyMessage,
                              style: TextStyle(
                                  color: context.colors.textSecondary)),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: lists.length,
                      itemBuilder: (context, i) =>
                          _listTile(context, lists[i], key),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _listTile(BuildContext context, Map<String, dynamic> list, String key) {
    final l10n = AppLocalizations.of(context)!;
    final items = (list['items'] as Map?) ?? const {};
    final contains = items.containsKey(key);
    final cover = ListService.itemsFrom(list);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => contains
          ? ListService.instance.removeFromList(list['id'] as String, key)
          : ListService.instance.addToList(list['id'] as String, item),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 56,
          child: cover.isEmpty
              ? Container(
                  color: context.colors.surfaceAlt,
                  child: Icon(Icons.playlist_play_rounded,
                      color: context.colors.textMuted))
              : TmdbImage(
                  url: Tmdb.poster(cover.first.posterPath, size: 'w185')),
        ),
      ),
      title: Text((list['name'] ?? l10n.addToListUntitled) as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${items.length} ${items.length == 1 ? l10n.addToListTitleSingular : l10n.addToListTitlePlural}',
          style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
      trailing: Icon(
        contains ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: contains ? context.colors.success : context.colors.textMuted,
      ),
    );
  }

  Future<void> _createAndAdd(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptForText(
      context,
      title: l10n.addToListCreateTitle,
      hint: l10n.addToListCreateHint,
      actionLabel: l10n.addToListCreateAction,
    );
    if (name == null || name.isEmpty) return;
    final id = await ListService.instance.createList(name);
    if (id != null) await ListService.instance.addToList(id, item);
  }
}
