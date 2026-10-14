import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/actor_guess_screen.dart';
import 'package:watch_verse/screens/daily_game_screen.dart';
import 'package:watch_verse/screens/games/frames_game_screen.dart';
import 'package:watch_verse/screens/games/title_wordle_screen.dart';

/// One card on the Games hub (`GamesHubScreen`). Strings are functions of
/// [AppLocalizations] so entries can live in a plain top-level list.
class GameEntry {
  final IconData icon;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;
  final WidgetBuilder builder;

  /// Optional one-line "today" status shown on the card (e.g. "Solved
  /// today"); emit null to show nothing. Omit for games without one.
  final Stream<String?> Function(AppLocalizations l10n)? todayStatus;

  const GameEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.todayStatus,
  });
}

/// Every game in the app, in hub order. To add a game, add an entry here.
final List<GameEntry> gameRegistry = [
  GameEntry(
    icon: Icons.theaters_rounded,
    title: (l10n) => l10n.dailyGameTitle,
    subtitle: (l10n) => l10n.gamesHubDailyMovieSubtitle,
    builder: (_) => const DailyGameScreen(),
    todayStatus: dailyGameTodayStatus,
  ),
  GameEntry(
    icon: Icons.photo_library_rounded,
    title: (l10n) => l10n.framesGameTitle,
    subtitle: (l10n) => l10n.gamesHubFramesSubtitle,
    builder: (_) => const FramesGameScreen(),
  ),
  GameEntry(
    icon: Icons.grid_view_rounded,
    title: (l10n) => l10n.titleWordleTitle,
    subtitle: (l10n) => l10n.gamesHubTitleWordleSubtitle,
    builder: (_) => const TitleWordleScreen(),
  ),
  GameEntry(
    icon: Icons.face_retouching_natural_rounded,
    title: (l10n) => l10n.actorGuessTitle,
    subtitle: (l10n) => l10n.actorGuessHubSubtitle,
    builder: (_) => const ActorGuessScreen(),
  ),
];
