import 'package:watch_verse/models/media.dart';

/// Pure, side-effect-free logic behind "My streaming services": parsing
/// TMDB's JustWatch-backed provider data, matching it against the user's
/// chosen services, region defaults and cache freshness. Kept free of
/// Flutter/Firebase/network so it's unit-testable (test/services/streaming_logic_test.dart).

/// Firestore fields on `users/{uid}`.
const streamingRegionField = 'streamingRegion';
const streamingProviderIdsField = 'streamingProviderIds';

/// How long a title's availability is trusted before it's re-fetched.
/// JustWatch data changes daily at most, so 24h keeps the watchlist filter
/// accurate without re-checking every title on every open.
const availabilityTtl = Duration(hours: 24);

/// Region used when neither the user nor the device names a supported one.
const fallbackStreamingRegion = 'US';

/// A country TMDB has provider data for.
class StreamingRegion {
  final String code; // ISO 3166-1, upper case
  final String name;
  const StreamingRegion({required this.code, required this.name});
}

/// The user's saved choice. An empty [providerIds] means "not set up".
class StreamingPrefs {
  /// Null when the user never picked one — callers use [effectiveRegion].
  final String? region;
  final Set<int> providerIds;

  const StreamingPrefs({this.region, this.providerIds = const {}});

  static const empty = StreamingPrefs();

  bool get isConfigured => providerIds.isNotEmpty;

  factory StreamingPrefs.fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return empty;
    final rawRegion = data[streamingRegionField];
    final region = rawRegion is String && rawRegion.trim().length == 2
        ? rawRegion.trim().toUpperCase()
        : null;
    final rawIds = data[streamingProviderIdsField];
    final ids = <int>{
      if (rawIds is List)
        for (final v in rawIds)
          if (v is num && v > 0) v.toInt(),
    };
    return StreamingPrefs(region: region, providerIds: ids);
  }

  Map<String, dynamic> toUserDoc() => {
    streamingRegionField: region,
    streamingProviderIdsField: (providerIds.toList()..sort()),
  };

  StreamingPrefs copyWith({String? region, Set<int>? providerIds}) =>
      StreamingPrefs(
        region: region ?? this.region,
        providerIds: providerIds ?? this.providerIds,
      );

  /// The saved region, else the device's, else [fallbackStreamingRegion].
  String effectiveRegion(String? deviceCountry) =>
      region ?? defaultStreamingRegion(deviceCountry, null);
}

/// The device's country when it's a supported region, otherwise
/// [fallbackStreamingRegion]. [available] null means "not known yet" — the
/// device country is then trusted if it looks like an ISO code.
String defaultStreamingRegion(
  String? deviceCountry,
  Iterable<String>? available,
) {
  final code = deviceCountry?.trim().toUpperCase() ?? '';
  final looksValid = RegExp(r'^[A-Z]{2}$').hasMatch(code);
  if (!looksValid) return fallbackStreamingRegion;
  if (available == null) return code;
  return available.contains(code) ? code : fallbackStreamingRegion;
}

/// `/watch/providers/regions` results → regions sorted by English name.
List<StreamingRegion> parseRegions(List<dynamic> raw) {
  final out = <StreamingRegion>[];
  final seen = <String>{};
  for (final r in raw) {
    if (r is! Map) continue;
    final code = (r['iso_3166_1'] as String? ?? '').toUpperCase();
    if (code.length != 2 || !seen.add(code)) continue;
    final name = (r['english_name'] as String?)?.trim();
    out.add(
      StreamingRegion(
        code: code,
        name: (name == null || name.isEmpty) ? code : name,
      ),
    );
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// Merges the movie and TV provider catalogs for [region] (a provider may be
/// in one or both), de-duplicated by id and ordered by TMDB's
/// `display_priorities[region]` — the same order JustWatch shows them in —
/// with the better (lower) priority winning when both lists carry it.
List<WatchProvider> mergeProviderCatalogs(
  List<dynamic> movie,
  List<dynamic> tv,
  String region,
) {
  final byId = <int, WatchProvider>{};
  final priority = <int, int>{};
  for (final raw in [...movie, ...tv]) {
    if (raw is! Map<String, dynamic>) continue;
    final p = WatchProvider.fromMap(raw);
    if (p.id == 0 || p.name.isEmpty) continue;
    final prios = raw['display_priorities'];
    final regional = prios is Map ? prios[region] : null;
    final prio = regional is num
        ? regional.toInt()
        : (raw['display_priority'] as num?)?.toInt() ?? 1 << 20;
    byId.putIfAbsent(p.id, () => p);
    final current = priority[p.id];
    if (current == null || prio < current) priority[p.id] = prio;
  }
  final out = byId.values.toList()
    ..sort((a, b) {
      final c = priority[a.id]!.compareTo(priority[b.id]!);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return out;
}

/// Providers a title can be *streamed* on in [region] right now — the
/// `flatrate` (subscription) bucket, plus `free`/`ads` when [includeFree].
/// Rent/buy are deliberately excluded ("on my services" means no extra
/// payment). No fallback to another region: a US-only listing must not show
/// up as available to someone in Germany.
List<WatchProvider> parseStreamingAvailability(
  Map<String, dynamic> results,
  String region, {
  bool includeFree = true,
}) {
  final regionData = results[region];
  if (regionData is! Map) return const [];
  final seen = <int>{};
  final out = <WatchProvider>[];
  for (final bucket in [
    'flatrate',
    if (includeFree) ...['free', 'ads'],
  ]) {
    final list = regionData[bucket];
    if (list is! List) continue;
    for (final p in list) {
      if (p is! Map<String, dynamic>) continue;
      final wp = WatchProvider.fromMap(p);
      if (wp.id != 0 && seen.add(wp.id)) out.add(wp);
    }
  }
  return out;
}

/// The subset of [available] the user subscribes to, in [available]'s order.
List<WatchProvider> matchUserServices(
  List<WatchProvider> available,
  Set<int> userProviderIds,
) => userProviderIds.isEmpty
    ? const []
    : available.where((p) => userProviderIds.contains(p.id)).toList();

/// [providers] with the user's own services moved to the front, keeping the
/// relative order within each group (stable).
List<WatchProvider> userServicesFirst(
  List<WatchProvider> providers,
  Set<int> userProviderIds,
) {
  if (userProviderIds.isEmpty) return providers;
  return [
    ...providers.where((p) => userProviderIds.contains(p.id)),
    ...providers.where((p) => !userProviderIds.contains(p.id)),
  ];
}

/// Whether a cache entry fetched at [fetchedAt] can still be used at [now].
/// An entry dated in the future (device clock moved back) is treated as
/// stale rather than trusted forever.
bool isAvailabilityFresh(
  DateTime fetchedAt,
  DateTime now, {
  Duration ttl = availabilityTtl,
}) {
  final age = now.difference(fetchedAt);
  return !age.isNegative && age < ttl;
}

/// A movie or show to check availability for.
class TitleRef {
  final MediaType type;
  final int id;
  const TitleRef(this.type, this.id);

  String keyFor(String region) => availabilityKey(type, id, region);

  @override
  bool operator ==(Object other) =>
      other is TitleRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

String availabilityKey(MediaType type, int id, String region) =>
    '${type.apiPath}-$id-$region';

/// One cached availability lookup (streaming providers for a title+region).
class CachedAvailability {
  final DateTime fetchedAt;
  final List<WatchProvider> providers;
  const CachedAvailability(this.fetchedAt, this.providers);

  Map<String, dynamic> toJson() => {
    't': fetchedAt.millisecondsSinceEpoch,
    'p': [
      for (final p in providers)
        {'provider_id': p.id, 'provider_name': p.name, 'logo_path': p.logoPath},
    ],
  };

  /// Null when [json] is malformed (old/corrupt cache entries are dropped).
  static CachedAvailability? fromJson(Object? json) {
    if (json is! Map) return null;
    final t = json['t'];
    final p = json['p'];
    if (t is! int || p is! List) return null;
    return CachedAvailability(DateTime.fromMillisecondsSinceEpoch(t), [
      for (final e in p)
        if (e is Map<String, dynamic>) WatchProvider.fromMap(e),
    ]);
  }
}

/// Keeps the [maxEntries] most recent fresh entries — drops stale ones and,
/// past the cap, the oldest, so the on-disk cache can't grow without bound.
Map<String, CachedAvailability> pruneAvailabilityCache(
  Map<String, CachedAvailability> entries,
  DateTime now, {
  Duration ttl = availabilityTtl,
  int maxEntries = 2000,
}) {
  final fresh =
      entries.entries
          .where((e) => isAvailabilityFresh(e.value.fetchedAt, now, ttl: ttl))
          .toList()
        ..sort((a, b) => b.value.fetchedAt.compareTo(a.value.fetchedAt));
  return Map.fromEntries(fresh.take(maxEntries));
}

/// "Netflix", "Netflix and Max", "Netflix, Max and 2 more" style label for
/// the matched services (names only; the caller adds "On your …").
String joinProviderNames(List<WatchProvider> providers, {int maxNames = 2}) {
  final names = providers.map((p) => p.name).toList();
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  if (names.length <= maxNames) {
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
  final shown = names.take(maxNames).join(', ');
  return '$shown and ${names.length - maxNames} more';
}
