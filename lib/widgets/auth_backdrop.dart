import 'dart:ui';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/responsive.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

/// Widest the auth forms get (fields + their 24 pt side padding).
const double authFormMaxWidth = 488;

/// Gap above the login form, over the backdrop. 250 pt on phones; on wide
/// windows it shrinks with the height so a landscape window (e.g. the
/// iPhone Duo's 951x669 inner display) still shows the form above the fold.
double authTopGap(Size window) => window.width < Breakpoints.medium
    ? 250
    : (window.height * 0.25).clamp(120.0, 250.0);

/// Atmospheric auth header: an auto-scrolling, blurred carousel of backdrops
/// from currently-playing movies, fading into the page background.
///
/// Fully crash-safe: it renders a gradient immediately, swaps in images only
/// once they load, and each image degrades to a placeholder on failure — a
/// network error never throws.
class AuthBackdrop extends StatefulWidget {
  final double height;
  const AuthBackdrop({super.key, this.height = 340});

  @override
  State<AuthBackdrop> createState() => _AuthBackdropState();
}

class _AuthBackdropState extends State<AuthBackdrop> {
  List<MediaItem> _items = const [];

  @override
  void initState() {
    super.initState();
    APIservices().getNowPlayingMovies().then((movies) {
      if (!mounted) return;
      setState(() {
        _items = movies.where((m) => m.backdropPath.isNotEmpty).take(10).toList();
      });
    }).catchError((_) {
      // Ignore — the gradient fallback stays.
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: FullBleed(child: _backdrop(context)),
    );
  }

  Widget _backdrop(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base gradient — visible while images load and as a safety net.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF241B2F), context.colors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          if (_items.isNotEmpty)
            CarouselSlider.builder(
              itemCount: _items.length,
              itemBuilder: (context, index, _) => TmdbImage(
                url: Tmdb.backdrop(_items[index].backdropPath, size: 'w780'),
              ),
              options: CarouselOptions(
                height: widget.height,
                autoPlay: true,
                viewportFraction: 1.0,
                autoPlayInterval: const Duration(seconds: 5),
                autoPlayAnimationDuration: const Duration(milliseconds: 1200),
              ),
            ),
          // Blur + darken everything painted so far.
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.black.withValues(alpha: 0.42)),
          ),
          // Melt into the page background at the bottom.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, context.colors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.45, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient wordmark + subtitle used at the top of both auth screens.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => context.colors.brandGradient.createShader(b),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

/// Themed text field with a leading icon and optional password toggle.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: context.colors.textSecondary),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: context.colors.textMuted,
                ),
                onPressed: onToggleObscure,
              ),
      ),
      validator: validator,
    );
  }
}

/// Full-width brand-gradient button with an inline loading state.
class GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: context.colors.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.colors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
      ),
    );
  }
}
