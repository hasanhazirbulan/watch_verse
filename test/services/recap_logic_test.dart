import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/recap_logic.dart';

Episode ep(int s, int e) => Episode(
      id: s * 100 + e,
      episodeNumber: e,
      seasonNumber: s,
      name: 'S${s}E$e',
      overview: '',
      stillPath: '',
      airDate: '2020-01-01',
      voteAverage: 0,
      runtime: 45,
    );

void main() {
  final now = DateTime(2026, 10, 15, 12);

  group('recapQualifies', () {
    test('never watched does not qualify', () {
      expect(recapQualifies(null, now), isFalse);
    });

    test('watched within 30 days does not qualify', () {
      expect(recapQualifies(now.subtract(const Duration(days: 29)), now),
          isFalse);
      expect(recapQualifies(now, now), isFalse);
    });

    test('exactly 30 days and older qualifies', () {
      expect(
          recapQualifies(now.subtract(const Duration(days: 30)), now), isTrue);
      expect(
          recapQualifies(now.subtract(const Duration(days: 400)), now), isTrue);
    });
  });

  group('recapEpisodes', () {
    final flat = [ep(1, 1), ep(1, 2), ep(1, 3), ep(2, 1), ep(2, 2), ep(2, 3)];

    test('nothing watched -> empty', () {
      expect(recapEpisodes(flat, const {}), isEmpty);
    });

    test('only ever returns watched episodes', () {
      final r = recapEpisodes(flat, {'s1e2': DateTime(2026, 1, 1)});
      expect(r.map((e) => e.episode.key), ['s1e2']);
      expect(r.single.watchedAt, DateTime(2026, 1, 1));
    });

    test('picks the most recently watched, returned in airing order', () {
      final r = recapEpisodes(flat, {
        's1e1': DateTime(2026, 1, 1),
        's1e2': DateTime(2026, 1, 2),
        's2e1': DateTime(2026, 3, 1), // watched later, out of order
        's1e3': DateTime(2026, 2, 1),
      });
      expect(r.map((e) => e.episode.key), ['s1e3', 's2e1']);
    });

    test('ties (season marked at once) favour the later episodes', () {
      final t = DateTime(2026, 5, 5);
      final r = recapEpisodes(flat, {'s1e1': t, 's1e2': t, 's1e3': t});
      expect(r.map((e) => e.episode.key), ['s1e2', 's1e3']);
    });

    test('unknown timestamp counts as newest', () {
      final r = recapEpisodes(flat, {
        's1e1': DateTime(2026, 1, 1),
        's1e2': DateTime(2026, 1, 2),
        's2e2': null,
      }, limit: 1);
      expect(r.single.episode.key, 's2e2');
    });

    test('watched keys missing from the episode list are ignored', () {
      final r = recapEpisodes(flat, {'s9e9': DateTime(2026, 9, 9)});
      expect(r, isEmpty);
    });

    test('respects limit and never leaks an unwatched neighbour', () {
      final r = recapEpisodes(flat, {'s2e1': DateTime(2026, 1, 1)}, limit: 2);
      expect(r.map((e) => e.episode.key), ['s2e1']);
      expect(recapEpisodes(flat, {'s2e1': null}, limit: 0), isEmpty);
    });
  });
}
