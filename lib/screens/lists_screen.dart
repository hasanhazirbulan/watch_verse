import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/list_detail_screen.dart';
import 'package:watch_verse/services/list_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/paywall_sheet.dart';
import 'package:watch_verse/widgets/text_prompt.dart';

enum _ListsTab { mine, following }

/// All of the user's custom lists, plus lists they follow from other users.
/// Reached from the Home drawer.
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  _ListsTab _tab = _ListsTab.mine;

  Future<void> _create(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptForText(
      context,
      title: l10n.listsNewListTitle,
      hint: l10n.listsNewListHint,
      actionLabel: l10n.listsCreateAction,
    );
    if (name == null || name.isEmpty) return;
    try {
      await ListService.instance.createList(name);
    } on ListLimitReachedException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.proListLimitReached)));
      showPaywallSheet(context);
    } catch (_) {
      // Any other failure (offline, permission) used to go unhandled with
      // no feedback — the list just never appeared.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final signedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.listsTitle),
        actions: [
          if (signedIn && _tab == _ListsTab.mine)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _create(context),
            ),
        ],
      ),
      body: !signedIn
          ? _empty(context, Icons.playlist_add_rounded,
              l10n.listsSignInTitle,
              l10n.listsSignInSubtitle)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedTabs(
                    labels: [l10n.listsTabMine, l10n.listsTabFollowing],
                    selected: _tab.index,
                    onChanged: (i) =>
                        setState(() => _tab = _ListsTab.values[i]),
                  ),
                ),
                Expanded(
                  child: _tab == _ListsTab.mine
                      ? _myLists(context, l10n)
                      : _followedLists(context, l10n),
                ),
              ],
            ),
    );
  }

  Widget _myLists(BuildContext context, AppLocalizations l10n) {
    return StreamListView<Map<String, dynamic>>(
      stream: ListService.instance.listsStream(),
      emptyBuilder: (context) => _empty(context, Icons.playlist_add_rounded,
          l10n.listsEmptyTitle, l10n.listsEmptySubtitle),
      builder: (context, lists) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: lists.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _card(context, lists[i]),
      ),
    );
  }

  Widget _followedLists(BuildContext context, AppLocalizations l10n) {
    return StreamListView<Map<String, dynamic>>(
      stream: ListService.instance.followedListsStream(),
      emptyBuilder: (context) => _empty(context, Icons.bookmark_add_outlined,
          l10n.listsFollowingEmptyTitle, l10n.listsFollowingEmptySubtitle),
      builder: (context, followed) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: followed.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _followedCard(context, followed[i]),
      ),
    );
  }

  Widget _followedCard(BuildContext context, Map<String, dynamic> ref) {
    final l10n = AppLocalizations.of(context)!;
    final listName = (ref['listName'] ?? l10n.listsUntitled) as String;
    final ownerName = (ref['ownerName'] ?? '') as String;
    final coverPosterPath = (ref['coverPosterPath'] ?? '') as String;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListDetailScreen(
            listId: ref['listId'] as String,
            name: listName,
            ownerUid: ref['ownerUid'] as String,
            ownerName: ownerName,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 62,
                child: coverPosterPath.isEmpty
                    ? Container(
                        color: context.colors.surfaceAlt,
                        child: Icon(Icons.playlist_play_rounded,
                            color: context.colors.textMuted))
                    : TmdbImage(
                        url: Tmdb.poster(coverPosterPath, size: 'w185')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  if (ownerName.isNotEmpty)
                    Text(l10n.listsFollowingByLabel(ownerName),
                        style: TextStyle(
                            color: context.colors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> list) {
    final l10n = AppLocalizations.of(context)!;
    final name = (list['name'] ?? l10n.listsUntitled) as String;
    final items = ListService.itemsFrom(list);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ListDetailScreen(listId: list['id'] as String, name: name)),
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
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                Text(
                    '${items.length} ${items.length == 1 ? l10n.listsTitleSingular : l10n.listsTitlePlural}',
                    style: TextStyle(
                        color: context.colors.textMuted, fontSize: 12)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: context.colors.textMuted),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(l10n.listsCardEmptySubtitle,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13))
            else
              SizedBox(
                height: 66,
                // Six 50px-wide thumbs need 300px; on a 320pt-wide phone
                // the card only has ~264px, so the row overflowed. Show only
                // as many as fit (max 6).
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                  children: [
                    for (final m in items.take(
                        (constraints.maxWidth / 50).floor().clamp(0, 6)))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 44,
                            height: 66,
                            child: TmdbImage(
                                url: Tmdb.poster(m.posterPath, size: 'w185')),
                          ),
                        ),
                      ),
                  ],
                ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
