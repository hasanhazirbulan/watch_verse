import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Social graph: follow/unfollow, user search, and reading other users' public
/// library + activity. Follower/following are stored as arrays on the user doc
/// (`followers` / `following`), matching the project's security rules.
class SocialService {
  SocialService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  static final SocialService instance = SocialService._();

  /// Test-only factory: inject a fake Firestore/Auth instead of touching
  /// real backends.
  @visibleForTesting
  factory SocialService.test(
          {required FirebaseFirestore firestore, required FirebaseAuth auth}) =>
      SocialService._(firestore: firestore, auth: auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  String? get uid => _auth.currentUser?.uid;

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

  /// [limit] defaults to 30 for callers showing one user's whole rail (e.g.
  /// [PublicProfileScreen]); friend fan-outs (see [friendsWatchedMovies])
  /// pass a much smaller limit since most of a high per-friend cap gets
  /// discarded after merging anyway — safe to lower only because of the
  /// `orderBy` here, which guarantees a small limit still returns the
  /// genuinely most-recent watches rather than an arbitrary 30.
  Future<List<Map<String, dynamic>>> userWatchedMovies(String userId,
      {int limit = 30}) async {
    try {
      final s = await _users
          .doc(userId)
          .collection('movies')
          .where('status', isEqualTo: 'watched')
          .orderBy('watchedAt', descending: true)
          .limit(limit)
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

  /// See [userWatchedMovies] re: [limit] and why a small one is safe here.
  Future<List<Map<String, dynamic>>> userShows(String userId,
      {int limit = 30}) async {
    try {
      final s = await _users
          .doc(userId)
          .collection('shows')
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();
      return s.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Batches the `name`/`photoURL` lookup for up to 20 uids into one query
  /// instead of one read per friend — [friendsActivity],
  /// [friendsWatchedMovies], and [friendsWatchedShows] each used to call
  /// `_users.doc(u).get()` inside their per-friend fan-out, turning every
  /// feed load into (friend count) extra reads on top of the per-friend
  /// content query that still has to happen separately. `whereIn` tops out
  /// at 30, well above the 20-friend cap these callers already use.
  Future<Map<String, Map<String, dynamic>>> _profilesByUid(
      List<String> uids) async {
    if (uids.isEmpty) return {};
    try {
      final snap =
          await _users.where(FieldPath.documentId, whereIn: uids).get();
      return {for (final d in snap.docs) d.id: d.data()};
    } catch (_) {
      return {};
    }
  }

  /// Merged, newest-first activity from the people [followingUids] follows.
  Future<List<Map<String, dynamic>>> friendsActivity(
      List<String> followingUids) async {
    if (followingUids.isEmpty) return [];
    final uids = followingUids.take(20).toList();
    final profiles = await _profilesByUid(uids);
    final lists = await Future.wait(uids.map((u) async {
      try {
        final name = (profiles[u]?['name'] ?? '') as String;
        final photo = (profiles[u]?['photoURL'] ?? '') as String;
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

  /// Movies followed users have watched, newest-watched first, tagged with
  /// who watched it — powers the home screen's "Your Friends Also Watched"
  /// slider. Same per-friend fan-out as [friendsActivity], but reads the raw
  /// movie docs (via [userWatchedMovies]) instead of the activity feed, so
  /// `rating` is guaranteed present when the friend rated it.
  Future<List<Map<String, dynamic>>> friendsWatchedMovies(
      List<String> followingUids, {int limit = 20}) async {
    if (followingUids.isEmpty) return [];
    final uids = followingUids.take(20).toList();
    final profiles = await _profilesByUid(uids);
    final lists = await Future.wait(uids.map((u) async {
      try {
        final name = (profiles[u]?['name'] ?? '') as String;
        final photo = (profiles[u]?['photoURL'] ?? '') as String;
        // Only a handful per friend — the merge below keeps just the top
        // [limit] across everyone anyway, so fetching each friend's full 30
        // here (like PublicProfileScreen does for one person) would mean
        // reading hundreds of docs just to discard nearly all of them.
        final movies = await userWatchedMovies(u, limit: 5);
        return movies
            .map((m) => {...m, 'actorName': name, 'actorPhoto': photo, 'actorUid': u})
            .toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }));
    final all = lists.expand((e) => e).toList();
    all.sort((a, b) {
      final ta = a['watchedAt'];
      final tb = b['watchedAt'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return _groupByContent(all, limit);
  }

  /// Merges per-friend fan-out results that share the same content id into
  /// one entry (so 3 friends watching the same movie renders as one card
  /// tagged with all 3, not 3 duplicate cards) — `items` must already be
  /// sorted newest-first; the first-seen doc per id becomes the
  /// representative (poster/rating fields), and every contributor lands in
  /// its `friends` list, in the same newest-first order.
  List<Map<String, dynamic>> _groupByContent(
      List<Map<String, dynamic>> items, int limit) {
    final order = <int>[];
    final representative = <int, Map<String, dynamic>>{};
    final friends = <int, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final id = (item['id'] ?? 0) as int;
      final friend = {
        'uid': item['actorUid'],
        'name': item['actorName'],
        'photo': item['actorPhoto'],
      };
      if (!representative.containsKey(id)) {
        representative[id] = item;
        friends[id] = [friend];
        order.add(id);
      } else {
        friends[id]!.add(friend);
      }
    }
    return [
      for (final id in order.take(limit))
        {...representative[id]!, 'friends': friends[id]!},
    ];
  }

  /// Shows followed users are watching/have finished, newest-updated first,
  /// tagged with who watched it — same shape as [friendsWatchedMovies], for
  /// the TV Shows tab of the friends slider. `userRating` is the friend's
  /// overall show rating (set via TvTrackingService.setRating), present
  /// directly on the show doc.
  Future<List<Map<String, dynamic>>> friendsWatchedShows(
      List<String> followingUids, {int limit = 20}) async {
    if (followingUids.isEmpty) return [];
    final uids = followingUids.take(20).toList();
    final profiles = await _profilesByUid(uids);
    final lists = await Future.wait(uids.map((u) async {
      try {
        final name = (profiles[u]?['name'] ?? '') as String;
        final photo = (profiles[u]?['photoURL'] ?? '') as String;
        // A bit more headroom than the movies fetch (7 vs. 5): some of the
        // most-recently-updated shows can be watchlist-only (watchedCount 0)
        // and get filtered out below, so a slightly larger pull keeps a
        // margin against under-filling this friend's slot in the merge.
        final shows = (await userShows(u, limit: 7))
            .where((s) => ((s['watchedCount'] ?? 0) as num) > 0)
            .toList();
        return shows
            .map((s) => {...s, 'actorName': name, 'actorPhoto': photo, 'actorUid': u})
            .toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }));
    final all = lists.expand((e) => e).toList();
    all.sort((a, b) {
      final ta = a['updatedAt'];
      final tb = b['updatedAt'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return _groupByContent(all, limit);
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

  /// Whether [targetUid]'s profile doc still exists. When it doesn't (that
  /// user deleted their account), a `set(merge)` of their `followers` would
  /// be a *create*, which the rules only allow for the owner — and since it
  /// shares a batch with this user's own write, the whole unfollow/block
  /// was rejected, leaving the deleted account stuck in `following`.
  Future<bool> _profileExists(String targetUid) async =>
      (await _users.doc(targetUid).get()).exists;

  Future<void> unfollow(String targetUid) async {
    final me = uid;
    if (me == null) return;
    final targetExists = await _profileExists(targetUid);
    final batch = _db.batch();
    if (targetExists) {
      batch.set(_users.doc(targetUid),
          {'followers': FieldValue.arrayRemove([me])}, SetOptions(merge: true));
    }
    batch.set(_users.doc(me),
        {'following': FieldValue.arrayRemove([targetUid])},
        SetOptions(merge: true));
    await batch.commit();
  }

  // -------------------------------------------------------------- blocking --

  /// UIDs the current user has blocked (their comments/content are hidden).
  Stream<List<String>> blockedStream() => myStream()
      .map((d) => (d?['blocked'] as List?)?.cast<String>() ?? const <String>[]);

  /// Blocks a user. Exactly what changes:
  ///  * their uid is added to *your* `blocked` list (their comments/content
  ///    are hidden from you client-side);
  ///  * you stop following them (removed from your `following`, and you from
  ///    their `followers`);
  ///  * they are removed from *your* `followers`.
  /// What it can't do: their own `following` array still lists you — the
  /// rules only allow cross-user writes to `followers`, so that entry stays
  /// until they unfollow. Nothing here stops them reading your public
  /// profile either; blocking is a "hide from me" filter, not access control.
  Future<void> block(String targetUid) async {
    final me = uid;
    if (me == null || me == targetUid) return;
    final targetExists = await _profileExists(targetUid);
    final batch = _db.batch();
    batch.set(
        _users.doc(me),
        {
          'blocked': FieldValue.arrayUnion([targetUid]),
          'following': FieldValue.arrayRemove([targetUid]),
          'followers': FieldValue.arrayRemove([targetUid]),
        },
        SetOptions(merge: true));
    // Remove me from their followers (the one field of theirs the rules let
    // us touch) so I no longer show up as following them.
    if (targetExists) {
      batch.set(_users.doc(targetUid),
          {'followers': FieldValue.arrayRemove([me])}, SetOptions(merge: true));
    }
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
