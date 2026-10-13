import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/import/import_models.dart';
import 'package:watch_verse/services/import/import_parser.dart';

ImportFile csvFile(String name, String text) =>
    ImportFile(name, Uint8List.fromList(utf8.encode(text)));

ImportFile zipFile(String name, Map<String, String> entries) {
  final archive = Archive();
  entries.forEach((path, text) {
    archive.addFile(ArchiveFile.bytes(path, utf8.encode(text)));
  });
  return ImportFile(name, ZipEncoder().encodeBytes(archive));
}

ImportedTitle byTitle(ParsedImport p, String title) =>
    p.titles.singleWhere((t) => t.title == title);

void main() {
  const parser = LibraryImportParser();

  group('parseCsv', () {
    test('strips a UTF-8 BOM so the first header is recognised', () {
      final t = LibraryImportParser.parseCsv(
          '﻿Date,Name,Year,Letterboxd URI\n2024-01-02,Heat,1995,x\n');
      expect(t.header.first, 'Date');
      expect(t.records.single['Name'], 'Heat');
    });

    test('handles CRLF, quoted commas, escaped quotes and newlines', () {
      final t = LibraryImportParser.parseCsv(
          'Date,Name,Year\r\n'
          '2024-01-02,"Crouching Tiger, Hidden Dragon",2000\r\n'
          '2024-01-03,"The ""Burbs""",1989\r\n'
          '2024-01-04,"Line\nBreak",2001\r\n');
      expect(t.records.map((r) => r['Name']), [
        'Crouching Tiger, Hidden Dragon',
        'The "Burbs"',
        'Line\nBreak',
      ]);
      expect(t.records.first['Year'], '2000');
    });

    test('tolerates short rows, blank lines and unknown columns', () {
      final t = LibraryImportParser.parseCsv(
          'Date,Name,Year,Mystery Column\n\n2024-01-02,Heat\n,,,\n');
      expect(t.records, hasLength(1));
      expect(t.records.single['Name'], 'Heat');
      expect(t.records.single.containsKey('Year'), isFalse);
    });

    test('empty input yields an empty table', () {
      final t = LibraryImportParser.parseCsv('');
      expect(t.header, isEmpty);
      expect(t.records, isEmpty);
    });
  });

  group('ratings conversion', () {
    test('Letterboxd keeps its 0.5–5 half-star scale', () {
      expect(LibraryImportParser.parseLetterboxdRating('4.5'), 4.5);
      expect(LibraryImportParser.parseLetterboxdRating('0.5'), 0.5);
      expect(LibraryImportParser.parseLetterboxdRating('5'), 5.0);
      expect(LibraryImportParser.parseLetterboxdRating(''), isNull);
      expect(LibraryImportParser.parseLetterboxdRating('0'), isNull);
      expect(LibraryImportParser.parseLetterboxdRating('7'), isNull);
      expect(LibraryImportParser.parseLetterboxdRating('abc'), isNull);
    });

    test('IMDb 1–10 is halved onto the 0.5–5 scale', () {
      expect(LibraryImportParser.parseImdbRating('10'), 5.0);
      expect(LibraryImportParser.parseImdbRating('7'), 3.5);
      expect(LibraryImportParser.parseImdbRating('1'), 0.5);
      expect(LibraryImportParser.parseImdbRating('0'), isNull);
      expect(LibraryImportParser.parseImdbRating('11'), isNull);
      expect(LibraryImportParser.parseImdbRating(''), isNull);
    });
  });

  group('Letterboxd', () {
    const watched = 'Date,Name,Year,Letterboxd URI\n'
        '2023-05-01,Heat,1995,https://boxd.it/aaa\n'
        '2023-05-02,"Crouching Tiger, Hidden Dragon",2000,https://boxd.it/bbb\n'
        '2023-05-03,Untitled Thing,,https://boxd.it/ccc\n'
        '2023-05-01,Heat,1995,https://boxd.it/aaa\n'; // duplicate row
    const ratings = 'Date,Name,Year,Letterboxd URI,Rating\n'
        '2023-06-01,Heat,1995,https://boxd.it/aaa,4.5\n'
        '2023-06-01,Paprika,2006,https://boxd.it/ddd,3\n';
    const diary =
        'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n'
        '2023-07-10,Heat,1995,https://boxd.it/e1,3.5,,,2023-07-09\n'
        '2024-02-10,Heat,1995,https://boxd.it/e2,4,Yes,"crime, la",2024-02-08\n'
        '2024-03-01,Arrival,2016,https://boxd.it/e3,2.5,,,2024-02-28\n';
    const watchlist = 'Date,Name,Year,Letterboxd URI\n'
        '2024-01-01,Stalker,1979,https://boxd.it/fff\n'
        '2024-01-01,Heat,1995,https://boxd.it/aaa\n';

    test('watched.csv: one title per film, duplicates merged', () {
      final p = parser.parseFiles([csvFile('watched.csv', watched)]);
      expect(p.titles, hasLength(3));
      final heat = byTitle(p, 'Heat');
      expect(heat.watched, isTrue);
      expect(heat.year, 1995);
      expect(heat.watchedOn, DateTime(2023, 5, 1));
      expect(heat.source, ImportSource.letterboxd);
      expect(byTitle(p, 'Untitled Thing').year, isNull);
      expect(byTitle(p, 'Crouching Tiger, Hidden Dragon').year, 2000);
    });

    test('zip: merges watched, ratings, diary and watchlist per film', () {
      final p = parser.parseFiles([
        zipFile('letterboxd-me-2026.zip', {
          'watched.csv': watched,
          'ratings.csv': ratings,
          'diary.csv': diary,
          'watchlist.csv': watchlist,
          'reviews.csv': diary, // ignored
          'profile.csv': 'Date Joined,Username\n2020-01-01,me\n', // ignored
          'likes/films.csv': 'Date,Name,Year,Letterboxd URI\n'
              '2020-01-01,Liked Only,2001,x\n', // ignored
          'deleted/diary.csv': diary, // ignored
        }),
      ]);
      expect(p.unrecognizedFiles, isEmpty);
      expect(p.titles.map((t) => t.title).toSet(), {
        'Heat',
        'Crouching Tiger, Hidden Dragon',
        'Untitled Thing',
        'Paprika',
        'Arrival',
        'Stalker',
      });

      final heat = byTitle(p, 'Heat');
      // ratings.csv is the current rating and beats diary ratings.
      expect(heat.rating, 4.5);
      expect(heat.diary, hasLength(2)); // reviews.csv/deleted/ not double-counted
      expect(heat.diary.last.rewatch, isTrue);
      // Diary "Watched Date" beats the watched.csv log date.
      expect(heat.watchedOn, DateTime(2024, 2, 8));
      expect(heat.watchlist, isTrue);

      final paprika = byTitle(p, 'Paprika');
      expect(paprika.watched, isTrue, reason: 'a rating implies watched');
      expect(paprika.rating, 3.0);
      expect(paprika.watchedOn, DateTime(2023, 6, 1));

      final arrival = byTitle(p, 'Arrival');
      expect(arrival.rating, 2.5, reason: 'diary rating when unrated');
      expect(arrival.diary.single.watchedOn, DateTime(2024, 2, 28));

      final stalker = byTitle(p, 'Stalker');
      expect(stalker.watchlist, isTrue);
      expect(stalker.watched, isFalse);
    });

    test('zip with a top-level folder still finds the CSVs', () {
      final p = parser.parseFiles([
        zipFile('export.zip', {'letterboxd-me/watched.csv': watched}),
      ]);
      expect(p.titles, hasLength(3));
    });

    test('diary rating: latest-dated entry wins regardless of row order', () {
      const d =
          'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n'
          '2024-02-10,Heat,1995,x,4,Yes,,2024-02-08\n'
          '2023-07-10,Heat,1995,y,2,,,2023-07-09\n';
      final heat = byTitle(parser.parseFiles([csvFile('diary.csv', d)]), 'Heat');
      expect(heat.rating, 4.0);
    });

    test('individual CSVs are recognised by filename, then header', () {
      final p = parser.parseFiles([
        csvFile('watchlist (1).csv', watchlist),
        csvFile('my-diary.csv', diary),
        csvFile('mystery.csv', 'Date,Name,Year,Letterboxd URI,Rating\n'
            '2023-06-01,Ran,1985,x,5\n'),
        csvFile('unknown.csv', 'Date,Name,Year,Letterboxd URI\n'
            '2023-06-01,Ran,1985,x\n'),
        csvFile('notes.csv', 'foo,bar\n1,2\n'),
      ]);
      expect(byTitle(p, 'Stalker').watchlist, isTrue);
      expect(byTitle(p, 'Arrival').diary, hasLength(1));
      expect(byTitle(p, 'Ran').rating, 5.0);
      // watched.csv and watchlist.csv look identical — don't guess.
      expect(p.unrecognizedFiles, ['unknown.csv', 'notes.csv']);
    });

    test('rows without a name are skipped and counted', () {
      final p = parser.parseFiles([
        csvFile('watched.csv',
            'Date,Name,Year,Letterboxd URI\n2023-01-01,,2000,x\n'),
      ]);
      expect(p.titles, isEmpty);
      expect(p.skippedRows, 1);
    });

    test('an invalid zip is reported as unrecognised', () {
      final p = parser.parseFiles(
          [ImportFile('broken.zip', Uint8List.fromList([1, 2, 3]))]);
      expect(p.unrecognizedFiles, ['broken.zip']);
    });
  });

  group('IMDb', () {
    const ratings = '﻿Const,Your Rating,Date Rated,Title,Original Title,'
        'URL,Title Type,IMDb Rating,Runtime (mins),Year,Genres,Num Votes,'
        'Release Date,Directors\r\n'
        'tt0111161,10,2024-03-01,The Shawshank Redemption,The Shawshank '
        'Redemption,https://www.imdb.com/title/tt0111161/,Movie,9.3,142,1994,'
        '"Drama",3000000,1994-10-14,Frank Darabont\r\n'
        'tt0903747,9,2024-03-02,Breaking Bad,Breaking Bad,u,TV Series,9.5,49,'
        '2008,"Crime, Drama, Thriller",2000000,2008-01-20,\r\n'
        'tt0959621,10,2024-03-03,Ozymandias,Ozymandias,u,TV Episode,10,47,2013,'
        'Drama,200000,2013-09-15,Rian Johnson\r\n'
        'tt1234567,7,2024-03-04,Old Style,Old Style,u,tvMiniSeries,7,50,2010,'
        'Drama,100,2010-01-01,\r\n'
        'tt0111161,10,2024-03-01,The Shawshank Redemption,x,u,movie,9.3,142,'
        '1994,Drama,3000000,1994-10-14,Frank Darabont\r\n';

    test('"Your Ratings": movies, series, conversion, skips, duplicates', () {
      final p = parser.parseFiles([csvFile('ratings.csv', ratings)]);
      expect(p.titles, hasLength(3));
      expect(p.skippedRows, 1); // the TV episode

      final shawshank = byTitle(p, 'The Shawshank Redemption');
      expect(shawshank.source, ImportSource.imdb);
      expect(shawshank.imdbId, 'tt0111161');
      expect(shawshank.kind, ImportKind.movie);
      expect(shawshank.rating, 5.0);
      expect(shawshank.watched, isTrue);
      expect(shawshank.watchedOn, DateTime(2024, 3, 1));
      expect(shawshank.year, 1994);

      final bb = byTitle(p, 'Breaking Bad');
      expect(bb.kind, ImportKind.tv);
      expect(bb.rating, 4.5);

      expect(byTitle(p, 'Old Style').kind, ImportKind.tv,
          reason: 'legacy camelCase title types');
    });

    test('watchlist export (Position column) → watchlist only', () {
      const wl = 'Position,Const,Created,Modified,Description,Title,'
          'Original Title,URL,Title Type,IMDb Rating,Runtime (mins),Year,'
          'Genres,Num Votes,Release Date,Directors,Your Rating,Date Rated\n'
          '1,tt0816692,2024-01-01,2024-01-01,,Interstellar,Interstellar,u,'
          'Movie,8.7,169,2014,Sci-Fi,2000000,2014-11-07,Christopher Nolan,,\n'
          '2,tt0944947,2024-01-02,2024-01-02,,Game of Thrones,x,u,TV Series,'
          '9.2,57,2011,Drama,2000000,2011-04-17,,,\n'
          '3,not-an-id,2024-01-02,2024-01-02,,Broken,x,u,Movie,1,1,2011,'
          'Drama,1,2011-04-17,,,\n';
      final p = parser.parseFiles([csvFile('WATCHLIST.csv', wl)]);
      expect(p.titles, hasLength(2));
      expect(p.skippedRows, 1);
      final i = byTitle(p, 'Interstellar');
      expect(i.watchlist, isTrue);
      expect(i.watched, isFalse);
      expect(i.rating, isNull);
      expect(byTitle(p, 'Game of Thrones').kind, ImportKind.tv);
    });

    test('ratings + watchlist for the same title merge on the IMDb id', () {
      final p = parser.parseFiles([
        csvFile('ratings.csv', ratings),
        csvFile('watchlist.csv',
            'Position,Const,Created,Title,Title Type,Year\n'
            '1,tt0111161,2024-01-01,The Shawshank Redemption,Movie,1994\n'),
      ]);
      final s = byTitle(p, 'The Shawshank Redemption');
      expect(s.watched, isTrue);
      expect(s.watchlist, isTrue);
    });
  });

  test('parseImportFiles is the isolate-friendly top-level entry', () {
    final p = parseImportFiles([
      csvFile('watched.csv', 'Date,Name,Year,Letterboxd URI\n2023-01-01,Heat,1995,x\n'),
    ]);
    expect(p.titles.single.title, 'Heat');
  });
}
