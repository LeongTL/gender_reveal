import 'package:cloud_firestore/cloud_firestore.dart';

/// Service class for managing Firebase Firestore operations
/// 
/// This service handles all Firebase interactions for the gender reveal
/// voting system, including reading vote counts and updating reveal status.
class FirestoreService {
  /// Firestore instance for database operations
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Document reference for the gender reveal event
  static const String _collectionName = 'events';
  static const String _documentId = 'baby-gender-reveal';
  
  /// Gets a stream of real-time updates from the gender reveal document
  /// 
  /// Returns a [Stream<DocumentSnapshot>] that emits updates whenever
  /// the vote counts or reveal status changes in Firestore.
  /// 
  /// The document structure should contain:
  /// - boyVotes: int (number of votes for boy)
  /// - girlVotes: int (number of votes for girl) 
  /// - isRevealed: bool (whether the gender has been revealed)
  static Stream<DocumentSnapshot> getGenderRevealStream() {
    return _firestore
        .collection(_collectionName)
        .doc(_documentId)
        .snapshots();
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
          .collection(_collectionName)
          .doc(_documentId)
          .update({'isRevealed': true});
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
  /// structure in Firestore. It creates the document with zero votes
  /// and reveal status set to false.
  /// 
  /// Parameters:
  /// - [mergeIfExists]: Whether to merge with existing document (default: true)
  /// 
  /// Returns a [Future<void>] that completes when initialization is successful.
  static Future<void> initializeGenderRevealDocument({bool mergeIfExists = true}) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(_documentId)
          .set({
        'boyVotes': 0,
        'girlVotes': 0,
        'isRevealed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
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
  /// This method resets vote counts to zero and sets isRevealed to false.
  /// Useful for testing or starting a new event.
  /// 
  /// Returns a [Future<void>] that completes when reset is successful.
  static Future<void> resetGenderRevealEvent() async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(_documentId)
          .update({
        'boyVotes': 0,
        'girlVotes': 0,
        'isRevealed': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
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
  /// of the gender reveal event.
  /// 
  /// Throws [FirebaseException] if the document doesn't exist or read fails.
  static Future<Map<String, dynamic>> getCurrentVoteData() async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(_documentId)
          .get();
      
      if (!doc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Gender reveal document does not exist',
        );
      }
      
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to get vote data: $e',
      );
    }
  }
}
