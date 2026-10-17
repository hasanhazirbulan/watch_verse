import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/responsive.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/social_widgets.dart';

/// Lists the people you've blocked, with a one-tap unblock. Blocked users'
/// comments and activity are hidden from you elsewhere in the app.
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final social = SocialService.instance;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedTitle)),
      body: StreamListView<String>(
        stream: social.blockedStream(),
        emptyBuilder: (context) => _empty(context),
        builder: (context, ids) => FutureListView<Map<String, dynamic>>(
          future: social.usersByIds(ids),
          emptyBuilder: (context) => _empty(context),
          builder: (context, users) => ReadableListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final u = users[i];
              final name = (u['name'] ?? l10n.blockedDefaultUserName) as String;
              final uid = (u['uid'] ?? '') as String;
              return ListTile(
                leading:
                    UserAvatar(photoURL: u['photoURL'] as String?, name: name),
                title: Text(name.isEmpty ? l10n.blockedDefaultUserName : name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.textPrimary,
                    side: BorderSide(color: context.colors.textMuted),
                  ),
                  onPressed: () => social.unblock(uid),
                  child: Text(l10n.blockedUnblockButton),
                ),
              );
            },
          ),
        ),
      ),
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
            Icon(Icons.block_rounded, size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(l10n.blockedEmptyTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l10n.blockedEmptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
