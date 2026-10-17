import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/account_deletion_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/services/app_firebase.dart';

/// Shown instead of the app when the signed-in user's profile carries a
/// `deletionPending` marker — i.e. an earlier "Delete account" was
/// interrupted partway. Finishes the deletion the user already confirmed,
/// rather than letting a half-purged account pass for a live one with an
/// empty library (see AccountDeletionService.deleteAccount).
class FinishDeletionScreen extends StatefulWidget {
  const FinishDeletionScreen({super.key});

  @override
  State<FinishDeletionScreen> createState() => _FinishDeletionScreenState();
}

class _FinishDeletionScreenState extends State<FinishDeletionScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // Post-frame: _resume looks up localizations/navigator via context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resume();
    });
  }

  Future<void> _resume() async {
    final l10n = AppLocalizations.of(context)!;
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _error = null);
    try {
      await AccountDeletionService.instance.resumePendingDeletion();
      nav.pushNamedAndRemoveUntil('/login', (r) => false);
    } on AccountDeletionIncompleteException catch (e) {
      final cause = e.cause;
      if (cause is FirebaseAuthException &&
          cause.code == 'requires-recent-login') {
        // Only a fresh sign-in can finish it — and the marker is still set,
        // so signing back in lands here again and completes it.
        await _signOut(nav);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.settingsDeleteAccountIncomplete)),
        );
        return;
      }
      if (mounted) setState(() => _error = cause.toString());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _signOut(NavigatorState nav) async {
    try {
      await AppFirebase.auth.signOut();
    } catch (_) {}
    nav.pushNamedAndRemoveUntil('/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = _error;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.accountDeletionFinishingTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  error == null
                      ? l10n.accountDeletionFinishingBody
                      : l10n.accountDeletionResumeFailed(error),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary),
                ),
                const SizedBox(height: 24),
                if (error == null)
                  const CircularProgressIndicator()
                else ...[
                  FilledButton(
                    onPressed: _resume,
                    child: Text(l10n.accountDeletionRetry),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        _signOut(Navigator.of(context, rootNavigator: true)),
                    child: Text(l10n.accountDeletionSignOut),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
