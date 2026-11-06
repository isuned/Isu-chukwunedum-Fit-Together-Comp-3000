



import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'auth_screen.dart';

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
            return const MainScreen();
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
  int selectedIndex = 0;

  int mySteps = 6500;
  int myGoal = 10000;

  final List<Friend> friends = [
    const Friend(name: 'Brother', steps: 10000, goal: 12000),
    const Friend(name: 'Alex', steps: 7500, goal: 10000),
    const Friend(name: 'Sarah', steps: 4200, goal: 8000),
  ];

  void updateGoal(int newGoal) {
    if (newGoal <= 0) return;

    setState(() {
      myGoal = newGoal;
    });
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

  @override
  Widget build(BuildContext context) {
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
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } on FirebaseAuthException {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to log out. Try again.'),
                  ),
                );
              }
            },
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
  }
}

// HOME SCREEN
class HomeScreen extends StatelessWidget {
  final int steps;
  final int goal;
  final ValueChanged<int> onGoalChanged;

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
                final value = int.tryParse(controller.text.trim());

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

    if (newGoal != null) {
      onGoalChanged(newGoal);
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
              final rankProgress = user.progress.clamp(0.0, 1.0);

              final score = fairCompetition
                  ? '${(rankProgress * 100).toStringAsFixed(1)}%'
                  : '${user.steps} steps';

              final medals = ['🥇', '🥈', '🥉'];
              final rankText = index < 3 ? medals[index] : '$rank';

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
