import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/games/game_day.dart';
import 'package:watch_verse/services/games/game_play_store.dart';

void main() {
  group('day index', () {
    test('day flips at midnight EST (05:00 UTC), not UTC midnight', () {
      expect(gameDateKey(DateTime.utc(2026, 10, 16, 4, 59)), '2026-10-15');
      expect(gameDateKey(DateTime.utc(2026, 10, 16, 5, 0)), '2026-10-16');
    });

    test('puzzle numbers count from launch and clamp before it', () {
      expect(gamePuzzleNumber(DateTime.utc(2026, 10, 15, 12)), 1);
      expect(gamePuzzleNumber(DateTime.utc(2026, 10, 16, 12)), 2);
      expect(gamePuzzleNumber(DateTime.utc(2027, 10, 15, 12)), 366);
      expect(gamePuzzleNumber(DateTime.utc(2026, 1, 1)), 1);
    });

    test('dailyPoolEntry wraps around the pool', () {
      const pool = ['a', 'b', 'c'];
      expect(dailyPoolEntry(pool, 1), 'a');
      expect(dailyPoolEntry(pool, 3), 'c');
      expect(dailyPoolEntry(pool, 4), 'a');
      expect(() => dailyPoolEntry(<String>[], 1), throwsStateError);
    });

    test('doc ids are namespaced by game and mode', () {
      expect(
        gamePlayDocId('frames', MediaType.movie, '2026-10-15'),
        'frames-movie-2026-10-15',
      );
      expect(
        gamePlayDocId('titleWordle', MediaType.tv, '2026-10-15'),
        'titleWordle-tv-2026-10-15',
      );
    });
  });

  group('GamePlayStore', () {
    test('saves and loads under users/{uid}/gamePlays', () async {
      final db = FakeFirebaseFirestore();
      final store = GamePlayStore.test(
        firestore: db,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
      );
      expect(await store.load('frames-movie-2026-10-15'), isNull);
      await store.save('frames-movie-2026-10-15', {'won': true});
      final doc = await db
          .collection('users')
          .doc('u1')
          .collection('gamePlays')
          .doc('frames-movie-2026-10-15')
          .get();
      expect(doc.data()?['won'], true);
      expect((await store.load('frames-movie-2026-10-15'))?['won'], true);
    });

    test('guests: load is null and save is a no-op', () async {
      final db = FakeFirebaseFirestore();
      final store = GamePlayStore.test(firestore: db, auth: MockFirebaseAuth());
      expect(store.isSignedIn, isFalse);
      await store.save('x', {'won': true});
      expect(await store.load('x'), isNull);
      expect((await db.collection('users').get()).docs, isEmpty);
    });
  });
}
