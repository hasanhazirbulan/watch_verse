import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:watch_verse/models/media.dart';

/// A single public comment on a movie or show. Comments can carry text and an
/// optional image/GIF, and other users can like them.
class Comment {
  final String id;
  final String uid;
  final String name;
  final String? photoURL;
  final String text;
  final String? imageUrl;
  final List<String> likes;
  final DateTime? createdAt;

  /// Set by the moderation Cloud Function once a comment collects enough
  /// reports (see functions/src/index.ts). Hidden comments are filtered out
  /// client-side in [CommentService.stream] rather than queried out, since
  /// most existing docs predate this field and `where('hidden', isEqualTo:
  /// false)` would exclude them too.
  final bool hidden;

  const Comment({
    required this.id,
    required this.uid,
    required this.name,
    required this.photoURL,
    required this.text,
    required this.imageUrl,
    required this.likes,
    required this.createdAt,
    this.hidden = false,
  });

  bool likedBy(String? uid) => uid != null && likes.contains(uid);

  factory Comment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final ts = d['createdAt'];
    return Comment(
      id: doc.id,
      uid: (d['uid'] ?? '') as String,
      name: (d['name'] ?? 'WatchVerse user') as String,
      photoURL: d['photoURL'] as String?,
      text: (d['text'] ?? '') as String,
      imageUrl: d['imageUrl'] as String?,
      likes: (d['likes'] as List?)?.cast<String>() ?? const [],
      createdAt: ts is Timestamp ? ts.toDate() : null,
      hidden: (d['hidden'] ?? false) as bool,
    );
  }
}

/// Public user comments (UGC) on titles — replaces the read-only TMDB reviews.
/// Stored in a top-level `comments` collection keyed by `mediaKey`
/// (`movie-123` / `tv-456`) so a single equality query + client-side sort
/// avoids any composite index.
class CommentService {
  CommentService._();
  static final CommentService instance = CommentService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('comments');

  static String keyFor(MediaType type, int id) => '${type.apiPath}-$id';

  Stream<List<Comment>> stream(MediaType type, int id) {
    return _col
        .where('mediaKey', isEqualTo: keyFor(type, id))
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map(Comment.fromDoc).where((c) => !c.hidden).toList();
      list.sort((a, b) {
        final ta = a.createdAt;
        final tb = b.createdAt;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta); // newest first
      });
      return list;
    });
  }

  Future<void> add({
    required MediaType type,
    required int id,
    required String text,
    String? imageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (text.trim().isEmpty && (imageUrl == null || imageUrl.isEmpty)) return;

    // Prefer the user's WatchVerse profile name/photo over the raw auth record.
    // Never fall back to the email: comments are public.
    final authName = user.displayName?.trim() ?? '';
    String name = authName.isNotEmpty ? authName : 'WatchVerse user';
    String? photo = user.photoURL;
    try {
      final prof = await _db.collection('users').doc(user.uid).get();
      final data = prof.data();
      if (data != null) {
        if ((data['name'] ?? '').toString().isNotEmpty) name = data['name'];
        if ((data['photoURL'] ?? '').toString().isNotEmpty) {
          photo = data['photoURL'];
        }
      }
    } catch (_) {/* fall back to auth fields */}

    await _col.add({
      'mediaKey': keyFor(type, id),
      'mediaType': type.apiPath,
      'mediaId': id,
      'uid': user.uid,
      'name': name,
      'photoURL': photo,
      'text': text.trim(),
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'likes': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleLike(Comment c) async {
    final me = uid;
    if (me == null) return;
    final liked = c.likes.contains(me);
    await _col.doc(c.id).update({
      'likes':
          liked ? FieldValue.arrayRemove([me]) : FieldValue.arrayUnion([me]),
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Files a lightweight moderation report (App Store UGC requirement).
  Future<void> report(String commentId) async {
    final me = uid;
    if (me == null) return;
    await _db.collection('reports').add({
      'commentId': commentId,
      'reportedBy': me,
      'at': FieldValue.serverTimestamp(),
    });
  }
}
