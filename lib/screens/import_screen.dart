import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/import/import_models.dart';
import 'package:watch_verse/services/import/import_parser.dart';
import 'package:watch_verse/services/import/library_import_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// Import history from Letterboxd / IMDb — the counterpart to the free
/// export in Settings. Explains where to get each export, lets the user
/// pick the file(s), then shows live progress (with cancel) and a summary.
/// All the real work lives in `lib/services/import/`.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

enum _Phase { idle, reading, running, done }

class _ImportScreenState extends State<ImportScreen> {
  _Phase _phase = _Phase.idle;
  int _done = 0;
  int _total = 0;
  ImportCancelToken? _cancel;
  ImportSummary? _summary;
  List<String> _unrecognized = const [];
  String? _message;

  Future<void> _pickAndImport() async {
    final l10n = AppLocalizations.of(context)!;
    // `any` rather than a zip/csv filter: Android file managers often
    // report CSV downloads under MIME types the filter doesn't map to, and
    // unrecognised files are reported back anyway.
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _phase = _Phase.reading;
      _message = null;
    });
    try {
      final files = <ImportFile>[
        for (final f in picked) ImportFile(f.name, await f.readAsBytes()),
      ];
      // Off the UI isolate — a big Letterboxd zip is a few MB of CSV.
      final parsed = await compute(parseImportFiles, files);
      if (!mounted) return;
      _unrecognized = parsed.unrecognizedFiles;
      if (parsed.isEmpty) {
        setState(() {
          _phase = _Phase.idle;
          _message = l10n.importNothingFound;
        });
        return;
      }
      final cancel = ImportCancelToken();
      setState(() {
        _phase = _Phase.running;
        _cancel = cancel;
        _done = 0;
        _total = parsed.titles.length;
      });
      final summary = await LibraryImportService().run(
        parsed,
        cancel: cancel,
        onProgress: (done, total) {
          if (mounted) setState(() => _done = done);
        },
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _message = l10n.importError(e.toString());
      });
    }
  }

  @override
  void dispose() {
    // Leaving mid-import stops further lookups; what's matched is kept.
    _cancel?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final signedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: !signedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.importSignInPrompt,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.textSecondary)),
              ),
            )
          : switch (_phase) {
              _Phase.idle => _intro(l10n),
              _Phase.reading => _busy(l10n.importReading, null),
              _Phase.running => _running(l10n),
              _Phase.done => _summaryView(l10n, _summary!),
            },
    );
  }

  // ------------------------------------------------------------------ idle --

  Widget _intro(AppLocalizations l10n) {
    final muted = TextStyle(color: context.colors.textSecondary, height: 1.4);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.importIntro, style: muted),
        const SizedBox(height: 20),
        _stepCard(l10n.importLetterboxdHeading, l10n.importLetterboxdSteps),
        const SizedBox(height: 12),
        _stepCard(l10n.importImdbHeading, l10n.importImdbSteps),
        const SizedBox(height: 16),
        Text(l10n.importWhatHappens, style: muted),
        if (_message != null) ...[
          const SizedBox(height: 16),
          Text(_message!, style: const TextStyle(color: Colors.red)),
        ],
        if (_unrecognized.isNotEmpty && _message != null) ...[
          const SizedBox(height: 8),
          Text(l10n.importUnrecognizedFiles(_unrecognized.join(', ')),
              style: muted),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _pickAndImport,
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(l10n.importPickFiles,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        Text(l10n.importPickHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
      ],
    );
  }

  Widget _stepCard(String title, String body) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(body,
                style: TextStyle(
                    color: context.colors.textSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- progress --

  Widget _busy(String label, double? value) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
                value: value, color: context.colors.primary),
            const SizedBox(height: 16),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _running(AppLocalizations l10n) {
    final cancelling = _cancel?.isCancelled ?? false;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _busy(
          cancelling
              ? l10n.importCancelling
              : l10n.importProgress('$_done', '$_total'),
          _total == 0 ? null : _done / _total,
        ),
        TextButton(
          onPressed: cancelling
              ? null
              : () => setState(() => _cancel?.cancel()),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- summary --

  Widget _summaryView(AppLocalizations l10n, ImportSummary s) {
    final rows = <(String, int)>[
      (l10n.importSummaryWatched, s.moviesWatched),
      (l10n.importSummaryRatings, s.ratings),
      (l10n.importSummaryWatchlist, s.watchlist),
      (l10n.importSummaryShows, s.shows),
      (l10n.importSummaryDiary, s.diaryEntries),
      (l10n.importSummaryExisting, s.alreadyInLibrary),
      (l10n.importSummarySkipped, s.skipped),
      (l10n.importSummaryUnmatched, s.unmatched.length),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.importDoneTitle,
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        if (s.cancelled) ...[
          const SizedBox(height: 8),
          Text(l10n.importCancelledNote,
              style: TextStyle(color: context.colors.textSecondary)),
        ],
        const SizedBox(height: 16),
        Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              for (final (label, count) in rows)
                ListTile(
                  dense: true,
                  title: Text(label,
                      style: TextStyle(color: context.colors.textPrimary)),
                  trailing: Text('$count',
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        if (_unrecognized.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(l10n.importUnrecognizedFiles(_unrecognized.join(', ')),
              style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
        ],
        if (s.unmatched.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showUnmatched(l10n, s.unmatched),
            icon: const Icon(Icons.help_outline_rounded),
            label: Text(l10n.importViewUnmatched),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: context.colors.primary),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.importDone),
        ),
        TextButton(
          onPressed: () => setState(() {
            _phase = _Phase.idle;
            _summary = null;
            _unrecognized = const [];
          }),
          child: Text(l10n.importMore),
        ),
      ],
    );
  }

  void _showUnmatched(AppLocalizations l10n, List<UnmatchedTitle> items) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (ctx, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                  '${l10n.importSummaryUnmatched} (${items.length})',
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.importUnmatchedHint,
                  style: TextStyle(color: context.colors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Expanded(
              // Lazily built — a big import can have hundreds of misses.
              child: ListView.builder(
                controller: controller,
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final u = items[i];
                  final source =
                      u.source == ImportSource.imdb ? 'IMDb' : 'Letterboxd';
                  return ListTile(
                    dense: true,
                    title: Text(
                        u.year == null ? u.title : '${u.title} (${u.year})',
                        style: TextStyle(color: context.colors.textPrimary)),
                    subtitle: Text(
                        u.lookupFailed
                            ? '$source · ${l10n.importLookupFailed}'
                            : source,
                        style: TextStyle(color: context.colors.textMuted)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
