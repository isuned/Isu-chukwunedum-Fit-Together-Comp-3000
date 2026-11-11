
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'user_profile_service.dart';

class LeaderboardEntry {
  final String userId;
  final String displayName;
  final int steps;
  final int goal;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.steps,
    required this.goal,
  });

  double get progress => goal > 0 ? steps / goal : 0;

  double get fairScore => progress.clamp(0.0, 1.0);

  factory LeaderboardEntry.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final rawSteps = data['steps'];
    final rawGoal = data['dailyStepGoal'];

    return LeaderboardEntry(
      userId: document.id,
      displayName:
          data['displayName'] as String? ?? 'FitTogether User',
      steps: rawSteps is int ? rawSteps : 0,
      goal: rawGoal is int && rawGoal > 0 ? rawGoal : 10000,
    );
  }
}

class RealLeaderboardScreen extends StatefulWidget {
  const RealLeaderboardScreen({super.key});

  @override
  State<RealLeaderboardScreen> createState() =>
      _RealLeaderboardScreenState();
}

class _RealLeaderboardScreenState
    extends State<RealLeaderboardScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final UserProfileService profileService = UserProfileService();

  bool fairCompetition = false;
  bool savingSteps = false;

  late final String myId;
  late final Stream<List<LeaderboardEntry>> leaderboardStream;

  @override
  void initState() {
    super.initState();

    myId = FirebaseAuth.instance.currentUser!.uid;
    leaderboardStream = watchLeaderboard();
  }

  Stream<List<LeaderboardEntry>> watchLeaderboard() {
    final requests = firestore.collection('friendRequests');

    final incoming = requests
        .where('toUid', isEqualTo: myId)
        .snapshots();

    final outgoing = requests
        .where('fromUid', isEqualTo: myId)
        .snapshots();

    return Rx.combineLatest2<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        Set<String>>(
      incoming,
      outgoing,
      (incomingData, outgoingData) {
        final friends = <String>{};

        for (final request in incomingData.docs) {
          if (request.data()['status'] == 'accepted') {
            friends.add(request.data()['fromUid'] as String);
          }
        }

        for (final request in outgoingData.docs) {
          if (request.data()['status'] == 'accepted') {
            friends.add(request.data()['toUid'] as String);
          }
        }

        return friends;
      },
    ).switchMap((friends) {
      final userIds = <String>{myId, ...friends};

      // Read individual documents so the friend-only
      // Firestore security rules can validate each one.
      final streams = userIds.map((userId) {
        return firestore
            .collection('leaderboardStats')
            .doc(userId)
            .snapshots();
      }).toList();

      return Rx.combineLatestList<
          DocumentSnapshot<Map<String, dynamic>>>(
        streams,
      ).map((documents) {
        return documents
            .where((document) => document.exists)
            .map(LeaderboardEntry.fromDocument)
            .toList();
      });
    });
  }

  Future<void> editDemoSteps(
    BuildContext context,
    int currentSteps,
  ) async {
    final controller = TextEditingController(
      text: currentSteps.toString(),
    );

    final newSteps = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Demo Steps'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Simulated daily steps',
              helperText: 'Testing only, not real activity data',
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
                    value >= 0 &&
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

    if (newSteps == null || !mounted || savingSteps) return;

    setState(() {
      savingSteps = true;
    });

    try {
      await profileService.updateDemoSteps(newSteps);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo step count saved.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save demo steps.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          savingSteps = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaderboardEntry>>(
      stream: leaderboardStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load the leaderboard. '
                'Check your Firestore security rules '
                'and internet connection.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final users = [...snapshot.data!];

        users.sort((a, b) {
          if (!fairCompetition) {
            final result = b.steps.compareTo(a.steps);

            if (result != 0) return result;
          } else {
            final result =
                b.fairScore.compareTo(a.fairScore);

            if (result != 0) return result;

            final stepsResult =
                b.steps.compareTo(a.steps);

            if (stepsResult != 0) return stepsResult;
          }

          return a.userId.compareTo(b.userId);
        });

        final myEntries = users.where(
          (user) => user.userId == myId,
        );

        final myEntry = myEntries.isNotEmpty
            ? myEntries.first
            : null;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
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
                const Text(
                  'Compete with your connected friends!',
                ),
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Demo mode: step counts are simulated '
                            'until Health Connect is integrated.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                      ? 'Ranked by percentage of personal goals.'
                      : 'Ranked by simulated daily steps.',
                ),
                const SizedBox(height: 18),
                if (myEntry != null)
                  OutlinedButton.icon(
                    onPressed: savingSteps
                        ? null
                        : () => editDemoSteps(
                              context,
                              myEntry.steps,
                            ),
                    icon: const Icon(Icons.edit),
                    label: Text(
                      'Change My Demo Steps (${myEntry.steps})',
                    ),
                  ),
                const SizedBox(height: 20),
                if (users.length == 1)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Only you are on this leaderboard. '
                      'Connect with a friend to start competing.',
                    ),
                  ),
                ...List.generate(users.length, (index) {
                  final user = users[index];
                  final rank = index + 1;

                  final progress =
                      user.progress.clamp(0.0, 1.0);

                  final score = fairCompetition
                      ? '${(user.fairScore * 100).toStringAsFixed(1)}%'
                      : '${user.steps} steps';

                  final medals = ['🥇', '🥈', '🥉'];

                  final rankText = index < 3
                      ? medals[index]
                      : '$rank';

                  final isMe = user.userId == myId;

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
                              style: const TextStyle(
                                fontSize: 22,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMe
                                      ? 'You (${user.displayName})'
                                      : user.displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${user.steps} / ${user.goal} steps',
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: progress,
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
                      'Fair scores are capped at 100%. '
                      'Equal scores are ranked by step count.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
