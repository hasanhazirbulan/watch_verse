import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/edit_profile_screen.dart';
import 'package:watch_verse/services/account_deletion_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

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

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
    try {
      await AccountDeletionService.instance.deleteAccount();
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
