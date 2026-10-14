import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';

import '../streaming_fakes.dart';

List<TitleRef> movies(int n) => [
  for (var i = 1; i <= n; i++) TitleRef(MediaType.movie, i),
];

Future<void> drain(AvailabilityChecker c) async {
  for (var i = 0; i < 200 && (c.isRunning || c.checked < c.total); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'checks with at most 4 requests in flight and reports progress',
    () async {
      final source = FakeStreamingSource(
        delay: const Duration(milliseconds: 5),
        availabilityById: {
          3: const [netflix],
        },
      );
      final checker = AvailabilityChecker(
        source: source,
        cache: AvailabilityCache(),
      );
      final progress = <int>[];
      checker.addListener(() => progress.add(checker.checked));

      await checker.check(movies(20), 'US');
      expect(checker.total, 20);
      await drain(checker);

      expect(source.requests, hasLength(20));
      expect(source.maxInFlight, 4);
      expect(checker.checked, 20);
      expect(progress.last, 20);
      expect(checker.availabilityFor(const TitleRef(MediaType.movie, 3)), [
        netflix,
      ]);
      expect(
        checker.availabilityFor(const TitleRef(MediaType.movie, 4)),
        isEmpty,
      );
      checker.dispose();
    },
  );

  test('cached titles cost no requests, also for a new checker', () async {
    final cache = AvailabilityCache();
    final source = FakeStreamingSource();
    final first = AvailabilityChecker(source: source, cache: cache);
    await first.check(movies(5), 'US');
    await drain(first);
    first.dispose();
    expect(source.requests, hasLength(5));

    final second = AvailabilityChecker(source: source, cache: cache);
    await second.check(movies(6), 'US');
    await drain(second);
    expect(source.requests, hasLength(6)); // only the new title
    second.dispose();
  });

  test('fetch: false only uses the cache', () async {
    final source = FakeStreamingSource();
    final checker = AvailabilityChecker(
      source: source,
      cache: AvailabilityCache(),
    );
    await checker.check(movies(3), 'US', fetch: false);
    expect(source.requests, isEmpty);
    expect(checker.isRunning, isFalse);
    checker.dispose();
  });

  test('failures are counted, not cached, and can be retried', () async {
    final source = FakeStreamingSource(failingIds: {2, 4});
    final checker = AvailabilityChecker(
      source: source,
      cache: AvailabilityCache(),
    );
    await checker.check(movies(4), 'US');
    await drain(checker);
    expect(checker.failedCount, 2);
    expect(checker.checked, 4);
    expect(checker.hasFailed(const TitleRef(MediaType.movie, 2)), isTrue);

    source.failingIds = {};
    checker.retryFailed();
    await drain(checker);
    expect(checker.failedCount, 0);
    expect(source.requests, hasLength(6));
    checker.dispose();
  });

  test('switching region re-checks', () async {
    final source = FakeStreamingSource();
    final checker = AvailabilityChecker(
      source: source,
      cache: AvailabilityCache(),
    );
    await checker.check(movies(2), 'US');
    await drain(checker);
    await checker.check(movies(2), 'DE');
    await drain(checker);
    expect(source.requests, hasLength(4));
    checker.dispose();
  });

  group('AvailabilityCache disk', () {
    test('persists across instances within the TTL', () async {
      var now = DateTime(2026, 10, 14, 9);
      final a = AvailabilityCache(clock: () => now);
      await a.ensureLoaded();
      a.put('movie-1-US', const [netflix]);
      await a.flush();

      now = now.add(const Duration(hours: 23));
      final b = AvailabilityCache(clock: () => now);
      await b.ensureLoaded();
      expect(b.peek('movie-1-US'), [isA<WatchProvider>()]);

      now = now.add(const Duration(hours: 2));
      final c = AvailabilityCache(clock: () => now);
      await c.ensureLoaded();
      expect(c.peek('movie-1-US'), isNull);
    });

    test('a corrupt cache is ignored', () async {
      SharedPreferences.setMockInitialValues({
        AvailabilityCache.prefsKey: '{not json',
      });
      final cache = AvailabilityCache();
      await cache.ensureLoaded();
      expect(cache.peek('movie-1-US'), isNull);
    });

    test('stores compact JSON keyed by type-id-region', () async {
      final cache = AvailabilityCache();
      await cache.ensureLoaded();
      cache.put('tv-9-TR', const [netflix]);
      await cache.flush();
      final prefs = await SharedPreferences.getInstance();
      final json =
          jsonDecode(prefs.getString(AvailabilityCache.prefsKey)!)
              as Map<String, dynamic>;
      expect(json.keys, ['tv-9-TR']);
    });
  });
}
