import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/list_detail_screen.dart';
import 'package:watch_verse/services/list_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/text_prompt.dart';

/// All of the user's custom lists. Reached from the Home drawer.
class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptForText(
      context,
      title: l10n.listsNewListTitle,
      hint: l10n.listsNewListHint,
      actionLabel: l10n.listsCreateAction,
    );
    if (name == null || name.isEmpty) return;
    await ListService.instance.createList(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final signedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.listsTitle),
        actions: [
          if (signedIn)
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
          : StreamListView<Map<String, dynamic>>(
              stream: ListService.instance.listsStream(),
              emptyBuilder: (context) => _empty(context,
                  Icons.playlist_add_rounded,
                  l10n.listsEmptyTitle, l10n.listsEmptySubtitle),
              builder: (context, lists) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: lists.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _card(context, lists[i]),
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
                child: Row(
                  children: [
                    for (final m in items.take(6))
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
