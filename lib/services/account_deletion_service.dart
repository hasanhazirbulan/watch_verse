import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Erases everything the app stores about one user, so "Delete account" in
/// Settings matches what the privacy policy promises (docs/privacy-policy.html).
///
/// Runs entirely client-side and therefore must finish *while the user is
/// still signed in* — every delete below is gated by the security rules on
/// `request.auth.uid`, so calling this after `user.delete()` would be
/// rejected.
///
/// Two things are deliberately out of reach from the client and are documented
/// in the privacy policy rather than silently skipped:
///
///  * `reports/{id}` — moderation records. The rules make them write-only
///    (`allow read: if false`), so they cannot even be queried here. They are
///    retained on legitimate-interest grounds for abuse handling.
///  * The `following` array of users who followed *this* user. The rules only
///    carve out `followers` for cross-user writes, so removing a dangling uid
///    from someone else's `following` list needs either a rules change or a
///    Cloud Function running with the Admin SDK.
///
/// Storage deletions are best-effort: a missing object is not an error (the
/// user may never have uploaded a photo), and a storage failure must not
/// abort the Firestore purge that carries the bulk of the personal data.
class AccountDeletionService {
  AccountDeletionService._({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage;

  static final AccountDeletionService instance = AccountDeletionService._();

  /// Test-only factory. [storage] is nullable so Firestore-level purging can
  /// be verified without a Storage fake — pass null to skip the file steps.
  @visibleForTesting
  factory AccountDeletionService.test({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    FirebaseStorage? storage,
  }) =>
      AccountDeletionService._(
          firestore: firestore, auth: auth, storage: storage);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage? _storage;

  /// Firestore caps a write batch at 500 operations; stay under it.
  static const _batchSize = 400;

  /// Deletes every document matched by [query], in batches.
  Future<void> _deleteAll(Query<Map<String, dynamic>> query) async {
    final snap = await query.get();
    for (var i = 0; i < snap.docs.length; i += _batchSize) {
      final batch = _db.batch();
      for (final doc in snap.docs.skip(i).take(_batchSize)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Removes the user's own library, history and private notes.
  Future<void> _purgeOwnData(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    await _deleteAll(userRef.collection('movies'));
    await _deleteAll(userRef.collection('activity'));
    await _deleteAll(userRef.collection('diary'));
    await _deleteAll(userRef.collection('lists'));
    await _deleteAll(userRef.collection('pollAnswers'));

    final shows = await userRef.collection('shows').get();
    for (final show in shows.docs) {
      await _deleteAll(show.reference.collection('watched'));
      await _deleteAll(show.reference.collection('notes'));
    }
    await _deleteAll(userRef.collection('shows'));
  }

  /// Deletes the user's public comments and strips their uid out of the
  /// `likes` array of everyone else's comments — a uid sitting in a likes
  /// array still links this person to a title, so it is personal data too.
  Future<void> _purgeComments(String uid) async {
    final comments = _db.collection('comments');

    await _deleteAll(comments.where('uid', isEqualTo: uid));

    final liked = await comments.where('likes', arrayContains: uid).get();
    for (var i = 0; i < liked.docs.length; i += _batchSize) {
      final batch = _db.batch();
      for (final doc in liked.docs.skip(i).take(_batchSize)) {
        batch.update(doc.reference, {
          'likes': FieldValue.arrayRemove([uid]),
        });
      }
      await batch.commit();
    }
  }

  /// Removes this user from the `followers` array of everyone they followed,
  /// so no dangling uid is left behind on another profile.
  Future<void> _purgeFollowGraph(String uid) async {
    final me = await _db.collection('users').doc(uid).get();
    final following =
        (me.data()?['following'] as List?)?.cast<String>() ?? const <String>[];

    for (final targetUid in following) {
      await _db.collection('users').doc(targetUid).set({
        'followers': FieldValue.arrayRemove([uid]),
      }, SetOptions(merge: true));
    }
  }

  /// Deletes the profile picture and every image attached to a comment.
  /// Best-effort: object-not-found and permission errors are swallowed so a
  /// storage hiccup cannot strand a half-deleted account.
  Future<void> _purgeStoredFiles(String uid) async {
    final storage = _storage;
    if (storage == null) return;

    try {
      await storage.ref('profile_images/$uid.jpg').delete();
    } on FirebaseException catch (_) {
      // No profile photo was ever uploaded, or it is already gone.
    }

    try {
      final images = await storage.ref('comment_images/$uid').listAll();
      for (final item in images.items) {
        await item.delete();
      }
    } on FirebaseException catch (_) {
      // Nothing uploaded, or the folder is already empty.
    }
  }

  /// Erases all of the signed-in user's data, then the account itself.
  ///
  /// Order matters: Firestore and Storage first (they need a live auth token),
  /// the auth record last. Throws [FirebaseAuthException] with code
  /// `requires-recent-login` if the session is too old — the caller is
  /// expected to prompt for re-authentication and try again.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    await _purgeComments(uid);
    await _purgeFollowGraph(uid);
    await _purgeStoredFiles(uid);
    await _purgeOwnData(uid);
    await _db.collection('users').doc(uid).delete();

    await user.delete();
  }
}
