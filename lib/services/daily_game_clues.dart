// Pure comparison/scoring logic for the daily guessing game — no Flutter,
// no Firebase — so the rules the player sees are unit-testable.

import 'package:watch_verse/models/game_clue_movie.dart';

/// Max guesses per puzzle, and the guess counts at which an extra hint
/// unlocks — matches spotle.movie's rules (10 guesses, hints after the 5th
/// and 8th).
const dailyGameMaxGuesses = 10;
const dailyGameHintUnlockGuesses = [5, 8];

/// How a guessed movie's attribute compares to the mystery movie's — drives
/// the tile's revealed color (green/gold/gray, matching spotle.movie's own
/// clue-tile convention). [unknown] is for a side with no data (box office
/// 0, no US certification, …): neither a match nor a real miss, and never
/// gets an arrow.
enum ClueMatch { exact, close, none, unknown }

/// For numeric clues: whether the *mystery* movie's value is higher or lower
/// than the guess's — i.e. which way the player should move next.
enum ClueDirection { none, higher, lower }

enum ClueKind {
  director,
  studio,
  year,
  revenue,
  rating,
  certification,
  cast,
  genres,
}

/// One tile's worth of comparison result. [value] is what the tile shows:
/// the guess's own value, except for the list clues (cast, genres, studio,
/// director) on a partial match, where it shows what's *shared* — the
/// useful part — with "+N" when more than one entry is.
class GameClue {
  final ClueKind kind;
  final String value;
  final ClueMatch match;
  final ClueDirection direction;

  const GameClue(this.kind, this.value, this.match,
      [this.direction = ClueDirection.none]);
}

/// Thresholds for a gold ("close") numeric tile — also quoted in the
/// how-to-play sheet, so keep the two in sync.
const dailyGameCloseYears = 5;
const dailyGameCloseRating = 0.5;
const dailyGameCloseRevenueRatio = 0.5;

/// How many hints are unlocked after [guessCount] guesses. A hint unlocks at
/// each threshold in [dailyGameHintUnlockGuesses] and *stays* unlocked.
int dailyGameHintsUnlocked(int guessCount) =>
    dailyGameHintUnlockGuesses.where((g) => guessCount >= g).length;

/// Compares [guess] to [mystery] for all 8 tiles, in display order.
List<GameClue> compareGameClues(GameClueMovie guess, GameClueMovie mystery) {
  final solved = guess.id == mystery.id;
  return [
    _listClue(ClueKind.director, guess.directors, mystery.directors, solved,
        primaryOnly: false),
    _listClue(ClueKind.studio, guess.productionCompanies,
        mystery.productionCompanies, solved,
        primaryOnly: true),
    _numberClue(ClueKind.year, guess.releaseYear, mystery.releaseYear, solved,
        format: (v) => '$v',
        isClose: (diff, _) => diff <= dailyGameCloseYears),
    _numberClue(ClueKind.revenue, guess.revenue, mystery.revenue, solved,
        format: (v) => formatGameRevenue(v.toInt()),
        // Exact only when the tiles would read the same; "close" is relative
        // since box office spans five orders of magnitude.
        isExact: (g, m) => formatGameRevenue(g.toInt()) ==
            formatGameRevenue(m.toInt()),
        isClose: (diff, m) => diff <= m * dailyGameCloseRevenueRatio),
    _numberClue(ClueKind.rating, _round1(guess.voteAverage),
        _round1(mystery.voteAverage), solved,
        format: (v) => v.toStringAsFixed(1),
        isClose: (diff, _) => diff <= dailyGameCloseRating + 1e-9),
    _certificationClue(guess.certification, mystery.certification, solved),
    _listClue(ClueKind.cast, guess.cast, mystery.cast, solved,
        primaryOnly: false, shownWhenNoMatch: 2),
    _listClue(ClueKind.genres, guess.genres, mystery.genres, solved,
        primaryOnly: false, shownWhenNoMatch: 2),
  ];
}

/// Compact box office, `$1.2B` / `$350M` / `$900K`; empty when unknown.
String formatGameRevenue(int revenue) {
  if (revenue <= 0) return '';
  if (revenue >= 1000000000) {
    return '\$${(revenue / 1000000000).toStringAsFixed(1)}B';
  }
  if (revenue >= 1000000) return '\$${(revenue / 1000000).round()}M';
  return '\$${(revenue / 1000).round()}K';
}

/// Wordle-style, spoiler-free share text: a header line, then one row of
/// emoji squares per guess (in the order guessed). [rows] are the compared
/// clue lists for each guess; [dateLabel] identifies the puzzle.
String buildDailyGameShareText({
  required String gameTitle,
  required String dateLabel,
  required List<List<GameClue>> rows,
  required bool won,
}) {
  final score = won ? '${rows.length}' : 'X';
  final buffer = StringBuffer()
    ..writeln('WatchVerse $gameTitle · $dateLabel · $score/$dailyGameMaxGuesses');
  for (final clues in rows) {
    buffer.writeln(clues.map((c) => switch (c.match) {
          ClueMatch.exact => '🟩',
          ClueMatch.close => '🟨',
          ClueMatch.none || ClueMatch.unknown => '⬜',
        }).join());
  }
  return buffer.toString().trimRight();
}

// ------------------------------------------------------------ helpers -----

double _round1(double v) => (v * 10).roundToDouble() / 10;

GameClue _numberClue(ClueKind kind, num guess, num mystery, bool solved,
    {required String Function(num) format,
    required bool Function(num diff, num mystery) isClose,
    bool Function(num guess, num mystery)? isExact}) {
  final value = guess > 0 ? format(guess) : '';
  if (solved) return GameClue(kind, value, ClueMatch.exact);
  // 0 = unknown on either side (no release date, unreported box office,
  // unrated): an arrow or a gray "miss" here would be a lie.
  if (guess <= 0 || mystery <= 0) {
    return GameClue(kind, value, ClueMatch.unknown);
  }
  if (isExact?.call(guess, mystery) ?? guess == mystery) {
    return GameClue(kind, value, ClueMatch.exact);
  }
  final direction =
      mystery > guess ? ClueDirection.higher : ClueDirection.lower;
  final match =
      isClose((guess - mystery).abs(), mystery) ? ClueMatch.close : ClueMatch.none;
  return GameClue(kind, value, match, direction);
}

GameClue _certificationClue(String guess, String mystery, bool solved) {
  if (solved) return GameClue(ClueKind.certification, guess, ClueMatch.exact);
  if (guess.isEmpty || mystery.isEmpty) {
    return GameClue(ClueKind.certification, guess, ClueMatch.unknown);
  }
  return GameClue(ClueKind.certification, guess,
      guess == mystery ? ClueMatch.exact : ClueMatch.none);
}

/// Exact = same set (or, with [primaryOnly], the same first entry — studios
/// are long co-production lists, so "same lead studio" is the useful exact
/// signal); close = anything shared.
GameClue _listClue(
    ClueKind kind, List<String> guess, List<String> mystery, bool solved,
    {required bool primaryOnly, int shownWhenNoMatch = 1}) {
  String summarize(List<String> items) => items.isEmpty
      ? ''
      : items.length == 1
          ? items.first
          : '${items.first} +${items.length - 1}';

  if (solved) {
    return GameClue(kind, summarize(guess.take(shownWhenNoMatch).toList()),
        ClueMatch.exact);
  }
  if (guess.isEmpty || mystery.isEmpty) {
    return GameClue(kind, guess.take(shownWhenNoMatch).join(', '),
        ClueMatch.unknown);
  }
  final mysterySet = mystery.toSet();
  final shared = guess.where(mysterySet.contains).toList();
  final exact = primaryOnly
      ? guess.first == mystery.first
      : shared.length == guess.toSet().length &&
          shared.length == mysterySet.length;
  if (exact) {
    final shown = primaryOnly ? [guess.first] : shared;
    return GameClue(kind, summarize(shown), ClueMatch.exact);
  }
  if (shared.isNotEmpty) {
    return GameClue(kind, summarize(shared), ClueMatch.close);
  }
  return GameClue(
      kind, guess.take(shownWhenNoMatch).join(', '), ClueMatch.none);
}
