import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_verse/services/account_deletion_service.dart';

class _MockStorage extends Mock implements FirebaseStorage {}

class _MockRef extends Mock implements Reference {}

class _MockListResult extends Mock implements ListResult {}

/// Covers data-layer fixes to account deletion that the original suite
/// (account_deletion_service_test.dart) didn't exercise: Storage purging,
/// a followed user who already deleted their own account, episode notes
/// orphaned by removeShow(), and "what should we watch?" polls.
void main() {
  const uid = 'user-1';
  const otherUid = 'user-2';
  final now = DateTime.utc(2026, 10, 13, 12);

  late FakeFirebaseFirestore firestore;

  AccountDeletionService serviceWith({FirebaseStorage? storage}) =>
      AccountDeletionService.test(
        firestore: firestore,
        auth: MockFirebaseAuth(
          mockUser: MockUser(
              uid: uid,
              metadata: UserMetadata(
                  0,
                  now
                      .subtract(const Duration(minutes: 1))
                      .millisecondsSinceEpoch)),
          signedIn: true,
        ),
        storage: storage,
        now: () => now,
      );

  setUp(() => firestore = FakeFirebaseFirestore());

  test('deletes the profile photo and every comment image from Storage',
      () async {
    final storage = _MockStorage();
    final profileRef = _MockRef();
    final folderRef = _MockRef();
    final img1 = _MockRef();
    final img2 = _MockRef();
    final listing = _MockListResult();

    when(() => storage.ref('profile_images/$uid.jpg')).thenReturn(profileRef);
    when(() => storage.ref('comment_images/$uid')).thenReturn(folderRef);
    when(() => profileRef.delete()).thenAnswer((_) async {});
    when(() => folderRef.listAll()).thenAnswer((_) async => listing);
    when(() => listing.items).thenReturn([img1, img2]);
    when(() => img1.delete()).thenAnswer((_) async {});
    when(() => img2.delete()).thenAnswer((_) async {});

    await serviceWith(storage: storage).deleteAccount();

    verify(() => profileRef.delete()).called(1);
    verify(() => img1.delete()).called(1);
    verify(() => img2.delete()).called(1);
  });

  test('a missing profile photo does not stop the rest of the deletion',
      () async {
    final storage = _MockStorage();
    final profileRef = _MockRef();
    final folderRef = _MockRef();
    when(() => storage.ref(any())).thenAnswer((inv) =>
        inv.positionalArguments.first == 'profile_images/$uid.jpg'
            ? profileRef
            : folderRef);
    when(() => profileRef.delete()).thenThrow(
        FirebaseException(plugin: 'firebase_storage', code: 'object-not-found'));
    when(() => folderRef.listAll()).thenThrow(
        FirebaseException(plugin: 'firebase_storage', code: 'object-not-found'));
    await firestore.collection('users').doc(uid).set({'name': 'Me'});

    await serviceWith(storage: storage).deleteAccount();

    expect((await firestore.collection('users').doc(uid).get()).exists,
        isFalse);
  });

  test(
      'does not recreate the profile of a followed user who already deleted '
      'their account', () async {
    // In production, set(merge) on the missing doc is a *create*, which the
    // rules reject for non-owners — aborting the whole deletion.
    await firestore.collection('users').doc(uid).set({
      'following': [otherUid, 'user-3'],
    });
    await firestore.collection('users').doc('user-3').set({
      'followers': [uid],
    });

    await serviceWith().deleteAccount();

    expect((await firestore.collection('users').doc(otherUid).get()).exists,
        isFalse);
    expect(
        (await firestore.collection('users').doc('user-3').get())
            .data()!['followers'],
        isEmpty);
    expect((await firestore.collection('users').doc(uid).get()).exists,
        isFalse);
  });

  test('deletes episode notes left behind under a removed show', () async {
    final me = firestore.collection('users').doc(uid);
    await me.set({'name': 'Me'});
    // Show 1399 was removed (no show doc), but its notes survived, and the
    // activity timeline still references it.
    await me
        .collection('shows')
        .doc('1399')
        .collection('notes')
        .doc('s1e1')
        .set({'note': 'private thought'});
    await me.collection('activity').add({'kind': 'episode', 'showId': 1399});

    await serviceWith().deleteAccount();

    expect(
        (await me.collection('shows').doc('1399').collection('notes').get())
            .docs,
        isEmpty);
  });

  test('deletes own watch polls and withdraws votes from others', () async {
    await firestore.collection('users').doc(uid).set({'name': 'Me'});
    await firestore.collection('watchPolls').doc('mine').set({
      'creatorUid': uid,
      'creatorName': 'Me',
      'memberUids': [uid, otherUid],
      'options': {},
    });
    await firestore.collection('watchPolls').doc('theirs').set({
      'creatorUid': otherUid,
      'memberUids': [otherUid, uid],
      'options': {
        'movie-1': {
          'id': 1,
          'votes': [uid, otherUid],
        },
        'movie-2': {
          'id': 2,
          'votes': <String>[],
        },
      },
    });

    await serviceWith().deleteAccount();

    expect((await firestore.collection('watchPolls').doc('mine').get()).exists,
        isFalse);
    final theirs =
        (await firestore.collection('watchPolls').doc('theirs').get()).data()!;
    expect((theirs['options'] as Map)['movie-1']['votes'], [otherUid]);
    expect((theirs['options'] as Map)['movie-2']['votes'], isEmpty);
  });
}
