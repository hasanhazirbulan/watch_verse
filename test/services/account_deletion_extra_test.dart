import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/account_deletion_service.dart';

/// Covers data-layer fixes to account deletion that the original suite
/// (account_deletion_service_test.dart) didn't exercise: a followed user who already deleted their own account, episode notes
/// orphaned by removeShow(), and "what should we watch?" polls.
void main() {
  const uid = 'user-1';
  const otherUid = 'user-2';
  final now = DateTime.utc(2026, 10, 13, 12);

  late FakeFirebaseFirestore firestore;

  AccountDeletionService serviceWith() =>
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
        now: () => now,
      );

  setUp(() => firestore = FakeFirebaseFirestore());

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
