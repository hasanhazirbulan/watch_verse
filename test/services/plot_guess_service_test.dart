import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/games/plot_guess_logic.dart';
import 'package:watch_verse/services/games/plot_guess_service.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final s = files[key];
    if (s == null) throw StateError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(s)));
  }
}

String _pool(List<int> ids) => jsonEncode({
      'items': [
        for (final id in ids)
          {
            'id': id,
            'title': 'T$id',
            'year': 2000,
            'genres': ['Drama'],
            'cast': ['A'],
            'tagline': '',
            'overview': 'Plot $id. More.',
            'posterPath': '/p.jpg',
          },
      ],
    });

void main() {
  late FakeFirebaseFirestore firestore;
  late PlotGuessService service;
  final now = DateTime.utc(2026, 10, 14, 12);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = PlotGuessService.test(
      firestore: firestore,
      auth: MockFirebaseAuth(
          signedIn: true, mockUser: MockUser(uid: 'u1')),
      bundle: _Bundle({
        PlotGuessService.poolAsset(PlotGameMode.movie): _pool([1, 2, 3]),
        PlotGuessService.poolAsset(PlotGameMode.tv): _pool([]),
      }),
    );
  });

  test('picks the puzzle by EST day index', () async {
    final p = await service.puzzleFor(PlotGameMode.movie, now);
    expect(p!.id, [1, 2, 3][plotGameDayIndex(now) % 3]);
    expect(await service.puzzleFor(PlotGameMode.tv, now), isNull);
  });

  test('saves attempts under gamePlays/plot-{mode}-{date}', () async {
    const attempts = [
      PlotAttempt.skip(),
      PlotAttempt.skip(),
      PlotAttempt(id: 9, title: 'Nine'),
    ];
    await service.saveAttempts(
      mode: PlotGameMode.movie,
      now: now,
      attempts: attempts,
      progress: plotGameProgress(attempts, 9),
    );
    final doc = await firestore
        .doc('users/u1/gamePlays/plot-movie-2026-10-14')
        .get();
    expect(doc.data()!['won'], isTrue);
    expect(doc.data()!['finished'], isTrue);
    // Two identical skips survive (no arrayUnion de-duplication).
    expect(doc.data()!['attempts'], hasLength(3));

    final streamed =
        await service.attemptsStream(PlotGameMode.movie, now).first;
    expect(streamed.map((a) => a.id), [0, 0, 9]);
  });

  test('guests read no progress and write nothing', () async {
    final guest = PlotGuessService.test(
        firestore: firestore, auth: MockFirebaseAuth());
    expect(await guest.attemptsStream(PlotGameMode.tv, now).first, isEmpty);
    await guest.saveAttempts(
        mode: PlotGameMode.tv,
        now: now,
        attempts: const [PlotAttempt.skip()],
        progress: plotGameProgress(const [PlotAttempt.skip()], 1));
    expect((await firestore.collectionGroup('gamePlays').get()).docs, isEmpty);
  });
}
