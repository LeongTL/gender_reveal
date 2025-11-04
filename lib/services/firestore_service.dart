import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

/// Service class for managing Firebase Firestore operations
/// 
/// This service handles all Firebase interactions for the gender reveal
/// voting system, including reading vote counts and updating reveal status.
class FirestoreService {
  /// Firestore instance for database operations
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Collection references
  static const String _usersCollection = 'users';
  static const String _boyVotesCollection = 'boyVotes';
  static const String _girlVotesCollection = 'girlVotes';
  static const String _userLatestVoteCollection = 'userLatestVotes';
  static const String _isRevealedCollection = 'isRevealed';
  static const String _isRevealedDocumentId = 'kpw3afYEF0Q2pVHnZlGg';

  /// Creates or updates user document in Firestore
  /// 
  /// This method stores/updates user information in the users collection.
  /// Structure: users/{userId} -> { userId, userName }
  static Future<void> createOrUpdateUser(String userId, String userName) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).set({
        'userId': userId,
        'userName': userName,
      }, SetOptions(merge: true));
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to create/update user: $e',
      );
    }
  }

  /// Gets user information from Firestore
  ///
  /// Returns the user document data or null if user doesn't exist.
  static Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to get user: $e',
      );
    }
  }

  /// Gets a stream of real-time updates with vote counts from collection lengths
  ///
  /// Returns a [Stream<Map<String, dynamic>>] that emits updates whenever
  /// votes are added/removed or reveal status changes.
  ///
  /// The data structure contains:
  /// - boyVotes: int (number of documents in boyVotes collection)
  /// - girlVotes: int (number of documents in girlVotes collection) 
  /// - isRevealed: bool (whether the gender has been revealed)
  static Stream<Map<String, dynamic>> getGenderRevealStream() {
    // Combine three streams for real-time updates
    return Rx.combineLatest3(
      _firestore.collection(_boyVotesCollection).snapshots().handleError((
        error,
      ) {
        print('Error in boyVotes stream: $error');
        throw error;
      }),
      _firestore.collection(_girlVotesCollection).snapshots().handleError((
        error,
      ) {
        print('Error in girlVotes stream: $error');
        throw error;
      }),
      _firestore
          .collection(_isRevealedCollection)
          .doc(_isRevealedDocumentId)
          .snapshots()
          .handleError((error) {
            print('Error in isRevealed stream: $error');
            throw error;
          }),
      (
        QuerySnapshot boyVotesSnapshot,
        QuerySnapshot girlVotesSnapshot,
        DocumentSnapshot revealDoc,
      ) {
        print(
          'Stream update - boyVotes: ${boyVotesSnapshot.docs.length}, girlVotes: ${girlVotesSnapshot.docs.length}',
        );

        // Get reveal status from isRevealed document
        final revealData = revealDoc.exists
            ? revealDoc.data() as Map<String, dynamic>?
            : null;
        final isRevealed = revealData?['isRevealed'] ?? false;

        return {
          'boyVotes': boyVotesSnapshot.docs.length,
          'girlVotes': girlVotesSnapshot.docs.length,
          'isRevealed': isRevealed,
        };
      },
    );
  }
  
  /// Triggers the gender reveal by updating the isRevealed flag
  /// 
  /// This method sets the 'isRevealed' field to true in Firestore,
  /// which will notify all connected clients to show the final result.
  /// 
  /// Returns a [Future<void>] that completes when the update is successful.
  /// 
  /// Throws [FirebaseException] if the update fails.
  static Future<void> triggerReveal() async {
    try {
      await _firestore
          .collection(_isRevealedCollection)
          .doc(_isRevealedDocumentId)
          .set({'isRevealed': true});
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to trigger reveal: $e',
      );
    }
  }
  
  /// Initializes the gender reveal document with default values
  /// 
  /// This method should be called once to set up the initial document
  /// structure in Firestore. It creates the document with reveal status 
  /// set to false. Vote counts are calculated from collection lengths.
  /// 
  /// Parameters:
  /// - [mergeIfExists]: Whether to merge with existing document (default: true)
  /// 
  /// Returns a [Future<void>] that completes when initialization is successful.
  static Future<void> initializeGenderRevealDocument({bool mergeIfExists = true}) async {
    try {
      await _firestore
          .collection(_isRevealedCollection)
          .doc(_isRevealedDocumentId)
          .set({
        'isRevealed': false,
      }, SetOptions(merge: mergeIfExists));
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to initialize document: $e',
      );
    }
  }
  
  /// Resets the gender reveal event to initial state
  /// 
  /// This method clears all votes from boyVotes and girlVotes collections
  /// and sets isRevealed to false. Useful for testing or starting a new event.
  /// 
  /// Returns a [Future<void>] that completes when reset is successful.
  static Future<void> resetGenderRevealEvent() async {
    try {
      // Clear all boy votes
      final boyVotesQuery = await _firestore
          .collection(_boyVotesCollection)
          .get();
      for (final doc in boyVotesQuery.docs) {
        await doc.reference.delete();
      }

      // Clear all girl votes
      final girlVotesQuery = await _firestore
          .collection(_girlVotesCollection)
          .get();
      for (final doc in girlVotesQuery.docs) {
        await doc.reference.delete();
      }

      // Reset reveal status
      await _firestore
          .collection(_isRevealedCollection)
          .doc(_isRevealedDocumentId)
          .set({'isRevealed': false});
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to reset event: $e',
      );
    }
  }
  
  /// Gets the current vote counts and reveal status
  /// 
  /// Returns a [Future<Map<String, dynamic>>] containing the current state
  /// of the gender reveal event with counts from collection lengths.
  /// 
  /// Throws [FirebaseException] if reading fails.
  static Future<Map<String, dynamic>> getCurrentVoteData() async {
    try {
      // Count documents in boyVotes and girlVotes collections
      final boyVotesSnapshot = await _firestore
          .collection(_boyVotesCollection)
          .get();
      final girlVotesSnapshot = await _firestore
          .collection(_girlVotesCollection)
          .get();

      // Get reveal status
      final revealDoc = await _firestore
          .collection(_isRevealedCollection)
          .doc(_isRevealedDocumentId)
          .get();
      
      final isRevealed = revealDoc.exists
          ? (revealDoc.data()?['isRevealed'] ?? false)
          : false;

      return {
        'boyVotes': boyVotesSnapshot.docs.length,
        'girlVotes': girlVotesSnapshot.docs.length,
        'isRevealed': isRevealed,
      };
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to get vote data: $e',
      );
    }
  }

  /// Casts a vote for boy prediction
  ///
  /// Creates a new document in boyVotes collection with user information.
  /// Vote count is calculated from collection length, not stored separately.
  ///
  /// Returns a [Future<void>] that completes when the vote is recorded.
  ///
  /// Throws [FirebaseException] if the update fails.
  static Future<void> voteForBoy() async {
    print('FirestoreService.voteForBoy() called'); // Debug
    try {
      final user = FirebaseAuth.instance.currentUser;
      print('Current user: ${user?.uid}'); // Debug
      if (user == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'User must be authenticated to vote',
        );
      }

      // Get user name from users collection
      print('Getting user data...'); // Debug
      final userData = await getUser(user.uid);
      final userName = userData?['userName'] ?? 'Anonymous User';
      print('User name: $userName'); // Debug

      // Add vote to boyVotes collection (for counting)
      print('Creating boy vote document...'); // Debug
      await _firestore.collection(_boyVotesCollection).add({
        'userId': user.uid,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userName,
      });

      // Update user's latest vote (for pools display)
      await _firestore.collection(_userLatestVoteCollection).doc(user.uid).set({
        'userId': user.uid,
        'userName': userName,
        'latestVote': 'boy',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Boy vote document created successfully'); // Debug
    } catch (e) {
      print('Error in voteForBoy: $e'); // Debug
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to vote for boy: $e',
      );
    }
  }

  /// Casts a vote for girl prediction
  ///
  /// Creates a new document in girlVotes collection with user information
  /// and increments the girlVotes count in the events collection.
  ///
  /// Casts a vote for girl prediction
  ///
  /// Creates a new document in girlVotes collection with user information.
  /// Vote count is calculated from collection length, not stored separately.
  ///
  /// Returns a [Future<void>] that completes when the vote is recorded.
  ///
  /// Throws [FirebaseException] if the update fails.
  static Future<void> voteForGirl() async {
    print('FirestoreService.voteForGirl() called'); // Debug
    try {
      final user = FirebaseAuth.instance.currentUser;
      print('Current user: ${user?.uid}'); // Debug
      if (user == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'User must be authenticated to vote',
        );
      }

      // Get user name from users collection
      print('Getting user data...'); // Debug
      final userData = await getUser(user.uid);
      final userName = userData?['userName'] ?? 'Anonymous User';
      print('User name: $userName'); // Debug

      // Add vote to girlVotes collection (for counting)
      print('Creating girl vote document...'); // Debug
      await _firestore.collection(_girlVotesCollection).add({
        'userId': user.uid,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userName,
      });

      // Update user's latest vote (for pools display)
      await _firestore.collection(_userLatestVoteCollection).doc(user.uid).set({
        'userId': user.uid,
        'userName': userName,
        'latestVote': 'girl',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Girl vote document created successfully'); // Debug
    } catch (e) {
      print('Error in voteForGirl: $e'); // Debug
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to vote for girl: $e',
      );
    }
  }

  /// Gets all boy votes with user information
  ///
  /// Returns a stream of QuerySnapshot containing all boy votes.
  static Stream<QuerySnapshot> getBoyVotesStream() {
    return _firestore
        .collection(_boyVotesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Gets all girl votes with user information
  ///
  /// Returns a stream of QuerySnapshot containing all girl votes.
  static Stream<QuerySnapshot> getGirlVotesStream() {
    return _firestore
        .collection(_girlVotesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Ensures current user exists in users collection
  ///
  /// This method should be called when user signs in to make sure
  /// their information is stored in the users collection.
  static Future<void> ensureCurrentUserExists() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final displayName =
          user.displayName ?? user.email?.split('@').first ?? 'Anonymous User';

      await createOrUpdateUser(user.uid, displayName);
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to ensure user exists: $e',
      );
    }
  }

  /// Clears all votes (for testing/reset purposes)
  ///
  /// This method deletes all documents from both boyVotes and girlVotes collections
  /// and resets the vote counts in the events collection.
  static Future<void> clearAllVotes() async {
    try {
      // Delete all boy votes
      final boyVotesQuery = await _firestore
          .collection(_boyVotesCollection)
          .get();
      for (final doc in boyVotesQuery.docs) {
        await doc.reference.delete();
      }

      // Delete all girl votes
      final girlVotesQuery = await _firestore
          .collection(_girlVotesCollection)
          .get();
      for (final doc in girlVotesQuery.docs) {
        await doc.reference.delete();
      }

      // Reset vote counts in events collection
      await resetGenderRevealEvent();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to clear all votes: $e',
      );
    }
  }

  /// Get a stream of user voting pools (boy voters and girl voters)
  /// Based on each user's latest vote choice, not all votes
  ///
  /// Returns a [Stream<Map<String, dynamic>>] containing:
  /// - boyVoters: List<Map> with users whose latest vote is for boy
  /// - girlVoters: List<Map> with users whose latest vote is for girl
  static Stream<Map<String, dynamic>> getVoterPoolsStream() {
    return _firestore.collection(_userLatestVoteCollection).snapshots().map((
      QuerySnapshot latestVotesSnapshot,
    ) {
      final boyVoters = <Map<String, dynamic>>[];
      final girlVoters = <Map<String, dynamic>>[];

      for (final doc in latestVotesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userInfo = {
          'userId': data['userId'] ?? 'Unknown',
          'userName': data['userName'] ?? 'Anonymous',
          'voteId': doc.id,
        };

        final latestVote = data['latestVote'] as String?;
        if (latestVote == 'boy') {
          boyVoters.add(userInfo);
        } else if (latestVote == 'girl') {
          girlVoters.add(userInfo);
        }
      }

      return {'boyVoters': boyVoters, 'girlVoters': girlVoters};
    });
  }
}
