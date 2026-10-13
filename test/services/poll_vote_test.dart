import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/poll_service.dart';

void main() {
  const uid = 'user-1';
  const pollId = 'movie-27205';

  late FakeFirebaseFirestore firestore;
  late PollService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = PollService.test(
      firestore: firestore,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true),
    );
  });

  Future<Map<String, dynamic>> poll() async =>
      (await firestore.collection('polls').doc(pollId).get()).data()!;

  test('first vote counts once and records the answer', () async {
    await service.vote(pollId, 'emotion', 'happy');

    final p = await poll();
    expect(p['emotionCounts'], {'happy': 1});
    expect(p['emotionTotal'], 1);
    final answer = (await firestore
            .collection('users')
            .doc(uid)
            .collection('pollAnswers')
            .doc(pollId)
            .get())
        .data()!;
    expect(answer['emotion'], 'happy');
  });

  // No "move a vote" or "two concurrent taps" case here:
  // fake_cloud_firestore ignores SetOptions(merge) on Transaction.set (it
  // replaces the whole doc), so a second transactional vote can't be
  // checked against it. Real Firestore merges.

  test('re-voting the same option is a no-op', () async {
    await service.vote(pollId, 'emotion', 'happy');
    await service.vote(pollId, 'emotion', 'happy');

    final p = await poll();
    expect(p['emotionCounts'], {'happy': 1});
    expect(p['emotionTotal'], 1);
  });
}
