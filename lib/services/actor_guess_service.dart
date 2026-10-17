import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:watch_verse/services/actor_guess_logic.dart';
import 'package:watch_verse/services/api_service.dart' show apiKey;
import 'package:watch_verse/services/app_firebase.dart';

/// A person result from the guess search.
class ActorGuessCandidate {
  final int id;
  final String name;
  final String profilePath;
  final List<String> knownFor;
  const ActorGuessCandidate({
    required this.id,
    required this.name,
    required this.profilePath,
    required this.knownFor,
  });
}

/// Turns a TMDB `/search/person` response into guess candidates: actors only
/// (no adult profiles), most popular first, so typing "chris" puts Chris
/// Hemsworth above an extra with the same first name.
@visibleForTesting
List<ActorGuessCandidate> parseActorGuessSearch(Map<String, dynamic> data) {
  final results = (data['results'] as List?) ?? const [];
  final people = <(double, ActorGuessCandidate)>[];
  for (final r in results) {
    if (r is! Map) continue;
    if (r['adult'] == true || r['known_for_department'] != 'Acting') continue;
    final id = r['id'];
    final name = r['name'];
    if (id is! int || name is! String || name.isEmpty) continue;
    final knownFor = <String>[
      for (final k in (r['known_for'] as List?) ?? const [])
        if (k is Map && (k['title'] ?? k['name']) is String)
          (k['title'] ?? k['name']) as String,
    ];
    people.add((
      (r['popularity'] as num?)?.toDouble() ?? 0,
      ActorGuessCandidate(
        id: id,
        name: name,
        profilePath: r['profile_path'] is String ? r['profile_path'] : '',
        knownFor: knownFor,
      ),
    ));
  }
  people.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final p in people) p.$2];
}

/// Backs the "Who's the Actor?" daily game: the bundled puzzle pool, the
/// player's per-day progress (`users/{uid}/gamePlays/actor-{yyyy-mm-dd}`,
/// covered by the existing owner-only `gamePlays` rule) and the TMDB person
/// search used to guess. Nothing here keeps streaks or other habit stats.
class ActorGuessService {
  ActorGuessService._({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    List<ActorGuessPuzzle>? pool,
  }) : _dbOverride = firestore,
       _authOverride = auth,
       _pool = pool;
  static final ActorGuessService instance = ActorGuessService._();

  @visibleForTesting
  factory ActorGuessService.test({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    List<ActorGuessPuzzle>? pool,
  }) => ActorGuessService._(firestore: firestore, auth: auth, pool: pool);

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _db => _dbOverride ?? AppFirebase.firestore;
  FirebaseAuth get _auth => _authOverride ?? AppFirebase.auth;

  static const poolAsset = 'assets/games/actor_guess_pool.json';

  List<ActorGuessPuzzle>? _pool;

  Future<List<ActorGuessPuzzle>> _loadPool() async {
    final cached = _pool;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(poolAsset);
    final pool = parseActorGuessPool(json.decode(raw));
    if (pool.isNotEmpty) _pool = pool;
    return pool;
  }

  /// Today's puzzle (EST calendar day of [utcNow]); null for an empty pool.
  Future<ActorGuessPuzzle?> puzzleFor(DateTime utcNow) async =>
      actorGuessPuzzleForDay(await _loadPool(), actorGuessDayIndex(utcNow));

  // ----------------------------------------------------------- progress ---

  DocumentReference<Map<String, dynamic>>? _playDoc(DateTime utcNow) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('gamePlays')
        .doc(actorGuessPlayDocId(utcNow));
  }

  Stream<ActorGuessProgress> progressStream(DateTime utcNow) {
    final doc = _playDoc(utcNow);
    if (doc == null) return Stream.value(const ActorGuessProgress());
    return doc.snapshots().map((s) => ActorGuessProgress.fromMap(s.data()));
  }

  /// Appends [guess] to the day's guesses. The caller decides win/finish
  /// (see [isActorGuessCorrect] / [actorGuessMaxAttempts]).
  Future<void> recordGuess({
    required DateTime utcNow,
    required ActorGuessEntry guess,
    required bool won,
    required bool finished,
  }) async {
    final doc = _playDoc(utcNow);
    if (doc == null) return;
    await doc.set({
      'game': 'actor',
      'guesses': FieldValue.arrayUnion([guess.toMap()]),
      'won': won,
      'finished': finished,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ------------------------------------------------------------- search ---

  static const _timeout = Duration(seconds: 15);

  /// TMDB `/search/person`, filtered/sorted by [parseActorGuessSearch].
  Future<List<ActorGuessCandidate>> searchActors(String query) async {
    if (apiKey.isEmpty) {
      throw StateError(
        'TMDB_API_KEY is not set. Run with '
        '--dart-define-from-file=secrets.json (see secrets.example.json).',
      );
    }
    final uri = Uri.parse('https://api.themoviedb.org/3/search/person').replace(
      queryParameters: {
        'api_key': apiKey,
        'language': 'en-US',
        'query': query,
        'include_adult': 'false',
      },
    );
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('TMDB person search failed (${res.statusCode})');
    }
    return parseActorGuessSearch(json.decode(res.body) as Map<String, dynamic>);
  }
}
