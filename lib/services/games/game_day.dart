import 'package:watch_verse/models/media.dart';

/// Shared "which puzzle is today" math for the bundled-pool daily games
/// (Frames, Title Wordle).
///
/// Same rules as `DailyGameService`: no server job, every device computes the
/// same day independently, and the day flips at midnight EST (fixed UTC-5,
/// DST deliberately ignored — everyone still sees the same puzzle as
/// everyone else).

/// The date puzzle #1 went live. Puzzle numbers in share texts count from
/// here, and pool entry `n - 1` is puzzle `n` (wrapping around the pool).
final gamesLaunchDate = DateTime.utc(2026, 10, 15);

/// The EST calendar date (as a UTC midnight) for [utcNow].
DateTime gameEstDate(DateTime utcNow) {
  final est = utcNow.toUtc().subtract(const Duration(hours: 5));
  return DateTime.utc(est.year, est.month, est.day);
}

/// 1-based puzzle number for [utcNow]. Days before launch clamp to #1 so a
/// build that ships early (or a wrong device clock) still gets a puzzle.
int gamePuzzleNumber(DateTime utcNow) {
  final days = gameEstDate(utcNow).difference(gamesLaunchDate).inDays;
  return days < 0 ? 1 : days + 1;
}

/// Today's entry from [pool] for puzzle [puzzleNumber] (wraps around).
T dailyPoolEntry<T>(List<T> pool, int puzzleNumber) {
  if (pool.isEmpty) throw StateError('Daily game pool is empty');
  return pool[(puzzleNumber - 1) % pool.length];
}

/// `yyyy-mm-dd` of the EST date for [utcNow].
String gameDateKey(DateTime utcNow) {
  final d = gameEstDate(utcNow);
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// Firestore doc id under `users/{uid}/gamePlays` — e.g.
/// `frames-movie-2026-10-15`. Shares the collection (and its owner-only
/// rule) with the original daily movie game, whose ids are bare dates.
String gamePlayDocId(String game, MediaType mode, String dateKey) =>
    '$game-${mode.apiPath}-$dateKey';
