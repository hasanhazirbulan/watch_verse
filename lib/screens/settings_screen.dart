import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/blocked_users_screen.dart';
import 'package:watch_verse/screens/edit_profile_screen.dart';
import 'package:watch_verse/services/account_deletion_service.dart';
import 'package:watch_verse/services/export_service.dart';
import 'package:watch_verse/services/legal_links.dart';
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
  bool _exporting = false;

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      await ExportService.instance.exportAll();
    } catch (e) {
      // Was try/finally only: a failed read or share left an uncaught error
      // and no feedback at all.
      debugPrint('Settings: export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

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
    } on AccountDeletionIncompleteException {
      // Deletion started (data may already be gone) but couldn't finish.
      // Don't leave the user in a half-emptied account — sign out; the
      // `deletionPending` marker makes the next sign-in finish the job.
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      nav.pushNamedAndRemoveUntil('/login', (r) => false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsDeleteAccountIncomplete)),
      );
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
            icon: Icons.block_rounded,
            label: l10n.profileBlockedUsers,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
          ),
          const SizedBox(height: 12),
          _tile(
            icon: _exporting
                ? Icons.hourglass_top_rounded
                : Icons.file_download_rounded,
            label: _exporting ? l10n.proExporting : l10n.proExportAction,
            onTap: _exporting ? null : _exportData,
          ),
          const SizedBox(height: 12),
          _tile(
            icon: Icons.delete_forever_rounded,
            label: l10n.settingsDeleteAccount,
            danger: true,
            onTap: _deleting ? null : _confirmDeleteAccount,
          ),
          const SizedBox(height: 28),
          _notificationsSection(l10n),
          const SizedBox(height: 28),
          Text(l10n.settingsAppInfoSection,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _tile(
            icon: Icons.privacy_tip_rounded,
            label: l10n.settingsPrivacyPolicy,
            onTap: () => LegalLinks.open(LegalLinks.privacyPolicy),
          ),
          const SizedBox(height: 12),
          _tile(
            icon: Icons.description_rounded,
            label: l10n.settingsTermsOfService,
            onTap: () => LegalLinks.open(LegalLinks.termsOfService),
          ),
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

  // Four independent toggles, all default-on (missing field == true) so
  // existing users don't silently lose notifications when this section
  // ships. Each just merges one bool field into the user doc — the Cloud
  // Functions side (functions/src/index.ts) reads the same fields before
  // sending, so a toggle takes effect on the next scheduled run/event.
  Widget _notificationsSection(AppLocalizations l10n) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsNotificationsSection,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? const <String, dynamic>{};
            return Material(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: [
                  _notifySwitch(userRef, data, 'notifyEpisodeTomorrow',
                      l10n.settingsNotifyEpisodeTomorrow),
                  const Divider(height: 1),
                  _notifySwitch(userRef, data, 'notifyEpisodeToday',
                      l10n.settingsNotifyEpisodeToday),
                  const Divider(height: 1),
                  _notifySwitch(userRef, data, 'notifyFriendActivity',
                      l10n.settingsNotifyFriendActivity),
                  const Divider(height: 1),
                  _notifySwitch(userRef, data, 'notifySharedWatch',
                      l10n.settingsNotifySharedWatch),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _notifySwitch(DocumentReference<Map<String, dynamic>> userRef,
      Map<String, dynamic> data, String field, String label) {
    final value = data[field] != false;
    return SwitchListTile(
      title: Text(label,
          style: TextStyle(
              color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
      value: value,
      activeThumbColor: context.colors.primary,
      onChanged: (v) => userRef.set({field: v}, SetOptions(merge: true)),
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
