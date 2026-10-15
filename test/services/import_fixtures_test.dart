import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/import/import_models.dart';
import 'package:watch_verse/services/import/import_parser.dart';

import '../../integration_test/fixtures/import_fixtures.dart';

/// Keeps the base64 copies the on-device import smoke test uses in sync with
/// the real fixture files, and checks the parser reads them as intended.
void main() {
  const dir = 'integration_test/fixtures';

  test('embedded fixtures match the files', () {
    expect(letterboxdExportZip,
        File('$dir/letterboxd-export.zip').readAsBytesSync());
    expect(imdbRatingsCsv, File('$dir/imdb-ratings.csv').readAsBytesSync());
  });

  test('fixtures parse to the titles the smoke test expects', () {
    final parsed = parseImportFiles([
      ImportFile('letterboxd-smoke-export.zip', letterboxdExportZip),
      ImportFile('ratings.csv', imdbRatingsCsv),
    ]);
    expect(parsed.unrecognizedFiles, isEmpty);
    expect(parsed.skippedRows, 1);
    ImportedTitle t(String title, ImportSource source) => parsed.titles
        .singleWhere((x) => x.title == title && x.source == source);

    final parasite = t('Parasite', ImportSource.letterboxd);
    expect(parasite.rating, 5);
    expect(parasite.diary.map((d) => d.rewatch), [false, true]);
    expect(parasite.watchedOn, DateTime(2025, 11, 2));
    expect(t('The Thing', ImportSource.letterboxd).rating, 4,
        reason: 'diary rating stands in when ratings.csv has none');
    expect(t('Amélie', ImportSource.letterboxd).watchedOn,
        DateTime(2025, 12, 24));
    expect(t('Dune: Part Two', ImportSource.letterboxd).watchlist, isTrue);
    expect(t('Breaking Bad', ImportSource.imdb).kind, ImportKind.tv);
    expect(t('Interstellar', ImportSource.imdb).rating, 3.5);
    // deleted/, likes/ and lists/ are ignored.
    expect(parsed.titles.map((x) => x.title),
        isNot(anyOf(contains('Cats'), contains('Heat'))));
    expect(parsed.titles, hasLength(12));
  });
}
