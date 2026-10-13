import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

class DatabaseService {
  DatabaseService._privateConstructor({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final DatabaseService _instance =
  DatabaseService._privateConstructor();

  static DatabaseService get instance {
    return _instance;
  }

  /// Test-only factory: inject a fake Firestore.
  @visibleForTesting
  factory DatabaseService.test({required FirebaseFirestore firestore}) =>
      DatabaseService._privateConstructor(firestore: firestore);

  final FirebaseFirestore _firestore;

  /// How often [createUser] retries a failed profile write before giving up.
  static const createUserAttempts = 3;

  /// Creates the `users/{uid}` profile doc right after sign-up.
  ///
  /// [email] is accepted for call-site compatibility but deliberately NOT
  /// stored: `users/{uid}` is readable by every signed-in user (public
  /// profiles, search), and nothing in the app reads an email from it — the
  /// signed-in user's own address comes from Firebase Auth.
  ///
  /// Retries a few times, then rethrows. It used to swallow the error, so a
  /// failed write let registration "succeed" with no profile doc at all
  /// (invisible to search, no public profile).
  Future<void> createUser({
    required String uid,
    required String email,
    String? name,
    String? profileImageUrl,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    for (var attempt = 1;; attempt++) {
      try {
        await _firestore.collection('users').doc(uid).set({
          'name': name,
          'profileImageUrl': profileImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      } catch (e) {
        debugPrint('Error creating user (attempt $attempt): $e');
        if (attempt >= createUserAttempts) rethrow;
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  // Fetch user data from Firestore
  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) async {
    try {
      // Fetch user document from Firestore
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      // Check if the document exists
      if (!userSnapshot.exists) {
        throw Exception('User document not found in Firestore.');
      }

      // Return the fetched document
      return userSnapshot;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      throw Exception('Failed to fetch user data');
    }
  }


  // Update user data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      debugPrint('Error updating user: $e');
      // Error handling
    }
  }

  // Delete a user
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      // Error handling
    }
  }

  // Create a new document
  Future<void> createDocument(
      String collectionName, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collectionName).add(data);
    } catch (e) {
      debugPrint('Error creating document: $e');
      // Error handling — e.g. show an error message to the user
    }
  }

  // Read a document
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
      String collectionName, String documentId) async {
    try {
      return await _firestore.collection(collectionName).doc(documentId).get();
    } catch (e) {
      debugPrint('Error reading document: $e');
      // Error handling
      rethrow;
    }
  }

  // Update a document
  Future<void> updateDocument(
      String collectionName, String documentId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collectionName).doc(documentId).update(data);
    } catch (e) {
      debugPrint('Error updating document: $e');
      // Error handling
    }
  }

  // Delete a document
  Future<void> deleteDocument(String collectionName, String documentId) async {
    try {
      await _firestore.collection(collectionName).doc(documentId).delete();
    } catch (e) {
      debugPrint('Error deleting document: $e');
      // Error handling
    }
  }

  // Read all documents in a collection
  Stream<QuerySnapshot<Map<String, dynamic>>> getDocuments(
      String collectionName) {
    try {
      return _firestore.collection(collectionName).snapshots();
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      // Error handling — e.g. return an empty Stream
      rethrow;
    }
  }
}
