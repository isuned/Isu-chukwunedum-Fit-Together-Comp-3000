
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('You must be logged in.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _requests {
    return _firestore.collection('friendRequests');
  }

  // Search public profiles by the start of their display name.
  Future<QuerySnapshot<Map<String, dynamic>>> searchUsers(
    String searchText,
  ) async {
    final search = searchText.trim().toLowerCase();

    if (search.length < 2) {
      throw ArgumentError('Enter at least two characters.');
    }

    return _firestore
        .collection('publicProfiles')
        .orderBy('searchName')
        .startAt([search])
        .endAt(['$search\uf8ff'])
        .limit(20)
        .get();
  }

  // Send a new friend request.
  Future<void> sendRequest(String otherUserId) async {
    final myId = currentUserId;

    if (myId == otherUserId) {
      throw ArgumentError('You cannot add yourself.');
    }

    final requestId = '${myId}_$otherUserId';

    await _requests.doc(requestId).set({
      'fromUid': myId,
      'toUid': otherUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Requests addressed to the logged-in user.
  Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequests() {
    return _requests
        .where('toUid', isEqualTo: currentUserId)
        .snapshots();
  }

  // Requests sent by the logged-in user.
  Stream<QuerySnapshot<Map<String, dynamic>>> outgoingRequests() {
    return _requests
        .where('fromUid', isEqualTo: currentUserId)
        .snapshots();
  }

  // Accept a request addressed to the current user.
  Future<void> acceptRequest(String requestId) async {
    await _requests.doc(requestId).update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // Decline a request addressed to the current user.
  Future<void> declineRequest(String requestId) async {
    await _requests.doc(requestId).update({
      'status': 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // Receive another user's public display name.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPublicProfile(
    String userId,
  ) {
    return _firestore
        .collection('publicProfiles')
        .doc(userId)
        .snapshots();
  }
}
