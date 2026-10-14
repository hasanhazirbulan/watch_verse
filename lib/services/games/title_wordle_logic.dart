import 'package:watch_verse/models/media.dart';

/// Pure rules for the daily Title Wordle — no Flutter, no Firebase, so every
/// edge case (duplicate letters, multi-word titles) is unit-testable.

const titleWordleMaxGuesses = 6;
const titleWordleMinLetters = 5;
const titleWordleMaxLetters = 8;

/// One puzzle in the bundled pool (`pools/title_wordle_pools.g.dart`).
///
/// [answer] is [title] normalized by [normalizeTitle]: upper-case A–Z words
/// separated by single spaces (`'THE MASK'`). Spaces are shown as gaps on the
/// board; the player only types letters.
class WordlePoolEntry {
  final int id;
  final String title;
  final String answer;
  final String posterPath;
  final String year;
  const WordlePoolEntry(
    this.id,
    this.title,
    this.answer,
    this.posterPath,
    this.year,
  );

  /// The answer without word gaps — what a full guess must match.
  String get letters => answer.replaceAll(' ', '');

  /// Letters per word, e.g. `[3, 4]` for `THE MASK`.
  List<int> get wordLengths => answer.split(' ').map((w) => w.length).toList();
}

enum LetterResult { correct, present, absent }

const _diacritics = {
  'À': 'A',
  'Á': 'A',
  'Â': 'A',
  'Ã': 'A',
  'Ä': 'A',
  'Å': 'A',
  'Ā': 'A',
  'Ç': 'C',
  'Č': 'C',
  'Ć': 'C',
  'È': 'E',
  'É': 'E',
  'Ê': 'E',
  'Ë': 'E',
  'Ē': 'E',
  'Ì': 'I',
  'Í': 'I',
  'Î': 'I',
  'Ï': 'I',
  'Ī': 'I',
  'İ': 'I',
  'Ñ': 'N',
  'Ń': 'N',
  'Ò': 'O',
  'Ó': 'O',
  'Ô': 'O',
  'Õ': 'O',
  'Ö': 'O',
  'Ō': 'O',
  'Ù': 'U',
  'Ú': 'U',
  'Û': 'U',
  'Ü': 'U',
  'Ū': 'U',
  'Ý': 'Y',
  'Ÿ': 'Y',
  'Š': 'S',
  'Ş': 'S',
  'Ž': 'Z',
  'Ğ': 'G',
};

final _separators = RegExp(r"[\s\-–—:/.,!?&]+");
final _dropped = RegExp(r"""['’`"()]""");
final _lettersOnly = RegExp(r'^[A-Z]+$');

/// Normalizes a title to its puzzle answer: accents stripped (`Déjà Vu` →
/// `DEJA VU`), apostrophes/quotes dropped (`Ocean's` → `OCEANS`), any other
/// punctuation or `&` treated as a word break. Returns null when the title
/// can't be a fair letters-only puzzle: it contains digits or non-Latin
/// letters (or nothing is left).
///
/// Must stay in sync with `normalizeWords()` in tool/generate_game_pools.js
/// (a test checks every bundled answer against this function).
String? normalizeTitle(String title) {
  final upper = title.toUpperCase();
  final buf = StringBuffer();
  for (final rune in upper.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_diacritics[ch] ?? ch);
  }
  final ascii = buf.toString();
  if (RegExp('[0-9]').hasMatch(ascii)) return null;
  final words = ascii
      .split(_separators)
      .map((w) => w.replaceAll(_dropped, ''))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty || words.any((w) => !_lettersOnly.hasMatch(w))) {
    return null;
  }
  return words.join(' ');
}

/// Wordle scoring for one [guess] against [answer] (both letters-only, same
/// length, upper-case).
///
/// Duplicate letters follow the standard two-pass rule: exact matches are
/// claimed first, then each remaining guess letter is "present" only while
/// the answer still has an unclaimed copy of it. E.g. `SPEED` against `ABIDE`
/// marks only the first `E` present (ABIDE has one `E`), and `LEVEL` against
/// `HOTEL` marks the final `E`/`L` correct and the earlier ones absent.
List<LetterResult> scoreGuess(String guess, String answer) {
  if (guess.length != answer.length) {
    throw ArgumentError('guess and answer must be the same length');
  }
  final result = List.filled(guess.length, LetterResult.absent);
  final remaining = <String, int>{};
  for (var i = 0; i < answer.length; i++) {
    if (guess[i] == answer[i]) {
      result[i] = LetterResult.correct;
    } else {
      remaining[answer[i]] = (remaining[answer[i]] ?? 0) + 1;
    }
  }
  for (var i = 0; i < guess.length; i++) {
    if (result[i] == LetterResult.correct) continue;
    final left = remaining[guess[i]] ?? 0;
    if (left > 0) {
      result[i] = LetterResult.present;
      remaining[guess[i]] = left - 1;
    }
  }
  return result;
}

/// Best-known state of each letter across all [guesses], for colouring the
/// on-screen keyboard. A letter only ever upgrades (absent < present <
/// correct).
Map<String, LetterResult> keyboardStates(
  List<String> guesses,
  String answerLetters,
) {
  final states = <String, LetterResult>{};
  for (final g in guesses) {
    if (g.length != answerLetters.length) continue;
    final scores = scoreGuess(g, answerLetters);
    for (var i = 0; i < g.length; i++) {
      final prev = states[g[i]];
      if (prev == null || scores[i].index < prev.index) {
        states[g[i]] = scores[i];
      }
    }
  }
  return states;
}

/// Saved game state for one day + mode.
class TitleWordleState {
  final String answerLetters;
  final List<String> guesses;
  const TitleWordleState(this.answerLetters, this.guesses);

  bool get won => guesses.isNotEmpty && guesses.last == answerLetters;
  bool get finished => won || guesses.length >= titleWordleMaxGuesses;

  /// Returns the state after submitting [guess], or null when the guess
  /// isn't accepted (wrong length, non-letters, or the game is over).
  TitleWordleState? submit(String guess) {
    final g = guess.toUpperCase();
    if (finished ||
        g.length != answerLetters.length ||
        !_lettersOnly.hasMatch(g)) {
      return null;
    }
    return TitleWordleState(answerLetters, [...guesses, g]);
  }

  /// Rebuilds a state from a Firestore doc, dropping anything malformed
  /// (e.g. guesses saved against a different answer after a pool update).
  factory TitleWordleState.fromMap(
    String answerLetters,
    Map<String, dynamic>? data,
  ) {
    final raw = data?['guesses'];
    final guesses = <String>[];
    if (raw is List) {
      for (final g in raw) {
        if (g is String &&
            g.length == answerLetters.length &&
            _lettersOnly.hasMatch(g)) {
          guesses.add(g);
        }
        if (guesses.length >= titleWordleMaxGuesses) break;
      }
    }
    // Ignore guesses recorded after a win (shouldn't happen, but a merge of
    // two devices could produce it).
    final winAt = guesses.indexOf(answerLetters);
    return TitleWordleState(
      answerLetters,
      winAt >= 0 ? guesses.sublist(0, winAt + 1) : guesses,
    );
  }

  Map<String, dynamic> toMap(int answerId) => {
    'game': 'titleWordle',
    'answerId': answerId,
    'guesses': guesses,
    'won': won,
    'finished': finished,
  };
}

/// Spoiler-free share text, e.g.
///
/// ```
/// WatchVerse Title Wordle #12 🎬 3/6
/// ⬛🟨⬛ ⬛🟩⬛⬛
/// ...
/// ```
/// Word gaps are kept so the shape of the title shows, letters are not.
String titleWordleShareText({
  required int puzzleNumber,
  required MediaType mode,
  required WordlePoolEntry entry,
  required List<String> guesses,
}) {
  final letters = entry.letters;
  final won = guesses.isNotEmpty && guesses.last == letters;
  final emoji = mode == MediaType.movie ? '🎬' : '📺';
  final score = won ? '${guesses.length}' : 'X';
  final buf = StringBuffer(
    'WatchVerse Title Wordle #$puzzleNumber $emoji $score/$titleWordleMaxGuesses',
  );
  for (final g in guesses) {
    final scores = scoreGuess(g, letters);
    final row = StringBuffer();
    var i = 0;
    for (final len in entry.wordLengths) {
      if (i > 0) row.write(' ');
      for (var j = 0; j < len; j++, i++) {
        row.write(switch (scores[i]) {
          LetterResult.correct => '🟩',
          LetterResult.present => '🟨',
          LetterResult.absent => '⬛',
        });
      }
    }
    buf.write('\n$row');
  }
  return buf.toString();
}
