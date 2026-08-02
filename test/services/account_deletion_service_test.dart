import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/account_deletion_service.dart';

/// Covers the Firestore half of account deletion — the part the privacy
/// policy makes promises about. Storage is skipped (no fake available), so
/// the service is built without it.
void main() {
  const uid = 'user-1';
  const otherUid = 'user-2';

  late FakeFirebaseFirestore firestore;
  late AccountDeletionService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
    service = AccountDeletionService.test(firestore: firestore, auth: auth);
  });

  Future<int> countComments() async =>
      (await firestore.collection('comments').get()).docs.length;

  test('deletes the user profile and their library', () async {
    await firestore.collection('users').doc(uid).set({'name': 'Me'});
    await firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
        .doc('27205')
        .set({'status': 'watched'});
    await firestore
        .collection('users')
        .doc(uid)
        .collection('diary')
        .doc('e1')
        .set({'note': 'private'});

    await service.deleteAccount();

    expect((await firestore.collection('users').doc(uid).get()).exists, isFalse);
    expect(
        (await firestore
                .collection('users')
                .doc(uid)
                .collection('movies')
                .get())
            .docs,
        isEmpty);
    expect(
        (await firestore.collection('users').doc(uid).collection('diary').get())
            .docs,
        isEmpty);
  });

  test('deletes the user own comments but leaves other people comments', () async {
    await firestore.collection('comments').add({'uid': uid, 'text': 'mine'});
    await firestore
        .collection('comments')
        .add({'uid': otherUid, 'text': 'theirs'});

    await service.deleteAccount();

    expect(await countComments(), 1);
    final remaining = (await firestore.collection('comments').get()).docs.single;
    expect(remaining.data()['uid'], otherUid);
  });

  test('strips the user uid out of likes on other people comments', () async {
    final ref = await firestore.collection('comments').add({
      'uid': otherUid,
      'text': 'theirs',
      'likes': [uid, 'user-3'],
    });

    await service.deleteAccount();

    final likes = (await ref.get()).data()!['likes'] as List;
    expect(likes, ['user-3']);
  });

  test('removes the user from the followers of everyone they followed',
      () async {
    await firestore.collection('users').doc(uid).set({
      'following': [otherUid],
    });
    await firestore.collection('users').doc(otherUid).set({
      'followers': [uid, 'user-3'],
    });

    await service.deleteAccount();

    final followers =
        (await firestore.collection('users').doc(otherUid).get())
            .data()!['followers'] as List;
    expect(followers, ['user-3']);
  });
}
