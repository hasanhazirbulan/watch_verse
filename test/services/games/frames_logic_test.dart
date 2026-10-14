import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/games/frames_logic.dart';
import 'package:watch_verse/services/games/pools/frames_pools.g.dart';

Map<String, dynamic> _backdrop(
  String path, {
  String? lang,
  int width = 1920,
  double ratio = 1.778,
  int votes = 0,
}) => {
  'file_path': path,
  'iso_639_1': lang,
  'width': width,
  'aspect_ratio': ratio,
  'vote_count': votes,
  'vote_average': votes > 0 ? 5.0 : 0.0,
};

void main() {
  group('pickFrameStills', () {
    test('drops text-bearing, small, non-16:9 and duplicate images', () {
      final stills = pickFrameStills([
        _backdrop('/en.jpg', lang: 'en', votes: 99),
        _backdrop('/small.jpg', width: 780),
        _backdrop('/square.jpg', ratio: 1.0),
        _backdrop('/ok.jpg'),
        _backdrop('/ok.jpg'),
        'garbage',
      ]);
      expect(stills, ['/ok.jpg']);
    });

    test('keeps the 6 most-voted, revealed least iconic first', () {
      final stills = pickFrameStills([
        for (var i = 0; i < 9; i++) _backdrop('/$i.jpg', votes: i),
      ]);
      expect(stills, [
        '/3.jpg',
        '/4.jpg',
        '/5.jpg',
        '/6.jpg',
        '/7.jpg',
        '/8.jpg',
      ]);
    });

    test('order is deterministic for ties', () {
      final a = pickFrameStills([_backdrop('/b.jpg'), _backdrop('/a.jpg')]);
      final b = pickFrameStills([_backdrop('/a.jpg'), _backdrop('/b.jpg')]);
      expect(a, b);
    });
  });

  group('FramesState', () {
    test('wrong guesses and skips unlock stills; a correct guess wins', () {
      var s = const FramesState(10, []);
      expect(s.stillsUnlocked, 1);
      s = s.submit(const FramesGuess(1, 'Wrong'))!;
      expect(s.stillsUnlocked, 2);
      s = s.submit(const FramesGuess.skip())!;
      expect(s.stillsUnlocked, 3);
      expect(
        s.submit(const FramesGuess(1, 'Wrong again')),
        isNull,
        reason: 'same title twice is rejected',
      );
      s = s.submit(const FramesGuess(10, 'Right'))!;
      expect(s.won, isTrue);
      expect(s.finished, isTrue);
      expect(s.stillsUnlocked, framesMaxStills);
      expect(s.submit(const FramesGuess.skip()), isNull);
    });

    test('six misses lose', () {
      var s = const FramesState(10, []);
      for (var i = 0; i < framesMaxStills; i++) {
        s = s.submit(const FramesGuess.skip())!;
      }
      expect(s.finished, isTrue);
      expect(s.won, isFalse);
    });

    test('round-trips through a Firestore map, ignoring junk', () {
      final s = const FramesState(10, [
        FramesGuess(1, 'A'),
        FramesGuess.skip(),
        FramesGuess(10, 'Answer'),
      ]);
      final map = s.toMap();
      expect(map['won'], true);
      final back = FramesState.fromMap(10, {
        'guesses': [
          ...map['guesses'] as List,
          {'id': 5, 'title': 'after win'},
        ],
      });
      expect(back.guesses.map((g) => g.id), [1, null, 10]);
      expect(back.won, isTrue);
      expect(
        FramesState.fromMap(10, {
          'guesses': [
            'x',
            {'id': -1},
            null,
            {'skip': true},
          ],
        }).guesses.length,
        1,
      );
      expect(FramesState.fromMap(10, null).guesses, isEmpty);
    });
  });

  test('share text: 🟥 wrong, ⬜ skip, 🟩 correct, ⬛ unused', () {
    final text = framesShareText(
      puzzleNumber: 123,
      mode: MediaType.movie,
      state: const FramesState(10, [
        FramesGuess(1, 'A'),
        FramesGuess.skip(),
        FramesGuess(10, 'Answer'),
      ]),
    );
    expect(text, 'WatchVerse Frames #123 🎬\n🟥⬜🟩⬛⬛⬛');
    expect(
      framesShareText(
        puzzleNumber: 1,
        mode: MediaType.tv,
        state: const FramesState(10, []),
      ),
      'WatchVerse Frames #1 📺\n⬛⬛⬛⬛⬛⬛',
    );
  });

  test('bundled pools are large and duplicate-free', () {
    for (final pool in [framesMoviePool, framesTvPool]) {
      expect(pool.length, greaterThanOrEqualTo(365));
      expect(pool.toSet().length, pool.length);
      expect(pool.every((id) => id > 0), isTrue);
    }
  });
}
