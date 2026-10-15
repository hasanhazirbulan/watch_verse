import 'package:watch_verse/models/media.dart';

/// Pure rules behind the "Where you left off" recap in Up Next (no Flutter,
/// no Firebase — unit-tested in `test/services/recap_logic_test.dart`).
///
/// Spoiler-safe by construction: everything here only ever selects from
/// episodes that are present in the user's watched set.

/// How long a show must go untouched before Up Next offers a recap.
const recapStaleAfter = Duration(days: 30);

/// How many watched episodes the recap sheet shows.
const recapEpisodeLimit = 2;

/// Whether a show last watched at [lastWatchedAt] gets a "Recap" chip.
/// Never-watched shows (null) don't: there's nothing to recap.
bool recapQualifies(DateTime? lastWatchedAt, DateTime now) =>
    lastWatchedAt != null && now.difference(lastWatchedAt) >= recapStaleAfter;

/// One watched episode in the recap, with when it was marked watched (null
/// when the timestamp is unknown).
class RecapEpisode {
  final Episode episode;
  final DateTime? watchedAt;
  const RecapEpisode(this.episode, this.watchedAt);
}

/// The last [limit] episodes the user marked watched, from [flat] (the
/// show's episodes in airing order) and [watchedAt] (watched episode key →
/// when it was marked; the map's keys *are* the watched set).
///
/// "Last" means most recently marked watched; episodes marked in the same
/// instant (a whole season at once) tie-break on airing order, so the later
/// episode wins. A null timestamp (a write whose server time hasn't resolved
/// yet) counts as the newest. The result is returned in airing order so the
/// sheet reads like a "previously on".
///
/// Only episodes whose key is in [watchedAt] can ever be returned.
List<RecapEpisode> recapEpisodes(
  List<Episode> flat,
  Map<String, DateTime?> watchedAt, {
  int limit = recapEpisodeLimit,
}) {
  if (limit <= 0) return const [];
  final order = <String, int>{};
  final candidates = <Episode>[];
  for (final e in flat) {
    if (!watchedAt.containsKey(e.key) || order.containsKey(e.key)) continue;
    order[e.key] = order.length;
    candidates.add(e);
  }
  int byRecency(Episode a, Episode b) {
    final ta = watchedAt[a.key];
    final tb = watchedAt[b.key];
    if (ta != tb) {
      if (ta == null) return -1;
      if (tb == null) return 1;
      final c = tb.compareTo(ta);
      if (c != 0) return c;
    }
    return order[b.key]!.compareTo(order[a.key]!);
  }

  candidates.sort(byRecency);
  final picked = candidates.take(limit).toList()
    ..sort((a, b) => order[a.key]!.compareTo(order[b.key]!));
  return [for (final e in picked) RecapEpisode(e, watchedAt[e.key])];
}
