import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cross-user "how was it?" poll (platform watched on / emotion felt /
/// favorite character), shown right after a movie or episode is marked
/// watched — TV Time-style.
///
/// Layout:
///   polls/{pollId}                        -> aggregate counts, readable by
///                                             every signed-in user
///   users/{uid}/pollAnswers/{pollId}       -> this user's own answers, so we
///                                             know what (if anything) they
///                                             already picked in each category
///
/// `characterCounts` is keyed by TMDB cast id (not the character's name) so a
/// name containing `.`, `/`, `[`, `]` or `~` (all forbidden in Firestore map
/// keys) can never break a write — the UI already has the cast list in
/// memory to turn an id back into a label.
class PollService {
  PollService._();
  static final PollService instance = PollService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static const emotionOptions = [
    'happy',
    'confusing',
    'sad',
    'scary',
    'frustrating',
    'shocking',
    'exciting',
    'boring',
  ];

  String moviePollId(int movieId) => 'movie-$movieId';
  String episodePollId(int showId, int season, int episode) =>
      'episode-$showId-s${season}e$episode';

  DocumentReference<Map<String, dynamic>> _pollRef(String pollId) =>
      _db.collection('polls').doc(pollId);

  DocumentReference<Map<String, dynamic>>? _answerRef(String pollId) {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('pollAnswers')
        .doc(pollId);
  }

  /// Live aggregate counts for a poll (null until the first vote).
  Stream<Map<String, dynamic>?> statsStream(String pollId) =>
      _pollRef(pollId).snapshots().map((s) => s.exists ? s.data() : null);

  /// Live view of this user's own answers for a poll.
  Stream<Map<String, dynamic>?> myAnswerStream(String pollId) {
    final ref = _answerRef(pollId);
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map((s) => s.exists ? s.data() : null);
  }

  /// Casts (or moves) this user's vote for [category] ('platform', 'emotion'
  /// or 'character') to [value]. A no-op if it matches their existing pick.
  Future<void> vote(String pollId, String category, String value) async {
    final answerRef = _answerRef(pollId);
    if (answerRef == null) return;

    final answerSnap = await answerRef.get();
    final previous = answerSnap.data()?[category] as String?;
    if (previous == value) return;

    final pollRef = _pollRef(pollId);
    final countsField = '${category}Counts';
    final totalField = '${category}Total';

    if (previous != null) {
      await pollRef.set({
        countsField: {previous: FieldValue.increment(-1)},
      }, SetOptions(merge: true));
    }
    await pollRef.set({
      countsField: {value: FieldValue.increment(1)},
      if (previous == null) totalField: FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await answerRef.set({
      category: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
