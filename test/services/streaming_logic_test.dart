import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/streaming/streaming_logic.dart';

const netflix = WatchProvider(id: 8, name: 'Netflix', logoPath: '/n.png');
const disney = WatchProvider(id: 337, name: 'Disney Plus', logoPath: '/d.png');
const max = WatchProvider(id: 1899, name: 'Max', logoPath: '/m.png');
const apple = WatchProvider(id: 2, name: 'Apple TV', logoPath: '/a.png');

Map<String, dynamic> p(
  int id,
  String name, {
  Map<String, int>? prios,
  int? prio,
}) => {
  'provider_id': id,
  'provider_name': name,
  'logo_path': '/$id.png',
  'display_priorities': ?prios,
  'display_priority': ?prio,
};

void main() {
  group('StreamingPrefs', () {
    test('parses the user doc defensively', () {
      final prefs = StreamingPrefs.fromUserDoc({
        'streamingRegion': 'de',
        'streamingProviderIds': [8, 337.0, 'x', -1, 0],
      });
      expect(prefs.region, 'DE');
      expect(prefs.providerIds, {8, 337});
      expect(prefs.isConfigured, isTrue);
    });

    test('missing/invalid fields mean "not set up"', () {
      expect(StreamingPrefs.fromUserDoc(null).isConfigured, isFalse);
      final prefs = StreamingPrefs.fromUserDoc({'streamingRegion': 'Germany'});
      expect(prefs.region, isNull);
      expect(prefs.providerIds, isEmpty);
    });

    test('round-trips through toUserDoc with sorted ids', () {
      const prefs = StreamingPrefs(region: 'TR', providerIds: {337, 8});
      final doc = prefs.toUserDoc();
      expect(doc, {
        'streamingRegion': 'TR',
        'streamingProviderIds': [8, 337],
      });
      expect(StreamingPrefs.fromUserDoc(doc).providerIds, {8, 337});
    });

    test('effectiveRegion prefers the saved region, then the device', () {
      expect(const StreamingPrefs(region: 'GB').effectiveRegion('DE'), 'GB');
      expect(StreamingPrefs.empty.effectiveRegion('de'), 'DE');
      expect(StreamingPrefs.empty.effectiveRegion(null), 'US');
    });
  });

  group('defaultStreamingRegion', () {
    test('uses the device country when supported', () {
      expect(defaultStreamingRegion('tr', ['US', 'TR']), 'TR');
    });
    test('falls back to US when unsupported or invalid', () {
      expect(defaultStreamingRegion('XX', ['US', 'TR']), 'US');
      expect(defaultStreamingRegion(null, ['US']), 'US');
      expect(defaultStreamingRegion('419', null), 'US');
    });
    test('trusts a well-formed code when the region list is unknown', () {
      expect(defaultStreamingRegion('br', null), 'BR');
    });
  });

  test('parseRegions de-duplicates and sorts by name', () {
    final regions = parseRegions([
      {'iso_3166_1': 'US', 'english_name': 'United States of America'},
      {'iso_3166_1': 'DE', 'english_name': 'Germany'},
      {'iso_3166_1': 'de', 'english_name': 'Dupe'},
      {'iso_3166_1': 'XYZ', 'english_name': 'Bad'},
      {'iso_3166_1': 'AT', 'english_name': ''},
      'garbage',
    ]);
    expect(regions.map((r) => r.code), ['AT', 'DE', 'US']);
    expect(regions.first.name, 'AT');
  });

  group('mergeProviderCatalogs', () {
    test('merges movie+tv, de-dupes, sorts by regional priority', () {
      final merged = mergeProviderCatalogs(
        [
          p(8, 'Netflix', prios: {'US': 3, 'DE': 1}),
          p(337, 'Disney Plus', prios: {'US': 1, 'DE': 5}),
        ],
        [
          p(8, 'Netflix', prios: {'US': 2, 'DE': 1}),
          p(1899, 'Max', prios: {'US': 2}),
        ],
        'US',
      );
      // Netflix: min(3, 2) = 2 ties with Max (2) → name order.
      expect(merged.map((e) => e.name), ['Disney Plus', 'Max', 'Netflix']);
    });

    test('falls back to display_priority, then sorts unknowns last', () {
      final merged = mergeProviderCatalogs(
        [
          p(1, 'Zed'),
          p(2, 'Beta', prio: 4),
          p(3, 'Alpha', prios: {'GB': 1}),
        ],
        [p(0, 'Invalid id')],
        'DE',
      );
      expect(merged.map((e) => e.name), ['Beta', 'Alpha', 'Zed']);
    });
  });

  group('parseStreamingAvailability', () {
    final results = {
      'US': {
        'flatrate': [p(8, 'Netflix')],
        'ads': [p(1899, 'Max')],
        'free': [p(8, 'Netflix')],
        'rent': [p(2, 'Apple TV')],
        'buy': [p(2, 'Apple TV')],
      },
    };

    test('only streaming buckets, de-duplicated, no rent/buy', () {
      expect(parseStreamingAvailability(results, 'US').map((e) => e.id), [
        8,
        1899,
      ]);
    });

    test('includeFree false keeps only flatrate', () {
      expect(
        parseStreamingAvailability(
          results,
          'US',
          includeFree: false,
        ).map((e) => e.id),
        [8],
      );
    });

    test('never falls back to another region', () {
      expect(parseStreamingAvailability(results, 'DE'), isEmpty);
    });
  });

  test('matchUserServices keeps availability order', () {
    expect(matchUserServices([max, netflix, apple], {8, 1899}), [max, netflix]);
    expect(matchUserServices([netflix], {}), isEmpty);
  });

  test('userServicesFirst is stable within groups', () {
    expect(userServicesFirst([apple, netflix, disney, max], {1899, 8}), [
      netflix,
      max,
      apple,
      disney,
    ]);
    expect(userServicesFirst([apple, netflix], {}), [apple, netflix]);
  });

  group('cache TTL', () {
    final now = DateTime(2026, 10, 14, 12);
    test('fresh within the TTL, stale at/after it', () {
      expect(
        isAvailabilityFresh(now.subtract(const Duration(hours: 23)), now),
        isTrue,
      );
      expect(isAvailabilityFresh(now.subtract(availabilityTtl), now), isFalse);
    });
    test('an entry from the future is stale', () {
      expect(
        isAvailabilityFresh(now.add(const Duration(minutes: 5)), now),
        isFalse,
      );
    });

    test('pruneAvailabilityCache drops stale entries and caps size', () {
      final entries = {
        'old': CachedAvailability(now.subtract(const Duration(days: 2)), []),
        'a': CachedAvailability(now.subtract(const Duration(hours: 1)), []),
        'b': CachedAvailability(now.subtract(const Duration(hours: 2)), []),
        'c': CachedAvailability(now.subtract(const Duration(hours: 3)), []),
      };
      expect(pruneAvailabilityCache(entries, now, maxEntries: 2).keys, [
        'a',
        'b',
      ]);
    });

    test('CachedAvailability JSON round-trip; malformed → null', () {
      final entry = CachedAvailability(now, const [netflix]);
      final back = CachedAvailability.fromJson(entry.toJson())!;
      expect(back.fetchedAt, now);
      expect(back.providers.single.name, 'Netflix');
      expect(CachedAvailability.fromJson({'t': 'x'}), isNull);
      expect(CachedAvailability.fromJson(null), isNull);
    });
  });

  test('joinProviderNames', () {
    expect(joinProviderNames([]), '');
    expect(joinProviderNames([netflix]), 'Netflix');
    expect(joinProviderNames([netflix, max]), 'Netflix and Max');
    expect(
      joinProviderNames([netflix, max, disney, apple]),
      'Netflix, Max and 2 more',
    );
  });

  test('TitleRef equality and keys', () {
    expect(
      const TitleRef(MediaType.movie, 1),
      const TitleRef(MediaType.movie, 1),
    );
    expect(
      const TitleRef(MediaType.movie, 1) == const TitleRef(MediaType.tv, 1),
      isFalse,
    );
    expect(const TitleRef(MediaType.tv, 5).keyFor('US'), 'tv-5-US');
  });
}
