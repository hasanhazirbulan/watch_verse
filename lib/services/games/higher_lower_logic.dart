import 'dart:math';

/// Pure logic for the endless "Higher or Lower" game: categories, the
/// shipped pool's item shape, the comparison rule, value formatting and the
/// shuffled draw order. No Flutter imports so it's trivially unit-testable.

enum HigherLowerCategory {
  movieRating('movieRating'),
  movieRevenue('movieRevenue'),
  tvRating('tvRating');

  const HigherLowerCategory(this.key);

  /// Key in `assets/games/higher_lower_pool.json` and in the personal-best
  /// preference key.
  final String key;

  bool get isTv => this == HigherLowerCategory.tvRating;
}

/// One title in a category pool, with the value being compared.
class HigherLowerItem {
  final int id;
  final String title;
  final int year;
  final String posterPath;
  final String backdropPath;

  /// Rating (0–10, one decimal — what's displayed is exactly what's
  /// compared) or worldwide box office in USD.
  final num value;

  const HigherLowerItem({
    required this.id,
    required this.title,
    required this.year,
    required this.posterPath,
    required this.backdropPath,
    required this.value,
  });

  factory HigherLowerItem.fromJson(Map<String, dynamic> j) => HigherLowerItem(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        year: (j['year'] as num?)?.toInt() ?? 0,
        posterPath: j['posterPath'] as String? ?? '',
        backdropPath: j['backdropPath'] as String? ?? '',
        value: j['value'] as num,
      );
}

/// Parses the pool asset into per-category item lists. Unknown categories
/// are ignored; a category missing from the file maps to an empty list, and
/// malformed entries are skipped.
Map<HigherLowerCategory, List<HigherLowerItem>> parseHigherLowerPool(
    Map<String, dynamic> json) {
  final cats = (json['categories'] as Map?) ?? const {};
  return {
    for (final c in HigherLowerCategory.values)
      c: [
        for (final e in (cats[c.key] as List?) ?? const [])
          if (e is Map<String, dynamic> && e['value'] is num && e['id'] is num)
            HigherLowerItem.fromJson(e),
      ],
  };
}

enum HigherLowerGuess { higher, lower }

/// Whether [guess] about [hidden] relative to [known] is right. Ties always
/// count as correct — the player had no way to call them.
bool higherLowerIsCorrect(num known, num hidden, HigherLowerGuess guess) {
  if (hidden == known) return true;
  return guess == HigherLowerGuess.higher ? hidden > known : hidden < known;
}

/// [higherLowerIsCorrect] for [category], also treating two values that
/// *display* the same (e.g. two box-office totals both shown as "$368M") as
/// a tie: the player is told ties count, and can only judge what's shown.
bool higherLowerCallIsCorrect(HigherLowerCategory category, num known,
    num hidden, HigherLowerGuess guess) {
  if (formatHigherLowerValue(category, known) ==
      formatHigherLowerValue(category, hidden)) {
    return true;
  }
  return higherLowerIsCorrect(known, hidden, guess);
}

/// "7.8 ★" for ratings; "$2.79B" / "$845M" / "$45.6M" / "$950K" for box
/// office. Billions get two decimals so two different values rarely *look*
/// equal while comparing differently.
String formatHigherLowerValue(HigherLowerCategory category, num value) {
  if (category != HigherLowerCategory.movieRevenue) {
    return '${value.toDouble().toStringAsFixed(1)} ★';
  }
  final v = value.toDouble();
  if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
  if (v >= 1e8) return '\$${(v / 1e6).toStringAsFixed(0)}M';
  if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
  return '\$${(v / 1e3).toStringAsFixed(0)}K';
}

/// Endless draw order over a pool: a shuffled pass through every item, then
/// a fresh shuffle — never handing back the title currently on screen.
class HigherLowerDeck {
  HigherLowerDeck(List<HigherLowerItem> items, {Random? random})
      : _items = List.of(items),
        _random = random ?? Random() {
    if (_items.map((e) => e.id).toSet().length < 2) {
      throw ArgumentError('A Higher or Lower pool needs at least 2 titles');
    }
    _refill();
  }

  final List<HigherLowerItem> _items;
  final Random _random;
  final List<HigherLowerItem> _queue = [];

  void _refill() {
    _queue
      ..clear()
      ..addAll(_items)
      ..shuffle(_random);
  }

  /// Next title, guaranteed different from [avoid] (by id).
  HigherLowerItem next({HigherLowerItem? avoid}) {
    for (var pass = 0; pass < 2; pass++) {
      if (_queue.isEmpty) _refill();
      final i =
          _queue.lastIndexWhere((e) => avoid == null || e.id != avoid.id);
      if (i >= 0) return _queue.removeAt(i);
      _queue.clear(); // only [avoid] was left in this pass
    }
    throw StateError('Pool has no title other than ${avoid?.id}');
  }
}

/// shared_preferences key for a category's personal best.
String higherLowerBestKey(HigherLowerCategory c) =>
    'higher_lower_best_${c.key}';
