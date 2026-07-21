import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  DatabaseService._privateConstructor(); // Private constructor

  static final DatabaseService _instance =
  DatabaseService._privateConstructor();

  static DatabaseService get instance {
    return _instance;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a user
  Future<void> createUser({
    required String uid,
    required String email,
    String? name,
    String? profileImageUrl,
    // Other user fields
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'profileImageUrl': profileImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        // Other user fields
      });
    } catch (e) {
      print('Error creating user: $e');
      // Error handling — e.g. show an error message to the user
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
      print('Error fetching user data: $e');
      throw Exception('Failed to fetch user data');
    }
  }


  // Update user data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      print('Error updating user: $e');
      // Error handling
    }
  }

  // Delete a user
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      print('Error deleting user: $e');
      // Error handling
    }
  }

  // Create a new document
  Future<void> createDocument(
      String collectionName, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collectionName).add(data);
    } catch (e) {
      print('Error creating document: $e');
      // Error handling — e.g. show an error message to the user
    }
  }

  // Read a document
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
      String collectionName, String documentId) async {
    try {
      return await _firestore.collection(collectionName).doc(documentId).get();
    } catch (e) {
      print('Error reading document: $e');
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
      print('Error updating document: $e');
      // Error handling
    }
  }

  // Delete a document
  Future<void> deleteDocument(String collectionName, String documentId) async {
    try {
      await _firestore.collection(collectionName).doc(documentId).delete();
    } catch (e) {
      print('Error deleting document: $e');
      // Error handling
    }
  }

  // Read all documents in a collection
  Stream<QuerySnapshot<Map<String, dynamic>>> getDocuments(
      String collectionName) {
    try {
      return _firestore.collection(collectionName).snapshots();
    } catch (e) {
      print('Error fetching documents: $e');
      // Error handling — e.g. return an empty Stream
      rethrow;
    }
  }
}
