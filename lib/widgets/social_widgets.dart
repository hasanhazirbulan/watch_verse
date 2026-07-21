import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/public_profile_screen.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// Circular user avatar with an initial-letter fallback.
class UserAvatar extends StatelessWidget {
  final String? photoURL;
  final String name;
  final double radius;
  const UserAvatar({
    super.key,
    required this.photoURL,
    required this.name,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final has = photoURL != null && photoURL!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.colors.surfaceAlt,
      backgroundImage: has ? NetworkImage(photoURL!) : null,
      child: has
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: radius * 0.8, fontWeight: FontWeight.bold),
            ),
    );
  }
}

/// Follow / Following toggle. Hidden for yourself and guests.
class FollowButton extends StatelessWidget {
  final String targetUid;
  const FollowButton({super.key, required this.targetUid});

  @override
  Widget build(BuildContext context) {
    final me = SocialService.instance.uid;
    if (me == null || me == targetUid) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: SocialService.instance.isFollowingStream(targetUid),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final following = snap.data ?? false;
        return GestureDetector(
          onTap: () => following
              ? SocialService.instance.unfollow(targetUid)
              : SocialService.instance.follow(targetUid),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: following ? null : context.colors.brandGradient,
              color: following ? context.colors.surfaceAlt : null,
              borderRadius: BorderRadius.circular(20),
              border: following
                  ? Border.all(color: context.colors.textMuted, width: 1)
                  : null,
            ),
            child: Text(
              following ? l10n.socialFollowing : l10n.socialFollow,
              style: TextStyle(
                color: following ? context.colors.textSecondary : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A row for a user in search / follower lists.
class UserTile extends StatelessWidget {
  final Map<String, dynamic> user; // needs uid, name, photoURL
  const UserTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = (user['uid'] ?? '') as String;
    final name = (user['name'] ?? l10n.socialDefaultUserName) as String;
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PublicProfileScreen(userId: uid, name: name)),
      ),
      leading: UserAvatar(photoURL: user['photoURL'] as String?, name: name),
      title: Text(name.isEmpty ? l10n.socialDefaultUserName : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('@${uid.length > 6 ? uid.substring(0, 6) : uid}',
          style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
      trailing: FollowButton(targetUid: uid),
    );
  }
}
