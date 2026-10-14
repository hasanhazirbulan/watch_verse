import 'package:watch_verse/models/media.dart';

/// Pure rules for the daily Frames game (guess the title from stills) — no
/// Flutter, no Firebase, so they're unit-testable.

/// Stills per puzzle — also the number of guesses (each wrong guess or skip
/// reveals the next still).
const framesMaxStills = 6;

/// One guess: a picked title, or a skip ([id] null).
class FramesGuess {
  final int? id;
  final String title;
  const FramesGuess(this.id, this.title);
  const FramesGuess.skip() : id = null, title = '';

  bool get isSkip => id == null;

  Map<String, dynamic> toMap() =>
      isSkip ? {'skip': true} : {'id': id, 'title': title};

  static FramesGuess? fromMap(Object? raw) {
    if (raw is! Map) return null;
    if (raw['skip'] == true) return const FramesGuess.skip();
    final id = raw['id'];
    if (id is! num || id <= 0) return null;
    return FramesGuess(id.toInt(), (raw['title'] as String?) ?? '');
  }
}

/// Saved game state for one day + mode.
class FramesState {
  final int answerId;
  final List<FramesGuess> guesses;
  const FramesState(this.answerId, this.guesses);

  bool get won => guesses.isNotEmpty && guesses.last.id == answerId;
  bool get finished => won || guesses.length >= framesMaxStills;

  /// How many stills the player may look at: one more than the guesses used,
  /// or all of them once the game is over.
  int get stillsUnlocked => finished
      ? framesMaxStills
      : (guesses.length + 1).clamp(1, framesMaxStills);

  bool hasGuessed(int id) => guesses.any((g) => g.id == id);

  /// State after [guess], or null if it isn't accepted (game over, or the
  /// same title guessed twice).
  FramesState? submit(FramesGuess guess) {
    if (finished) return null;
    if (!guess.isSkip && hasGuessed(guess.id!)) return null;
    return FramesState(answerId, [...guesses, guess]);
  }

  factory FramesState.fromMap(int answerId, Map<String, dynamic>? data) {
    final raw = data?['guesses'];
    final guesses = <FramesGuess>[];
    if (raw is List) {
      for (final e in raw) {
        final g = FramesGuess.fromMap(e);
        if (g == null) continue;
        guesses.add(g);
        if (g.id == answerId || guesses.length >= framesMaxStills) break;
      }
    }
    return FramesState(answerId, guesses);
  }

  Map<String, dynamic> toMap() => {
    'game': 'frames',
    'answerId': answerId,
    'guesses': guesses.map((g) => g.toMap()).toList(),
    'won': won,
    'finished': finished,
  };
}

/// Picks up to [framesMaxStills] backdrop paths for the puzzle, ordered
/// hardest-first.
///
/// [backdrops] is TMDB's `images.backdrops` list. Only language-neutral
/// images (`iso_639_1 == null`, i.e. no title text burned in) at a usable
/// size and roughly 16:9 are kept. TMDB votes are a decent proxy for how
/// iconic a still is (the most-voted is usually the key-art backdrop), so the
/// top [framesMaxStills] by vote are revealed least-iconic first and the most
/// recognizable one last. Ties break on the file path so every device orders
/// identically.
List<String> pickFrameStills(List<dynamic> backdrops) {
  final seen = <String>{};
  final candidates = <({String path, double votes, int count})>[];
  for (final b in backdrops) {
    if (b is! Map) continue;
    if (b['iso_639_1'] != null) continue;
    final path = b['file_path'];
    if (path is! String || path.isEmpty || !seen.add(path)) continue;
    final width = (b['width'] as num?)?.toInt() ?? 0;
    final ratio = (b['aspect_ratio'] as num?)?.toDouble() ?? 0;
    if (width < 1280 || ratio < 1.6 || ratio > 1.95) continue;
    candidates.add((
      path: path,
      votes: (b['vote_average'] as num?)?.toDouble() ?? 0,
      count: (b['vote_count'] as num?)?.toInt() ?? 0,
    ));
  }
  candidates.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    final byVotes = b.votes.compareTo(a.votes);
    if (byVotes != 0) return byVotes;
    return a.path.compareTo(b.path);
  });
  return candidates
      .take(framesMaxStills)
      .map((c) => c.path)
      .toList()
      .reversed
      .toList();
}

/// Spoiler-free share text, e.g. `WatchVerse Frames #12 🎬\n🟥⬜🟩⬛⬛⬛`
/// (🟥 wrong, ⬜ skipped, 🟩 correct, ⬛ unused).
String framesShareText({
  required int puzzleNumber,
  required MediaType mode,
  required FramesState state,
}) {
  final emoji = mode == MediaType.movie ? '🎬' : '📺';
  final row = StringBuffer();
  for (var i = 0; i < framesMaxStills; i++) {
    if (i >= state.guesses.length) {
      row.write('⬛');
    } else {
      final g = state.guesses[i];
      row.write(g.isSkip ? '⬜' : (g.id == state.answerId ? '🟩' : '🟥'));
    }
  }
  return 'WatchVerse Frames #$puzzleNumber $emoji\n$row';
}
