import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// The one place the app reaches the default Firestore / Auth instances.
///
/// Screens and service singletons go through here instead of calling
/// `FirebaseFirestore.instance` / `FirebaseAuth.instance` directly, so a
/// widget test can swap in fakes for the whole app at once (see
/// test/layout/) without initializing Firebase. In the app the overrides are
/// always null and this is exactly the default instances.
class AppFirebase {
  AppFirebase._();

  @visibleForTesting
  static FirebaseFirestore? firestoreOverride;

  @visibleForTesting
  static FirebaseAuth? authOverride;

  static FirebaseFirestore get firestore =>
      firestoreOverride ?? FirebaseFirestore.instance;

  static FirebaseAuth get auth => authOverride ?? FirebaseAuth.instance;
}
