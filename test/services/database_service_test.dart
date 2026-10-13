import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/database_service.dart';

void main() {
  test('createUser does not store the email on the world-readable profile',
      () async {
    final firestore = FakeFirebaseFirestore();
    final service = DatabaseService.test(firestore: firestore);

    await service.createUser(uid: 'u1', email: 'me@example.com', name: 'Me');

    final data = (await firestore.collection('users').doc('u1').get()).data()!;
    expect(data.containsKey('email'), isFalse);
    expect(data['name'], 'Me');
  });

  test('createUser propagates a persistent failure instead of swallowing it',
      () async {
    // It used to catch and debugPrint, so registration "succeeded" with no
    // profile doc at all.
    // Rules that reject every write make each attempt fail.
    final firestore = FakeFirebaseFirestore(securityRules: '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
''');

    await expectLater(
      DatabaseService.test(firestore: firestore).createUser(
          uid: 'u1', email: 'e', name: 'n', retryDelay: Duration.zero),
      throwsA(anything),
    );
  });
}
