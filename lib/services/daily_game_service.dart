import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:watch_verse/models/game_clue_movie.dart';
import 'package:watch_verse/services/api_service.dart';

/// Max guesses per puzzle, and the guess counts at which an extra hint
/// unlocks — matches spotle.movie's rules (10 guesses, hints after the 5th
/// and 8th).
const dailyGameMaxGuesses = 10;
const dailyGameHintUnlockGuesses = [5, 8];

/// How many past days (including today) the "Rewatch" menu offers.
const dailyGameRewatchDays = 7;

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
class DailyGameService {
  DailyGameService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  static final DailyGameService instance = DailyGameService._();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final APIservices _api = APIservices();

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

  int _dayIndex(DateTime utcNow) =>
      _estCalendarDate(utcNow).difference(_referenceDate).inDays;

  int get _todayIndex => _dayIndex(DateTime.now().toUtc());

  /// `yyyy-mm-dd` for [daysAgo] (0 = today) — used both as the Firestore
  /// `gamePlays` doc id and as the "Rewatch" menu's display date.
  String dateKeyForDaysAgo(int daysAgo) {
    final date = _referenceDate.add(Duration(days: _todayIndex - daysAgo));
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  // -------------------------------------------------------------- pool -----

  List<int>? _poolCache;

  Future<List<int>> _pool() async {
    if (_poolCache != null) return _poolCache!;
    final doc =
        await _db.collection('gameConfig').doc('dailyMoviePool').get();
    final ids = (doc.data()?['movieIds'] as List<dynamic>? ?? [])
        .map((e) => (e as num).toInt())
        .toList();
    _poolCache = ids;
    return ids;
  }

  /// The mystery movie for [daysAgo] (0 = today, 1 = yesterday, ...), fully
  /// resolved with all 8 clue attributes.
  Future<GameClueMovie?> mysteryMovieForDaysAgo(int daysAgo) async {
    final pool = await _pool();
    if (pool.isEmpty) return null;
    final index = (_todayIndex - daysAgo) % pool.length;
    return _api.getGameClueData(pool[index]);
  }

  // ---------------------------------------------------------- progress -----

  CollectionReference<Map<String, dynamic>>? get _playsCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('gamePlays');
  }

  Stream<Map<String, dynamic>?> progressStream(int daysAgo) {
    final col = _playsCol;
    if (col == null) return Stream.value(null);
    return col
        .doc(dateKeyForDaysAgo(daysAgo))
        .snapshots()
        .map((d) => d.data());
  }

  /// Appends [guessedMovieId] to today's (or a rewatch day's) guess list and
  /// records the outcome. `finished` is true once the player has won or used
  /// all [dailyGameMaxGuesses] guesses — the game screen decides which.
  Future<void> recordGuess({
    required int daysAgo,
    required int guessedMovieId,
    required bool won,
    required bool finished,
  }) async {
    final col = _playsCol;
    if (col == null) return;
    final ref = col.doc(dateKeyForDaysAgo(daysAgo));
    await ref.set({
      'guessedIds': FieldValue.arrayUnion([guessedMovieId]),
      'won': won,
      'finished': finished,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (daysAgo == 0 && finished) {
      await _updateStreak(won: won);
    }
  }

  Future<void> useHint(int daysAgo, int hintsUsed) async {
    await _playsCol
        ?.doc(dateKeyForDaysAgo(daysAgo))
        .set({'hintsUsed': hintsUsed}, SetOptions(merge: true));
  }

  // ------------------------------------------------------------ streak -----

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  Future<void> _updateStreak({required bool won}) async {
    final ref = _userDoc;
    if (ref == null) return;
    final today = dateKeyForDaysAgo(0);
    final yesterday = dateKeyForDaysAgo(1);
    final snap = await ref.get();
    final data = snap.data() ?? const <String, dynamic>{};
    final lastWinDateKey = data['gameLastWinDateKey'] as String?;
    final priorStreak = ((data['gameCurrentStreak'] ?? 0) as num).toInt();
    final bestStreak = ((data['gameBestStreak'] ?? 0) as num).toInt();

    final newStreak =
        won ? (lastWinDateKey == yesterday ? priorStreak + 1 : 1) : 0;

    await ref.set({
      'gameCurrentStreak': newStreak,
      'gameBestStreak': newStreak > bestStreak ? newStreak : bestStreak,
      if (won) 'gameLastWinDateKey': today,
    }, SetOptions(merge: true));
  }

  /// Live `(current, best)` streak, for the game screen's header.
  Stream<(int, int)> streakStream() {
    final ref = _userDoc;
    if (ref == null) return Stream.value((0, 0));
    return ref.snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      return (
        ((data['gameCurrentStreak'] ?? 0) as num).toInt(),
        ((data['gameBestStreak'] ?? 0) as num).toInt(),
      );
    });
  }
}
