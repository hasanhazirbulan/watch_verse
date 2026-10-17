import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/streaming/streaming_logic.dart';
import 'package:watch_verse/services/app_firebase.dart';

export 'package:watch_verse/services/streaming/streaming_logic.dart';

/// Where the user's streaming choice is stored.
abstract class StreamingPrefsStore {
  /// False for guests — the feature is hidden for them (their watchlist is
  /// empty anyway, it lives in Firestore).
  bool get canSave;
  Stream<StreamingPrefs> watch();
  Future<void> save(StreamingPrefs prefs);
}

/// `users/{uid}.streamingRegion` / `.streamingProviderIds` (owner-writable
/// under the existing rules).
class FirestoreStreamingPrefsStore implements StreamingPrefsStore {
  FirestoreStreamingPrefsStore({FirebaseFirestore? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _db => _dbOverride ?? AppFirebase.firestore;
  FirebaseAuth get _auth => _authOverride ?? AppFirebase.auth;

  DocumentReference<Map<String, dynamic>>? get _ref {
    final uid = _auth.currentUser?.uid;
    return uid == null ? null : _db.collection('users').doc(uid);
  }

  @override
  bool get canSave => _auth.currentUser != null;

  @override
  Stream<StreamingPrefs> watch() {
    final ref = _ref;
    if (ref == null) return Stream.value(StreamingPrefs.empty);
    return ref.snapshots().map((s) => StreamingPrefs.fromUserDoc(s.data()));
  }

  @override
  Future<void> save(StreamingPrefs prefs) async {
    final ref = _ref;
    if (ref == null) throw StateError('Not signed in');
    await ref.set(prefs.toUserDoc(), SetOptions(merge: true));
  }
}

/// TMDB endpoints the feature needs, behind an interface so widget tests can
/// inject fake data (no network).
abstract class StreamingDataSource {
  Future<List<StreamingRegion>> regions();

  /// Movie + TV provider catalog for [region], in JustWatch display order.
  Future<List<WatchProvider>> catalog(String region);

  /// Providers [ref] can be streamed on (flatrate/free/ads) in [region].
  Future<List<WatchProvider>> availability(TitleRef ref, String region);
}

class TmdbStreamingDataSource implements StreamingDataSource {
  TmdbStreamingDataSource([APIservices? api]) : _api = api ?? APIservices();
  final APIservices _api;

  // Session caches; failures are evicted so a retry really retries.
  Future<List<StreamingRegion>>? _regions;
  final _catalogs = <String, Future<List<WatchProvider>>>{};

  @override
  Future<List<StreamingRegion>> regions() => _regions ??= _api
      .getWatchProviderRegions()
      .then(parseRegions)
      .catchError((Object e) {
        _regions = null;
        throw e;
      });

  @override
  Future<List<WatchProvider>> catalog(String region) =>
      _catalogs.putIfAbsent(region, () async {
        try {
          final lists = await Future.wait([
            _api.getWatchProviderCatalog(MediaType.movie, region),
            _api.getWatchProviderCatalog(MediaType.tv, region),
          ]);
          return mergeProviderCatalogs(lists[0], lists[1], region);
        } catch (_) {
          _catalogs.remove(region);
          rethrow;
        }
      });

  @override
  Future<List<WatchProvider>> availability(TitleRef ref, String region) async =>
      parseStreamingAvailability(
        await _api.getWatchProvidersRaw(ref.type, ref.id),
        region,
      );
}

/// Per-title availability cache: in memory for the session, mirrored to
/// shared_preferences (one JSON blob) with a [availabilityTtl] TTL so the
/// next app launch doesn't re-check the whole watchlist either.
class AvailabilityCache {
  AvailabilityCache({DateTime Function()? clock, this.ttl = availabilityTtl})
    : _clock = clock ?? DateTime.now;

  static const prefsKey = 'streaming_availability_v1';

  final DateTime Function() _clock;
  final Duration ttl;
  final Map<String, CachedAvailability> _entries = {};
  Future<void>? _loading;
  bool _dirty = false;

  /// Reads the disk cache once (stale entries dropped). Never throws — a
  /// corrupt/unavailable cache just means re-fetching.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final loaded = <String, CachedAvailability>{};
      decoded.forEach((k, v) {
        final entry = CachedAvailability.fromJson(v);
        if (k is String && entry != null) loaded[k] = entry;
      });
      final fresh = pruneAvailabilityCache(loaded, _clock(), ttl: ttl);
      // Entries put() while loading are newer; keep them.
      fresh.forEach((k, v) => _entries.putIfAbsent(k, () => v));
    } catch (e) {
      debugPrint('AvailabilityCache: load failed: $e');
    }
  }

  /// Fresh providers for [key], or null when unknown/expired. Call
  /// [ensureLoaded] first to include disk entries.
  List<WatchProvider>? peek(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (!isAvailabilityFresh(entry.fetchedAt, _clock(), ttl: ttl)) {
      _entries.remove(key);
      return null;
    }
    return entry.providers;
  }

  void put(String key, List<WatchProvider> providers) {
    _entries[key] = CachedAvailability(_clock(), providers);
    _dirty = true;
  }

  /// Writes pending changes to disk (batched by the caller, not per put).
  Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pruned = pruneAvailabilityCache(_entries, _clock(), ttl: ttl);
      await prefs.setString(
        prefsKey,
        jsonEncode(pruned.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (e) {
      debugPrint('AvailabilityCache: flush failed: $e');
    }
  }
}

/// Bundles the feature's dependencies so screens can take fakes in tests.
class StreamingDeps {
  StreamingDeps({
    required this.prefs,
    required this.source,
    required this.cache,
    String? Function()? deviceCountry,
  }) : deviceCountry = deviceCountry ?? _platformCountry;

  final StreamingPrefsStore prefs;
  final StreamingDataSource source;
  final AvailabilityCache cache;
  final String? Function() deviceCountry;

  static String? _platformCountry() =>
      WidgetsBinding.instance.platformDispatcher.locale.countryCode;

  static StreamingDeps? _instance;
  static StreamingDeps get instance => _instance ??= StreamingDeps(
    prefs: FirestoreStreamingPrefsStore(),
    source: TmdbStreamingDataSource(),
    cache: AvailabilityCache(),
  );

  /// The user's region, or the device's when unset. Falls back to the device
  /// region if the profile read is slow/failing — callers only need a hint.
  Future<String> resolveRegion() async {
    try {
      final p = await prefs.watch().first.timeout(const Duration(seconds: 3));
      return p.effectiveRegion(deviceCountry());
    } catch (_) {
      return defaultStreamingRegion(deviceCountry(), null);
    }
  }
}

/// Checks a list of titles' availability with bounded concurrency and
/// reports progress. Results come from [AvailabilityCache] when fresh, so
/// reopening a screen (or relaunching within the TTL) costs no requests.
/// Failures are tracked per title (not cached) and can be retried.
class AvailabilityChecker extends ChangeNotifier {
  AvailabilityChecker({
    required StreamingDataSource source,
    required AvailabilityCache cache,
    this.concurrency = 4,
  }) : _source = source,
       _cache = cache;

  final StreamingDataSource _source;
  final AvailabilityCache _cache;
  final int concurrency;

  String? _region;
  List<TitleRef> _current = const [];
  final Map<TitleRef, List<WatchProvider>> _results = {};
  final Set<TitleRef> _failed = {};
  final Queue<TitleRef> _queue = Queue();
  final Set<TitleRef> _pending = {}; // queued or in flight
  int _active = 0;
  int _generation = 0;
  bool _disposed = false;

  String? get region => _region;

  /// Streaming providers for [ref] (possibly empty), or null if not known yet.
  List<WatchProvider>? availabilityFor(TitleRef ref) => _results[ref];

  bool hasFailed(TitleRef ref) => _failed.contains(ref);

  int get total => _current.length;
  int get checked => _current
      .where((r) => _results.containsKey(r) || _failed.contains(r))
      .length;
  int get failedCount => _current.where(_failed.contains).length;
  bool get isRunning => _current.any(_pending.contains);

  /// Starts checking [refs] in [region]; titles already known are skipped.
  /// Safe to call on every rebuild — only new titles get queued. With
  /// [fetch] false only fresh cache entries are used (no network), e.g. for
  /// badges while the filter is off.
  Future<void> check(
    List<TitleRef> refs,
    String region, {
    bool fetch = true,
  }) async {
    if (region != _region) {
      _region = region;
      _generation++;
      _results.clear();
      _failed.clear();
      _queue.clear();
      _pending.clear();
    }
    _current = List.unmodifiable(refs);
    final gen = _generation;
    await _cache.ensureLoaded();
    if (_disposed || gen != _generation) return;
    for (final ref in refs) {
      if (_results.containsKey(ref) ||
          _failed.contains(ref) ||
          _pending.contains(ref)) {
        continue;
      }
      final cached = _cache.peek(ref.keyFor(region));
      if (cached != null) {
        _results[ref] = cached;
      } else if (fetch) {
        _queue.add(ref);
        _pending.add(ref);
      }
    }
    _pump();
    _notify();
  }

  /// Re-queues every title whose lookup failed.
  void retryFailed() {
    final region = _region;
    if (region == null) return;
    final failed = _failed.toList();
    _failed.clear();
    for (final ref in failed) {
      if (_pending.add(ref)) _queue.add(ref);
    }
    _pump();
    _notify();
  }

  void _pump() {
    while (_active < concurrency && _queue.isNotEmpty) {
      unawaited(_run(_queue.removeFirst(), _generation, _region!));
    }
  }

  Future<void> _run(TitleRef ref, int gen, String region) async {
    _active++;
    try {
      final providers = await _source.availability(ref, region);
      _cache.put(ref.keyFor(region), providers);
      if (gen == _generation) _results[ref] = providers;
    } catch (e) {
      debugPrint('AvailabilityChecker: ${ref.type.apiPath} ${ref.id}: $e');
      if (gen == _generation) _failed.add(ref);
    } finally {
      _active--;
      if (gen == _generation) _pending.remove(ref);
      if (!_disposed) {
        _pump();
        if (_active == 0 && _queue.isEmpty) unawaited(_cache.flush());
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _queue.clear();
    unawaited(_cache.flush());
    super.dispose();
  }
}
