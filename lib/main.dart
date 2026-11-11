




import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'auth_screen.dart';
import 'user_profile_service.dart';

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

// SAMPLE FRIEND MODEL
class Friend {
  final String name;
  final int steps;
  final int goal;

  const Friend({
    required this.name,
    required this.steps,
    required this.goal,
  });

  double get progress => goal > 0 ? steps / goal : 0.0;
}

// MAIN NAVIGATION AND SHARED DATA
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final UserProfileService profileService = UserProfileService();

  late Future<void> profileInitialization;

  int selectedIndex = 0;

  // Mock step data until Android Health Connect is integrated.
  final int mySteps = 6500;

  // Mock friends until the real friends system is implemented.
  final List<Friend> friends = [
    const Friend(name: 'Brother', steps: 10000, goal: 12000),
    const Friend(name: 'Alex', steps: 7500, goal: 10000),
    const Friend(name: 'Sarah', steps: 4200, goal: 8000),
  ];

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

    // The Firestore StreamBuilder below automatically updates
    // the dashboard and leaderboard after the goal changes.
  }

  void addFriend(String name) {
    if (name.trim().isEmpty) return;

    setState(() {
      friends.add(
        Friend(
          name: name.trim(),
          steps: 0,
          goal: 10000,
        ),
      );
    });
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
                      'Check your connection and Firestore rules.',
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

            final savedGoal = profileData['dailyStepGoal'];

            final int myGoal =
                savedGoal is int && savedGoal > 0
                    ? savedGoal
                    : 10000;

            final pages = [
              HomeScreen(
                steps: mySteps,
                goal: myGoal,
                onGoalChanged: updateGoal,
              ),
              FriendsScreen(
                friends: friends,
                onAddFriend: addFriend,
              ),
              LeaderboardScreen(
                mySteps: mySteps,
                myGoal: myGoal,
                friends: friends,
              ),
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

                if (value != null && value > 0) {
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

// FRIENDS AND FAMILY SCREEN
// Friends are still mock data at this development stage.
class FriendsScreen extends StatelessWidget {
  final List<Friend> friends;
  final ValueChanged<String> onAddFriend;

  const FriendsScreen({
    super.key,
    required this.friends,
    required this.onAddFriend,
  });

  Future<void> addFriend(BuildContext context) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Friend'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Friend name',
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
                final name = controller.text.trim();

                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, name);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name != null) {
      onAddFriend(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Friends & Family',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Stay active together!'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => addFriend(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Friend'),
            ),
            const SizedBox(height: 20),
            ...friends.map((friend) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(friend.name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${friend.steps} / ${friend.goal} steps',
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: friend.progress.clamp(0.0, 1.0),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// LEADERBOARD SCREEN
class LeaderboardScreen extends StatefulWidget {
  final int mySteps;
  final int myGoal;
  final List<Friend> friends;

  const LeaderboardScreen({
    super.key,
    required this.mySteps,
    required this.myGoal,
    required this.friends,
  });

  @override
  State<LeaderboardScreen> createState() =>
      _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool fairCompetition = false;

  @override
  Widget build(BuildContext context) {
    final users = [
      Friend(
        name: 'You',
        steps: widget.mySteps,
        goal: widget.myGoal,
      ),
      ...widget.friends,
    ];

    users.sort((a, b) {
      if (!fairCompetition) {
        return b.steps.compareTo(a.steps);
      }

      // Fair competition: cap ranking scores at 100%.
      final aScore = a.progress.clamp(0.0, 1.0);
      final bScore = b.progress.clamp(0.0, 1.0);

      final result = bScore.compareTo(aScore);

      if (result != 0) return result;

      // Break ties using the total step count.
      return b.steps.compareTo(a.steps);
    });

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('See how everyone is doing!'),
            const SizedBox(height: 24),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Total Steps'),
                  icon: Icon(Icons.directions_walk),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Fair Competition'),
                  icon: Icon(Icons.flag),
                ),
              ],
              selected: {fairCompetition},
              onSelectionChanged: (selection) {
                setState(() {
                  fairCompetition = selection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              fairCompetition
                  ? 'Personal Goal Leaderboard'
                  : 'Most Steps Today',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fairCompetition
                  ? 'Ranked by progress towards personal goals.'
                  : 'Ranked by total daily steps.',
            ),
            const SizedBox(height: 20),
            ...List.generate(users.length, (index) {
              final user = users[index];
              final rank = index + 1;
              final rankProgress =
                  user.progress.clamp(0.0, 1.0);

              final score = fairCompetition
                  ? '${(rankProgress * 100).toStringAsFixed(1)}%'
                  : '${user.steps} steps';

              final medals = ['🥇', '🥈', '🥉'];
              final rankText =
                  index < 3 ? medals[index] : '$rank';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          rankText,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${user.steps} / ${user.goal} steps',
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: rankProgress,
                              minHeight: 8,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        score,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (fairCompetition)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Competition scores are capped at 100%. '
                  'If scores are equal, the user with more '
                  'steps ranks higher.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

