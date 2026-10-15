import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:watch_verse/utils/avatar_image.dart';

/// Thrown when a picked photo can't be made small enough to store inline.
class ProfilePhotoTooLargeException implements Exception {
  const ProfilePhotoTooLargeException();
  @override
  String toString() => 'photo is too large after compression';
}

/// Sets/removes the signed-in user's profile photo. The photo is a small
/// image `data:` URI in `users/{uid}.photoURL` — the project is on the Spark
/// plan, which has no Cloud Storage bucket (see utils/avatar_image.dart).
class ProfilePhotoService {
  ProfilePhotoService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final ProfilePhotoService instance = ProfilePhotoService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _userRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to change your photo.');
    return _db.collection('users').doc(uid);
  }

  /// Stores [bytes] (as picked: ideally a ≤192px JPEG, but PNG/GIF are
  /// shrunk to fit) and returns the saved `data:` URI.
  Future<String> setPhoto(Uint8List bytes) async {
    final ref = _userRef();
    final fitted = await shrinkAvatar(bytes);
    final url = fitted == null ? null : avatarDataUri(fitted);
    if (url == null) throw const ProfilePhotoTooLargeException();
    await ref.set({'photoURL': url}, SetOptions(merge: true));
    return url;
  }

  /// Clears the photo, so the initials avatar shows again.
  Future<void> removePhoto() => _userRef()
      .set({'photoURL': FieldValue.delete()}, SetOptions(merge: true));
}
