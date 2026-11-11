
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No user is signed in.');
    }
    return user;
  }

  DocumentReference<Map<String, dynamic>> get _userDocument {
    return _firestore.collection('users').doc(_user.uid);
  }

  String _safeName(String? name, User user) {
    final trimmed = name?.trim() ?? '';

    if (trimmed.isNotEmpty) {
      return trimmed.length > 50
          ? trimmed.substring(0, 50)
          : trimmed;
    }

    // Existing accounts may not have a display name.
    // Avoid putting their email address in the public directory.
    return 'FitTogether User';
  }

  Future<void> ensureUserProfileExists() async {
    final user = _user;
    final document = _userDocument;

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
        missingFields['createdAt'] =
            FieldValue.serverTimestamp();
      }

      if (missingFields.isNotEmpty) {
        transaction.update(document, missingFields);
      }
    });

    // Make this account discoverable through friend search.
    await publishPublicProfile();
  }

  Future<void> publishPublicProfile([String? providedName]) async {
    final user = _user;

    // Use a provided name if available. Otherwise, use the name
    // from Firebase Authentication or the private profile.
    String? name = providedName ?? user.displayName;

    if (name == null || name.trim().isEmpty) {
      final privateProfile = await _userDocument.get();
      name = privateProfile.data()?['displayName'] as String?;
    }

    final displayName = _safeName(name, user);

    await _firestore.collection('publicProfiles')
        .doc(user.uid)
        .set({
      'displayName': displayName,
      'searchName': displayName.toLowerCase(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile() {
    return _userDocument.snapshots();
  }

  Future<void> updateDailyStepGoal(int newGoal) async {
    if (newGoal <= 0) {
      throw ArgumentError('Step goal must be positive.');
    }

    await _userDocument.update({
      'dailyStepGoal': newGoal,
    });
  }

  Future<void> updateDisplayName(String newName) async {
    final name = newName.trim();

    if (name.isEmpty || name.length > 50) {
      throw ArgumentError(
        'Display name must be between 1 and 50 characters.',
      );
    }

    await _userDocument.set({
      'displayName': name,
    }, SetOptions(merge: true));

    await publishPublicProfile(name);
  }
}

