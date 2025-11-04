import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service class to handle barrage messages for the gender reveal party
/// 
/// This service manages real-time messaging between guests (vote screen) 
/// and the big screen display (reveal screen) using Firebase Firestore.
/// 
/// Document structure:
/// - barrage_status: bool (always true when user creates message)
/// - barrage_message: string (the message content)
/// - createdAt: timestamp (when the message was created)
/// - createdBy: string (identifier for the sender)
class BarrageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'barrage_message';

  /// Send a new barrage message to Firestore
  /// 
  /// [message] - The message content (max 20 characters)
  /// [sender] - Optional sender identifier (defaults to 'guest')
  static Future<void> sendMessage(String message, {String sender = 'guest'}) async {
    try {
      // Validate message length
      if (message.trim().isEmpty || message.length > 20) {
        throw Exception('Message must be 1-20 characters');
      }

      await _firestore.collection(_collectionName).add({
        'barrage_message': message.trim(),
        'createdAt': Timestamp.now(),
        'barrage_status': true, // always set to true when user adds message
        'createdBy': sender,
      });

      debugPrint('Barrage message sent: $message');
    } catch (e) {
      debugPrint('Error sending barrage message: $e');
      rethrow;
    }
  }

  /// Get real-time stream of new barrage messages
  /// 
  /// Returns messages that haven't been displayed yet, ordered by timestamp
  static Stream<QuerySnapshot> getMessageStream() {
    return _firestore
        .collection(_collectionName)
        .where('barrage_status', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Get real-time stream of ALL barrage messages for continuous display
  /// 
  /// Returns all messages regardless of display status, ordered by timestamp
  static Stream<QuerySnapshot> getAllMessageStream() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Mark a message as displayed to prevent showing it again
  /// 
  /// [messageId] - The Firestore document ID of the message
  static Future<void> markAsDisplayed(String messageId) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(messageId)
          .update({'barrage_status': true});
    } catch (e) {
      debugPrint('Error marking message as displayed: $e');
    }
  }

  /// Clear all barrage messages (admin function)
  /// 
  /// Useful for starting fresh or clearing inappropriate content
  static Future<void> clearAllMessages() async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore.collection(_collectionName).get();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('All barrage messages cleared');
    } catch (e) {
      debugPrint('Error clearing messages: $e');
      rethrow;
    }
  }

  /// Get recent messages for preview (last 10 messages)
  /// 
  /// Used in the input widget to show recent activity
  static Stream<QuerySnapshot> getRecentMessagesStream() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }

  /// Clean up old messages (older than 24 hours)
  /// 
  /// Helps maintain database performance
  static Future<void> cleanupOldMessages() async {
    try {
      final yesterday = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );

      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('createdAt', isLessThan: yesterday)
          .get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Cleaned up ${snapshot.docs.length} old messages');
    } catch (e) {
      debugPrint('Error cleaning up old messages: $e');
    }
  }
}
