
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> get _userDocument {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No user is currently signed in.');
    }

    return _firestore.collection('users').doc(user.uid);
  }

  // Create a user profile and fill in any missing default fields.
  // Existing step goals and profile details are preserved.
  Future<void> ensureUserProfileExists() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No user is currently signed in.');
    }

    final document = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        transaction.set(document, {
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'dailyStepGoal': 10000,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Fill in missing fields without resetting an existing goal.
      final data = snapshot.data() ?? <String, dynamic>{};
      final missingFields = <String, dynamic>{};

      if (!data.containsKey('email')) {
        missingFields['email'] = user.email ?? '';
      }

      if (!data.containsKey('displayName')) {
        missingFields['displayName'] = user.displayName ?? '';
      }

      if (!data.containsKey('dailyStepGoal')) {
        missingFields['dailyStepGoal'] = 10000;
      }

      if (!data.containsKey('createdAt')) {
        missingFields['createdAt'] = FieldValue.serverTimestamp();
      }

      if (missingFields.isNotEmpty) {
        transaction.update(document, missingFields);
      }
    });
  }

  // Receive real-time updates when the user profile changes.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile() {
    return _userDocument.snapshots();
  }

  // Save the user's chosen daily step goal.
  Future<void> updateDailyStepGoal(int newGoal) async {
    if (newGoal <= 0) {
      throw ArgumentError('Step goal must be greater than zero.');
    }

    await _userDocument.update({
      'dailyStepGoal': newGoal,
    });
  }

  // Save the user's display name.
  // Using merge avoids deleting any existing goal or profile fields.
  Future<void> updateDisplayName(String newName) async {
    final name = newName.trim();

    if (name.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    await _userDocument.set({
      'displayName': name,
    }, SetOptions(merge: true));
  }
}
