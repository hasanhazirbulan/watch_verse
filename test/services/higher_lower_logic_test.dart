import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/services/games/higher_lower_logic.dart';
import 'package:watch_verse/services/games/higher_lower_service.dart';

HigherLowerItem _item(int id, num value) => HigherLowerItem(
    id: id,
    title: 'T$id',
    year: 2000,
    posterPath: '',
    backdropPath: '',
    value: value);

void main() {
  group('higherLowerIsCorrect', () {
    test('higher / lower', () {
      expect(higherLowerIsCorrect(7.0, 8.1, HigherLowerGuess.higher), isTrue);
      expect(higherLowerIsCorrect(7.0, 8.1, HigherLowerGuess.lower), isFalse);
      expect(higherLowerIsCorrect(7.0, 6.9, HigherLowerGuess.lower), isTrue);
      expect(higherLowerIsCorrect(7.0, 6.9, HigherLowerGuess.higher), isFalse);
    });

    test('ties are always correct', () {
      for (final g in HigherLowerGuess.values) {
        expect(higherLowerIsCorrect(7.5, 7.5, g), isTrue);
        expect(higherLowerIsCorrect(1000, 1000.0, g), isTrue);
      }
    });
  });

  group('higherLowerCallIsCorrect', () {
    test('values that display the same count as a tie', () {
      const c = HigherLowerCategory.movieRevenue;
      // Both show as "\$368M" — the player can't tell them apart.
      expect(formatHigherLowerValue(c, 368200000),
          formatHigherLowerValue(c, 368400000));
      for (final g in HigherLowerGuess.values) {
        expect(higherLowerCallIsCorrect(c, 368400000, 368200000, g), isTrue);
      }
      // Visibly different values still have to be called right.
      expect(
          higherLowerCallIsCorrect(
              c, 368000000, 372000000, HigherLowerGuess.lower),
          isFalse);
      expect(
          higherLowerCallIsCorrect(HigherLowerCategory.movieRating, 7.0, 7.1,
              HigherLowerGuess.lower),
          isFalse);
    });
  });

  group('formatHigherLowerValue', () {
    test('ratings', () {
      expect(formatHigherLowerValue(HigherLowerCategory.movieRating, 7.8),
          '7.8 ★');
      expect(formatHigherLowerValue(HigherLowerCategory.tvRating, 9), '9.0 ★');
    });

    test('box office', () {
      const c = HigherLowerCategory.movieRevenue;
      expect(formatHigherLowerValue(c, 2923706026), '\$2.92B');
      expect(formatHigherLowerValue(c, 845000000), '\$845M');
      expect(formatHigherLowerValue(c, 45600000), '\$45.6M');
      expect(formatHigherLowerValue(c, 950000), '\$950K');
    });
  });

  group('HigherLowerDeck', () {
    test('never deals the title on screen', () {
      final deck = HigherLowerDeck([_item(1, 1), _item(2, 2)],
          random: Random(1));
      var current = deck.next();
      for (var i = 0; i < 100; i++) {
        final next = deck.next(avoid: current);
        expect(next.id, isNot(current.id));
        current = next;
      }
    });

    test('a pass deals every title before repeating', () {
      final items = [for (var i = 1; i <= 20; i++) _item(i, i)];
      final deck = HigherLowerDeck(items, random: Random(3));
      final seen = {for (var i = 0; i < 20; i++) deck.next().id};
      expect(seen, hasLength(20));
    });

    test('needs two distinct titles', () {
      expect(() => HigherLowerDeck([_item(1, 1)]), throwsArgumentError);
    });
  });

  test('parseHigherLowerPool skips malformed rows', () {
    final pool = parseHigherLowerPool({
      'categories': {
        'movieRating': [
          {'id': 1, 'title': 'A', 'value': 7.1},
          {'id': 2, 'title': 'B'},
          'junk',
        ],
      },
    });
    expect(pool[HigherLowerCategory.movieRating], hasLength(1));
    expect(pool[HigherLowerCategory.tvRating], isEmpty);
  });

  test('shipped pool has a few hundred valid titles per category', () {
    final pool = parseHigherLowerPool(jsonDecode(
            File('assets/games/higher_lower_pool.json').readAsStringSync())
        as Map<String, dynamic>);
    for (final c in HigherLowerCategory.values) {
      final items = pool[c]!;
      expect(items.length, greaterThanOrEqualTo(300), reason: c.key);
      expect(items.map((e) => e.id).toSet(), hasLength(items.length));
      for (final e in items) {
        expect(e.value, greaterThan(0));
        expect(e.title, isNotEmpty);
        if (c != HigherLowerCategory.movieRevenue) {
          // What's displayed (one decimal) is exactly what's compared.
          expect((e.value * 10).round() / 10, e.value);
        }
      }
    }
  });

  group('HigherLowerService best scores', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('only keeps the highest score per category', () async {
      final s = HigherLowerService();
      expect(await s.submitScore(HigherLowerCategory.movieRating, 5), 5);
      expect(await s.submitScore(HigherLowerCategory.movieRating, 3), 5);
      expect(await s.submitScore(HigherLowerCategory.tvRating, 2), 2);
      final best = await s.bestScores();
      expect(best[HigherLowerCategory.movieRating], 5);
      expect(best[HigherLowerCategory.tvRating], 2);
      expect(best[HigherLowerCategory.movieRevenue], 0);
    });
  });
}
