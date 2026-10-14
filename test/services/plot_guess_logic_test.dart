import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/games/plot_guess_logic.dart';

const _r = plotRedaction;

PlotPuzzle _puzzle({
  String overview = 'First sentence is here. Second sentence follows.',
  int year = 1999,
  List<String> genres = const ['Drama'],
  List<String> cast = const ['Actor One', 'Actor Two'],
  String tagline = 'A tagline.',
}) =>
    PlotPuzzle(
      id: 42,
      title: 'Mystery',
      year: year,
      genres: genres,
      cast: cast,
      tagline: tagline,
      redactedOverview: overview,
      posterPath: '/p.jpg',
    );

void main() {
  group('plotTitleWords', () {
    test('drops stopwords, lower-cases and singularizes', () {
      expect(plotTitleWords(['The Lord of the Rings']), {'lord', 'ring'});
      expect(plotTitleWords(['Avengers: Endgame']), {'avenger', 'endgame'});
    });

    test('splits hyphenated titles and keeps numbers', () {
      expect(plotTitleWords(['Spider-Man 2']), {'spider', '2'});
    });
  });

  group('plotNameTokens', () {
    test('splits multi-name credits and ignores role words / notes', () {
      expect(plotNameTokens(['Bruce Wayne / Batman', 'Young Bruce (voice)']),
          {'Bruce', 'Wayne', 'Batman'});
      expect(plotNameTokens(["Ellis 'Red' Redding", 'Dr. Alan Grant']),
          {'Ellis', 'Red', 'Redding', 'Alan', 'Grant'});
    });

    test('lower-case role descriptions are not names', () {
      expect(plotNameTokens(['the bartender', 'Himself']), isEmpty);
    });
  });

  group('PlotRedactor', () {
    final plain = PlotRedactor();

    test('hides title words anywhere, case-insensitively', () {
      expect(
        plain.redact('A hacker learns the matrix is a lie.',
            titles: ['The Matrix']),
        'A hacker learns the $_r is a lie.',
      );
    });

    test('hides credited character names and collapses full names', () {
      expect(
        plain.redact('Harry Potter goes to school. Harry makes friends.',
            names: {'Harry', 'Potter'}),
        '$_r goes to school. $_r makes friends.',
      );
    });

    test('keeps a possessive suffix after a hidden name', () {
      expect(plain.redact("Neo's world ends.", names: {'Neo'}),
          "$_r's world ends.");
    });

    test('hides unknown capitalized words mid-sentence', () {
      expect(plain.redact('A boy travels to Hogwarts with friends.'),
          'A boy travels to $_r with friends.');
    });

    test('does not touch sentence-initial words without a dictionary', () {
      expect(plain.redact('When it rains. Then it pours.'),
          'When it rains. Then it pours.');
    });

    test('keeps generic capitalized words and everyday vocabulary', () {
      final r = PlotRedactor(
        genericCapitalized: {'American', 'London'},
        everydayWords: {'resistance'},
      );
      expect(
        r.redact('An American spy in London joins the Resistance in Gondor.'),
        'An American spy in London joins the Resistance in $_r.',
      );
    });

    test('with a dictionary, hides sentence-initial non-words', () {
      final r = PlotRedactor(dictionaryWords: {'when', 'after'});
      expect(r.redact('Frodo leaves. After that, rain.'),
          '$_r leaves. After that, rain.');
    });

    test('a capitalized word next to a hidden name is part of it', () {
      final r = PlotRedactor(genericCapitalized: {'Rick', 'Captain'});
      expect(
        r.redact('Then blade runner Rick Deckard and Captain Kirk meet.',
            titles: ['Blade Runner'], names: {'Deckard', 'Kirk'}),
        'Then $_r and $_r meet.',
      );
    });

    test('honorifics and abbreviations are not sentence ends or names', () {
      expect(plain.redact('He meets Dr. Grant at the park.', names: {'Grant'}),
          'He meets Dr. $_r at the park.');
      expect(plain.redact('It opens Dec. 7, 1941.'), 'It opens Dec. 7, 1941.');
    });

    test('hides a hyphenated compound when a part is a giveaway', () {
      expect(plain.redact('a friendly Spider-Man swings by',
              titles: ['Spider-Man']),
          'a friendly $_r swings by');
      expect(plain.redact('a well-known story'), 'a well-known story');
    });

    test('acronyms are kept only when known to be generic', () {
      expect(
          plain.redact('An FBI agent named Clarice hunts.',
              names: {'Clarice'}),
          'An $_r agent named $_r hunts.');
      final r = PlotRedactor(genericCapitalized: {'FBI'});
      expect(r.redact('An FBI agent named Clarice hunts.', names: {'Clarice'}),
          'An FBI agent named $_r hunts.');
    });
  });

  group('splitPlotSentences', () {
    test('splits on sentence ends but not abbreviations or initials', () {
      expect(
        splitPlotSentences(
            'Dr. Grant visits the U.S. Army base. He meets J. Smith! Why?'),
        ['Dr. Grant visits the U.S. Army base.', 'He meets J. Smith!', 'Why?'],
      );
    });

    test('a sentence may start with a redaction block or a quote', () {
      expect(splitPlotSentences('He runs. $_r follows. "Stop," he says.'),
          ['He runs.', '$_r follows.', '"Stop," he says.']);
    });
  });

  group('plotOpeningSplit', () {
    test('single sentence → no rest', () {
      final s = plotOpeningSplit('Only one sentence here.');
      expect(s.opening, 'Only one sentence here.');
      expect(s.rest, isEmpty);
    });

    test('short first sentences are joined, but something is left over', () {
      final s = plotOpeningSplit('Short one. Short two. Short three.');
      expect(s.opening, 'Short one. Short two.');
      expect(s.rest, 'Short three.');
    });

    test('a long first sentence stands alone', () {
      final first = 'A ${'very ' * 30}long first sentence.';
      final s = plotOpeningSplit('$first Second. Third.');
      expect(s.opening, first);
      expect(s.rest, 'Second. Third.');
    });
  });

  group('clue schedule', () {
    test('full order: rest → year → genres → actor → tagline', () {
      expect(plotClueOrder(_puzzle()), [
        PlotClueKind.plotRest,
        PlotClueKind.year,
        PlotClueKind.genres,
        PlotClueKind.actor,
        PlotClueKind.tagline,
      ]);
    });

    test('second actor stands in for a missing tagline', () {
      expect(plotClueOrder(_puzzle(tagline: '')).last,
          PlotClueKind.secondActor);
    });

    test('one-sentence plot skips the plot-rest clue', () {
      final order = plotClueOrder(_puzzle(overview: 'Just this.'));
      expect(order.first, PlotClueKind.year);
      expect(order, hasLength(plotGameMaxAttempts - 1));
    });

    test('one clue per miss, all once finished', () {
      final p = _puzzle();
      expect(plotRevealedClues(p, 0), isEmpty);
      expect(plotRevealedClues(p, 2), [PlotClueKind.plotRest, PlotClueKind.year]);
      expect(plotRevealedClues(p, 99), plotClueOrder(p));
      expect(plotRevealedClues(p, 1, finished: true), plotClueOrder(p));
    });
  });

  group('plotGameProgress', () {
    const wrong = PlotAttempt(id: 7, title: 'Wrong');
    const right = PlotAttempt(id: 42, title: 'Mystery');
    const skip = PlotAttempt.skip();

    test('in progress', () {
      final p = plotGameProgress([wrong, skip], 42);
      expect(p.won, isFalse);
      expect(p.finished, isFalse);
      expect(p.missed, 2);
      expect(p.attemptsLeft, plotGameMaxAttempts - 2);
    });

    test('win stops the game and ignores anything after it', () {
      final p = plotGameProgress([wrong, right, wrong], 42);
      expect(p.won, isTrue);
      expect(p.finished, isTrue);
      expect(p.attempts, hasLength(2));
      expect(p.missed, 1);
    });

    test('loses after max attempts', () {
      final p = plotGameProgress(
          List.filled(plotGameMaxAttempts + 2, wrong), 42);
      expect(p.won, isFalse);
      expect(p.finished, isTrue);
      expect(p.attempts, hasLength(plotGameMaxAttempts));
    });

    test('attempt json is lenient', () {
      expect(PlotAttempt.fromJson({'id': 5.0, 'title': 'X'}).id, 5);
      expect(PlotAttempt.fromJson('junk').isSkip, isTrue);
      expect(PlotAttempt.fromJson(right.toJson()).title, 'Mystery');
    });
  });

  group('day index', () {
    test('rolls over at midnight EST (05:00 UTC)', () {
      final before = DateTime.utc(2026, 10, 15, 4, 59);
      final after = DateTime.utc(2026, 10, 15, 5, 0);
      expect(plotGameDateKey(before), '2026-10-14');
      expect(plotGameDateKey(after), '2026-10-15');
      expect(plotGameDayIndex(after) - plotGameDayIndex(before), 1);
    });

    test('anchored at 2024-01-01 EST', () {
      expect(plotGameDayIndex(DateTime.utc(2024, 1, 1, 5)), 0);
      expect(plotGameDayIndex(DateTime.utc(2025, 1, 1, 5)), 366);
    });

    test('doc id and pool index', () {
      expect(plotGameDocId(PlotGameMode.tv, DateTime.utc(2026, 1, 2, 12)),
          'plot-tv-2026-01-02');
      expect(plotGamePuzzleIndex(1000, 365), 1000 % 365);
      expect(() => plotGamePuzzleIndex(1, 0), throwsArgumentError);
    });
  });

  group('plotGameShareText', () {
    test('win: one square per attempt, padded, no title', () {
      final text = plotGameShareText(
        header: 'WatchVerse Plot · Movie',
        dateKey: '2026-10-14',
        progress: plotGameProgress(const [
          PlotAttempt(id: 1, title: 'Secret A'),
          PlotAttempt.skip(),
          PlotAttempt(id: 42, title: 'Mystery'),
        ], 42),
      );
      expect(text, 'WatchVerse Plot · Movie · 2026-10-14\n🟥⬛🟩⬜⬜⬜ 3/6');
      expect(text, isNot(contains('Mystery')));
      expect(text, isNot(contains('Secret')));
    });

    test('loss shows X', () {
      final text = plotGameShareText(
        header: 'H',
        dateKey: 'd',
        progress: plotGameProgress(
            List.filled(plotGameMaxAttempts, const PlotAttempt.skip()), 42),
      );
      expect(text, endsWith('⬛⬛⬛⬛⬛⬛ X/6'));
    });
  });

  group('shipped pools', () {
    for (final mode in PlotGameMode.values) {
      test('${mode.key} pool is big enough and never shows the title', () {
        final json = jsonDecode(
                File('assets/games/plot_pool_${mode.key}.json')
                    .readAsStringSync())
            as Map<String, dynamic>;
        final items = (json['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(PlotPuzzle.fromJson)
            .toList();
        expect(items.length, greaterThanOrEqualTo(365));
        expect(items.map((p) => p.id).toSet(), hasLength(items.length));
        final word = RegExp(r"[\p{L}\p{N}]+", unicode: true);
        for (final p in items) {
          expect(p.redactedOverview, isNotEmpty, reason: p.title);
          expect(p.year, greaterThan(0), reason: p.title);
          expect(p.cast, isNotEmpty, reason: p.title);
          final titleWords = plotTitleWords([p.title]);
          for (final text in [p.redactedOverview, p.tagline]) {
            for (final m in word.allMatches(text)) {
              final w = m.group(0)!.toLowerCase();
              final singular = w.length > 3 && w.endsWith('s') && !w.endsWith('ss')
                  ? w.substring(0, w.length - 1)
                  : w;
              expect(titleWords.contains(singular), isFalse,
                  reason: '"${p.title}" leaks "$w" in: $text');
            }
          }
        }
      });
    }
  });
}
