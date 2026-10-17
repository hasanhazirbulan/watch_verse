import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:watch_verse/models/game_clue_movie.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/app_firebase.dart';

export 'package:watch_verse/services/daily_game_clues.dart'
    show dailyGameMaxGuesses, dailyGameHintUnlockGuesses;

/// How many past days (including today) the "Pick a day" menu offers.
const dailyGameRewatchDays = 7;

/// One player's progress on one day's puzzle (`users/{uid}/gamePlays/{dateKey}`).
class DailyGamePlay {
  final List<int> guessedIds;
  final bool won;
  final bool finished;
  final int hintsUsed;

  const DailyGamePlay({
    this.guessedIds = const [],
    this.won = false,
    this.finished = false,
    this.hintsUsed = 0,
  });

  static const empty = DailyGamePlay();

  /// Lenient parse — a missing doc is simply an unplayed day.
  factory DailyGamePlay.fromMap(Map<String, dynamic>? data) {
    if (data == null) return empty;
    return DailyGamePlay(
      guessedIds: [
        for (final e in (data['guessedIds'] as List?) ?? const [])
          if (e is num) e.toInt(),
      ],
      won: data['won'] == true,
      finished: data['finished'] == true,
      hintsUsed: ((data['hintsUsed'] ?? 0) as num).toInt(),
    );
  }
}

/// Picks WatchVerse's daily mystery movie and tracks the signed-in user's
/// progress on it.
///
/// **Deterministic, not server-scheduled** (see the project-wide "no Cloud
/// Functions / no Blaze" constraint): a curated pool of movie TMDB IDs lives
/// in a single world-readable Firestore doc (`gameConfig/dailyMoviePool`,
/// seeded once by `tool/seed_daily_game_pool.js`, never written by the
/// client). Every device computes the same day index independently —
/// `daysSinceReference % pool.length` — so the puzzle rotates at midnight EST
/// for everyone without a cron job or webhook.
///
/// Days are addressed by that absolute day index (see [todayIndex]), not by
/// "days ago": a screen left open across midnight keeps pointing at the
/// puzzle it loaded, instead of silently writing the old movie's guesses
/// into the new day's progress doc.
class DailyGameService {
  DailyGameService._(
      {FirebaseFirestore? firestore,
      FirebaseAuth? auth,
      APIservices? api,
      DateTime Function()? clock})
      : _db = firestore ?? AppFirebase.firestore,
        _auth = auth ?? AppFirebase.auth,
        _api = api ?? APIservices(),
        _clock = clock ?? DateTime.now;
  static final DailyGameService instance = DailyGameService._();

  /// Test-only factory: inject a fake Firestore/Auth (and optionally a stub
  /// TMDB client and a fixed clock) instead of touching real backends.
  @visibleForTesting
  factory DailyGameService.test({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    APIservices? api,
    DateTime Function()? clock,
  }) =>
      DailyGameService._(
          firestore: firestore, auth: auth, api: api, clock: clock);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final APIservices _api;
  final DateTime Function() _clock;

  String? get _uid => _auth.currentUser?.uid;

  // ---------------------------------------------------------- day index ---

  /// Arbitrary fixed anchor — only the *difference* in days matters, so any
  /// past date works. Kept as a UTC date (no time-of-day) shifted by the
  /// EST offset before differencing, so "today" flips at midnight EST rather
  /// than midnight UTC/local.
  static final _referenceDate = DateTime.utc(2024, 1, 1);

  DateTime _estCalendarDate(DateTime utcNow) {
    // Fixed UTC-5 (EST) offset — deliberately ignores DST (EDT is UTC-4).
    // The puzzle rotating an hour off during EDT is a cosmetic gap, not a
    // correctness one: everyone still sees the same movie as everyone else.
    final est = utcNow.subtract(const Duration(hours: 5));
    return DateTime.utc(est.year, est.month, est.day);
  }

  /// Absolute index of today's puzzle. Read it once and hold on to it.
  int get todayIndex =>
      _estCalendarDate(_clock().toUtc()).difference(_referenceDate).inDays;

  /// The calendar date (UTC midnight) of puzzle [day] — for display.
  DateTime dateForDay(int day) => _referenceDate.add(Duration(days: day));

  /// `yyyy-mm-dd` for puzzle [day] — the Firestore `gamePlays` doc id.
  String dateKeyForDay(int day) {
    final date = dateForDay(day);
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  // -------------------------------------------------------------- pool -----

  List<int>? _poolCache;

  /// The movie-ID pool from `gameConfig/dailyMoviePool.movieIds`.
  ///
  /// Read errors (permission, offline with nothing cached) propagate so the
  /// screen can offer a retry. A missing doc/field yields an empty pool
  /// (the screen's "puzzle isn't ready" state) and is *not* cached — it used
  /// to be, so a retry after seeding kept saying "not ready" until the app
  /// was restarted. Entries are parsed leniently: ints, whole doubles and
  /// numeric strings are accepted, anything else (null, a map, "abc",
  /// 0/negative) is skipped instead of one bad element throwing a TypeError
  /// for everyone. A `movieIds` that isn't a list at all is a seeding bug
  /// and throws a [FormatException] rather than looking "not ready".
  Future<List<int>> _pool() async {
    final cached = _poolCache;
    if (cached != null) return cached;
    final doc =
        await _db.collection('gameConfig').doc('dailyMoviePool').get();
    final raw = doc.data()?['movieIds'];
    if (raw == null) return const [];
    if (raw is! List) {
      throw FormatException(
          'gameConfig/dailyMoviePool.movieIds must be a list of TMDB ids, '
          'got ${raw.runtimeType}');
    }
    final ids = <int>[];
    for (final e in raw) {
      final id = switch (e) {
        int v => v,
        double v when v.isFinite && v == v.truncateToDouble() => v.toInt(),
        String v => int.tryParse(v.trim()),
        _ => null,
      };
      if (id != null && id > 0) ids.add(id);
    }
    if (ids.isNotEmpty) _poolCache = ids;
    return ids;
  }

  /// The mystery movie for puzzle [day], fully resolved with all 8 clue
  /// attributes. Null when the pool is empty (unseeded); throws when the
  /// pool can't be read or TMDB fails.
  Future<GameClueMovie?> mysteryMovieForDay(int day) async {
    final pool = await _pool();
    if (pool.isEmpty) return null;
    return clueData(pool[day % pool.length]);
  }

  // -------------------------------------------------------- clue cache -----

  final Map<int, Future<GameClueMovie>> _clueCache = {};

  /// [APIservices.getGameClueData], memoized for the app session: every
  /// guess row (and the mystery) is a TMDB call, and reopening the game or
  /// switching days used to refetch all of them. Concurrent callers share
  /// one in-flight request; a failure is evicted so a retry refetches.
  Future<GameClueMovie> clueData(int movieId) {
    return _clueCache.putIfAbsent(movieId, () {
      final future = _api.getGameClueData(movieId);
      future.then((_) {}, onError: (Object _) {
        _clueCache.remove(movieId);
      });
      return future;
    });
  }

  // ---------------------------------------------------------- progress -----

  CollectionReference<Map<String, dynamic>>? get _playsCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('gamePlays');
  }

  /// Live progress for puzzle [day]; [DailyGamePlay.empty] when signed out
  /// or not played yet.
  Stream<DailyGamePlay> progressStream(int day) {
    final col = _playsCol;
    if (col == null) return Stream.value(DailyGamePlay.empty);
    return col
        .doc(dateKeyForDay(day))
        .snapshots()
        .map((d) => DailyGamePlay.fromMap(d.data()));
  }

  /// Appends [guessedMovieId] to puzzle [day]'s guess list and records the
  /// outcome. `finished` is true once the player has won or used all
  /// guesses — the game screen decides which.
  Future<void> recordGuess({
    required int day,
    required int guessedMovieId,
    required bool won,
    required bool finished,
  }) async {
    final col = _playsCol;
    if (col == null) return;
    await col.doc(dateKeyForDay(day)).set({
      'guessedIds': FieldValue.arrayUnion([guessedMovieId]),
      'won': won,
      'finished': finished,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> useHint(int day, int hintsUsed) async {
    await _playsCol
        ?.doc(dateKeyForDay(day))
        .set({'hintsUsed': hintsUsed}, SetOptions(merge: true));
  }
}
