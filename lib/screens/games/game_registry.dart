import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/actor_guess_screen.dart';
import 'package:watch_verse/screens/daily_game_screen.dart';
import 'package:watch_verse/screens/games/frames_game_screen.dart';
import 'package:watch_verse/screens/games/higher_lower_screen.dart';
import 'package:watch_verse/screens/games/plot_guess_screen.dart';
import 'package:watch_verse/screens/games/title_wordle_screen.dart';
import 'package:watch_verse/services/actor_guess_logic.dart';
import 'package:watch_verse/services/games/game_day.dart';
import 'package:watch_verse/services/games/higher_lower_service.dart';
import 'package:watch_verse/services/games/plot_guess_logic.dart';

/// How a hub status chip is tinted.
enum GameStatusTone { neutral, progress, done, missed }

/// One "today" chip on a Games hub card, e.g. 🎬 Solved today.
class GameStatusChip {
  final IconData? icon;
  final String label;
  final GameStatusTone tone;
  const GameStatusChip(this.label, {this.icon, this.tone = GameStatusTone.neutral});
}

/// One card on the Games hub (`GamesHubScreen`). Strings are functions of
/// [AppLocalizations] so entries can live in a plain top-level list.
class GameEntry {
  final IconData icon;

  /// Two colors for the card's art tile gradient.
  final List<Color> art;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;
  final WidgetBuilder builder;

  /// Daily puzzle (vs. an endless game you can play any time).
  final bool daily;

  /// Optional "today" chips shown on the card (e.g. "Solved today"); emit
  /// an empty list to show nothing. Omit for games without one.
  final Stream<List<GameStatusChip>> Function(AppLocalizations l10n)?
      todayStatus;

  const GameEntry({
    required this.icon,
    required this.art,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.daily = true,
    this.todayStatus,
  });
}

/// Every game in the app, in hub order. To add a game, add an entry here.
final List<GameEntry> gameRegistry = [
  GameEntry(
    icon: Icons.theaters_rounded,
    art: const [Color(0xFFFF6A3D), Color(0xFFFF2E63)],
    title: (l10n) => l10n.dailyGameTitle,
    subtitle: (l10n) => l10n.gamesHubDailyMovieSubtitle,
    builder: (_) => const DailyGameScreen(),
    todayStatus: _dailyMovieStatus,
  ),
  GameEntry(
    icon: Icons.photo_library_rounded,
    art: const [Color(0xFF4DA3FF), Color(0xFF6A5BFF)],
    title: (l10n) => l10n.framesGameTitle,
    subtitle: (l10n) => l10n.gamesHubFramesSubtitle,
    builder: (_) => const FramesGameScreen(),
    todayStatus: (l10n) => _perModeStatus(l10n, guestCanPlay: true, {
      for (final m in MediaType.values)
        m: gamePlayDocId('frames', m, gameDateKey(DateTime.now().toUtc())),
    }),
  ),
  GameEntry(
    icon: Icons.grid_view_rounded,
    art: const [Color(0xFF3DDC97), Color(0xFF14A37F)],
    title: (l10n) => l10n.titleWordleTitle,
    subtitle: (l10n) => l10n.gamesHubTitleWordleSubtitle,
    builder: (_) => const TitleWordleScreen(),
    todayStatus: (l10n) => _perModeStatus(l10n, guestCanPlay: true, {
      for (final m in MediaType.values)
        m: gamePlayDocId(
            'titleWordle', m, gameDateKey(DateTime.now().toUtc())),
    }),
  ),
  GameEntry(
    icon: Icons.description_rounded,
    art: const [Color(0xFFFFC531), Color(0xFFFF8A3D)],
    title: (l10n) => l10n.plotGameTitle,
    subtitle: (l10n) => l10n.gamesHubPlotSubtitle,
    builder: (_) => const PlotGuessScreen(),
    todayStatus: (l10n) => _perModeStatus(l10n, guestCanPlay: false, {
      MediaType.movie: plotGameDocId(PlotGameMode.movie, DateTime.now()),
      MediaType.tv: plotGameDocId(PlotGameMode.tv, DateTime.now()),
    }),
  ),
  GameEntry(
    icon: Icons.face_retouching_natural_rounded,
    art: const [Color(0xFFB46BFF), Color(0xFF6A5BFF)],
    title: (l10n) => l10n.actorGuessTitle,
    subtitle: (l10n) => l10n.actorGuessHubSubtitle,
    builder: (_) => const ActorGuessScreen(),
    todayStatus: (l10n) => _perModeStatus(l10n, guestCanPlay: false, {
      null: actorGuessPlayDocId(DateTime.now().toUtc()),
    }),
  ),
  GameEntry(
    icon: Icons.swap_vert_rounded,
    art: const [Color(0xFF2BD2FF), Color(0xFF2C7BE0)],
    title: (l10n) => l10n.higherLowerTitle,
    subtitle: (l10n) => l10n.gamesHubHigherLowerSubtitle,
    builder: (_) => const HigherLowerScreen(),
    daily: false,
    todayStatus: _higherLowerStatus,
  ),
];

// --------------------------------------------------------------- status ---

Stream<List<GameStatusChip>> _dailyMovieStatus(AppLocalizations l10n) {
  if (FirebaseAuth.instance.currentUser == null) {
    return Stream.value([GameStatusChip(l10n.gamesHubStatusSignIn)]);
  }
  return dailyGameTodayStatus(l10n).map((s) {
    if (s == null) return const <GameStatusChip>[];
    final tone = s == l10n.gamesHubStatusSolved
        ? GameStatusTone.done
        : s == l10n.gamesHubStatusMissed
            ? GameStatusTone.missed
            : s == l10n.gamesHubStatusInProgress
                ? GameStatusTone.progress
                : GameStatusTone.neutral;
    return [GameStatusChip(s, tone: tone)];
  });
}

/// Today's chips from the `gamePlays` docs of a game, one chip per mode
/// ([docIds] keyed by mode; a null key = a game without modes). Every doc
/// these games write has `finished` and `won`.
Stream<List<GameStatusChip>> _perModeStatus(
  AppLocalizations l10n,
  Map<MediaType?, String> docIds, {
  required bool guestCanPlay,
}) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(
        guestCanPlay ? const [] : [GameStatusChip(l10n.gamesHubStatusSignIn)]);
  }
  final plays = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('gamePlays');
  final modes = docIds.keys.toList();
  final latest = <MediaType?, Map<String, dynamic>?>{};
  final subs = <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
  late final StreamController<List<GameStatusChip>> controller;

  GameStatusChip chip(MediaType? mode, Map<String, dynamic>? data) {
    final icon = switch (mode) {
      MediaType.movie => Icons.movie_outlined,
      MediaType.tv => Icons.tv_rounded,
      null => null,
    };
    if (data == null) {
      return GameStatusChip(l10n.gamesHubStatusNotPlayed, icon: icon);
    }
    if (data['finished'] == true) {
      return data['won'] == true
          ? GameStatusChip(l10n.gamesHubStatusSolved,
              icon: icon, tone: GameStatusTone.done)
          : GameStatusChip(l10n.gamesHubStatusMissed,
              icon: icon, tone: GameStatusTone.missed);
    }
    return GameStatusChip(l10n.gamesHubStatusInProgress,
        icon: icon, tone: GameStatusTone.progress);
  }

  void emit() {
    if (latest.length < modes.length) return; // wait for every mode
    controller.add([for (final m in modes) chip(m, latest[m])]);
  }

  controller = StreamController<List<GameStatusChip>>(
    onListen: () {
      for (final m in modes) {
        subs.add(plays.doc(docIds[m]).snapshots().listen(
          (snap) {
            latest[m] = snap.data();
            emit();
          },
          onError: (Object e) => debugPrint('GamesHub: status failed: $e'),
        ));
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}

Stream<List<GameStatusChip>> _higherLowerStatus(AppLocalizations l10n) async* {
  try {
    final best = await HigherLowerService.instance.bestScores();
    final top = best.values.fold<int>(0, (a, b) => a > b ? a : b);
    yield top > 0
        ? [
            GameStatusChip(l10n.higherLowerBest(top),
                icon: Icons.emoji_events_outlined, tone: GameStatusTone.done)
          ]
        : const [];
  } catch (e) {
    debugPrint('GamesHub: best scores unavailable: $e');
    yield const [];
  }
}
