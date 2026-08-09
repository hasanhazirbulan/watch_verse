import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watch_verse/services/movie_service.dart';

/// WatchVerse Pro data export: every watched movie + diary entry as a CSV,
/// shared via the system share sheet. Built in-memory (`XFile.fromData`) so
/// no temp-file plumbing or `path_provider` dependency is needed — one-shot,
/// not something worth the extra moving part.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  Future<void> exportDiaryCsv() async {
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

    final csv = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final file = XFile.fromData(
      bytes,
      name: 'watchverse_diary.csv',
      mimeType: 'text/csv',
    );
    await Share.shareXFiles([file]);
  }

  String _formatDate(Object? value) {
    if (value is! Timestamp) return '';
    final d = value.toDate();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
