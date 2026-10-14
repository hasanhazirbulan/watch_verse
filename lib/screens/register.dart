import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/main_screen.dart';
import 'package:watch_verse/services/database_service.dart';
import 'package:watch_verse/services/notification_service.dart';
import 'package:watch_verse/services/pro_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/validators.dart';
import 'package:watch_verse/widgets/auth_backdrop.dart';

class RegisterScreen extends StatefulWidget {
  /// Test-only override — defaults to [FirebaseAuth.instance] so production
  /// call sites (`RegisterScreen()`) don't need to change.
  final FirebaseAuth? auth;
  const RegisterScreen({super.key, this.auth});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // `late` so DatabaseService.instance (which touches Firestore) is only
  // resolved when actually needed (inside _register()), not eagerly at
  // State construction — form-validation-only widget tests never reach it.
  late final DatabaseService _databaseService = DatabaseService.instance;
  final _formKey = GlobalKey<FormState>();
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscureText = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      try {
        await _databaseService.createUser(
          uid: cred.user!.uid,
          email: _emailController.text.trim(),
          name: _nameController.text.trim(),
        );
      } catch (_) {
        // Roll back the auth account so retrying doesn't hit
        // "email-already-in-use" for an account with no profile doc.
        await cred.user!.delete().catchError((_) => _auth.signOut());
        rethrow;
      }
      unawaited(ProService.instance.onProfileCreated(cred.user!.uid));
      unawaited(NotificationService.instance.onProfileCreated(cred.user!.uid));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          _showError(l10n.errorWeakPassword);
          break;
        case 'email-already-in-use':
          _showError(l10n.errorEmailInUse);
          break;
        default:
          _showError(e.message ?? l10n.errorGeneric);
      }
    } catch (e) {
      _showError(l10n.errorCreateAccount(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AuthBackdrop(height: 300),
          ),
          Positioned(
            top: 8,
            left: 4,
            child: SafeArea(child: BackButton(color: Colors.white)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 120),
                  AuthHeader(
                    title: l10n.createAccountTitle,
                    subtitle: l10n.createAccountSubtitle,
                  ),
                  const SizedBox(height: 28),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AuthField(
                          controller: _nameController,
                          hint: l10n.usernameHint,
                          icon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? l10n.usernameRequired
                              : null,
                        ),
                        const SizedBox(height: 16),
                        AuthField(
                          controller: _emailController,
                          hint: l10n.emailHint,
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return l10n.emailRequired;
                            }
                            if (!isValidEmail(v)) return l10n.emailInvalid;
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthField(
                          controller: _passwordController,
                          hint: l10n.passwordHint,
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscureText,
                          onToggleObscure: () =>
                              setState(() => _obscureText = !_obscureText),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return l10n.passwordRequiredRegister;
                            }
                            if (v.length < 6) {
                              return l10n.passwordTooShort;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthField(
                          controller: _confirmPasswordController,
                          hint: l10n.confirmPasswordHint,
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscureText,
                          validator: (v) => (v != _passwordController.text)
                              ? l10n.passwordsDoNotMatch
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: l10n.createAccountButton,
                    loading: _loading,
                    onPressed: _register,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.alreadyHaveAccountPrompt,
                          style: TextStyle(color: context.colors.textMuted)),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.logInLowercase,
                            style: TextStyle(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
