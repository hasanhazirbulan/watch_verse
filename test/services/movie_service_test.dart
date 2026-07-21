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
