import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart';

Movie _sparse() => Movie(
      id: 42,
      title: 'Seed Title',
      overview: '',
      posterPath: '/seed.jpg',
      backDropPath: '',
      releaseDate: '',
      voteAverage: 0,
    );

void main() {
  group('movieWithStoredMeta', () {
    test('returns the seed unchanged when nothing is stored', () {
      final seed = _sparse();
      expect(identical(movieWithStoredMeta(seed, null), seed), isTrue);
    });

    test('fills blank seed fields from the stored movie doc', () {
      // Shape written by MovieService._meta.
      final merged = movieWithStoredMeta(_sparse(), {
        'id': 42,
        'title': 'Stored Title',
        'posterPath': '/stored.jpg',
        'backdropPath': '/backdrop.jpg',
        'releaseDate': '1999-03-31',
        'voteAverage': 8.2,
        'overview': 'A hacker learns the truth.',
        'runtime': 136,
        'genres': ['Action', 'Science Fiction'],
        'status': 'watched',
      });

      expect(merged.id, 42);
      // Non-empty seed values win.
      expect(merged.title, 'Seed Title');
      expect(merged.posterPath, '/seed.jpg');
      // Blank seed values are backfilled instead of overwriting the doc.
      expect(merged.overview, 'A hacker learns the truth.');
      expect(merged.backDropPath, '/backdrop.jpg');
      expect(merged.releaseDate, '1999-03-31');
      expect(merged.voteAverage, 8.2);
      expect(merged.runtime, 136);
      expect(merged.genres, ['Action', 'Science Fiction']);
    });

    test('accepts an integer voteAverage in the stored doc', () {
      final merged = movieWithStoredMeta(_sparse(), {'voteAverage': 7});
      expect(merged.voteAverage, 7.0);
    });
  });
}
