import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watch_verse/services/list_service.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';

/// Full-library data export: every movie, show, diary entry, and list as
/// CSV, shared via the system share sheet in one action.
///
/// Free for everyone, not a Pro perk — a WatchVerse library should always be
/// yours to take elsewhere, no subscription required. This category has
/// twice in 2026 validated the fear this answers (TV Time deleting
/// histories on shutdown, Trakt reneging on its pricing promises to the
/// users who trusted it most), so it's treated as a trust feature rather
/// than a retention lever.
///
/// Built in-memory (`XFile.fromData`) so no temp-file plumbing or
/// `path_provider` dependency is needed.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  Future<void> exportAll() async {
    final files = await Future.wait([
      _moviesFile(),
      _showsFile(),
      _diaryFile(),
      _listsFile(),
    ]);
    await Share.shareXFiles(files);
  }

  Future<XFile> _moviesFile() async {
    final movies = await MovieService.instance.allMoviesOnce();
    final rows = <List<dynamic>>[
      ['Title', 'Status', 'Favorite', 'Rating', 'Release Date'],
      for (final m in movies)
        [
          m['title'] ?? '',
          m['status'] ?? '',
          (m['favorite'] == true) ? 'yes' : 'no',
          m['rating'] ?? '',
          m['releaseDate'] ?? '',
        ],
    ];
    return _csvFile(rows, 'watchverse_movies.csv');
  }

  Future<XFile> _showsFile() async {
    final shows = await TvTrackingService.instance.allShowsOnce();
    final rows = <List<dynamic>>[
      ['Name', 'Status', 'Episodes Watched', 'Total Episodes', 'Rating'],
      for (final s in shows)
        [
          s['name'] ?? '',
          s['status'] ?? '',
          s['watchedCount'] ?? 0,
          s['totalEpisodes'] ?? '',
          s['rating'] ?? '',
        ],
    ];
    return _csvFile(rows, 'watchverse_shows.csv');
  }

  Future<XFile> _diaryFile() async {
    final entries = await MovieService.instance.allDiaryEntriesOnce();
    final rows = <List<dynamic>>[
      ['Title', 'Watched On', 'Rating', 'Note'],
      for (final e in entries)
        [
          e['title'] ?? '',
          _formatDate(e['watchedOn']),
          e['rating'] ?? '',
          e['note'] ?? '',
        ],
    ];
    return _csvFile(rows, 'watchverse_diary.csv');
  }

  Future<XFile> _listsFile() async {
    final lists = await ListService.instance.listsStream().first;
    final rows = <List<dynamic>>[
      ['Name', 'Item Count', 'Public'],
      for (final l in lists)
        [
          l['name'] ?? '',
          ListService.countOf(l),
          (l['public'] == true) ? 'yes' : 'no',
        ],
    ];
    return _csvFile(rows, 'watchverse_lists.csv');
  }

  Future<XFile> _csvFile(List<List<dynamic>> rows, String name) async {
    final csv = Csv().encode(rows);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    return XFile.fromData(bytes, name: name, mimeType: 'text/csv');
  }

  String _formatDate(Object? value) {
    if (value is! Timestamp) return '';
    final d = value.toDate();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
