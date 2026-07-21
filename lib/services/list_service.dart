import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:watch_verse/models/media.dart';

/// User-created custom lists (Letterboxd-style), e.g. "Watch in 2026", "Top 10".
///
/// One doc per list at `users/{uid}/lists/{listId}`. Items live in an `items`
/// **map** keyed by `mediaKey` (`movie-123` / `tv-456`) → so membership,
/// de-dupe, count and display all come from the single list doc with no
/// subcollection or composite index. Covered by the existing owner-write rule.
class ListService {
  ListService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
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

  // ----------------------------------------------------------------- writes --

  Future<String?> createList(String name) async {
    final col = _col;
    if (col == null) return null;
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
