import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/social_service.dart';

void main() {
  const me = 'user-1';
  const gone = 'deleted-user';
  const other = 'user-2';

  late FakeFirebaseFirestore firestore;
  late SocialService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = SocialService.test(
      firestore: firestore,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: me), signedIn: true),
    );
  });

  Future<Map<String, dynamic>?> user(String id) async =>
      (await firestore.collection('users').doc(id).get()).data();

  test('unfollowing a user who deleted their account updates only my doc',
      () async {
    // In production the old set(merge) on the missing doc was a *create*,
    // rejected by the rules, which rolled back the whole batch.
    await firestore.collection('users').doc(me).set({
      'following': [gone],
    });

    await service.unfollow(gone);

    expect((await user(me))!['following'], isEmpty);
    expect(await user(gone), isNull);
  });

  test('unfollow still removes me from an existing user followers', () async {
    await firestore.collection('users').doc(me).set({'following': [other]});
    await firestore.collection('users').doc(other).set({
      'followers': [me, 'user-3'],
    });

    await service.unfollow(other);

    expect((await user(me))!['following'], isEmpty);
    expect((await user(other))!['followers'], ['user-3']);
  });

  test('blocking a deleted user does not recreate their profile', () async {
    await firestore.collection('users').doc(me).set({'following': [gone]});

    await service.block(gone);

    expect((await user(me))!['blocked'], [gone]);
    expect(await user(gone), isNull);
  });

  test('block drops the follow both from my following and my followers',
      () async {
    await firestore.collection('users').doc(me).set({
      'following': [other],
      'followers': [other, 'user-3'],
    });
    await firestore.collection('users').doc(other).set({
      'followers': [me],
      'following': [me],
    });

    await service.block(other);

    final mine = (await user(me))!;
    expect(mine['blocked'], [other]);
    expect(mine['following'], isEmpty);
    expect(mine['followers'], ['user-3']);
    expect((await user(other))!['followers'], isEmpty);
  });
}
