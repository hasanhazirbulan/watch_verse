import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/utils/genre_names.dart';

void main() {
  test('localizedGenre translates TMDB genres for Turkish only', () {
    expect(localizedGenre('Science Fiction', 'tr'), 'Bilim Kurgu');
    expect(localizedGenre('Science Fiction', 'en'), 'Science Fiction');
    expect(localizedGenre('Unknown', 'tr'), 'Unknown');
  });

  test('localizedGenreText handles joined lists and clue summaries', () {
    expect(localizedGenreText('Action, Drama', 'tr'), 'Aksiyon, Dram');
    expect(localizedGenreText('Action +1', 'tr'), 'Aksiyon +1');
    expect(localizedGenreText('Action & Adventure, Crime', 'tr'),
        'Aksiyon & Macera, Suç');
    expect(localizedGenreText('Action, Drama', 'en'), 'Action, Drama');
  });

  test('localizedGenreText does not touch genre words inside other words', () {
    expect(localizedGenreText('Warfare', 'tr'), 'Warfare');
  });
}
