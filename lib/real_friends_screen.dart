
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'friends_service.dart';

class RealFriendsScreen extends StatefulWidget {
  const RealFriendsScreen({super.key});

  @override
  State<RealFriendsScreen> createState() =>
      _RealFriendsScreenState();
}

class _RealFriendsScreenState extends State<RealFriendsScreen> {
  final FriendsService service = FriendsService();
  final TextEditingController searchController =
      TextEditingController();

  Future<QuerySnapshot<Map<String, dynamic>>>? searchFuture;
  String? searchError;
  String? busyId;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void search() {
    final query = searchController.text.trim();

    if (query.length < 2) {
      setState(() {
        searchFuture = null;
        searchError = 'Enter at least two characters.';
      });
      return;
    }

    setState(() {
      searchError = null;
      searchFuture = service.searchUsers(query);
    });
  }

  Future<void> performAction(
    String id,
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (busyId != null) return;

    setState(() {
      busyId = id;
    });

    try {
      await action();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not complete that action. '
            'Check your connection or Firestore rules.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          busyId = null;
        });
      }
    }
  }

  Widget profileName(String userId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.watchPublicProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Profile unavailable');
        }

        if (!snapshot.hasData) {
          return const Text('Loading...');
        }

        final data = snapshot.data!.data();
        final name = data?['displayName'] as String?;

        return Text(
          name?.isNotEmpty == true
              ? name!
              : 'FitTogether User',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }

  Widget heading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget searchResults(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> results,
    Set<String> friendIds,
    Set<String> pendingOutgoingIds,
    Set<String> pendingIncomingIds,
  ) {
    final matches = results.where(
      (document) => document.id != service.currentUserId,
    ).toList();

    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No matching users found.'),
      );
    }

    return Column(
      children: matches.map((document) {
        final userId = document.id;
        final name =
            document.data()['displayName'] as String? ??
                'FitTogether User';

        String? status;

        if (friendIds.contains(userId)) {
          status = 'Friends';
        } else if (pendingOutgoingIds.contains(userId)) {
          status = 'Request sent';
        } else if (pendingIncomingIds.contains(userId)) {
          status = 'Respond below';
        }

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(name),
            trailing: status != null
                ? Text(
                    status,
                    style: const TextStyle(fontSize: 12),
                  )
                : TextButton(
                    onPressed: busyId != null
                        ? null
                        : () => performAction(
                              userId,
                              () => service.sendRequest(userId),
                              'Friend request sent!',
                            ),
                    child: const Text('Add'),
                  ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.incomingRequests(),
      builder: (context, incomingSnapshot) {
        if (incomingSnapshot.hasError) {
          return const Center(
            child: Text('Unable to load incoming requests.'),
          );
        }

        if (!incomingSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.outgoingRequests(),
          builder: (context, outgoingSnapshot) {
            if (outgoingSnapshot.hasError) {
              return const Center(
                child: Text('Unable to load sent requests.'),
              );
            }

            if (!outgoingSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final incoming = incomingSnapshot.data!.docs;
            final outgoing = outgoingSnapshot.data!.docs;

            final pendingIncoming = incoming.where(
              (doc) => doc.data()['status'] == 'pending',
            ).toList();

            final pendingOutgoing = outgoing.where(
              (doc) => doc.data()['status'] == 'pending',
            ).toList();

            final acceptedIncoming = incoming.where(
              (doc) => doc.data()['status'] == 'accepted',
            );

            final acceptedOutgoing = outgoing.where(
              (doc) => doc.data()['status'] == 'accepted',
            );

            final friendIds = <String>{
              ...acceptedIncoming.map(
                (doc) => doc.data()['fromUid'] as String,
              ),
              ...acceptedOutgoing.map(
                (doc) => doc.data()['toUid'] as String,
              ),
            };

            final pendingOutgoingIds = pendingOutgoing
                .map((doc) => doc.data()['toUid'] as String)
                .toSet();

            final pendingIncomingIds = pendingIncoming
                .map((doc) => doc.data()['fromUid'] as String)
                .toSet();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
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
                    const Text(
                      'Find friends and stay active together!',
                    ),

                    heading('Find Friends'),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            textInputAction:
                                TextInputAction.search,
                            onSubmitted: (_) => search(),
                            decoration: const InputDecoration(
                              labelText: 'Search display name',
                              hintText: 'e.g. Alex',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: search,
                          child: const Text('Search'),
                        ),
                      ],
                    ),

                    if (searchError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        searchError!,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],

                    if (searchFuture != null) ...[
                      const SizedBox(height: 12),
                      FutureBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        future: searchFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text(
                              'Search failed. Check your connection.',
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          return searchResults(
                            snapshot.data!.docs,
                            friendIds,
                            pendingOutgoingIds,
                            pendingIncomingIds,
                          );
                        },
                      ),
                    ],

                    heading('Friend Requests'),

                    if (pendingIncoming.isEmpty)
                      const Text('No incoming friend requests.'),

                    ...pendingIncoming.map((request) {
                      final senderId =
                          request.data()['fromUid'] as String;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              profileName(senderId),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: busyId != null
                                        ? null
                                        : () => performAction(
                                              request.id,
                                              () => service
                                                  .acceptRequest(
                                                    request.id,
                                                  ),
                                              'Friend request accepted!',
                                            ),
                                    icon: const Icon(
                                      Icons.check,
                                    ),
                                    label: const Text('Accept'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: busyId != null
                                        ? null
                                        : () => performAction(
                                              request.id,
                                              () => service
                                                  .declineRequest(
                                                    request.id,
                                                  ),
                                              'Friend request declined.',
                                            ),
                                    icon: const Icon(
                                      Icons.close,
                                    ),
                                    label: const Text('Decline'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    heading('Sent Requests'),

                    if (pendingOutgoing.isEmpty)
                      const Text('No pending sent requests.'),

                    ...pendingOutgoing.map((request) {
                      final recipientId =
                          request.data()['toUid'] as String;

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.schedule,
                          ),
                          title: profileName(recipientId),
                          subtitle: const Text(
                            'Waiting for acceptance',
                          ),
                        ),
                      );
                    }),

                    heading('My Friends'),

                    if (friendIds.isEmpty)
                      const Text(
                        'You have no connected friends yet.',
                      ),

                    ...friendIds.map((friendId) {
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: profileName(friendId),
                          subtitle: const Text(
                            'Connected friend',
                          ),
                          trailing: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
