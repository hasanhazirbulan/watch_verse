import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/edit_profile_screen.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/theme/theme_controller.dart';

/// App-level preferences plus account management (edit profile, delete
/// account) — the drawer is the only other entry point into account actions,
/// so this is where they all live.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;

  Future<void> _confirmDeleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteAccountConfirmTitle),
        content: Text(l10n.settingsDeleteAccountConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsDeleteAccountAction,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteAccount();
  }

  /// Deletes every doc under `users/{uid}` — the schema is fixed (see
  /// firestore.rules), so unlike a generic "delete everything" this doesn't
  /// need an Admin SDK to enumerate collections. Must run while still
  /// signed in: the security rules gate every one of these deletes on
  /// `request.auth.uid == uid`, so this has to finish *before*
  /// `user.delete()` or the writes would be rejected.
  Future<void> _purgeUserData(String uid) async {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(uid);

    Future<void> deleteAll(Query<Map<String, dynamic>> query) async {
      final snap = await query.get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = db.batch();
        for (final doc in snap.docs.skip(i).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    await deleteAll(userRef.collection('movies'));
    await deleteAll(userRef.collection('activity'));
    await deleteAll(userRef.collection('diary'));
    await deleteAll(userRef.collection('lists'));
    await deleteAll(userRef.collection('pollAnswers'));

    final shows = await userRef.collection('shows').get();
    for (final show in shows.docs) {
      await deleteAll(show.reference.collection('watched'));
      await deleteAll(show.reference.collection('notes'));
    }
    await deleteAll(userRef.collection('shows'));

    await userRef.delete();
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
    try {
      await _purgeUserData(user.uid);
      await user.delete();
      nav.pushNamedAndRemoveUntil('/login', (r) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      if (e.code == 'requires-recent-login') {
        messenger.showSnackBar(
          SnackBar(
              content:
                  Text(l10n.settingsDeleteAccountRequiresRecentLogin)),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
              content:
                  Text(l10n.settingsDeleteAccountError(e.message ?? e.code))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsDeleteAccountError(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.settingsAccountSection,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _tile(
            icon: Icons.person_rounded,
            label: l10n.profileEditProfileTitle,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          const SizedBox(height: 12),
          _tile(
            icon: Icons.delete_forever_rounded,
            label: l10n.settingsDeleteAccount,
            danger: true,
            onTap: _deleting ? null : _confirmDeleteAccount,
          ),
          const SizedBox(height: 28),
          Text(l10n.appearance,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance,
            builder: (context, mode, _) => SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeSystem),
                  icon: const Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                  icon: const Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                  icon: const Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selected) =>
                  ThemeController.instance.setMode(selected.first),
            ),
          ),
          const SizedBox(height: 28),
          Text(l10n.settingsAppInfoSection,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final info = snap.data;
              if (info == null) return const SizedBox.shrink();
              return Text(
                l10n.settingsAppVersion('${info.version} (${info.buildNumber})'),
                style: TextStyle(color: context.colors.textMuted, fontSize: 13),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? Colors.red : context.colors.textPrimary;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: color),
        title: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: context.colors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
