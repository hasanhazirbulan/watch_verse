import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/app_firebase.dart';

/// "What should we watch?" group polls — a small friend group picks between
/// a handful of movie/show candidates. Distinct from [PollService] (which
/// aggregates "how was it?" opinions across *everyone* on a specific
/// title): a watch poll is scoped to one specific group of invited members
/// and votes are single-choice per member.
///
/// One doc per poll at top-level `watchPolls/{pollId}` (not nested under a
/// user, since every member needs to read and vote on it):
///   title         : string
///   creatorUid/creatorName
///   memberUids    : [uid, ...]              — creator + everyone invited
///   options       : { "movie-123": {id, mediaType, title, posterPath,
///                      votes: [uid, ...]}, ... }
///   status        : 'open' | 'closed'
class WatchPollService {
  WatchPollService._();
  static final WatchPollService instance = WatchPollService._();

  final FirebaseFirestore _db = AppFirebase.firestore;
  String? get _uid => AppFirebase.auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('watchPolls');

  static String optionKeyFor(MediaItem m) => '${m.mediaType.apiPath}-${m.id}';

  // ----------------------------------------------------------------- reads --

  /// Polls this user created or was invited to, most-recently-active first.
  Stream<List<Map<String, dynamic>>> myPollsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _col
        .where('memberUids', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Stream<Map<String, dynamic>?> pollStream(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? {...d.data()!, 'id': d.id} : null);

  // ---------------------------------------------------------------- writes --

  Future<String?> createPoll({
    required String title,
    required List<MediaItem> options,
    required List<String> invitedUids,
  }) async {
    final uid = _uid;
    if (uid == null || options.isEmpty) return null;
    final me = await _db.collection('users').doc(uid).get();
    final creatorName = (me.data()?['name'] ?? '') as String;

    final doc = _col.doc();
    await doc.set({
      'title': title.trim().isEmpty ? null : title.trim(),
      'creatorUid': uid,
      'creatorName': creatorName,
      'memberUids': [uid, ...invitedUids.where((u) => u != uid)],
      'options': {
        for (final o in options)
          optionKeyFor(o): {
            'id': o.id,
            'mediaType': o.mediaType.apiPath,
            'title': o.title,
            'posterPath': o.posterPath,
            'votes': <String>[],
          },
      },
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Casts (or moves) this user's single vote to [optionKey]. Voting the
  /// option you already picked un-votes it (toggle).
  Future<void> vote(String pollId, String optionKey) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _col.doc(pollId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      final options = Map<String, dynamic>.from(data['options'] as Map? ?? {});
      var alreadyOnChosen = false;

      for (final key in options.keys.toList()) {
        final opt = Map<String, dynamic>.from(options[key] as Map);
        final votes = List<String>.from((opt['votes'] as List?) ?? const []);
        final had = votes.remove(uid);
        if (key == optionKey && had) alreadyOnChosen = true;
        opt['votes'] = votes;
        options[key] = opt;
      }

      if (!alreadyOnChosen && options.containsKey(optionKey)) {
        final chosen = Map<String, dynamic>.from(options[optionKey] as Map);
        final votes = List<String>.from((chosen['votes'] as List?) ?? const []);
        votes.add(uid);
        chosen['votes'] = votes;
        options[optionKey] = chosen;
      }

      tx.update(ref, {
        'options': options,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Creator-only: locks in the current standings so the poll reads as
  /// decided rather than still-open.
  Future<void> closePoll(String pollId) async {
    await _col.doc(pollId).set(
        {'status': 'closed', 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  Future<void> deletePoll(String pollId) async {
    await _col.doc(pollId).delete();
  }
}
