import 'dart:async';

import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';

/// In-memory stand-ins for the streaming feature's Firestore/TMDB deps.
class FakePrefsStore implements StreamingPrefsStore {
  FakePrefsStore([this.current = StreamingPrefs.empty]);
  StreamingPrefs current;
  final saves = <StreamingPrefs>[];
  bool failSaves = false;

  @override
  bool get canSave => true;

  @override
  Stream<StreamingPrefs> watch() => Stream.value(current);

  @override
  Future<void> save(StreamingPrefs prefs) async {
    if (failSaves) throw StateError('offline');
    current = prefs;
    saves.add(prefs);
  }
}

class FakeStreamingSource implements StreamingDataSource {
  FakeStreamingSource({
    this.regionList = const [],
    this.catalogs = const {},
    this.availabilityById = const {},
    this.failingIds = const {},
    this.delay = Duration.zero,
  });

  final List<StreamingRegion> regionList;
  final Map<String, List<WatchProvider>> catalogs;
  final Map<int, List<WatchProvider>> availabilityById;
  Set<int> failingIds;
  final Duration delay;

  final requests = <TitleRef>[];
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<List<StreamingRegion>> regions() async => regionList;

  @override
  Future<List<WatchProvider>> catalog(String region) async =>
      catalogs[region] ?? const [];

  @override
  Future<List<WatchProvider>> availability(TitleRef ref, String region) async {
    requests.add(ref);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      await Future<void>.delayed(delay);
      if (failingIds.contains(ref.id)) throw StateError('TMDB down');
      return availabilityById[ref.id] ?? const [];
    } finally {
      inFlight--;
    }
  }
}

const netflix = WatchProvider(id: 8, name: 'Netflix', logoPath: '');
const disney = WatchProvider(id: 337, name: 'Disney Plus', logoPath: '');
const mubi = WatchProvider(id: 11, name: 'MUBI', logoPath: '');
