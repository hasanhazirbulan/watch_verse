import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';

void main() {
  const uid = 'user-1';
  const show = TvShow(
    id: 1399,
    name: 'Show',
    overview: '',
    posterPath: '',
    backdropPath: '',
    firstAirDate: '2011-04-17',
    lastAirDate: '',
    voteAverage: 8,
    numberOfSeasons: 1,
    numberOfEpisodes: 3,
    status: '',
    genres: [],
    seasons: [],
  );
  Episode ep(int n) => Episode(
        id: n,
        episodeNumber: n,
        seasonNumber: 1,
        name: 'E$n',
        overview: '',
        stillPath: '',
        airDate: '2011-04-17',
        voteAverage: 0,
        runtime: 60,
      );

  late FakeFirebaseFirestore firestore;
  late TvTrackingService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TvTrackingService.test(
      firestore: firestore,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true),
    );
  });

  DocumentReference<Map<String, dynamic>> showDoc() => firestore
      .collection('users')
      .doc(uid)
      .collection('shows')
      .doc('${show.id}');

  Future<int> activityCount() async => (await firestore
          .collection('users')
          .doc(uid)
          .collection('activity')
          .get())
      .docs
      .length;

  test('a double tap marks the episode once, not twice', () async {
    await Future.wait([
      service.setEpisodeWatched(show, ep(1), true),
      service.setEpisodeWatched(show, ep(1), true),
    ]);

    final data = (await showDoc().get()).data()!;
    expect(data['watchedCount'], 1);
    expect(data['watchedMinutes'], 60);
    expect(await activityCount(), 1);
  });

  test('quick taps on two episodes count both', () async {
    await Future.wait([
      service.setEpisodeWatched(show, ep(1), true),
      service.setEpisodeWatched(show, ep(2), true),
    ]);

    final data = (await showDoc().get()).data()!;
    expect(data['watchedCount'], 2);
    expect(data['watchedMinutes'], 120);
    expect(data['status'], 'watching');
  });

  test('season mark racing a single-episode mark does not double count',
      () async {
    await Future.wait([
      service.setEpisodeWatched(show, ep(1), true),
      service.setSeasonWatched(show, [ep(1), ep(2), ep(3)], true),
    ]);

    final data = (await showDoc().get()).data()!;
    expect(data['watchedCount'], 3);
    expect(data['watchedMinutes'], 180);
    expect(data['status'], 'completed');
  });

  test('marking/unmarking a season of more than 500 episodes works',
      () async {
    // The fake enforces Firestore's 500-writes-per-batch cap.
    final season = [for (var n = 1; n <= 600; n++) ep(n)];
    await service.setSeasonWatched(show, season, true);
    var data = (await showDoc().get()).data()!;
    expect(data['watchedCount'], 600);
    expect(data['watchedMinutes'], 600 * 60);
    expect((await showDoc().collection('watched').get()).docs.length, 600);

    await service.setSeasonWatched(show, season, false);
    data = (await showDoc().get()).data()!;
    expect(data['watchedCount'], 0);
    expect(data['watchedMinutes'], 0);
    expect((await showDoc().collection('watched').get()).docs, isEmpty);
  });

  test('catch-up of more than 500 episodes and removing the show work',
      () async {
    final eps = [for (var n = 1; n <= 1000; n++) ep(n)];
    await service.markEpisodesWatched(show, eps);
    expect((await showDoc().get()).data()!['watchedCount'], 1000);
    expect((await showDoc().collection('watched').get()).docs.length, 1000);

    await service.removeShow(show.id);
    expect((await showDoc().get()).exists, isFalse);
    expect((await showDoc().collection('watched').get()).docs, isEmpty);
  });

  test('watchedAtByKey maps exactly the watched episodes to dates', () async {
    await service.setEpisodeWatched(show, ep(1), true);
    await service.setEpisodeWatched(show, ep(3), true);

    final map = await service.watchedAtByKey(show.id);
    expect(map.keys.toSet(), {'s1e1', 's1e3'});
    expect(map.values.every((d) => d != null), isTrue);
  });

  test('watch then unwatch leaves no history entry behind', () async {
    await service.setEpisodeWatched(show, ep(1), true);
    await service.setEpisodeWatched(show, ep(1), false);

    final data = (await showDoc().get()).data()!;
    expect(data['watchedCount'], 0);
    expect(data['watchedMinutes'], 0);
    expect(await activityCount(), 0);
  });
}
