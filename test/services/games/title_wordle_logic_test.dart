import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/games/pools/title_wordle_pools.g.dart';
import 'package:watch_verse/services/games/title_wordle_logic.dart';

const c = LetterResult.correct;
const p = LetterResult.present;
const a = LetterResult.absent;

void main() {
  group('scoreGuess', () {
    test('all correct / all absent', () {
      expect(scoreGuess('ALIEN', 'ALIEN'), [c, c, c, c, c]);
      expect(scoreGuess('BOOST', 'ALIEN'), [a, a, a, a, a]);
    });

    test('present letters in the wrong spot', () {
      expect(scoreGuess('NEILA', 'ALIEN'), [p, p, c, p, p]);
    });

    test('duplicate guess letter, single answer copy: only one marked', () {
      // ABIDE has one E: the first E in SPEED is present, the second absent.
      expect(scoreGuess('SPEED', 'ABIDE'), [a, a, p, a, p]);
    });

    test(
      'exact match claims the copy before an earlier misplaced duplicate',
      () {
        // HOTEL has one L and one E, both matched exactly by LEVEL's last two
        // letters — so LEVEL's first L and E get nothing.
        expect(scoreGuess('LEVEL', 'HOTEL'), [a, a, a, c, c]);
        // RIVER has one E: EERIE's first E is present, the others absent.
        expect(scoreGuess('EERIE', 'RIVER'), [p, a, p, p, a]);
      },
    );

    test('two answer copies allow two present marks', () {
      // LLAMA vs HELLO: answer has two Ls, both guess Ls are misplaced.
      expect(scoreGuess('LLAMA', 'HELLO'), [p, p, a, a, a]);
      // HELLO vs LLAMA: answer has two Ls; guess L at 2 and 3 misplaced.
      expect(scoreGuess('HELLO', 'LLAMA'), [a, a, p, p, a]);
    });

    test('correct duplicate plus extra copy', () {
      expect(scoreGuess('TTTTTTTT', 'TOYSTORY'), [c, a, a, a, c, a, a, a]);
    });

    test('length mismatch throws', () {
      expect(() => scoreGuess('ABC', 'ABCD'), throwsArgumentError);
    });
  });

  test('keyboardStates keeps the best result per letter', () {
    final s = keyboardStates(['NEILA', 'ALIEN'], 'ALIEN');
    expect(s['A'], c);
    expect(s['N'], c);
    final s2 = keyboardStates(['SPEED'], 'ABIDE');
    expect(s2['E'], p);
    expect(s2['S'], a);
  });

  group('normalizeTitle', () {
    test('strips accents, apostrophes and punctuation', () {
      expect(normalizeTitle('Déjà Vu'), 'DEJA VU');
      expect(normalizeTitle('Amélie'), 'AMELIE');
      expect(normalizeTitle("Ocean's"), 'OCEANS');
      expect(normalizeTitle('Face/Off'), 'FACE OFF');
      expect(normalizeTitle('Kick-Ass'), 'KICK ASS');
      expect(normalizeTitle('Pain & Gain'), 'PAIN GAIN');
      expect(normalizeTitle('Shazam!'), 'SHAZAM');
      expect(normalizeTitle('I, Robot'), 'I ROBOT');
      expect(normalizeTitle('Shōgun'), 'SHOGUN');
    });

    test('rejects digits and non-Latin scripts', () {
      expect(normalizeTitle('Se7en'), isNull);
      expect(normalizeTitle('1917'), isNull);
      expect(normalizeTitle('千と千尋の神隠し'), isNull);
      expect(normalizeTitle('  '), isNull);
    });
  });

  test('TitleWordleState submit / win / lose', () {
    var s = const TitleWordleState('ALIEN', []);
    expect(s.submit('ABC'), isNull); // wrong length
    expect(s.submit('AL1EN'), isNull); // non-letters
    s = s.submit('boost')!; // lower-case accepted
    expect(s.guesses, ['BOOST']);
    expect(s.finished, isFalse);
    s = s.submit('ALIEN')!;
    expect(s.won, isTrue);
    expect(s.finished, isTrue);
    expect(s.submit('NEILA'), isNull);

    var l = const TitleWordleState('ALIEN', []);
    for (var i = 0; i < titleWordleMaxGuesses; i++) {
      l = l.submit('BOOST')!;
    }
    expect(l.finished, isTrue);
    expect(l.won, isFalse);
  });

  test(
    'TitleWordleState.fromMap drops malformed data and post-win guesses',
    () {
      final s = TitleWordleState.fromMap('ALIEN', {
        'guesses': ['BOOST', 42, 'TOOLONG', 'ALIEN', 'NEILA'],
      });
      expect(s.guesses, ['BOOST', 'ALIEN']);
      expect(s.won, isTrue);
      expect(TitleWordleState.fromMap('ALIEN', null).guesses, isEmpty);
      expect(
        TitleWordleState.fromMap('ALIEN', {'guesses': 'nope'}).guesses,
        isEmpty,
      );
      final map = s.toMap(348);
      expect(map['answerId'], 348);
      expect(map['won'], true);
      expect(map['finished'], true);
    },
  );

  test('share text keeps word gaps and hides letters', () {
    const entry = WordlePoolEntry(
      862,
      'Toy Story',
      'TOY STORY',
      '/p.jpg',
      '1995',
    );
    final text = titleWordleShareText(
      puzzleNumber: 7,
      mode: MediaType.movie,
      entry: entry,
      guesses: ['TOYSHORT', 'TOYSTORY'],
    );
    expect(text.split('\n'), [
      'WatchVerse Title Wordle #7 🎬 2/6',
      '🟩🟩🟩 🟩⬛🟩🟩🟨',
      '🟩🟩🟩 🟩🟩🟩🟩🟩',
    ]);
    expect(text.contains('TOY'), isFalse);
    final lost = titleWordleShareText(
      puzzleNumber: 7,
      mode: MediaType.tv,
      entry: entry,
      guesses: List.filled(6, 'AAAAAAAA'),
    );
    expect(lost.split('\n').first, 'WatchVerse Title Wordle #7 📺 X/6');
  });

  group('bundled pools', () {
    for (final (name, pool) in [
      ('movie', titleWordleMoviePool),
      ('tv', titleWordleTvPool),
    ]) {
      test('$name pool entries are valid puzzles', () {
        expect(pool.length, greaterThanOrEqualTo(300));
        final ids = <int>{};
        final answers = <String>{};
        for (final e in pool) {
          expect(ids.add(e.id), isTrue, reason: 'duplicate id ${e.id}');
          expect(
            answers.add(e.letters),
            isTrue,
            reason: 'duplicate answer ${e.answer}',
          );
          expect(
            normalizeTitle(e.title),
            e.answer,
            reason: 'generator/app normalization drift for "${e.title}"',
          );
          expect(
            e.letters.length,
            inInclusiveRange(titleWordleMinLetters, titleWordleMaxLetters),
          );
          expect(e.posterPath, isNotEmpty);
        }
      });
    }
  });
}
