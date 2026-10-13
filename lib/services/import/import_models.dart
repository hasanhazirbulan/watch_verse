/// Plain data types shared by the Letterboxd/IMDb import pipeline:
/// [LibraryImportParser] (pure, no Flutter/Firebase) produces
/// [ParsedImport]; `LibraryImportService` matches and writes it, producing
/// an [ImportSummary]. Kept free of Firestore/Flutter types so parsing can
/// run in a background isolate.
library;

import 'dart:typed_data';

/// A file the user picked: a Letterboxd `.zip`, or any single CSV.
class ImportFile {
  final String name;
  final Uint8List bytes;
  const ImportFile(this.name, this.bytes);
}

enum ImportSource { letterboxd, imdb }

/// What a title should become in WatchVerse. Letterboxd only exports films;
/// IMDb's `Title Type` column decides (series → tracked show).
enum ImportKind { movie, tv }

/// One dated watch from Letterboxd's `diary.csv` (rewatches included).
class ImportedDiaryEntry {
  final DateTime watchedOn;
  final double? rating;
  final bool rewatch;

  const ImportedDiaryEntry({
    required this.watchedOn,
    this.rating,
    this.rewatch = false,
  });
}

/// Everything the export files say about one title, merged across files
/// (e.g. Letterboxd `watched.csv` + `ratings.csv` + `diary.csv` rows for the
/// same film become one of these).
class ImportedTitle {
  final ImportSource source;

  /// De-dupe key across files and duplicate rows: `imdb:tt…` for IMDb,
  /// `lb:<normalized name>|<year>` for Letterboxd. (Letterboxd's URI column
  /// can't be used — in `diary.csv` it points at the diary entry, not the
  /// film, so it differs from the same film's URI in `watched.csv`.)
  final String key;
  final String title;
  final int? year;
  final String? imdbId;
  final ImportKind kind;

  bool watched = false;

  /// Latest Letterboxd diary "Watched Date" — the most precise date.
  DateTime? diaryWatchedOn;

  /// When it was logged as watched (Letterboxd `watched.csv` Date).
  DateTime? loggedOn;

  /// When it was rated (Letterboxd `ratings.csv` Date / IMDb Date Rated) —
  /// only a fallback for the watch date.
  DateTime? ratedOn;

  /// Already converted to WatchVerse's 0.5–5 half-star scale.
  double? rating;
  bool watchlist = false;
  final List<ImportedDiaryEntry> diary = [];

  ImportedTitle({
    required this.source,
    required this.key,
    required this.title,
    required this.year,
    this.imdbId,
    this.kind = ImportKind.movie,
  });

  /// Best available watch date: diary date, else logged date, else rated
  /// date, else null (the importer then uses "now").
  DateTime? get watchedOn => diaryWatchedOn ?? loggedOn ?? ratedOn;

  /// The later of [a] and [b] (either may be null).
  static DateTime? later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
  }
}

/// Output of [LibraryImportParser.parseFiles].
class ParsedImport {
  final List<ImportedTitle> titles;

  /// Rows that were recognised but can't be imported (TV episodes, video
  /// games, podcasts…) or had no usable title/id.
  final int skippedRows;

  /// Names of picked files that weren't a recognised Letterboxd/IMDb export.
  final List<String> unrecognizedFiles;

  const ParsedImport({
    required this.titles,
    this.skippedRows = 0,
    this.unrecognizedFiles = const [],
  });

  bool get isEmpty => titles.isEmpty;
}

/// A title that couldn't be matched to TMDB, shown in the summary's
/// "unmatched" list so the user can add it by hand.
class UnmatchedTitle {
  final String title;
  final int? year;
  final ImportSource source;

  /// True when the TMDB lookup itself failed (network/API error) rather than
  /// returning no confident match — re-running the import may fix these.
  final bool lookupFailed;

  const UnmatchedTitle({
    required this.title,
    required this.year,
    required this.source,
    this.lookupFailed = false,
  });
}

class ImportSummary {
  /// Movies newly marked watched.
  int moviesWatched = 0;

  /// Ratings written (movies + shows) — only where none existed yet.
  int ratings = 0;

  /// Movies newly added to the watchlist.
  int watchlist = 0;

  /// TV shows newly added to "My Shows" (no episodes marked watched).
  int shows = 0;

  /// Dated diary entries added (Letterboxd diary only).
  int diaryEntries = 0;

  /// Matched titles that needed no change — already in the library with
  /// equal-or-newer data (re-imports land here).
  int alreadyInLibrary = 0;

  /// See [ParsedImport.skippedRows].
  int skipped = 0;

  final List<UnmatchedTitle> unmatched = [];

  bool cancelled = false;
}
