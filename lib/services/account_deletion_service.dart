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
    DateTime Function()? now,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage,
        _now = now ?? DateTime.now;

  /// Production instance. Storage must be wired in here: `_storage` is
  /// nullable only so tests can skip the file steps, and leaving it null in
  /// production silently skipped deleting profile/comment images.
  static final AccountDeletionService instance =
      AccountDeletionService._(storage: FirebaseStorage.instance);

  /// Test-only factory. [storage] is nullable so Firestore-level purging can
  /// be verified without a Storage fake — pass null to skip the file steps.
  @visibleForTesting
  factory AccountDeletionService.test({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    FirebaseStorage? storage,
    DateTime Function()? now,
  }) =>
      AccountDeletionService._(
          firestore: firestore, auth: auth, storage: storage, now: now);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage? _storage;
  final DateTime Function() _now;

  /// Test hook: runs after every subcollection is purged but before the
  /// profile doc / Auth user are deleted. Throwing from it simulates the app
  /// being killed at the worst possible moment.
  @visibleForTesting
  Future<void> Function()? debugInterruptAfterPurge;

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

    // Episode notes can outlive their show doc (removeShow() only deletes
    // `watched`), and a subcollection under a missing parent doc never shows
    // up in `shows.get()` below. Collect show ids from the activity timeline
    // *before* it is deleted so those orphaned notes are still found.
    final showIds = <String>{};
    final activity = await userRef.collection('activity').get();
    for (final doc in activity.docs) {
      final showId = doc.data()['showId'];
      if (showId is num) showIds.add(showId.toInt().toString());
    }

    await _deleteAll(userRef.collection('movies'));
    await _deleteAll(userRef.collection('activity'));
    await _deleteAll(userRef.collection('diary'));
    await _deleteAll(userRef.collection('lists'));
    await _deleteAll(userRef.collection('pollAnswers'));
    await _deleteAll(userRef.collection('followedLists'));
    await _deleteAll(userRef.collection('gamePlays'));

    final shows = await userRef.collection('shows').get();
    showIds.addAll(shows.docs.map((d) => d.id));
    for (final showId in showIds) {
      final show = userRef.collection('shows').doc(showId);
      await _deleteAll(show.collection('watched'));
      await _deleteAll(show.collection('notes'));
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
      // update(), not set(merge): if the followed user already deleted their
      // own account, set(merge) would *create* their doc, which the rules
      // only allow for the owner — the resulting permission-denied used to
      // abort every deletion (and every resume) of anyone who followed them.
      try {
        await _db.collection('users').doc(targetUid).update({
          'followers': FieldValue.arrayRemove([uid]),
        });
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
      }
    }
  }

  /// "What should we watch?" polls: deletes the ones this user created
  /// (they carry `creatorName`) and withdraws their votes from the rest.
  /// The rules only let a non-creator touch `options`, so this user's uid
  /// stays in other creators' `memberUids` — the same kind of residue as
  /// the `following` arrays described on the class.
  Future<void> _purgeWatchPolls(String uid) async {
    final polls = await _db
        .collection('watchPolls')
        .where('memberUids', arrayContains: uid)
        .get();
    for (final doc in polls.docs) {
      final data = doc.data();
      if (data['creatorUid'] == uid) {
        await doc.reference.delete();
        continue;
      }
      final options = Map<String, dynamic>.from(data['options'] as Map? ?? {});
      var changed = false;
      for (final key in options.keys.toList()) {
        final opt = options[key];
        if (opt is! Map) continue;
        final votes = List<Object?>.from(opt['votes'] as List? ?? const []);
        if (votes.remove(uid)) {
          options[key] = {...opt, 'votes': votes};
          changed = true;
        }
      }
      if (changed) await doc.reference.update({'options': options});
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

  /// How recent the last sign-in must be before [deleteAccount] will touch
  /// anything. Firebase rejects `user.delete()` with `requires-recent-login`
  /// once the sign-in is older than ~5 minutes; this is deliberately tighter
  /// so the purge itself (which can take a while on a big library) still
  /// finishes inside Firebase's window.
  static const recentLoginWindow = Duration(minutes: 3);

  /// Profile-doc fields marking an account as mid-deletion. Written (merged)
  /// before anything is destroyed and only removed together with the doc.
  static const pendingField = 'deletionPending';
  static const pendingAtField = 'deletionRequestedAt';

  /// Whether the signed-in user's last sign-in is recent enough for
  /// `user.delete()` to succeed. Only a heuristic (device clock vs. server
  /// timestamp) — [resumePendingDeletion] covers the case where it's wrong.
  bool hasRecentLogin() {
    final last = _auth.currentUser?.metadata.lastSignInTime;
    if (last == null) return false;
    return _now().toUtc().difference(last.toUtc()) < recentLoginWindow;
  }

  /// Erases all of the signed-in user's data, then the account itself.
  ///
  /// Built so an interruption (app killed, network drop, stale session) can
  /// never leave a live, normal-looking account on top of an empty library —
  /// the state behind the unresolved "my data disappeared" report in
  /// plan.md:
  ///
  ///  1. **Fail fast on a stale session.** If the last sign-in is outside
  ///     [recentLoginWindow], throws [FirebaseAuthException] with code
  ///     `requires-recent-login` *before any data is touched*. Previously
  ///     this only surfaced at `user.delete()`, after the purge had run.
  ///  2. **Mark the profile doc** `deletionPending: true` (merged, so the
  ///     `following` list [_purgeFollowGraph] reads survives). From here on
  ///     an interrupted run is recognisable: the app checks
  ///     [hasPendingDeletion] on startup/sign-in and finishes the job via
  ///     [resumePendingDeletion] instead of showing an empty library.
  ///  3. Purge comments, follow graph, Storage and subcollections — every
  ///     step is idempotent, so a resume can safely redo any of them.
  ///  4. Delete the profile doc, then the Auth user. Firestore must go first
  ///     (every delete is gated by `request.auth.uid` still being valid). If
  ///     `user.delete()` still fails, a bare `deletionPending` doc (no
  ///     personal data) is written back so the next sign-in resumes rather
  ///     than finding a profile-less account.
  ///
  /// Throws [FirebaseAuthException] (`requires-recent-login`) when nothing
  /// was touched — the caller should ask the user to sign in again — and
  /// [AccountDeletionIncompleteException] when deletion started (data may
  /// already be gone) but couldn't finish — the caller must sign the user
  /// out; signing back in resumes it.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!hasRecentLogin()) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Deleting an account needs a sign-in from the last '
            '${recentLoginWindow.inMinutes} minutes.',
      );
    }

    // Nothing has been destroyed yet, so a failure here leaves the account
    // fully intact — let it propagate as-is.
    await _markPending(user.uid, merge: true);

    await _finish(user);
  }

  /// Whether the signed-in user's profile doc carries the `deletionPending`
  /// marker of a [deleteAccount] run that didn't complete.
  Future<bool> hasPendingDeletion() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final snap = await _db.collection('users').doc(user.uid).get();
    return snap.data()?[pendingField] == true;
  }

  /// Finishes a deletion that [deleteAccount] started but didn't complete.
  /// Returns false (and does nothing) when no deletion is pending.
  ///
  /// Deliberately skips the recent-login pre-check: the data is already
  /// partly gone and the user confirmed the deletion, so purging the rest is
  /// right either way. Only the final `user.delete()` may still need a fresh
  /// sign-in, reported as [AccountDeletionIncompleteException].
  Future<bool> resumePendingDeletion() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (!await hasPendingDeletion()) return false;
    await _finish(user);
    return true;
  }

  Future<void> _markPending(String uid, {required bool merge}) =>
      _db.collection('users').doc(uid).set({
        pendingField: true,
        pendingAtField: FieldValue.serverTimestamp(),
      }, SetOptions(merge: merge));

  /// Steps 3–4 of [deleteAccount]. Runs only once the pending marker is set,
  /// so every failure is surfaced as [AccountDeletionIncompleteException] —
  /// the account must not be treated as intact afterwards.
  Future<void> _finish(User user) async {
    final uid = user.uid;
    try {
      await _purgeComments(uid);
      await _purgeFollowGraph(uid); // reads this user's own `following` field — must run before the profile doc is deleted
      await _purgeWatchPolls(uid);
      await _purgeStoredFiles(uid);
      await _purgeOwnData(uid);
      await debugInterruptAfterPurge?.call();
      // Last Firestore write: the marker goes away only together with the
      // doc, once everything under it is already gone.
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      throw AccountDeletionIncompleteException(e);
    }

    try {
      await user.delete();
    } catch (e) {
      // The profile doc is gone but the account is not. Put back a bare
      // marker so the next sign-in resumes instead of landing on an account
      // with no profile at all. Best-effort: the caller is told the
      // deletion didn't finish either way.
      try {
        await _markPending(uid, merge: false);
      } catch (_) {}
      throw AccountDeletionIncompleteException(e);
    }
  }
}

/// [AccountDeletionService] started erasing the account (the profile doc is
/// marked `deletionPending`, and some data may already be gone) but couldn't
/// finish. Don't keep using the account as if it were intact: sign the user
/// out — signing back in resumes the deletion.
class AccountDeletionIncompleteException implements Exception {
  AccountDeletionIncompleteException(this.cause);

  final Object cause;

  @override
  String toString() => 'AccountDeletionIncompleteException: $cause';
}
