
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'auth_screen.dart';
import 'user_profile_service.dart';
import 'real_friends_screen.dart';
import 'real_leaderboard_screen.dart';

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

      // Show login or dashboard depending on authentication.
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

  late Future<void> profileInitialization;

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    // Ensure this user has a saved Firestore profile,
    // searchable public profile and leaderboard statistics.
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

    // Firestore updates the dashboard and leaderboard automatically.
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
            appBar: AppBar(
              title: const Text('FitTogether'),
              actions: [
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout),
                  onPressed: logout,
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to load your profile.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check your internet connection '
                      'and Firestore security rules.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: retryProfileInitialization,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Listen for updates to the logged-in user's profile.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: profileService.watchProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('FitTogether'),
                  actions: [
                    IconButton(
                      tooltip: 'Logout',
                      icon: const Icon(Icons.logout),
                      onPressed: logout,
                    ),
                  ],
                ),
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

            final profileData = profileSnapshot.data!.data();

            if (profileData == null) {
              return const Scaffold(
                body: Center(
                  child: Text('Your user profile was not found.'),
                ),
              );
            }

            // Saved personal daily step goal.
            final savedGoal = profileData['dailyStepGoal'];

            final int myGoal =
                savedGoal is int && savedGoal > 0
                    ? savedGoal
                    : 10000;

            // Saved simulated steps for testing.
            // Android Health Connect will replace these later.
            final savedSteps = profileData['demoSteps'];

            final int mySteps =
                savedSteps is int && savedSteps >= 0
                    ? savedSteps
                    : 6500;

            final pages = [
              HomeScreen(
                steps: mySteps,
                goal: myGoal,
                onGoalChanged: updateGoal,
              ),
              const RealFriendsScreen(),
              const RealLeaderboardScreen(),
            ];

            return Scaffold(
              appBar: AppBar(
                title: const Text('FitTogether'),
                actions: [
                  IconButton(
                    tooltip: 'Logout',
                    icon: const Icon(Icons.logout),
                    onPressed: logout,
                  ),
                ],
              ),
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

// HOME SCREEN
class HomeScreen extends StatelessWidget {
  final int steps;
  final int goal;
  final Future<void> Function(int) onGoalChanged;

  const HomeScreen({
    super.key,
    required this.steps,
    required this.goal,
    required this.onGoalChanged,
  });

  Future<void> changeGoal(BuildContext context) async {
    final controller = TextEditingController(
      text: goal.toString(),
    );

    final newGoal = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Daily Step Goal'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'New step goal',
              helperText: 'Enter a value between 1 and 1,000,000',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
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
        );
      },
    );

    controller.dispose();

    if (newGoal == null || !context.mounted) return;

    try {
      await onGoalChanged(newGoal);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily step goal saved!'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save your step goal. Please try again.',
          ),
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
            const SizedBox(height: 40),
            const Text(
              "Today's Steps",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 30),
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
            const SizedBox(height: 30),
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
          ],
        ),
      ),
    );
  }
}
