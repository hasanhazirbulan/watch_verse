import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Social graph: follow/unfollow, user search, and reading other users' public
/// library + activity. Follower/following are stored as arrays on the user doc
/// (`followers` / `following`), matching the project's security rules.
class SocialService {
  SocialService._();
  static final SocialService instance = SocialService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ----------------------------------------------------------------- reads --

  Stream<Map<String, dynamic>?> userStream(String userId) => _users
      .doc(userId)
      .snapshots()
      .map((s) => s.exists ? {...s.data()!, 'uid': userId} : null);

  Stream<Map<String, dynamic>?> myStream() {
    final me = uid;
    if (me == null) return Stream.value(null);
    return userStream(me);
  }

  Stream<bool> isFollowingStream(String targetUid) => myStream().map((d) {
        final list = (d?['following'] as List?) ?? const [];
        return list.contains(targetUid);
      });

  /// Prefix search on the `name` field (case-sensitive; good enough for MVP).
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final snap = await _users
          .orderBy('name')
          .startAt([q])
          .endAt(['$q'])
          .limit(25)
          .get();
      return snap.docs
          .where((d) => d.id != uid)
          .map((d) => {...d.data(), 'uid': d.id})
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> usersByIds(List<String> ids) async {
    final out = <Map<String, dynamic>>[];
    for (final id in ids.take(50)) {
      try {
        final s = await _users.doc(id).get();
        if (s.exists) out.add({...s.data()!, 'uid': id});
      } catch (_) {/* skip */}
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> userWatchedMovies(String userId) async {
    try {
      final s = await _users
          .doc(userId)
          .collection('movies')
          .where('status', isEqualTo: 'watched')
          .limit(30)
          .get();
      return s.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> userFavoriteMovies(String userId) async {
    try {
      final s = await _users
          .doc(userId)
          .collection('movies')
          .where('favorite', isEqualTo: true)
          .limit(20)
          .get();
      return s.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> userShows(String userId) async {
    try {
      final s =
          await _users.doc(userId).collection('shows').limit(30).get();
      return s.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Merged, newest-first activity from the people [followingUids] follows.
  Future<List<Map<String, dynamic>>> friendsActivity(
      List<String> followingUids) async {
    if (followingUids.isEmpty) return [];
    final lists =
        await Future.wait(followingUids.take(20).map((u) async {
      try {
        final userSnap = await _users.doc(u).get();
        final name = (userSnap.data()?['name'] ?? '') as String;
        final photo = (userSnap.data()?['photoURL'] ?? '') as String;
        final act = await _users
            .doc(u)
            .collection('activity')
            .orderBy('at', descending: true)
            .limit(8)
            .get();
        return act.docs
            .map((d) => {
                  ...d.data(),
                  'actorName': name,
                  'actorPhoto': photo,
                  'actorUid': u,
                })
            .toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }));
    final all = lists.expand((e) => e).toList();
    all.sort((a, b) {
      final ta = a['at'];
      final tb = b['at'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return all;
  }

  // ---------------------------------------------------------------- writes --

  Future<void> follow(String targetUid) async {
    final me = uid;
    if (me == null || me == targetUid) return;
    final batch = _db.batch();
    batch.set(_users.doc(targetUid),
        {'followers': FieldValue.arrayUnion([me])}, SetOptions(merge: true));
    batch.set(_users.doc(me),
        {'following': FieldValue.arrayUnion([targetUid])},
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> unfollow(String targetUid) async {
    final me = uid;
    if (me == null) return;
    final batch = _db.batch();
    batch.set(_users.doc(targetUid),
        {'followers': FieldValue.arrayRemove([me])}, SetOptions(merge: true));
    batch.set(_users.doc(me),
        {'following': FieldValue.arrayRemove([targetUid])},
        SetOptions(merge: true));
    await batch.commit();
  }

  // -------------------------------------------------------------- blocking --

  /// UIDs the current user has blocked (their comments/content are hidden).
  Stream<List<String>> blockedStream() => myStream()
      .map((d) => (d?['blocked'] as List?)?.cast<String>() ?? const <String>[]);

  /// Blocks a user: hides them from you and also drops any follow relationship.
  Future<void> block(String targetUid) async {
    final me = uid;
    if (me == null || me == targetUid) return;
    final batch = _db.batch();
    batch.set(
        _users.doc(me),
        {
          'blocked': FieldValue.arrayUnion([targetUid]),
          'following': FieldValue.arrayRemove([targetUid]),
        },
        SetOptions(merge: true));
    // Remove me from their followers so the block takes effect both ways.
    batch.set(_users.doc(targetUid),
        {'followers': FieldValue.arrayRemove([me])}, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> unblock(String targetUid) async {
    final me = uid;
    if (me == null) return;
    await _users.doc(me).set(
        {'blocked': FieldValue.arrayRemove([targetUid])},
        SetOptions(merge: true));
  }
}
