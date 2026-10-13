import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:watch_verse/services/import/import_models.dart';

/// Top-level entry point so the UI can run parsing off the main isolate via
/// `compute(parseImportFiles, files)` — a 2000-film Letterboxd zip is a few
/// MB of CSV.
ParsedImport parseImportFiles(List<ImportFile> files) =>
    const LibraryImportParser().parseFiles(files);

/// Pure-Dart parser for the two export formats people bring from other
/// trackers. No Flutter, Firebase or network — fully unit-testable.
///
/// **Letterboxd** (Settings → Import & Export → Export Your Data) gives a
/// `.zip`; its root holds `watched.csv` (Date,Name,Year,Letterboxd URI),
/// `ratings.csv` (+ Rating, 0.5–5 in half steps), `diary.csv`
/// (Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date) and
/// `watchlist.csv` (same columns as watched). Everything else in the zip
/// (reviews, profile, comments, `lists/`, `likes/`, `deleted/`,
/// `orphaned/`) is ignored. Those four CSVs can also be picked one by one.
///
/// **IMDb** "Your Ratings" export (Const,Your Rating,Date Rated,Title,…,
/// Title Type,…,Year,…) and the watchlist export (Position,Const,Created,…
/// Title,…,Title Type,…). Recognised by header, not filename — IMDb's own
/// ratings file is also called `ratings.csv`.
///
/// Rating conversion to WatchVerse's 0–5 half-star scale:
///   * Letterboxd 0.5–5 (half steps) → unchanged (same scale).
///   * IMDb 1–10 (integers) → value / 2, so 10 → 5.0, 7 → 3.5, 1 → 0.5.
///     Every IMDb value lands exactly on a half star, so nothing is lost.
class LibraryImportParser {
  const LibraryImportParser();

  /// Letterboxd zip subfolders whose CSVs share a basename with the ones we
  /// want (e.g. `likes/films.csv`, `deleted/watched.csv`) but aren't the
  /// user's current history.
  static const _ignoredZipFolders = {'lists', 'likes', 'deleted', 'orphaned'};

  /// Uncompressed size cap per zip entry — the real files are well under
  /// 1 MB even for huge libraries; this only guards against a bogus zip.
  static const _maxEntryBytes = 50 * 1024 * 1024;

  ParsedImport parseFiles(List<ImportFile> files) {
    final acc = _Accumulator();
    final unrecognized = <String>[];
    for (final f in files) {
      if (f.name.toLowerCase().endsWith('.zip')) {
        if (!_parseZip(f, acc)) unrecognized.add(f.name);
      } else {
        final ok = _parseCsvFile(f.name, _decode(f.bytes), acc,
            fromZip: false);
        if (!ok) unrecognized.add(f.name);
      }
    }
    return ParsedImport(
      titles: acc.titles.values.toList(),
      skippedRows: acc.skipped,
      unrecognizedFiles: unrecognized,
    );
  }

  bool _parseZip(ImportFile f, _Accumulator acc) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(f.bytes);
    } catch (_) {
      return false;
    }
    var any = false;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final segments = entry.name.split('/').where((s) => s.isNotEmpty);
      if (segments.any((s) => s.startsWith('__MACOSX'))) continue;
      final dirs = segments.take(segments.length - 1).map((s) => s.toLowerCase());
      if (dirs.any(_ignoredZipFolders.contains)) continue;
      if (!entry.name.toLowerCase().endsWith('.csv')) continue;
      if (entry.size > _maxEntryBytes) continue;
      final bytes = entry.readBytes();
      if (bytes == null) continue;
      if (_parseCsvFile(segments.last, _decode(bytes), acc, fromZip: true)) {
        any = true;
      }
    }
    return any;
  }

  static String _decode(List<int> bytes) =>
      utf8.decode(bytes, allowMalformed: true);

  /// Returns whether [name] was a recognised export file.
  bool _parseCsvFile(String name, String text, _Accumulator acc,
      {required bool fromZip}) {
    final rows = parseCsv(text);
    final header = rows.header;
    if (header.isEmpty) return false;
    final base = name.toLowerCase().split('/').last.replaceAll('.csv', '');

    // ---- IMDb (ratings or watchlist/list) ----
    if (header.contains('Const')) {
      if (header.contains('Position') || base.contains('watchlist')) {
        for (final r in rows.records) {
          _imdbRow(r, acc, watchlist: true);
        }
        return true;
      }
      if (header.contains('Your Rating')) {
        for (final r in rows.records) {
          _imdbRow(r, acc, watchlist: false);
        }
        return true;
      }
      return false;
    }

    // ---- Letterboxd ----
    if (!header.contains('Name')) return false;
    final _LbKind kind;
    if (fromZip) {
      // Exact basenames only: the zip also has reviews.csv, profile.csv…
      switch (base) {
        case 'watched':
          kind = _LbKind.watched;
        case 'ratings':
          kind = _LbKind.ratings;
        case 'diary':
          kind = _LbKind.diary;
        case 'watchlist':
          kind = _LbKind.watchlist;
        default:
          return false;
      }
    } else if (base.contains('watchlist')) {
      kind = _LbKind.watchlist;
    } else if (base.contains('diary') || header.contains('Watched Date')) {
      kind = _LbKind.diary;
    } else if (base.contains('rating') || header.contains('Rating')) {
      kind = _LbKind.ratings;
    } else if (base.contains('watched')) {
      kind = _LbKind.watched;
    } else {
      // Date,Name,Year,URI with an unknown filename — watched.csv and
      // watchlist.csv are indistinguishable by content, so don't guess.
      return false;
    }
    for (final r in rows.records) {
      _letterboxdRow(r, kind, acc);
    }
    return true;
  }

  // ------------------------------------------------------------ Letterboxd --

  void _letterboxdRow(Map<String, String> r, _LbKind kind, _Accumulator acc) {
    final name = (r['Name'] ?? '').trim();
    if (name.isEmpty) {
      acc.skipped++;
      return;
    }
    final year = parseYear(r['Year']);
    final key = 'lb:${normalizeKey(name)}|${year ?? ''}';
    final t = acc.titles.putIfAbsent(
      key,
      () => ImportedTitle(
          source: ImportSource.letterboxd, key: key, title: name, year: year),
    );
    final date = parseDate(r['Date']);
    switch (kind) {
      case _LbKind.watched:
        t.watched = true;
        t.loggedOn = ImportedTitle.later(t.loggedOn, date);
      case _LbKind.ratings:
        final rating = parseLetterboxdRating(r['Rating']);
        if (rating != null) {
          // Letterboxd only lets you rate films you've watched.
          t.watched = true;
          t.rating = rating;
          t.ratedOn = ImportedTitle.later(t.ratedOn, date);
          acc.ratingsFileKeys.add(key);
        }
      case _LbKind.diary:
        final watchedOn = parseDate(r['Watched Date']) ?? date;
        final rating = parseLetterboxdRating(r['Rating']);
        t.watched = true;
        if (watchedOn != null) {
          t.diary.add(ImportedDiaryEntry(
            watchedOn: watchedOn,
            rating: rating,
            rewatch: (r['Rewatch'] ?? '').trim().toLowerCase() == 'yes',
          ));
          t.diaryWatchedOn = ImportedTitle.later(t.diaryWatchedOn, watchedOn);
        }
        // ratings.csv holds the *current* rating and wins; otherwise the
        // latest-dated diary rating stands in for it.
        if (rating != null && !acc.ratingsFileKeys.contains(key)) {
          final prev = acc.diaryRatingDate[key];
          if (prev == null ||
              (watchedOn != null && !watchedOn.isBefore(prev))) {
            t.rating = rating;
            acc.diaryRatingDate[key] = watchedOn ?? prev ?? DateTime(0);
          }
        }
      case _LbKind.watchlist:
        t.watchlist = true;
    }
  }

  /// Letterboxd ratings are 0.5–5 in half steps — already WatchVerse's
  /// scale. Anything out of range or unparsable is treated as "no rating".
  static double? parseLetterboxdRating(String? raw) {
    final v = double.tryParse((raw ?? '').trim());
    if (v == null || v < 0.5 || v > 5) return null;
    return (v * 2).round() / 2;
  }

  // ------------------------------------------------------------------ IMDb --

  /// Normalised IMDb `Title Type`s (lowercase, letters only — covers both
  /// the current "TV Series" and the legacy "tvSeries" spellings).
  static const _imdbTvTypes = {'tvseries', 'tvminiseries'};
  static const _imdbUnsupportedTypes = {
    'tvepisode', // we can't tell which show/season it belongs to from here
    'videogame',
    'podcastseries',
    'podcastepisode',
    'musicvideo',
  };

  void _imdbRow(Map<String, String> r, _Accumulator acc,
      {required bool watchlist}) {
    final id = (r['Const'] ?? '').trim();
    final title = (r['Title'] ?? '').trim();
    final type = (r['Title Type'] ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
    if (!RegExp(r'^tt\d+$').hasMatch(id) ||
        _imdbUnsupportedTypes.contains(type)) {
      acc.skipped++;
      return;
    }
    final key = 'imdb:$id';
    final t = acc.titles.putIfAbsent(
      key,
      () => ImportedTitle(
        source: ImportSource.imdb,
        key: key,
        title: title.isEmpty ? id : title,
        year: parseYear(r['Year']),
        imdbId: id,
        kind: _imdbTvTypes.contains(type) ? ImportKind.tv : ImportKind.movie,
      ),
    );
    if (watchlist) {
      t.watchlist = true;
      return;
    }
    final rating = parseImdbRating(r['Your Rating']);
    if (rating == null) {
      acc.skipped++;
      return;
    }
    // A rating on IMDb implies you've seen it.
    t.watched = true;
    t.rating = rating;
    t.ratedOn = ImportedTitle.later(t.ratedOn, parseDate(r['Date Rated']));
  }

  /// IMDb 1–10 → WatchVerse 0.5–5 (÷2). See class doc.
  static double? parseImdbRating(String? raw) {
    final v = double.tryParse((raw ?? '').trim());
    if (v == null || v < 1 || v > 10) return null;
    return (v.round()) / 2;
  }

  // --------------------------------------------------------------- helpers --

  static int? parseYear(String? raw) {
    final m = RegExp(r'\d{4}').firstMatch(raw ?? '');
    return m == null ? null : int.parse(m.group(0)!);
  }

  /// `YYYY-MM-DD` (both sites) → a local calendar date, or null.
  static DateTime? parseDate(String? raw) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch((raw ?? '').trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  /// Case/whitespace-insensitive key so "The Thing " and "the thing" rows
  /// from different files merge.
  static String normalizeKey(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// RFC 4180 CSV → header + records keyed by (trimmed) header name. Handles
  /// a UTF-8 BOM, CRLF/LF, quoted fields with commas/quotes/newlines, short
  /// rows, and extra/unknown columns (simply carried along, never required).
  static CsvTable parseCsv(String text) {
    var input = text;
    if (input.startsWith('﻿')) input = input.substring(1);
    final rows = Csv(autoDetect: false).decode(input);
    if (rows.isEmpty) return const CsvTable([], []);
    final header = rows.first.map((e) => e.toString().trim()).toList();
    final records = <Map<String, String>>[];
    for (final row in rows.skip(1)) {
      if (row.every((c) => c.toString().trim().isEmpty)) continue;
      records.add({
        for (var i = 0; i < header.length && i < row.length; i++)
          header[i]: row[i].toString(),
      });
    }
    return CsvTable(header, records);
  }
}

class CsvTable {
  final List<String> header;
  final List<Map<String, String>> records;
  const CsvTable(this.header, this.records);
}

enum _LbKind { watched, ratings, diary, watchlist }

class _Accumulator {
  final titles = <String, ImportedTitle>{};
  int skipped = 0;

  /// Letterboxd keys whose rating came from ratings.csv (authoritative).
  final ratingsFileKeys = <String>{};

  /// Watch date of the diary entry currently supplying a key's rating.
  final diaryRatingDate = <String, DateTime>{};
}
