


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

  static String todayDate() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _safeName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'FitTogether User';
    }

    return name.length > 50
        ? name.substring(0, 50)
        : name;
  }

  // Ensure the private profile exists without resetting saved data.
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
          'stepsSource': 'demo',
          'stepsDate': todayDate(),
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

      if (!data.containsKey('stepsSource')) {
        missing['stepsSource'] = 'demo';
      }

      if (!data.containsKey('stepsDate')) {
        missing['stepsDate'] = todayDate();
      }

      if (!data.containsKey('createdAt')) {
        missing['createdAt'] =
            FieldValue.serverTimestamp();
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

    await _firestore
        .collection('publicProfiles')
        .doc(user.uid)
        .set({
      'displayName': displayName,
      'searchName': displayName.toLowerCase(),
    });
  }

  // Create leaderboard data if missing and migrate older test data.
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
        'stepsSource': 'demo',
        'stepsDate': todayDate(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final current = existing.data()!;
    final changes = <String, dynamic>{};

    if (current['displayName'] != name) {
      changes['displayName'] = name;
    }

    if (current['dailyStepGoal'] != goal) {
      changes['dailyStepGoal'] = goal;
    }

    // Older leaderboard documents had no date or source.
    if (!current.containsKey('stepsDate')) {
      changes['stepsDate'] = todayDate();
    }

    if (!current.containsKey('stepsSource')) {
      changes['stepsSource'] = 'demo';
    }

    if (changes.isNotEmpty) {
      changes['updatedAt'] = FieldValue.serverTimestamp();
      await statsRef.update(changes);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile() {
    return _userDocument.snapshots();
  }

  // Update the user's goal in both private and shared records.
  Future<void> updateDailyStepGoal(int newGoal) async {
    if (newGoal <= 0 || newGoal > 1000000) {
      throw ArgumentError(
        'Goal must be between 1 and 1,000,000.',
      );
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

  // Save simulated steps for development and testing.
  Future<void> updateDemoSteps(int newSteps) async {
    if (newSteps < 0 || newSteps > 1000000) {
      throw ArgumentError(
        'Demo steps must be between 0 and 1,000,000.',
      );
    }

    final batch = _firestore.batch();
    final date = todayDate();

    batch.update(_userDocument, {
      'demoSteps': newSteps,
      'stepsSource': 'demo',
      'stepsDate': date,
    });

    batch.update(_statsDocument, {
      'steps': newSteps,
      'stepsDate': date,
      'stepsSource': 'demo',
      'isDemo': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Save a Health Connect reading to Firestore.
  // This should only be called after the user agrees to share.
  Future<void> updateRealSteps(int realSteps) async {
    if (realSteps < 0 || realSteps > 1000000) {
      throw ArgumentError(
        'Steps must be between 0 and 1,000,000.',
      );
    }

    final date = todayDate();
    final batch = _firestore.batch();

    batch.update(_userDocument, {
      'realSteps': realSteps,
      'stepsSource': 'healthConnect',
      'stepsDate': date,
      'lastStepSync': FieldValue.serverTimestamp(),
    });

    batch.update(_statsDocument, {
      'steps': realSteps,
      'stepsDate': date,
      'stepsSource': 'healthConnect',
      'isDemo': false,
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

    final stats = await _statsDocument.get();

    if (stats.exists) {
      await _statsDocument.update({
        'displayName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
