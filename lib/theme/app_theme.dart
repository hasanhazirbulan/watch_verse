import 'package:flutter/material.dart';

/// Central color palette for WatchVerse, as a [ThemeExtension] so it can vary
/// between [AppColors.dark] and [AppColors.light] and update live when the
/// user switches theme. Access via `context.colors` (see [AppColorsX]) rather
/// than as static constants, since the values are no longer compile-time
/// constants shared by every screen.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color card;
  final Color primary;
  final Color primaryDark;
  final Color accent; // gold, ratings/stars
  final Color success;
  final Color info;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Brand gradient (use for buttons, highlights, active pills).
  final LinearGradient brandGradient;

  /// A soft top-to-bottom scrim used over backdrop imagery so text stays
  /// legible. Deliberately the same dark scrim in both themes since it sits
  /// over photographic posters/backdrops, not app chrome.
  final LinearGradient posterScrim;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.card,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.success,
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brandGradient,
    required this.posterScrim,
  });

  static const _brandGradient = LinearGradient(
    colors: [Color(0xFFFF6A3D), Color(0xFFFF2E63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const _posterScrim = LinearGradient(
    colors: [Colors.transparent, Color(0xCC0B0C10)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// A cohesive, premium dark theme with a warm "cinema" brand gradient
  /// (coral -> magenta) plus a gold accent used for ratings.
  static const dark = AppColors(
    background: Color(0xFF0B0C10),
    surface: Color(0xFF15171E),
    surfaceAlt: Color(0xFF1E212B),
    card: Color(0xFF181A22),
    primary: Color(0xFFFF6A3D),
    primaryDark: Color(0xFFFF2E63),
    accent: Color(0xFFFFC531),
    success: Color(0xFF3DDC97),
    info: Color(0xFF4DA3FF),
    textPrimary: Color(0xFFF5F6FA),
    textSecondary: Color(0xFF9AA0AE),
    textMuted: Color(0xFF6B7280),
    brandGradient: _brandGradient,
    posterScrim: _posterScrim,
  );

  /// Light counterpart: same brand identity (coral/magenta/gold), inverted
  /// surfaces and text.
  static const light = AppColors(
    background: Color(0xFFF6F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF0F4),
    card: Color(0xFFFFFFFF),
    primary: Color(0xFFFF6A3D),
    primaryDark: Color(0xFFFF2E63),
    accent: Color(0xFFC98A00),
    success: Color(0xFF1E9E6B),
    info: Color(0xFF2C7BE0),
    textPrimary: Color(0xFF14161C),
    textSecondary: Color(0xFF52586A),
    textMuted: Color(0xFF8A90A0),
    brandGradient: _brandGradient,
    posterScrim: _posterScrim,
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? card,
    Color? primary,
    Color? primaryDark,
    Color? accent,
    Color? success,
    Color? info,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    LinearGradient? brandGradient,
    LinearGradient? posterScrim,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      card: card ?? this.card,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      info: info ?? this.info,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brandGradient: brandGradient ?? this.brandGradient,
      posterScrim: posterScrim ?? this.posterScrim,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      card: Color.lerp(card, other.card, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brandGradient:
          LinearGradient.lerp(brandGradient, other.brandGradient, t)!,
      posterScrim: LinearGradient.lerp(posterScrim, other.posterScrim, t)!,
    );
  }
}

/// Shorthand for reaching the active [AppColors] from any widget:
/// `context.colors.background`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// TMDB image helpers. Centralizes the CDN base + sizing so we never sprinkle
/// raw URL strings across the UI again.
class Tmdb {
  Tmdb._();

  static const String _imageBase = 'https://image.tmdb.org/t/p';

  /// Poster (2:3). Returns null when there's no image so callers can show a
  /// graceful placeholder.
  static String? poster(String? path, {String size = 'w342'}) =>
      (path == null || path.isEmpty) ? null : '$_imageBase/$size$path';

  /// Backdrop (16:9).
  static String? backdrop(String? path, {String size = 'w780'}) =>
      (path == null || path.isEmpty) ? null : '$_imageBase/$size$path';

  /// Episode still (16:9).
  static String? still(String? path, {String size = 'w300'}) =>
      (path == null || path.isEmpty) ? null : '$_imageBase/$size$path';

  /// Provider / small square logo.
  static String? logo(String? path, {String size = 'w92'}) =>
      (path == null || path.isEmpty) ? null : '$_imageBase/$size$path';
}

class AppTheme {
  AppTheme._();

  static ThemeData _themeFor(AppColors colors, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return base.copyWith(
      extensions: [colors],
      scaffoldBackgroundColor: colors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        surface: colors.surface,
        primary: colors.primary,
        secondary: colors.accent,
        onPrimary: Colors.white,
        onSurface: colors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      ),
      dividerColor: brightness == Brightness.dark
          ? Colors.white10
          : Colors.black12,
      cardColor: colors.card,
      dialogTheme: DialogThemeData(backgroundColor: colors.surfaceAlt),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surfaceAlt,
        contentTextStyle: TextStyle(color: colors.textPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        hintStyle: TextStyle(color: colors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  static final ThemeData dark = _themeFor(AppColors.dark, Brightness.dark);
  static final ThemeData light = _themeFor(AppColors.light, Brightness.light);
}
