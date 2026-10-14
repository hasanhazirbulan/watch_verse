// Pure logic for the daily "Plot" guessing game: overview redaction, the
// progressive clue schedule, the EST day index and the share text.
//
// Deliberately free of Flutter imports so `tool/generate_plot_higher_lower_pools.dart`
// (a plain `dart run` script) can reuse the exact same redaction code when it
// precomputes the redacted overviews shipped in `assets/games/`.

/// What a hidden proper noun / title word is replaced with. Consecutive
/// redacted words collapse into one block, so "Harry Potter" and "Neo" look
/// the same and the block count doesn't leak name lengths.
const plotRedaction = '█████';

/// Guesses (including skips) per puzzle. Every wrong guess or skip reveals
/// the next clue from [plotClueOrder].
const plotGameMaxAttempts = 6;

enum PlotGameMode {
  movie,
  tv;

  /// Stable id used in Firestore doc ids and asset file names.
  String get key => name;
}

// ------------------------------------------------------------- redaction ---

/// Words never treated as title words — redacting every "the"/"of" would
/// just make the text unreadable without hiding anything.
const _titleStopwords = {
  'a', 'an', 'the', 'of', 'and', 'in', 'on', 'at', 'to', 'for', 'with',
  'from', 'by', 'is', 'it', 'its', 'as', 'or', 'my', 'me', 'you', 'your',
  'his', 'her', 'our', 'we', 'i', 'be', 'are', 'was', 'not', 'no', 'all',
  'de', 'la', 'le', 'el', 'les', 'vs', 'part', 'chapter', 'episode',
  'volume', 'vol', 'collection', 'movie', 'film', 'show', 'series', 'one',
  'two', 'this', 'that', 'into', 'up', 'out', 'so', 'do', 'what', 'who',
  'how', 'when', 'where', 'there', 'here', 'they', 'them', 'he', 'she',
  'him', 'us', 'but', 'if', 'than', 'then', 'about', 'after', 'before',
  'over', 'under', 'off', 'down', 'new', 'man', 'men', 'day', 'way',
  'across', 'through', 'beyond', 'against', 'between', 'without', 'within',
  'among', 'behind', 'toward', 'towards', 'around', 'upon', 'again', 'back',
};

/// Capitalized words that are never worth hiding on their own (calendar
/// words, honorifics, the pronoun "I").
const _alwaysKeep = {
  'I', 'Mr', 'Mrs', 'Ms', 'Dr', 'Jr', 'Sr', 'St', 'OK', 'TV', 'Det', 'Lt',
  'Sgt', 'Capt', 'Col', 'Gen', 'Prof', 'Rev', 'Mt', 'Ph', 'PhD',
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday', 'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December', 'Jan', 'Feb',
  'Mar', 'Apr', 'Jun', 'Jul', 'Aug', 'Sep', 'Sept', 'Oct', 'Nov', 'Dec',
};

/// Credit-list words that describe a role rather than name a character
/// ("Young Bruce Wayne", "Agent Smith (voice)") — character tokens in this
/// set are not treated as names to hide.
const _roleWords = {
  'Dr', 'Mr', 'Mrs', 'Ms', 'Miss', 'Sir', 'Lady', 'Lord', 'King', 'Queen',
  'Prince', 'Princess', 'Agent', 'Captain', 'Detective', 'Officer',
  'Sergeant', 'Sgt', 'Lieutenant', 'Lt', 'Professor', 'Prof', 'Doctor',
  'Young', 'Old', 'Little', 'Big', 'The', 'A', 'An', 'Of', 'And', 'Himself',
  'Herself', 'Themselves', 'Self', 'Voice', 'Voices', 'Uncredited',
  'Narrator', 'Man', 'Woman', 'Boy', 'Girl', 'Kid', 'Mother', 'Father',
  'Mom', 'Dad', 'Uncle', 'Aunt', 'Grandma', 'Grandpa', 'Teacher', 'Nurse',
  'Guard', 'Cop', 'Driver', 'Waitress', 'Waiter', 'Bartender', 'Reporter',
  'Soldier', 'Additional', 'Jr', 'Sr', 'Older', 'Younger', 'Teen',
  'Adult', 'Child', 'Baby', 'General', 'Colonel', 'Major', 'Chief',
  'Sheriff', 'Deputy', 'Judge', 'President', 'Senator', 'Mayor',
  'Brother', 'Sister', 'Son', 'Daughter', 'Wife', 'Husband', 'Friend',
  'Archive', 'Footage', 'Various', 'Characters', 'Guest',
  'Host', 'New', 'Mister', 'Madame', 'Count', 'Duke', 'Baron',
};

final _wordRe = RegExp(r"[\p{L}\p{N}]+(?:['’\-][\p{L}\p{N}]+)*", unicode: true);
final _upperStart = RegExp(r'^\p{Lu}', unicode: true);
final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _possessive = RegExp(r"['’]s$", caseSensitive: false);
// Gap between two redacted words that still reads as one name
// ("Harry Potter", "Spider - Man", "Bonnie & Clyde").
final _collapsibleGap = RegExp(r'^[\s\-–·&]*$');

String _normalizeWord(String w) {
  var s = w.toLowerCase().replaceAll('’', "'");
  s = s.replaceAll(_possessive, '');
  if (s.length > 3 && s.endsWith('s') && !s.endsWith('ss')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// The words of [titles] (title, original title, franchise name) that a
/// redacted overview must not show. Lower-cased and singularized, so
/// "Avengers" also hides "Avenger".
Set<String> plotTitleWords(Iterable<String> titles) {
  final out = <String>{};
  for (final t in titles) {
    for (final m in _wordRe.allMatches(t)) {
      for (final part in m.group(0)!.split('-')) {
        final n = _normalizeWord(part);
        if (n.isEmpty || _titleStopwords.contains(n)) continue;
        // Single letters only when they're a real title token ("V").
        if (n.length == 1 && !RegExp(r'^[\p{L}\p{N}]$', unicode: true).hasMatch(part)) {
          continue;
        }
        out.add(n);
      }
    }
  }
  return out;
}

/// Character-name tokens to hide, from TMDB credit `character` strings like
/// "Bruce Wayne / Batman" or "Ellis 'Red' Redding". Case-sensitive (only the
/// capitalized form is a name: "Will" the character, not "will" the verb).
Set<String> plotNameTokens(Iterable<String> characters) {
  final out = <String>{};
  for (final c in characters) {
    final cleaned = c.replaceAll(RegExp(r'\(.*?\)'), ' ');
    for (final m in _wordRe.allMatches(cleaned)) {
      for (final part in m.group(0)!.split('-')) {
        final base = part.replaceAll(_possessive, '');
        if (base.length < 2 || !_upperStart.hasMatch(base)) continue;
        if (_roleWords.contains(base)) continue;
        out.add(base);
      }
    }
  }
  return out;
}

/// Hides the giveaways in a TMDB overview: the title's words, character
/// names, franchise/universe words, and capitalized proper nouns (places,
/// organizations, made-up words) that aren't everyday vocabulary.
///
/// The vocabulary sets come from the pool generator, which builds them from
/// a few thousand overviews plus a system dictionary; the defaults (empty)
/// make the redactor conservative — it then only hides title words, names
/// and capitalized words in the *middle* of a sentence.
class PlotRedactor {
  PlotRedactor({
    this.genericCapitalized = const {},
    this.everydayWords = const {},
    this.dictionaryWords = const {},
  });

  /// Capitalized tokens seen across many unrelated titles ("American",
  /// "FBI", "Christmas", "New", "York") — not giveaways, so kept.
  final Set<String> genericCapitalized;

  /// Lower-case words used lower-case in many overviews — a capitalized use
  /// mid-sentence ("the Force", "the Resistance") is still kept.
  final Set<String> everydayWords;

  /// Lower-case dictionary words. A sentence-initial capitalized word that
  /// isn't a dictionary word ("Frodo …") is treated as a proper noun. Empty
  /// means sentence-initial words are only hidden for title/name matches.
  final Set<String> dictionaryWords;

  /// [titles] hide their words in any case. [franchise] — the franchise's
  /// other titles and universe terms ("Batman Begins", "Gotham", "Jedi") —
  /// hides only *capitalized* uses of its words, even when they'd otherwise
  /// pass as generic ("the Avengers", "Gotham City", "the Galactic Empire"),
  /// so "a new hope" in an unrelated sense stays readable. A sentence-initial
  /// franchise word that is also everyday vocabulary ("Force", "Empire") is
  /// kept, since the capital there says nothing.
  ///
  /// [franchisePhrases] ("Captain America: Civil War", "Galactic Empire")
  /// are hidden wherever they appear verbatim (case-sensitive), even when
  /// every word in them is ordinary.
  String redact(
    String text, {
    Iterable<String> titles = const [],
    Iterable<String> names = const [],
    Iterable<String> franchise = const [],
    Iterable<String> franchisePhrases = const [],
  }) {
    final titleWords = plotTitleWords(titles);
    final franchiseWords = plotTitleWords(franchise);
    final nameSet = names is Set<String> ? names : names.toSet();

    final tokens = <_Token>[];
    for (final m in _wordRe.allMatches(text)) {
      final token = m.group(0)!;
      final possessive = _possessive.firstMatch(token);
      final base =
          possessive == null ? token : token.substring(0, possessive.start);
      final sentenceStart = _isSentenceStart(text, m.start);
      tokens.add(_Token(
        start: m.start,
        end: m.end,
        base: base,
        suffix: possessive == null ? '' : token.substring(possessive.start),
        sentenceStart: sentenceStart,
        hide: _shouldHide(
            base, sentenceStart, titleWords, franchiseWords, nameSet),
      ));
    }
    _hidePhrases(text, tokens, franchisePhrases);

    // A capitalized word right next to a hidden one is almost always the
    // rest of the same name ("Blade Runner Rick Deckard", "Captain Kirk",
    // "New Yorkers") even when it's common on its own — hide it too, so
    // half-redacted names don't leak first names or ranks.
    for (var changed = true; changed;) {
      changed = false;
      for (var i = 0; i < tokens.length; i++) {
        final t = tokens[i];
        if (t.hide || t.sentenceStart || !_isNameLike(t.base)) continue;
        bool adjacentHidden(int j, bool before) {
          if (j < 0 || j >= tokens.length || !tokens[j].hide) return false;
          final left = before ? tokens[j] : t;
          final right = before ? t : tokens[j];
          // "█████'s Theater" is a possessive, not one name.
          if (left.suffix.isNotEmpty) return false;
          return text.substring(left.end, right.start) == ' ';
        }

        if (adjacentHidden(i - 1, true) || adjacentHidden(i + 1, false)) {
          t.hide = true;
          changed = true;
        }
      }
    }

    final out = StringBuffer();
    var last = 0;
    var lastWasRedaction = false;
    for (final t in tokens) {
      final gap = text.substring(last, t.start);
      if (t.hide) {
        // "Harry Potter" → one block: merge into the previous block by
        // dropping the gap between them.
        if (!(lastWasRedaction && _collapsibleGap.hasMatch(gap))) {
          out.write(gap);
          out.write(plotRedaction);
        }
        out.write(t.suffix);
        lastWasRedaction = t.suffix.isEmpty;
      } else {
        out.write(gap);
        out.write(text.substring(t.start, t.end));
        lastWasRedaction = false;
      }
      last = t.end;
    }
    out.write(text.substring(last));
    return out.toString();
  }

  static void _hidePhrases(
      String text, List<_Token> tokens, Iterable<String> phrases) {
    if (tokens.isEmpty) return;
    final plain = text.replaceAll('’', "'");
    for (final raw in phrases) {
      final phrase = raw.trim().replaceAll('’', "'");
      if (phrase.isEmpty) continue;
      for (var i = plain.indexOf(phrase); i >= 0;
          i = plain.indexOf(phrase, i + 1)) {
        final end = i + phrase.length;
        final boundedBefore = i == 0 || !_wordChar.hasMatch(plain[i - 1]);
        final boundedAfter =
            end >= plain.length || !_wordChar.hasMatch(plain[end]);
        if (!boundedBefore || !boundedAfter) continue;
        for (final t in tokens) {
          if (t.start >= i && t.end <= end + 2) t.hide = true;
        }
      }
    }
  }

  static bool _isNameLike(String base) =>
      base.length >= 2 &&
      _upperStart.hasMatch(base) &&
      !_alwaysKeep.contains(base) &&
      // Acronyms ("FBI", "NASA") are organizations, not name parts.
      base != base.toUpperCase();

  bool _shouldHide(String base, bool sentenceStart, Set<String> titleWords,
      Set<String> franchiseWords, Set<String> names) {
    final parts = base.split('-');
    if (parts.length > 1) {
      // "Spider-Man": hide the whole compound if any part is a giveaway, but
      // don't treat an ordinary lower-case compound as a proper noun.
      return parts.any((p) {
        if (p.isEmpty) return false;
        final first = sentenceStart && p == parts.first;
        return _isTitleWord(p, titleWords) ||
            names.contains(p) ||
            _isFranchiseWord(p, first, franchiseWords) ||
            (_upperStart.hasMatch(p) && _isUnknownProperNoun(p, first));
      });
    }
    if (_isTitleWord(base, titleWords)) return true;
    if (_isFranchiseWord(base, sentenceStart, franchiseWords)) return true;
    if (!_upperStart.hasMatch(base)) return false;
    if (names.contains(base)) return true;
    return _isUnknownProperNoun(base, sentenceStart);
  }

  bool _isFranchiseWord(
      String word, bool sentenceStart, Set<String> franchiseWords) {
    if (franchiseWords.isEmpty || word.length < 2) return false;
    // Capitalized, or a number like "007".
    if (!RegExp(r'^[\p{Lu}\p{N}]', unicode: true).hasMatch(word) ||
        _alwaysKeep.contains(word)) {
      return false;
    }
    if (!franchiseWords.contains(_normalizeWord(word))) return false;
    return !(sentenceStart && everydayWords.contains(word.toLowerCase()));
  }

  bool _isTitleWord(String word, Set<String> titleWords) {
    if (titleWords.isEmpty) return false;
    final n = _normalizeWord(word);
    if (n.length == 1 && !_upperStart.hasMatch(word) && !RegExp(r'\d').hasMatch(word)) {
      return false; // lone lower-case letters never match a title initial
    }
    return titleWords.contains(n);
  }

  bool _isUnknownProperNoun(String word, bool sentenceStart) {
    if (word.length < 2) return false;
    if (_alwaysKeep.contains(word)) return false;
    if (genericCapitalized.contains(word)) return false;
    final lower = word.toLowerCase();
    if (sentenceStart) {
      if (dictionaryWords.isEmpty) return false;
      return !dictionaryWords.contains(lower) && !everydayWords.contains(lower);
    }
    return !everydayWords.contains(lower);
  }

  static bool _isSentenceStart(String text, int index) {
    var i = index - 1;
    // Skip whitespace and opening quotes/brackets.
    while (i >= 0 && RegExp(r'''[\s"“‘'(\[]''').hasMatch(text[i])) {
      i--;
    }
    if (i < 0) return true;
    final c = text[i];
    if (c == '!' || c == '?' || c == ':' || c == '\n') return true;
    if (c == '.' || c == '…') {
      // "Dr. Grant" / "J. Edgar": an abbreviation, not a sentence end.
      return !_endsWithAbbreviation(text, i);
    }
    // Closing quote after a sentence end: `…said." Then`.
    if ((c == '"' || c == '”' || c == '’') && i > 0) {
      final p = text[i - 1];
      return p == '.' || p == '!' || p == '?';
    }
    return false;
  }
}

class _Token {
  _Token({
    required this.start,
    required this.end,
    required this.base,
    required this.suffix,
    required this.sentenceStart,
    required this.hide,
  });
  final int start;
  final int end;
  final String base;
  final String suffix;
  final bool sentenceStart;
  bool hide;
}

const _abbreviations = {
  'mr', 'mrs', 'ms', 'dr', 'st', 'jr', 'sr', 'vs', 'mt', 'ft', 'lt', 'sgt',
  'capt', 'col', 'gen', 'prof', 'rev', 'no', 'u.s', 'u.k', 'e.g', 'i.e',
  'etc', 'inc', 'co', 'ltd', 'det', 'jan', 'feb', 'mar', 'apr', 'jun', 'jul',
  'aug', 'sep', 'sept', 'oct', 'nov', 'dec',
};

bool _endsWithAbbreviation(String text, int dotIndex) {
  var j = dotIndex - 1;
  while (j >= 0 && RegExp(r'[A-Za-z.]').hasMatch(text[j])) {
    j--;
  }
  final word = text.substring(j + 1, dotIndex).toLowerCase();
  if (word.isEmpty) return false;
  if (_abbreviations.contains(word)) return true;
  // Initials ("J. R. R." / "U.S.A") — single letters or dotted letters.
  return RegExp(r'^([a-z]\.)*[a-z]$').hasMatch(word);
}

// ------------------------------------------------------------- sentences ---

/// Splits an overview into sentences, without breaking on "Dr." / "U.S." /
/// initials. Each sentence keeps its trailing punctuation; whitespace between
/// sentences is dropped.
List<String> splitPlotSentences(String text) {
  final out = <String>[];
  final t = text.trim();
  var start = 0;
  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (c != '.' && c != '!' && c != '?' && c != '…') continue;
    var end = i + 1;
    // Absorb runs like "?!", "..." and closing quotes/brackets.
    while (end < t.length && RegExp(r'''[.!?…"”’')\]]''').hasMatch(t[end])) {
      end++;
    }
    if (end >= t.length) break;
    if (!RegExp(r'\s').hasMatch(t[end])) continue;
    var next = end;
    while (next < t.length && RegExp(r'\s').hasMatch(t[next])) {
      next++;
    }
    if (next >= t.length) break;
    final nc = t[next];
    final startsNew = RegExp(r'''[\p{Lu}\p{N}"“‘'(█]''', unicode: true).hasMatch(nc);
    if (!startsNew) continue;
    if (c == '.' && _endsWithAbbreviation(t, i)) continue;
    out.add(t.substring(start, end).trim());
    start = next;
    i = next - 1;
  }
  final tail = t.substring(start).trim();
  if (tail.isNotEmpty) out.add(tail);
  return out;
}

/// Splits [overview] into the opening shown before any guess and the rest
/// revealed after the first miss. The opening is the first sentence, plus
/// following ones while it's under [minOpeningChars] — but never all of
/// them when there's more than one, so the first miss still reveals
/// something.
({String opening, String rest}) plotOpeningSplit(String overview,
    {int minOpeningChars = 90}) {
  final sentences = splitPlotSentences(overview);
  if (sentences.length <= 1) return (opening: overview.trim(), rest: '');
  var take = 1;
  var length = sentences.first.length;
  while (length < minOpeningChars && take < sentences.length - 1) {
    length += sentences[take].length + 1;
    take++;
  }
  return (
    opening: sentences.take(take).join(' '),
    rest: sentences.skip(take).join(' '),
  );
}

// ---------------------------------------------------------------- puzzle ---

/// One shipped puzzle from `assets/games/plot_pool_{mode}.json`.
class PlotPuzzle {
  final int id;
  final String title;
  final int year;
  final List<String> genres;
  final List<String> cast;
  final String tagline;
  final String redactedOverview;
  final String posterPath;

  const PlotPuzzle({
    required this.id,
    required this.title,
    required this.year,
    required this.genres,
    required this.cast,
    required this.tagline,
    required this.redactedOverview,
    required this.posterPath,
  });

  factory PlotPuzzle.fromJson(Map<String, dynamic> j) => PlotPuzzle(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        year: (j['year'] as num?)?.toInt() ?? 0,
        genres: ((j['genres'] as List?) ?? const []).cast<String>(),
        cast: ((j['cast'] as List?) ?? const []).cast<String>(),
        tagline: j['tagline'] as String? ?? '',
        redactedOverview: j['overview'] as String? ?? '',
        posterPath: j['posterPath'] as String? ?? '',
      );
}

/// Clues revealed one per wrong guess/skip, after the plot's opening.
enum PlotClueKind { plotRest, year, genres, actor, tagline, secondActor }

/// The order clues unlock for [p]: rest of the plot → year → genres →
/// top-billed actor → tagline. Missing ones are skipped, and the second-billed
/// actor stands in when there's no tagline, so a 6-attempt game gets up to
/// 5 extra clues.
List<PlotClueKind> plotClueOrder(PlotPuzzle p) {
  final all = [
    if (plotOpeningSplit(p.redactedOverview).rest.isNotEmpty) PlotClueKind.plotRest,
    if (p.year > 0) PlotClueKind.year,
    if (p.genres.isNotEmpty) PlotClueKind.genres,
    if (p.cast.isNotEmpty) PlotClueKind.actor,
    if (p.tagline.trim().isNotEmpty) PlotClueKind.tagline,
    if (p.cast.length > 1) PlotClueKind.secondActor,
  ];
  return all.take(plotGameMaxAttempts - 1).toList();
}

/// Clues visible after [missed] wrong guesses/skips (all of them once the
/// game is [finished]).
List<PlotClueKind> plotRevealedClues(PlotPuzzle p, int missed,
    {bool finished = false}) {
  final order = plotClueOrder(p);
  if (finished) return order;
  return order.take(missed.clamp(0, order.length)).toList();
}

// --------------------------------------------------------------- attempts ---

/// One guess (or a skip, `id == 0`) as stored in `gamePlays`.
class PlotAttempt {
  final int id;
  final String title;
  const PlotAttempt({required this.id, required this.title});
  const PlotAttempt.skip()
      : id = 0,
        title = '';

  bool get isSkip => id == 0;

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  /// Lenient: malformed entries become skips rather than throwing.
  factory PlotAttempt.fromJson(Object? raw) {
    if (raw is Map) {
      final id = raw['id'];
      return PlotAttempt(
        id: id is num ? id.toInt() : 0,
        title: raw['title'] is String ? raw['title'] as String : '',
      );
    }
    return const PlotAttempt.skip();
  }
}

/// Derived game state from the attempt list.
class PlotGameProgress {
  final List<PlotAttempt> attempts;
  final bool won;
  final bool finished;
  const PlotGameProgress(
      {required this.attempts, required this.won, required this.finished});

  /// Wrong guesses + skips — the number of clues unlocked.
  int get missed => won ? attempts.length - 1 : attempts.length;
  int get attemptsLeft => plotGameMaxAttempts - attempts.length;
}

PlotGameProgress plotGameProgress(List<PlotAttempt> attempts, int answerId) {
  final capped = attempts.take(plotGameMaxAttempts).toList();
  final winAt = capped.indexWhere((a) => a.id == answerId && answerId != 0);
  final effective = winAt >= 0 ? capped.take(winAt + 1).toList() : capped;
  final won = winAt >= 0;
  return PlotGameProgress(
    attempts: effective,
    won: won,
    finished: won || effective.length >= plotGameMaxAttempts,
  );
}

// ------------------------------------------------------------- day index ---

/// Same rotation scheme as the daily movie game: a fixed anchor date and a
/// fixed UTC-5 (EST) offset, so everyone gets the same puzzle and it flips
/// at midnight EST without any server job.
final _referenceDate = DateTime.utc(2024, 1, 1);

DateTime _estCalendarDate(DateTime utcNow) {
  final est = utcNow.toUtc().subtract(const Duration(hours: 5));
  return DateTime.utc(est.year, est.month, est.day);
}

int plotGameDayIndex(DateTime now) =>
    _estCalendarDate(now).difference(_referenceDate).inDays;

/// `yyyy-mm-dd` (EST calendar date) for [now].
String plotGameDateKey(DateTime now) {
  final d = _estCalendarDate(now);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Firestore doc id under `users/{uid}/gamePlays`.
String plotGameDocId(PlotGameMode mode, DateTime now) =>
    'plot-${mode.key}-${plotGameDateKey(now)}';

int plotGamePuzzleIndex(int dayIndex, int poolLength) {
  if (poolLength <= 0) throw ArgumentError.value(poolLength, 'poolLength');
  return dayIndex % poolLength;
}

// ----------------------------------------------------------------- share ---

/// Spoiler-free result: one square per attempt (🟥 wrong, ⬛ skip, 🟩 right)
/// padded with ⬜ up to [plotGameMaxAttempts].
String plotGameShareText({
  required String header,
  required String dateKey,
  required PlotGameProgress progress,
}) {
  final squares = StringBuffer();
  for (var i = 0; i < progress.attempts.length; i++) {
    final a = progress.attempts[i];
    final isWin = progress.won && i == progress.attempts.length - 1;
    squares.write(isWin ? '🟩' : (a.isSkip ? '⬛' : '🟥'));
  }
  for (var i = progress.attempts.length; i < plotGameMaxAttempts; i++) {
    squares.write('⬜');
  }
  final score = progress.won
      ? '${progress.attempts.length}/$plotGameMaxAttempts'
      : 'X/$plotGameMaxAttempts';
  return '$header · $dateKey\n$squares $score';
}
