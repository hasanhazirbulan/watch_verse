import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/account_deletion_service.dart';

/// Covers the Firestore half of account deletion — the part the privacy
/// policy makes promises about. Storage is skipped (no fake available), so
/// the service is built without it.
void main() {
  const uid = 'user-1';
  const otherUid = 'user-2';

  final now = DateTime.utc(2026, 10, 13, 12);

  /// Metadata for a user whose last sign-in was [ago] before [now].
  UserMetadata signedInAgo(Duration ago) => UserMetadata(
      0, now.subtract(ago).millisecondsSinceEpoch);

  late FakeFirebaseFirestore firestore;
  late AccountDeletionService service;

  AccountDeletionService serviceFor(MockUser user) => AccountDeletionService.test(
        firestore: firestore,
        auth: MockFirebaseAuth(mockUser: user, signedIn: true),
        now: () => now,
      );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = serviceFor(MockUser(
        uid: uid, metadata: signedInAgo(const Duration(minutes: 1))));
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

  group('interruption safety', () {
    DocumentReference<Map<String, dynamic>> profile() =>
        firestore.collection('users').doc(uid);

    Future<int> movieCount() async =>
        (await profile().collection('movies').get()).docs.length;

    Future<void> seedAccount() async {
      await profile().set({'name': 'Me', 'following': [otherUid]});
      await profile().collection('movies').doc('27205').set({'status': 'watched'});
      await profile().collection('gamePlays').doc('2026-10-13').set({'won': true});
      await firestore.collection('users').doc(otherUid).set({
        'followers': [uid],
      });
      await firestore.collection('comments').add({'uid': uid, 'text': 'mine'});
    }

    test('stale sign-in fails with requires-recent-login before any data is touched',
        () async {
      await seedAccount();
      final user = _RecordingUser(
          uid: uid, metadata: signedInAgo(const Duration(minutes: 30)));
      service = serviceFor(user);

      await expectLater(
        service.deleteAccount(),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'requires-recent-login')),
      );

      final data = (await profile().get()).data()!;
      expect(data['name'], 'Me');
      expect(data.containsKey(AccountDeletionService.pendingField), isFalse);
      expect(await movieCount(), 1);
      expect(await countComments(), 1);
      expect(user.deleteCalls, 0);
    });

    test('interruption after the purge leaves deletionPending set', () async {
      await seedAccount();
      service.debugInterruptAfterPurge = () async => throw StateError('app killed');

      await expectLater(service.deleteAccount(),
          throwsA(isA<AccountDeletionIncompleteException>()));

      // The library is gone, but the profile is flagged — the app can tell
      // this apart from a live account that just lost its data.
      final snap = await profile().get();
      expect(snap.exists, isTrue);
      expect(snap.data()![AccountDeletionService.pendingField], isTrue);
      expect(snap.data()![AccountDeletionService.pendingAtField], isNotNull);
      expect(await movieCount(), 0);
      expect(await service.hasPendingDeletion(), isTrue);
    });

    test('resume finishes an interrupted deletion', () async {
      await seedAccount();
      final user = _RecordingUser(
          uid: uid, metadata: signedInAgo(const Duration(minutes: 1)));
      service = serviceFor(user);
      service.debugInterruptAfterPurge = () async => throw StateError('app killed');
      await expectLater(service.deleteAccount(),
          throwsA(isA<AccountDeletionIncompleteException>()));
      expect(user.deleteCalls, 0);

      // Next launch: a fresh service instance, no interruption this time.
      final relaunched = serviceFor(user);
      expect(await relaunched.resumePendingDeletion(), isTrue);

      expect((await profile().get()).exists, isFalse);
      expect(await movieCount(), 0);
      expect(
          (await profile().collection('gamePlays').get()).docs, isEmpty);
      expect(await countComments(), 0);
      final followers =
          (await firestore.collection('users').doc(otherUid).get())
              .data()!['followers'] as List;
      expect(followers, isEmpty);
      expect(user.deleteCalls, 1);
    });

    test('resume is a no-op when no deletion is pending', () async {
      await seedAccount();

      expect(await service.resumePendingDeletion(), isFalse);

      expect((await profile().get()).data()!['name'], 'Me');
      expect(await movieCount(), 1);
    });

    test('auth delete failing at the very end leaves a pending marker behind',
        () async {
      await seedAccount();
      final user = _RecordingUser(
        uid: uid,
        metadata: signedInAgo(const Duration(minutes: 1)),
        deleteError: FirebaseAuthException(code: 'requires-recent-login'),
      );
      service = serviceFor(user);

      await expectLater(
        service.deleteAccount(),
        throwsA(isA<AccountDeletionIncompleteException>().having(
            (e) => (e.cause as FirebaseAuthException).code,
            'cause.code',
            'requires-recent-login')),
      );

      // Profile doc was deleted, then put back as a bare marker with no
      // personal data, so the next sign-in resumes the deletion.
      final data = (await profile().get()).data()!;
      expect(data[AccountDeletionService.pendingField], isTrue);
      expect(data.containsKey('name'), isFalse);
      expect(await movieCount(), 0);
      expect(await service.hasPendingDeletion(), isTrue);
    });
  });
}

/// MockUser that counts `delete()` calls and can be told to fail them.
// ignore: must_be_immutable
class _RecordingUser extends MockUser {
  _RecordingUser({super.uid, super.metadata, this.deleteError});

  final Exception? deleteError;
  int deleteCalls = 0;

  @override
  Future<void> delete() async {
    deleteCalls++;
    final error = deleteError;
    if (error != null) throw error;
  }
}
