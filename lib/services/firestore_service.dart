import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for saving and loading resume data from Cloud Firestore.
///
/// Resume data is stored per-user at `/resumes/{userId}`.
/// Only authenticated (non-guest) users can use cloud sync.
class FirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Returns the currently signed-in Firebase user's UID, or null
  /// if no user is signed in.
  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Whether cloud sync is available (user is authenticated via Firebase).
  static bool get isCloudSyncAvailable => _currentUserId != null;

  /// Save resume data to Firestore.
  ///
  /// [resumeData] should be the same map produced by `_buildResumeStateMap()`
  /// in main.dart.
  static Future<bool> saveResume(Map<String, dynamic> resumeData) async {
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint('FirestoreService: No authenticated user, skipping cloud save.');
      return false;
    }

    try {
      await _db.collection('resumes').doc(uid).set(
        {
          ...resumeData,
          'updatedAt': FieldValue.serverTimestamp(),
          'userId': uid,
        },
        SetOptions(merge: true),
      );
      debugPrint('FirestoreService: Resume saved to Firestore for user $uid');
      return true;
    } catch (e) {
      debugPrint('FirestoreService: Failed to save resume — $e');
      return false;
    }
  }

  /// Load resume data from Firestore.
  ///
  /// Returns `null` if no data is found or user is not authenticated.
  static Future<Map<String, dynamic>?> loadResume() async {
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint('FirestoreService: No authenticated user, skipping cloud load.');
      return null;
    }

    try {
      final doc = await _db.collection('resumes').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        debugPrint('FirestoreService: No resume found in Firestore for user $uid');
        return null;
      }

      debugPrint('FirestoreService: Resume loaded from Firestore for user $uid');
      return doc.data()!;
    } catch (e) {
      debugPrint('FirestoreService: Failed to load resume — $e');
      return null;
    }
  }

  /// Delete resume data from Firestore.
  static Future<bool> deleteResume() async {
    final uid = _currentUserId;
    if (uid == null) return false;

    try {
      await _db.collection('resumes').doc(uid).delete();
      debugPrint('FirestoreService: Resume deleted from Firestore for user $uid');
      return true;
    } catch (e) {
      debugPrint('FirestoreService: Failed to delete resume — $e');
      return false;
    }
  }
}
