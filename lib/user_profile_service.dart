

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

  DocumentReference<Map<String, dynamic>> get _userDocument =>
      _firestore.collection('users').doc(_user.uid);

  DocumentReference<Map<String, dynamic>> get _statsDocument =>
      _firestore.collection('leaderboardStats').doc(_user.uid);

  String _safeName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'FitTogether User';
    return name.length > 50 ? name.substring(0, 50) : name;
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
          'demoSteps': 6500,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final missing = <String, dynamic>{};

      if (!data.containsKey('email')) {
        missing['email'] = user.email ?? '';
      }
      if (!data.containsKey('displayName')) {
        missing['displayName'] = user.displayName ?? '';
      }
      if (!data.containsKey('dailyStepGoal')) {
        missing['dailyStepGoal'] = 10000;
      }
      if (!data.containsKey('demoSteps')) {
        missing['demoSteps'] = 6500;
      }
      if (!data.containsKey('createdAt')) {
        missing['createdAt'] = FieldValue.serverTimestamp();
      }

      if (missing.isNotEmpty) {
        transaction.update(document, missing);
      }
    });

    await publishPublicProfile();
    await ensureLeaderboardStatsExists();
  }

  Future<void> publishPublicProfile([String? providedName]) async {
    final user = _user;
    String? name = providedName ?? user.displayName;

    if (name == null || name.trim().isEmpty) {
      final snapshot = await _userDocument.get();
      name = snapshot.data()?['displayName'] as String?;
    }

    final displayName = _safeName(name);

    await _firestore.collection('publicProfiles')
        .doc(user.uid)
        .set({
      'displayName': displayName,
      'searchName': displayName.toLowerCase(),
    });
  }

  Future<void> ensureLeaderboardStatsExists() async {
    final profile = await _userDocument.get();
    final data = profile.data();

    if (data == null) {
      throw StateError('User profile not found.');
    }

    final rawGoal = data['dailyStepGoal'];
    final rawSteps = data['demoSteps'];

    final goal = rawGoal is int && rawGoal > 0
        ? rawGoal
        : 10000;

    final steps = rawSteps is int && rawSteps >= 0
        ? rawSteps
        : 6500;

    final name = _safeName(data['displayName'] as String?);
    final statsRef = _statsDocument;
    final existing = await statsRef.get();

    if (!existing.exists) {
      await statsRef.set({
        'displayName': name,
        'steps': steps,
        'dailyStepGoal': goal,
        'isDemo': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Keep profile details in sync without resetting demo steps.
    final current = existing.data()!;
    if (current['displayName'] != name ||
        current['dailyStepGoal'] != goal) {
      await statsRef.update({
        'displayName': name,
        'dailyStepGoal': goal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile() {
    return _userDocument.snapshots();
  }

  Future<void> updateDailyStepGoal(int newGoal) async {
    if (newGoal <= 0 || newGoal > 1000000) {
      throw ArgumentError('Goal must be between 1 and 1,000,000.');
    }

    final batch = _firestore.batch();

    batch.update(_userDocument, {
      'dailyStepGoal': newGoal,
    });

    batch.update(_statsDocument, {
      'dailyStepGoal': newGoal,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> updateDemoSteps(int newSteps) async {
    if (newSteps < 0 || newSteps > 1000000) {
      throw ArgumentError(
        'Demo steps must be between 0 and 1,000,000.',
      );
    }

    final batch = _firestore.batch();

    batch.update(_userDocument, {
      'demoSteps': newSteps,
    });

    batch.update(_statsDocument, {
      'steps': newSteps,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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

    // New accounts might not have statistics yet.
    final stats = await _statsDocument.get();

    if (stats.exists) {
      await _statsDocument.update({
        'displayName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
