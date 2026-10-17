import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:watch_verse/services/app_firebase.dart';

/// Per-day progress for the bundled-pool games, stored at
/// `users/{uid}/gamePlays/{game}-{mode}-{yyyy-mm-dd}` so a finished puzzle
/// stays finished on every device. Reuses the original daily game's
/// owner-only `gamePlays` rule — no rules change needed — and is wiped with
/// the rest of `gamePlays` by account deletion.
///
/// Guests (no Firebase user) play locally: [load] returns null and [save] is
/// a no-op.
class GamePlayStore {
  GamePlayStore._({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _dbOverride = firestore,
      _authOverride = auth;
  static final GamePlayStore instance = GamePlayStore._();

  @visibleForTesting
  factory GamePlayStore.test({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) => GamePlayStore._(firestore: firestore, auth: auth);

  // Resolved lazily so merely constructing a game screen in a widget test
  // doesn't require an initialized Firebase app.
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _db => _dbOverride ?? AppFirebase.firestore;
  FirebaseAuth get _auth => _authOverride ?? AppFirebase.auth;

  bool get isSignedIn => _auth.currentUser != null;

  DocumentReference<Map<String, dynamic>>? _doc(String docId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('gamePlays').doc(docId);
  }

  /// The saved state, or null for a guest / a puzzle not started yet.
  Future<Map<String, dynamic>?> load(String docId) async {
    final ref = _doc(docId);
    if (ref == null) return null;
    final snap = await ref.get();
    return snap.data();
  }

  /// Overwrites the saved state (the client holds the whole, small state, so
  /// a full write is simpler and safer than merging list fields).
  Future<void> save(String docId, Map<String, dynamic> state) async {
    final ref = _doc(docId);
    if (ref == null) return;
    await ref.set({...state, 'updatedAt': FieldValue.serverTimestamp()});
  }
}
