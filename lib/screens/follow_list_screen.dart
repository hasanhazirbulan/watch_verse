import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/social_widgets.dart';

/// Shows a list of users given their uids (a user's followers or following).
class FollowListScreen extends StatefulWidget {
  final String title;
  final List<String> userIds;
  const FollowListScreen(
      {super.key, required this.title, required this.userIds});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late final Future<List<Map<String, dynamic>>> _future =
      SocialService.instance.usersByIds(widget.userIds);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: widget.userIds.isEmpty
          ? _empty(context)
          : FutureListView<Map<String, dynamic>>(
              future: _future,
              emptyBuilder: (_) => _empty(context),
              builder: (context, users) => ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, i) => UserTile(user: users[i]),
              ),
            ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Text(AppLocalizations.of(context)!.followListEmptyMessage,
          style: TextStyle(color: context.colors.textSecondary)),
    );
  }
}
