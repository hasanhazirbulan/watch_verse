/// Pure logic for the daily "Who's the Actor?" game — no Flutter, Firebase or
/// network imports, so it's unit-testable on its own (see
/// test/services/actor_guess_logic_test.dart).
library;

/// Guesses per puzzle — one per clue.
const actorGuessMaxAttempts = 6;

// ------------------------------------------------------------------ pool ---

class ActorGuessTitle {
  final int id;

  /// `movie` or `tv`.
  final String type;
  final String title;
  final int year;
  final String posterPath;

  const ActorGuessTitle({
    required this.id,
    required this.type,
    required this.title,
    required this.year,
    required this.posterPath,
  });

  bool get isTv => type == 'tv';

  static ActorGuessTitle? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final type = raw['type'];
    if (id is! int || title is! String || (type != 'movie' && type != 'tv')) {
      return null;
    }
    return ActorGuessTitle(
      id: id,
      type: type as String,
      title: title,
      year: raw['year'] is int ? raw['year'] as int : 0,
      posterPath: raw['posterPath'] is String
          ? raw['posterPath'] as String
          : '',
    );
  }
}

/// One day's mystery actor with every clue precomputed by
/// `tool/actor_guess_build_pool.js`.
class ActorGuessPuzzle {
  final int id;
  final String name;
  final String profilePath;
  final int debutYear;
  final String country;
  final String characterName;
  final String characterTitle;

  /// Their best-known titles, most voted-on first (9 in the generated pool).
  final List<ActorGuessTitle> titles;

  const ActorGuessPuzzle({
    required this.id,
    required this.name,
    required this.profilePath,
    required this.debutYear,
    required this.country,
    required this.characterName,
    required this.characterTitle,
    required this.titles,
  });

  /// Titles ranked 7–9: the hardest poster clue.
  List<ActorGuessTitle> get deepCutTitles => _slice(6, 9);

  /// Titles ranked 4–6.
  List<ActorGuessTitle> get knownTitles => _slice(3, 6);

  /// Titles ranked 1–3: nearly a giveaway, so it's the 5th clue.
  List<ActorGuessTitle> get topTitles => _slice(0, 3);

  List<ActorGuessTitle> _slice(int from, int to) => titles.length <= from
      ? const []
      : titles.sublist(from, to > titles.length ? titles.length : to);

  static ActorGuessPuzzle? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final character = raw['character'];
    if (id is! int || name is! String || name.isEmpty || character is! Map) {
      return null;
    }
    final titles = <ActorGuessTitle>[];
    for (final t in (raw['titles'] as List?) ?? const []) {
      final parsed = ActorGuessTitle.fromJson(t);
      if (parsed != null) titles.add(parsed);
    }
    if (titles.isEmpty) return null;
    return ActorGuessPuzzle(
      id: id,
      name: name,
      profilePath: raw['profilePath'] is String
          ? raw['profilePath'] as String
          : '',
      debutYear: raw['debutYear'] is int ? raw['debutYear'] as int : 0,
      country: raw['country'] is String ? raw['country'] as String : '',
      characterName: character['name'] is String
          ? character['name'] as String
          : '',
      characterTitle: character['title'] is String
          ? character['title'] as String
          : '',
      titles: titles,
    );
  }
}

/// Parses the decoded `assets/games/actor_guess_pool.json`. Malformed entries
/// are skipped rather than failing the whole pool.
List<ActorGuessPuzzle> parseActorGuessPool(Object? decoded) {
  final actors = decoded is Map ? decoded['actors'] : null;
  if (actors is! List) {
    throw const FormatException('actor_guess_pool.json: missing "actors" list');
  }
  return [for (final a in actors) ?ActorGuessPuzzle.fromJson(a)];
}

// ------------------------------------------------------------- day index ---

/// Same anchor and rollover as the daily movie game (`DailyGameService`):
/// fixed UTC-5 (EST, DST ignored), so everyone gets the same actor and it
/// flips at midnight EST.
final _referenceDate = DateTime.utc(2024, 1, 1);

DateTime _estCalendarDate(DateTime utcNow) {
  final est = utcNow.toUtc().subtract(const Duration(hours: 5));
  return DateTime.utc(est.year, est.month, est.day);
}

/// Days since the reference date, in EST calendar days.
int actorGuessDayIndex(DateTime utcNow) =>
    _estCalendarDate(utcNow).difference(_referenceDate).inDays;

/// `yyyy-mm-dd` (EST calendar) for [utcNow] — used in the Firestore doc id
/// and the share text.
String actorGuessDateKey(DateTime utcNow) {
  final d = _estCalendarDate(utcNow);
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// `users/{uid}/gamePlays/{id}` doc id for the day's progress.
String actorGuessPlayDocId(DateTime utcNow) =>
    'actor-${actorGuessDateKey(utcNow)}';

/// The puzzle for [dayIndex]; wraps around the pool. Null for an empty pool.
ActorGuessPuzzle? actorGuessPuzzleForDay(
  List<ActorGuessPuzzle> pool,
  int dayIndex,
) {
  if (pool.isEmpty) return null;
  return pool[dayIndex % pool.length];
}

// ---------------------------------------------------------- clue schedule ---

/// Clue order, hardest first. Each wrong guess reveals the next one.
enum ActorGuessClue {
  /// First movie year + birth country.
  origin,

  /// Three lesser-known titles (ranked 7–9).
  deepCuts,

  /// Three more titles (ranked 4–6).
  knownTitles,

  /// A famous character they played.
  character,

  /// Their three best-known titles.
  topTitles,

  /// Their photo, heavily blurred.
  photo,
}

/// How many clues are visible after [wrongGuesses] misses: one up front, one
/// more per miss, all of them once the game is over.
int actorGuessCluesVisible(int wrongGuesses, {required bool finished}) {
  if (finished) return ActorGuessClue.values.length;
  final n = wrongGuesses + 1;
  return n > ActorGuessClue.values.length ? ActorGuessClue.values.length : n;
}

// ---------------------------------------------------------------- guesses ---

/// One guess as stored in Firestore (`guesses` array of `{id, name}`).
class ActorGuessEntry {
  final int id;
  final String name;
  const ActorGuessEntry(this.id, this.name);

  Map<String, Object> toMap() => {'id': id, 'name': name};

  static ActorGuessEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final intId = id is int ? id : (id is num ? id.toInt() : null);
    if (intId == null) return null;
    return ActorGuessEntry(intId, name is String ? name : '');
  }
}

/// Parsed progress doc. Missing/odd fields fall back to "not started".
class ActorGuessProgress {
  final List<ActorGuessEntry> guesses;
  final bool won;
  final bool finished;
  const ActorGuessProgress({
    this.guesses = const [],
    this.won = false,
    this.finished = false,
  });

  int get wrongGuesses => won ? guesses.length - 1 : guesses.length;

  static ActorGuessProgress fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ActorGuessProgress();
    final raw = data['guesses'];
    return ActorGuessProgress(
      guesses: [
        if (raw is List)
          for (final g in raw) ?ActorGuessEntry.fromMap(g),
      ],
      won: data['won'] == true,
      finished: data['finished'] == true,
    );
  }
}

const _foldMap = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'æ': 'ae',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'ď': 'd',
  'đ': 'd',
  'ð': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ğ': 'g',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ı': 'i',
  'ł': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ő': 'o',
  'œ': 'oe',
  'ř': 'r',
  'ś': 's',
  'š': 's',
  'ş': 's',
  'ß': 'ss',
  'ť': 't',
  'ţ': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ű': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ž': 'z',
  'ź': 'z',
  'ż': 'z',
  'þ': 'th',
};

/// Case/diacritics-insensitive form of a name: "Léa Seydoux" and
/// "lea  SEYDOUX" both become "lea seydoux". Punctuation (hyphens, dots,
/// apostrophes) collapses to single spaces.
String normalizeActorName(String name) {
  final lower = name.toLowerCase().replaceAll('İ', 'i');
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_foldMap[ch] ?? ch);
  }
  return buf.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// A guess is right when it's the same TMDB person, or a person with the
/// same normalized name (TMDB has the odd duplicate profile).
bool isActorGuessCorrect({
  required int guessId,
  required String guessName,
  required ActorGuessPuzzle puzzle,
}) {
  if (guessId == puzzle.id) return true;
  final a = normalizeActorName(guessName);
  return a.isNotEmpty && a == normalizeActorName(puzzle.name);
}

/// Spoiler-free share text: one square per guess, no names.
///
/// ```
/// WatchVerse · Who's the Actor? · 2026-10-14
/// 🟥🟥🟩 3/6
/// ```
String actorGuessShareText({
  required String gameTitle,
  required String dateKey,
  required int guessCount,
  required bool won,
}) {
  final misses = won ? guessCount - 1 : guessCount;
  final squares = '${'🟥' * misses}${won ? '🟩' : ''}';
  final score = won
      ? '$guessCount/$actorGuessMaxAttempts'
      : 'X/$actorGuessMaxAttempts';
  return 'WatchVerse · $gameTitle · $dateKey\n$squares $score';
}

/// Turkish names for the birth countries in the bundled pool (stored in
/// English by `tool/actor_guess_build_pool.js`). Unknown names and other
/// locales fall through unchanged.
const _countryNamesTr = {
  'USA': 'ABD', 'UK': 'Birleşik Krallık', 'Canada': 'Kanada',
  'Australia': 'Avustralya', 'Ireland': 'İrlanda', 'France': 'Fransa',
  'Denmark': 'Danimarka', 'Sweden': 'İsveç', 'Germany': 'Almanya',
  'New Zealand': 'Yeni Zelanda', 'Spain': 'İspanya',
  'Puerto Rico': 'Porto Riko', 'Ukraine': 'Ukrayna',
  'South Africa': 'Güney Afrika', 'Israel': 'İsrail', 'Austria': 'Avusturya',
  'Netherlands': 'Hollanda', 'Benin': 'Benin', 'Italy': 'İtalya',
  'Romania': 'Romanya', 'Brazil': 'Brezilya', 'South Korea': 'Güney Kore',
  'Chile': 'Şili', 'Cuba': 'Küba', 'Nigeria': 'Nijerya',
  'Guatemala': 'Guatemala', 'Channel Islands': 'Manş Adaları',
  'Guyana': 'Guyana', 'Mexico': 'Meksika', 'Lebanon': 'Lübnan',
  'Japan': 'Japonya', 'China': 'Çin', 'Colombia': 'Kolombiya',
  'India': 'Hindistan', 'Oman': 'Umman', 'Bermuda': 'Bermuda',
  'Turkey': 'Türkiye', 'Russia': 'Rusya', 'Poland': 'Polonya',
  'Norway': 'Norveç', 'Belgium': 'Belçika', 'Switzerland': 'İsviçre',
  'Greece': 'Yunanistan', 'Argentina': 'Arjantin', 'Hungary': 'Macaristan',
};

String localizedCountry(String country, String languageCode) =>
    languageCode == 'tr' ? (_countryNamesTr[country] ?? country) : country;
