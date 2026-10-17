import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart' show apiKey;
import 'package:watch_verse/services/games/plot_guess_logic.dart';
import 'package:watch_verse/services/app_firebase.dart';

/// Daily "Plot" game: picks today's puzzle from the shipped pool
/// (`assets/games/plot_pool_{movie,tv}.json`, redacted ahead of time by
/// `tool/generate_plot_higher_lower_pools.dart`) and stores the signed-in player's
/// attempts in `users/{uid}/gamePlays/plot-{mode}-{yyyy-mm-dd}` — the same
/// owner-only collection the daily movie game uses, so no rule changes.
///
/// Like the daily movie game the rotation is deterministic (EST day index
/// modulo pool size), so there's no backend job.
class PlotGuessService {
  PlotGuessService._(
      {FirebaseFirestore? firestore,
      FirebaseAuth? auth,
      AssetBundle? bundle,
      http.Client? client})
      : _dbOverride = firestore,
        _authOverride = auth,
        _bundle = bundle ?? rootBundle,
        _client = client;
  static final PlotGuessService instance = PlotGuessService._();

  @visibleForTesting
  factory PlotGuessService.test({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    AssetBundle? bundle,
    http.Client? client,
  }) =>
      PlotGuessService._(
          firestore: firestore, auth: auth, bundle: bundle, client: client);

  // Resolved lazily so merely constructing the singleton never touches
  // Firebase (keeps widget tests that only render the screen simple).
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _db => _dbOverride ?? AppFirebase.firestore;
  FirebaseAuth get _auth => _authOverride ?? AppFirebase.auth;
  final AssetBundle _bundle;
  final http.Client? _client;

  static String poolAsset(PlotGameMode mode) =>
      'assets/games/plot_pool_${mode.key}.json';

  final Map<PlotGameMode, List<PlotPuzzle>> _pools = {};

  Future<List<PlotPuzzle>> pool(PlotGameMode mode) async {
    final cached = _pools[mode];
    if (cached != null) return cached;
    final raw = await _bundle.loadString(poolAsset(mode));
    final items = ((jsonDecode(raw) as Map<String, dynamic>)['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map(PlotPuzzle.fromJson)
        .where((p) => p.id > 0 && p.redactedOverview.isNotEmpty)
        .toList();
    if (items.isNotEmpty) _pools[mode] = items;
    return items;
  }

  /// Today's puzzle for [mode], or null when the pool is empty.
  Future<PlotPuzzle?> puzzleFor(PlotGameMode mode, DateTime now) async {
    final items = await pool(mode);
    if (items.isEmpty) return null;
    return items[plotGamePuzzleIndex(plotGameDayIndex(now), items.length)];
  }

  // ----------------------------------------------------------- progress ---

  /// Guests have no `gamePlays` to write to — the screen shows a sign-in
  /// prompt instead (same as the daily movie game).
  bool get isSignedIn => _auth.currentUser != null;

  DocumentReference<Map<String, dynamic>>? _doc(
      PlotGameMode mode, DateTime now) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('gamePlays')
        .doc(plotGameDocId(mode, now));
  }

  /// Attempts already made on the [mode] puzzle for [now]'s day.
  Stream<List<PlotAttempt>> attemptsStream(PlotGameMode mode, DateTime now) {
    final doc = _doc(mode, now);
    if (doc == null) return Stream.value(const []);
    return doc.snapshots().map((s) => [
          for (final a in (s.data()?['attempts'] as List?) ?? const [])
            PlotAttempt.fromJson(a),
        ]);
  }

  /// Persists the full attempt list (an array, not `arrayUnion`: two skips
  /// are identical maps and would collapse into one).
  Future<void> saveAttempts({
    required PlotGameMode mode,
    required DateTime now,
    required List<PlotAttempt> attempts,
    required PlotGameProgress progress,
  }) async {
    final doc = _doc(mode, now);
    if (doc == null) return;
    await doc.set({
      'game': 'plot',
      'mode': mode.key,
      'attempts': [for (final a in attempts) a.toJson()],
      'won': progress.won,
      'finished': progress.finished,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ------------------------------------------------------------- search ---

  /// Title search for guesses — movies in movie mode, shows in TV mode —
  /// most popular first so the famous title tops same-name matches.
  Future<List<MediaItem>> search(PlotGameMode mode, String query) async {
    if (query.trim().isEmpty) return const [];
    if (apiKey.isEmpty) {
      throw StateError('TMDB_API_KEY is not set (see secrets.example.json).');
    }
    final uri = Uri.https(
        'api.themoviedb.org', '/3/search/${mode == PlotGameMode.tv ? 'tv' : 'movie'}', {
      'api_key': apiKey,
      'language': 'en-US',
      'query': query,
      'include_adult': 'false',
    });
    final client = _client;
    final res = await (client != null ? client.get(uri) : http.get(uri))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('TMDB search failed (${res.statusCode})');
    }
    final results = ((jsonDecode(res.body) as Map<String, dynamic>)['results']
                as List? ??
            const [])
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => ((b['popularity'] as num?) ?? 0)
          .compareTo((a['popularity'] as num?) ?? 0));
    return results
        .map(mode == PlotGameMode.tv
            ? MediaItem.fromTvMap
            : MediaItem.fromMovieMap)
        .where((m) => m.id != 0)
        .toList();
  }
}
