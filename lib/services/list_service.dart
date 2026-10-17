import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/pro_service.dart';
import 'package:watch_verse/services/app_firebase.dart';

/// Thrown by [ListService.createList] when a free account is already at the
/// [ListService.freeListLimit] and tries to create another list. Callers
/// catch this specifically to open the Pro paywall instead of a generic
/// error (see `lists_screen.dart`).
class ListLimitReachedException implements Exception {
  const ListLimitReachedException();
}

/// User-created custom lists (Letterboxd-style), e.g. "Watch in 2026", "Top 10".
///
/// One doc per list at `users/{uid}/lists/{listId}`. Items live in an `items`
/// **map** keyed by `mediaKey` (`movie-123` / `tv-456`) → so membership,
/// de-dupe, count and display all come from the single list doc with no
/// subcollection or composite index. Covered by the existing owner-write rule.
class ListService {
  ListService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? AppFirebase.firestore,
        _auth = auth ?? AppFirebase.auth;
  static final ListService instance = ListService._();

  /// Test-only factory: inject a fake Firestore/Auth instead of touching
  /// real backends.
  @visibleForTesting
  factory ListService.test(
          {required FirebaseFirestore firestore, required FirebaseAuth auth}) =>
      ListService._(firestore: firestore, auth: auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('lists');
  }

  /// This user's own record of a list they follow — a self-owned doc, not a
  /// write to the list owner's data, so it needs no new cross-user security
  /// rule (unlike SocialService.follow(), which does write into another
  /// user's doc and carries a documented caveat for it — see
  /// firestore.rules). Denormalizes enough to render a preview card without
  /// re-fetching the source list.
  CollectionReference<Map<String, dynamic>>? get _followedCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('followedLists');
  }

  static String _followedRefId(String ownerUid, String listId) =>
      '${ownerUid}_$listId';

  static String keyFor(MediaItem m) => '${m.mediaType.apiPath}-${m.id}';

  /// The display items of a list doc, newest-added first.
  static List<MediaItem> itemsFrom(Map<String, dynamic>? list) {
    final map = (list?['items'] as Map?) ?? const {};
    final values = map.values.whereType<Map>().toList()
      ..sort((a, b) =>
          ((b['addedAt'] ?? 0) as num).compareTo((a['addedAt'] ?? 0) as num));
    return values
        .map((v) => MediaItem(
              id: (v['id'] ?? 0) as int,
              title: (v['title'] ?? '') as String,
              overview: '',
              posterPath: (v['posterPath'] ?? '') as String,
              backdropPath: '',
              date: '',
              voteAverage: 0,
              mediaType:
                  v['mediaType'] == 'tv' ? MediaType.tv : MediaType.movie,
            ))
        .toList();
  }

  static int countOf(Map<String, dynamic> list) =>
      ((list['items'] as Map?) ?? const {}).length;

  // ------------------------------------------------------------------ reads --

  Stream<List<Map<String, dynamic>>> listsStream() {
    final col = _col;
    if (col == null) return Stream.value([]);
    return col.orderBy('updatedAt', descending: true).snapshots().map(
        (s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Stream<Map<String, dynamic>?> listStream(String id) {
    final col = _col;
    if (col == null) return Stream.value(null);
    return col
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? {...d.data()!, 'id': d.id} : null);
  }

  /// Live read of a list belonging to [ownerUid] — works for your own lists
  /// and, thanks to the public-read rule below, anyone else's *public*
  /// list too. Used both for viewing a friend's public list and for
  /// re-rendering something already in [followedListsStream].
  Stream<Map<String, dynamic>?> publicListStream(
      String ownerUid, String listId) {
    return _db
        .collection('users')
        .doc(ownerUid)
        .collection('lists')
        .doc(listId)
        .snapshots()
        .map((d) => d.exists
            ? {...d.data()!, 'id': d.id, 'ownerUid': ownerUid}
            : null);
  }

  /// [ownerUid]'s public lists — for their public profile screen. A plain
  /// one-time fetch (matches the other userXxx() reads in SocialService)
  /// rather than a stream, since a visited profile doesn't need to update
  /// live.
  Future<List<Map<String, dynamic>>> publicListsFor(String ownerUid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(ownerUid)
          .collection('lists')
          .where('public', isEqualTo: true)
          .get();
      return snap.docs
          .map((d) => {...d.data(), 'id': d.id, 'ownerUid': ownerUid})
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Lists this user follows, newest-followed first.
  Stream<List<Map<String, dynamic>>> followedListsStream() {
    final col = _followedCol;
    if (col == null) return Stream.value([]);
    return col.orderBy('addedAt', descending: true).snapshots().map(
        (s) => s.docs.map((d) => {...d.data(), 'refId': d.id}).toList());
  }

  Stream<bool> isFollowingListStream(String ownerUid, String listId) {
    final col = _followedCol;
    if (col == null) return Stream.value(false);
    return col
        .doc(_followedRefId(ownerUid, listId))
        .snapshots()
        .map((d) => d.exists);
  }

  // ----------------------------------------------------------------- writes --

  /// Custom lists a free (non-Pro) account can have at once. WatchVerse Pro
  /// removes this cap entirely.
  static const freeListLimit = 3;

  Future<String?> createList(String name) async {
    final col = _col;
    if (col == null) return null;
    if (!ProService.instance.isPro) {
      final existing = await col.count().get();
      if ((existing.count ?? 0) >= freeListLimit) {
        throw const ListLimitReachedException();
      }
    }
    final doc = col.doc();
    await doc.set({
      'name': name,
      'items': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> renameList(String id, String name) async {
    await _col?.doc(id).set(
        {'name': name, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  /// Makes a list visible on the owner's public profile and readable
  /// (read-only) by other signed-in users — see the relaxed `lists` read
  /// rule in firestore.rules. Defaults to private (missing/false).
  Future<void> setPublic(String id, bool public) async {
    await _col?.doc(id).set(
        {'public': public, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  /// Follows someone else's public list — a doc under *this* user's own
  /// `followedLists`, not a write to the owner's list, so it needs no
  /// cross-user write permission. [ownerName]/[listName]/[coverPosterPath]
  /// are denormalized for the "lists I follow" preview card.
  Future<void> followList({
    required String ownerUid,
    required String listId,
    required String ownerName,
    required String listName,
    String coverPosterPath = '',
  }) async {
    final col = _followedCol;
    if (col == null || ownerUid == _uid) return; // can't follow your own list
    await col.doc(_followedRefId(ownerUid, listId)).set({
      'ownerUid': ownerUid,
      'listId': listId,
      'ownerName': ownerName,
      'listName': listName,
      'coverPosterPath': coverPosterPath,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollowList(String ownerUid, String listId) async {
    await _followedCol?.doc(_followedRefId(ownerUid, listId)).delete();
  }

  Future<void> deleteList(String id) async {
    await _col?.doc(id).delete();
  }

  Future<void> addToList(String listId, MediaItem m) async {
    final key = keyFor(m);
    await _col?.doc(listId).set({
      'items': {
        key: {
          'mediaType': m.mediaType.apiPath,
          'id': m.id,
          'title': m.title,
          'posterPath': m.posterPath,
          'addedAt': DateTime.now().millisecondsSinceEpoch,
        }
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeFromList(String listId, String key) async {
    await _col?.doc(listId).update({
      'items.$key': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
