import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/movie_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/services/year_in_review.dart';
import 'package:watch_verse/services/year_in_review_source.dart';

void main() {
  test('reads library + in-year episodes and exact runtimes', () async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1'),
    );
    final user = db.collection('users').doc('u1');
    Timestamp ts(int y, int m, int d) => Timestamp.fromDate(DateTime(y, m, d));

    await user.collection('diary').add({
      'mediaType': 'movie',
      'id': 1,
      'title': 'Film 1',
      'watchedOn': ts(2025, 3, 1),
    });
    await user.collection('movies').doc('1').set({
      'id': 1,
      'title': 'Film 1',
      'status': 'watched',
      'watchedAt': ts(2025, 3, 1),
      'runtime': 100,
    });
    // Touched in 2025 → queried.
    await user.collection('shows').doc('10').set({
      'id': 10,
      'name': 'Show 10',
      'watchedCount': 3,
      'watchedMinutes': 150,
      'updatedAt': ts(2025, 6, 1),
    });
    final watched = user.collection('shows').doc('10').collection('watched');
    await watched.doc('s1e1').set({
      'season': 1,
      'episode': 1,
      'watchedAt': ts(2025, 5, 1),
    });
    await watched.doc('s1e2').set({
      'season': 1,
      'episode': 2,
      'watchedAt': ts(2025, 5, 2),
    });
    await watched.doc('s1e3').set({
      'season': 1,
      'episode': 3,
      'watchedAt': ts(2024, 5, 2),
    });
    // Last touched before 2025 → its episodes can't be in 2025.
    await user.collection('shows').doc('20').set({
      'id': 20,
      'name': 'Show 20',
      'watchedCount': 1,
      'updatedAt': ts(2024, 1, 1),
    });
    await user.collection('activity').add({
      'kind': 'episode',
      'showId': 10,
      'season': 1,
      'episode': 1,
      'runtime': 42,
      'at': ts(2025, 5, 1),
    });

    final source = FirestoreYearInReviewSource(
      movies: MovieService.test(firestore: db, auth: auth),
      tv: TvTrackingService.test(firestore: db, auth: auth),
    );
    final input = await source.load(2025);
    expect(input.diaryEntries.single['watchedOn'], DateTime(2025, 3, 1));
    expect(input.episodes.map((e) => e.key), unorderedEquals(['s1e1', 's1e2']));
    expect(input.episodeRuntimes, {episodeRuntimeKey(10, 's1e1'): 42});

    final r = computeYearInReview(input, 2025, now: DateTime(2026, 10, 14));
    expect(r.filmWatches, 1);
    expect(r.episodes, 2);
    expect(r.episodeMinutes, 42 + 50); // exact + show average
    expect(r.totalMinutes, 100 + 92);
  });
}
