import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/model.dart';
import 'package:watch_verse/services/movie_service.dart';

void main() {
  const uid = 'user-1';
  final movie = Movie(
    id: 27205,
    title: 'Inception',
    overview: '',
    posterPath: '/poster.jpg',
    backDropPath: '',
    releaseDate: '2010-07-16',
    voteAverage: 8.4,
  );

  late FakeFirebaseFirestore firestore;
  late MovieService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
    service = MovieService.test(firestore: firestore, auth: auth);
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> movieDoc() => firestore
      .collection('users')
      .doc(uid)
      .collection('movies')
      .doc(movie.id.toString())
      .get();

  Future<DocumentSnapshot<Map<String, dynamic>>> activityDoc() => firestore
      .collection('users')
      .doc(uid)
      .collection('activity')
      .doc('movie-${movie.id}')
      .get();

  test('setStatus(watched) upserts the movie and logs activity', () async {
    await service.setStatus(movie, 'watched');

    final doc = await movieDoc();
    expect(doc.exists, isTrue);
    expect(doc.data()!['status'], 'watched');
    expect(doc.data()!['title'], 'Inception');
    expect((await activityDoc()).exists, isTrue);
  });

  test('setStatus(watchlist) does not log activity', () async {
    await service.setStatus(movie, 'watchlist');

    expect((await movieDoc()).data()!['status'], 'watchlist');
    expect((await activityDoc()).exists, isFalse);
  });

  test('setFavorite toggles the favorite flag', () async {
    await service.setFavorite(movie, true);
    expect((await movieDoc()).data()!['favorite'], isTrue);

    await service.setFavorite(movie, false);
    expect((await movieDoc()).data()!['favorite'], isFalse);
  });

  test('setFavorite is unbounded — a 4th favorite is not blocked', () async {
    final other1 = Movie(
        id: 1,
        title: 'A',
        overview: '',
        posterPath: '',
        backDropPath: '',
        releaseDate: '',
        voteAverage: 0);
    final other2 = Movie(
        id: 2,
        title: 'B',
        overview: '',
        posterPath: '',
        backDropPath: '',
        releaseDate: '',
        voteAverage: 0);
    final other3 = Movie(
        id: 3,
        title: 'C',
        overview: '',
        posterPath: '',
        backDropPath: '',
        releaseDate: '',
        voteAverage: 0);

    await service.setFavorite(other1, true);
    await service.setFavorite(other2, true);
    await service.setFavorite(other3, true);
    await service.setFavorite(movie, true);

    expect((await movieDoc()).data()!['favorite'], isTrue);
    expect(await service.favoritesStream().first, hasLength(4));
  });

  test('setShowcaseSlot curates the showcase independently of favorite order',
      () async {
    final other1 = Movie(
        id: 1,
        title: 'A',
        overview: '',
        posterPath: '',
        backDropPath: '',
        releaseDate: '',
        voteAverage: 0);
    await service.setFavorite(movie, true);
    await service.setFavorite(other1, true);

    await service.setShowcaseSlot(other1.id, 0);
    await service.setShowcaseSlot(movie.id, 1);

    final showcase = await service.showcaseStream().first;
    expect(showcase.map((m) => m['id']), [other1.id, movie.id]);
  });

  test('un-favoriting a movie also removes it from the showcase', () async {
    await service.setFavorite(movie, true);
    await service.setShowcaseSlot(movie.id, 0);
    expect((await movieDoc()).data()!['showcaseSlot'], 0);

    await service.setFavorite(movie, false);
    expect((await movieDoc()).data()!['showcaseSlot'], isNull);
  });

  test('setRating stores the rating', () async {
    await service.setRating(movie, 4.5);
    expect((await movieDoc()).data()!['rating'], 4.5);
  });

  test('remove deletes the movie doc and its activity entry', () async {
    await service.setStatus(movie, 'watched');
    await service.remove(movie.id);

    expect((await movieDoc()).exists, isFalse);
    expect((await activityDoc()).exists, isFalse);
  });
}
