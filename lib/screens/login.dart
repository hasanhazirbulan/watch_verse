import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/main_screen.dart';
import 'package:watch_verse/screens/register.dart';
import 'package:watch_verse/services/database_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/auth_backdrop.dart';

class LoginScreen extends StatefulWidget {
  /// Test-only override — defaults to [FirebaseAuth.instance] so production
  /// call sites (`LoginScreen()`) don't need to change.
  final FirebaseAuth? auth;
  const LoginScreen({super.key, this.auth});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await DatabaseService.instance.getUser(cred.user!.uid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _showError(l10n.errorUserNotFound);
          break;
        case 'wrong-password':
        case 'invalid-credential':
          _showError(l10n.errorWrongPassword);
          break;
        default:
          _showError(e.message ?? l10n.errorGeneric);
      }
    } catch (e) {
      _showError(l10n.errorSignIn(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AuthBackdrop(height: 440),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 250),
                  AuthHeader(
                    title: l10n.appTitle,
                    subtitle: l10n.loginSubtitle,
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AuthField(
                          controller: _emailController,
                          hint: l10n.emailHint,
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return l10n.emailRequired;
                            }
                            if (!v.contains('@')) return l10n.emailInvalid;
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
                          validator: (v) => (v == null || v.isEmpty)
                              ? l10n.passwordRequiredLogin
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: l10n.logIn,
                    loading: _loading,
                    onPressed: _login,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                    ),
                    icon: Icon(Icons.explore_outlined,
                        size: 18, color: context.colors.textSecondary),
                    label: Text(l10n.continueAsGuest,
                        style: TextStyle(color: context.colors.textSecondary)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.noAccountPrompt,
                          style: TextStyle(color: context.colors.textMuted)),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        child: Text(l10n.register,
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
