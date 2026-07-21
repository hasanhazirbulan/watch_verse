import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/list_service.dart';

void main() {
  const uid = 'user-1';
  const movie = MediaItem(
    id: 42,
    title: 'Interstellar',
    overview: '',
    posterPath: '/poster.jpg',
    backdropPath: '',
    date: '2014-11-05',
    voteAverage: 8.6,
    mediaType: MediaType.movie,
  );

  late FakeFirebaseFirestore firestore;
  late ListService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
    service = ListService.test(firestore: firestore, auth: auth);
  });

  Future<Map<String, dynamic>?> listDoc(String id) async {
    final doc = await firestore
        .collection('users')
        .doc(uid)
        .collection('lists')
        .doc(id)
        .get();
    return doc.data();
  }

  test('createList creates a doc with the given name and no items', () async {
    final id = await service.createList('Watch in 2026');

    final data = await listDoc(id!);
    expect(data, isNotNull);
    expect(data!['name'], 'Watch in 2026');
    expect(data['items'], isEmpty);
  });

  test('addToList adds an item keyed by mediaType-id', () async {
    final id = await service.createList('Favorites');
    await service.addToList(id!, movie);

    final data = await listDoc(id);
    final items = data!['items'] as Map;
    expect(items.containsKey('movie-42'), isTrue);
    expect(items['movie-42']['title'], 'Interstellar');
  });

  test('removeFromList removes the item', () async {
    final id = await service.createList('Favorites');
    await service.addToList(id!, movie);
    await service.removeFromList(id, ListService.keyFor(movie));

    final data = await listDoc(id);
    expect((data!['items'] as Map), isEmpty);
  });

  test('listsStream emits lists created for the current user', () async {
    await service.createList('A');
    await service.createList('B');

    final lists = await service.listsStream().first;
    expect(lists.length, 2);
    expect(lists.map((l) => l['name']), containsAll(['A', 'B']));
  });

  test('renameList updates the name', () async {
    final id = await service.createList('Old name');
    await service.renameList(id!, 'New name');

    final data = await listDoc(id);
    expect(data!['name'], 'New name');
  });

  test('deleteList removes the doc', () async {
    final id = await service.createList('Temp');
    await service.deleteList(id!);

    expect(await listDoc(id), isNull);
  });
}
