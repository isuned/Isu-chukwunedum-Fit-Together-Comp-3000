


import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'auth_screen.dart';
import 'user_profile_service.dart';
import 'real_friends_screen.dart';
import 'real_leaderboard_screen.dart';
import 'health_service.dart';
import 'health_test_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FitTogetherApp());
}

// MAIN APPLICATION
class FitTogetherApp extends StatelessWidget {
  const FitTogetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTogether',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Text('Unable to check login status.'),
              ),
            );
          }

          if (snapshot.hasData) {
            return MainScreen(
              key: ValueKey(snapshot.data!.uid),
            );
          }

          return const AuthScreen();
        },
      ),
    );
  }
}

// MAIN NAVIGATION AND FIRESTORE DATA
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final UserProfileService profileService = UserProfileService();
  final HealthService healthService = HealthService();

  late Future<void> profileInitialization;

  int selectedIndex = 0;
  bool syncingSteps = false;

  @override
  void initState() {
    super.initState();
    profileInitialization = profileService.ensureUserProfileExists();
  }

  void retryProfileInitialization() {
    setState(() {
      profileInitialization = profileService.ensureUserProfileExists();
    });
  }

  Future<void> updateGoal(int newGoal) async {
    if (newGoal <= 0) return;
    await profileService.updateDailyStepGoal(newGoal);
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to log out. Try again.'),
        ),
      );
    }
  }

  void openHealthConnectTest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HealthTestScreen(),
      ),
    );
  }

  // Read real steps and share today's total with connected friends.
  Future<void> syncRealSteps() async {
    if (syncingSteps) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share Your Steps?'),
        content: const Text(
          'FitTogether will read today\'s steps from '
          'Health Connect and save your daily total '
          'to Firebase.\n\n'
          'Your accepted friends will be able to see '
          'this step count and your goal on the '
          'leaderboards. Your other health records '
          'will not be shared.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Read and Share'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      syncingSteps = true;
    });

    try {
      final realSteps = await healthService.getTodaySteps();

      if (!mounted) return;

      await profileService.updateRealSteps(realSteps);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$realSteps real steps synced successfully!',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to sync steps: $error',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          syncingSteps = false;
        });
      }
    }
  }

  AppBar buildAppBar() {
    return AppBar(
      title: const Text('FitTogether'),
      actions: [
        IconButton(
          tooltip: 'Test Health Connect',
          icon: const Icon(Icons.monitor_heart_outlined),
          onPressed: openHealthConnectTest,
        ),
        IconButton(
          tooltip: 'Logout',
          icon: const Icon(Icons.logout),
          onPressed: logout,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: profileInitialization,
      builder: (context, initializationSnapshot) {
        if (initializationSnapshot.connectionState !=
            ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (initializationSnapshot.hasError) {
          return Scaffold(
            appBar: buildAppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load your profile.'),
                  const SizedBox(height: 12),
                  const Text(
                    'Check your connection and Firestore rules.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: retryProfileInitialization,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          stream: profileService.watchProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return Scaffold(
                appBar: buildAppBar(),
                body: const Center(
                  child: Text('Unable to retrieve your profile.'),
                ),
              );
            }

            if (!profileSnapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final data = profileSnapshot.data!.data();

            if (data == null) {
              return Scaffold(
                appBar: buildAppBar(),
                body: const Center(
                  child: Text('Your profile was not found.'),
                ),
              );
            }

            final savedGoal = data['dailyStepGoal'];

            final int myGoal =
                savedGoal is int && savedGoal > 0
                    ? savedGoal
                    : 10000;

            final savedDate = data['stepsDate'] as String?;
            final source = data['stepsSource'] as String?;
            final isToday =
                savedDate == UserProfileService.todayDate();

            final bool usingRealSteps =
                isToday && source == 'healthConnect';

            final bool usingDemoSteps =
                isToday && source == 'demo';

            final savedRealSteps = data['realSteps'];
            final savedDemoSteps = data['demoSteps'];

            int mySteps = 0;

            if (usingRealSteps && savedRealSteps is int) {
              mySteps = savedRealSteps;
            } else if (usingDemoSteps &&
                savedDemoSteps is int) {
              mySteps = savedDemoSteps;
            }

            final String dataLabel = usingRealSteps
                ? 'Real steps from Health Connect'
                : usingDemoSteps
                    ? 'Demo steps (testing only)'
                    : 'No steps recorded for today';

            final pages = [
              HomeScreen(
                steps: mySteps,
                goal: myGoal,
                dataLabel: dataLabel,
                onGoalChanged: updateGoal,
                onSyncSteps: syncRealSteps,
                syncingSteps: syncingSteps,
              ),
              const RealFriendsScreen(),
              const RealLeaderboardScreen(),
            ];

            return Scaffold(
              appBar: buildAppBar(),
              body: SafeArea(
                child: pages[selectedIndex],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: 'Friends',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.leaderboard_outlined),
                    selectedIcon: Icon(Icons.leaderboard),
                    label: 'Leaderboard',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// HOME DASHBOARD
class HomeScreen extends StatelessWidget {
  final int steps;
  final int goal;
  final String dataLabel;
  final Future<void> Function(int) onGoalChanged;
  final Future<void> Function() onSyncSteps;
  final bool syncingSteps;

  const HomeScreen({
    super.key,
    required this.steps,
    required this.goal,
    required this.dataLabel,
    required this.onGoalChanged,
    required this.onSyncSteps,
    required this.syncingSteps,
  });

  Future<void> changeGoal(BuildContext context) async {
    final controller = TextEditingController(
      text: goal.toString(),
    );

    final newGoal = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Daily Step Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New step goal',
            helperText: 'Between 1 and 1,000,000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(
                controller.text.trim(),
              );

              if (value != null &&
                  value > 0 &&
                  value <= 1000000) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newGoal == null || !context.mounted) return;

    try {
      await onGoalChanged(newGoal);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily goal saved!'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save goal.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (steps / goal).clamp(0.0, 1.0);
    final percentage = (steps / goal * 100).round();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'FitTogether',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Every step counts!'),
            const SizedBox(height: 30),
            const Text(
              "Today's Steps",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                height: 220,
                width: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 220,
                      width: 220,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 15,
                        backgroundColor: Colors.grey.shade300,
                        color: Colors.green,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$steps',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('of $goal steps'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              dataLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Daily Goal Progress',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$percentage% Completed',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      steps >= goal
                          ? 'Congratulations! Goal reached!'
                          : 'Keep going! Every step counts.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => changeGoal(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Change Goal'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: syncingSteps ? null : onSyncSteps,
              icon: const Icon(Icons.sync),
              label: Text(
                syncingSteps
                    ? 'Syncing Steps...'
                    : 'Sync Real Steps',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reads today\'s steps from Health Connect '
              'when you choose to sync.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
