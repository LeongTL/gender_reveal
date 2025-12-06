import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'encryption_service.dart';

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
  static const String _babyGenderCollection = 'z_baby_gender';
  static const String _babyGenderDocumentId = 'z_baby_document';

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
  static Future<void> initializeGenderRevealDocument({
    bool mergeIfExists = true,
  }) async {
    try {
      await _firestore
          .collection(_isRevealedCollection)
          .doc(_isRevealedDocumentId)
          .set({'isRevealed': false}, SetOptions(merge: mergeIfExists));
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

      // Clear all user latest votes (voter names)
      final userLatestVotesQuery = await _firestore
          .collection(_userLatestVoteCollection)
          .get();
      for (final doc in userLatestVotesQuery.docs) {
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

  /// Saves baby gender selection to Firestore with encryption
  ///
  /// This method encrypts the baby gender before storing it in the database
  /// so you can't accidentally see the answer when working with the database.
  /// Only one document is allowed in the collection at a time.
  static Future<void> saveBabyGender(String gender) async {
    try {
      // Validate input
      if (gender.toLowerCase() != 'boy' && gender.toLowerCase() != 'girl') {
        throw ArgumentError('Invalid gender. Must be "boy" or "girl".');
      }

      // Encrypt the gender value so it's not visible in the database
      final encryptedGender = EncryptionService.encryptGender(
        gender.toLowerCase(),
      );

      // Debug: Show what the encrypted value looks like
      print('🔐 Encrypting gender "$gender" → "$encryptedGender"');

      await _firestore
          .collection(_babyGenderCollection)
          .doc(_babyGenderDocumentId)
          .set({
            'baby_gender': encryptedGender, // Store encrypted value
            'created_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to save baby gender: $e',
      );
    }
  }

  /// Gets baby gender information from Firestore with decryption
  ///
  /// Returns the baby gender document data with decrypted gender value,
  /// or null if it doesn't exist.
  static Future<Map<String, dynamic>?> getBabyGender() async {
    try {
      final doc = await _firestore
          .collection(_babyGenderCollection)
          .doc(_babyGenderDocumentId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final encryptedGender = data['baby_gender'] as String?;

      if (encryptedGender != null) {
        try {
          // Decrypt the gender value before returning
          final decryptedGender = EncryptionService.decryptGender(
            encryptedGender,
          );

          // Debug: Show decryption (remove in production)
          print('🔓 Decrypting gender "$encryptedGender" → "$decryptedGender"');

          // Return data with decrypted gender
          return {
            ...data,
            'baby_gender': decryptedGender, // Replace encrypted with decrypted
          };
        } catch (decryptError) {
          print('❌ Failed to decrypt baby gender: $decryptError');
          // Return original data if decryption fails
          return data;
        }
      }

      return data;
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to get baby gender: $e',
      );
    }
  }

  /// Deletes the baby gender record from Firestore
  ///
  /// This method removes the baby gender document completely.
  static Future<void> deleteBabyGender() async {
    try {
      await _firestore
          .collection(_babyGenderCollection)
          .doc(_babyGenderDocumentId)
          .delete();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to delete baby gender: $e',
      );
    }
  }

  /// Stream for real-time baby gender updates with decryption
  ///
  /// Returns a stream that emits baby gender data changes in real-time
  /// with decrypted gender values.
  static Stream<Map<String, dynamic>?> getBabyGenderStream() {
    return _firestore
        .collection(_babyGenderCollection)
        .doc(_babyGenderDocumentId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;

          final data = snapshot.data()!;
          final encryptedGender = data['baby_gender'] as String?;

          if (encryptedGender != null) {
            try {
              // Decrypt the gender value in real-time
              final decryptedGender = EncryptionService.decryptGender(
                encryptedGender,
              );

              // Return data with decrypted gender
              return {
                ...data,
                'baby_gender':
                    decryptedGender, // Replace encrypted with decrypted
              };
            } catch (decryptError) {
              print('❌ Failed to decrypt baby gender in stream: $decryptError');
              // Return original data if decryption fails
              return data;
            }
          }

          return data;
        });
  }

  // ========================================
  // ESP32 Configuration Methods
  // ========================================

  /// Get ESP32 device IP address from Firestore
  ///
  /// Fetches the IP address from the esp_config collection.
  /// Returns null if the document doesn't exist or deviceIP field is missing.
  ///
  /// Structure: esp_config/esp_document -> { deviceIP: "192.168.31.37" }
  static Future<String?> getESP32DeviceIP() async {
    try {
      final doc = await _firestore
          .collection('esp_config')
          .doc('esp_document')
          .get();

      if (doc.exists) {
        final ip = doc.data()?['deviceIP'] as String?;
        if (ip != null && ip.isNotEmpty) {
          print('✅ ESP32 IP fetched from Firestore: $ip');
          return ip;
        } else {
          print('⚠️ ESP32 document exists but deviceIP field is empty');
          return null;
        }
      } else {
        print('⚠️ ESP32 config document does not exist in Firestore');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching ESP32 IP from Firestore: $e');
      return null;
    }
  }

  /// Update ESP32 device IP address in Firestore (Admin only)
  ///
  /// Updates or creates the IP address in the esp_config collection.
  /// This allows admins to change the ESP32 IP without code changes.
  static Future<void> updateESP32DeviceIP(String ip) async {
    try {
      await _firestore.collection('esp_config').doc('esp_document').set({
        'deviceIP': ip,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ ESP32 IP updated in Firestore: $ip');
    } catch (e) {
      print('❌ Error updating ESP32 IP in Firestore: $e');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to update ESP32 IP: $e',
      );
    }
  }

  /// ========================================
  /// ESP32 Command Queue Methods (Cloud Relay)
  /// ========================================

  /// Collection name for ESP32 commands
  static const String _esp32CommandsCollection = 'esp32_commands';

  /// Adds a command to the ESP32 command queue in Firestore
  ///
  /// This method writes commands to Firestore instead of sending HTTP requests.
  /// The ESP32 will poll Firestore and execute pending commands.
  ///
  /// [command] - Command type: 'set_theme', 'set_color', 'run_effect', 'turn_off'
  /// [parameters] - Map of command-specific parameters
  /// [deviceId] - Optional device identifier for multi-device setups
  /// [createdBy] - Optional user ID who created the command
  static Future<String> addESP32Command({
    required String command,
    required Map<String, dynamic> parameters,
    String? deviceId,
    String? createdBy,
  }) async {
    try {
      final docRef = await _firestore.collection(_esp32CommandsCollection).add({
        'command': command,
        'parameters': parameters,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        if (deviceId != null) 'deviceId': deviceId,
        if (createdBy != null) 'createdBy': createdBy,
      });

      print('✅ ESP32 command added to Firestore: $command (${docRef.id})');
      return docRef.id;
    } catch (e) {
      print('❌ Error adding ESP32 command to Firestore: $e');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to add ESP32 command: $e',
      );
    }
  }

  /// Sends a blinking effect command to ESP32 via Realtime Database
  ///
  /// [duration] - Duration in milliseconds (e.g., 10000 for 10 seconds)
  /// [brightness] - Brightness value (0-255)
  static Future<String> sendBlinkingCommand(
    int duration,
    int brightness,
  ) async {
    return _sendCommandViaRestAPI(
      'set_blinking',
      {'duration': duration, 'brightness': brightness},
    );
  }

  /// Sends a theme command to ESP32 via Realtime Database (instant push!)
  ///
  /// [theme] - Theme name ('boy', 'girl', 'neutral', 'rainbow')
  /// [brightness] - Brightness value (0-255)
  /// [permanent] - If true, theme will not auto-return to rainbow
  static Future<String> sendThemeCommand(
    String theme,
    int brightness, {
    bool permanent = false,
  }) async {
    return _sendCommandViaRestAPI(
      'set_theme',
      {
        'theme': theme,
        'brightness': brightness,
        'permanent': permanent,
      },
    );
  }

  /// Helper method to send commands via REST API (web-compatible)
  static Future<String> _sendCommandViaRestAPI(
    String command,
    Map<String, dynamic> parameters,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      final dbUrl = FirebaseDatabase.instance.app.options.databaseURL;
      if (dbUrl == null) {
        throw Exception('Database URL not configured');
      }

      // Generate unique key
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = (timestamp % 100000).toString().padLeft(5, '0');
      final key = '-Web${timestamp}${randomSuffix}';

      final commandData = {
        'command': command,
        'parameters': parameters,
        'timestamp': timestamp,
        'createdBy': currentUser.uid,
      };

      // Get auth token
      final idToken = await currentUser.getIdToken();

      // Send via REST API
      final url = Uri.parse('$dbUrl/esp32_commands/$key.json?auth=$idToken');

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(commandData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Command sent via REST API: $command ($key)');
        return key;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending command via REST API: $e');
      rethrow;
    }
  }

  /// Sends a custom color command to ESP32 via Realtime Database (instant push!)
  ///
  /// [red] - Red value (0-255)
  /// [green] - Green value (0-255)
  /// [blue] - Blue value (0-255)
  /// [brightness] - LED brightness (0-255)
  static Future<String> sendColorCommand(
    int red,
    int green,
    int blue,
    int brightness,
  ) async {
    return _sendCommandViaRestAPI(
      'set_color',
      {
        'red': red,
        'green': green,
        'blue': blue,
        'brightness': brightness,
      },
    );
  }

  /// Sends an effect command to ESP32 via Realtime Database (instant push!)
  ///
  /// [effect] - Effect name: 'rainbow', 'sparkle', 'comet', 'running', 'fade', 'chase'
  /// [speed] - Effect speed (1-100)
  /// [brightness] - LED brightness (0-255)
  static Future<String> sendEffectCommand(
    String effect,
    int speed,
    int brightness, {
    int? duration, // Optional duration in milliseconds (for running effects)
  }) async {
    // Build parameters map
    final parameters = {
      'effect': effect,
      'speed': speed,
      'brightness': brightness,
    };

    // Add duration if specified (for running effects like comet)
    if (duration != null) {
      parameters['duration'] = duration;
    }

    return _sendCommandViaRestAPI('run_effect', parameters);
  }

  /// Sends a turn off command to ESP32 via Realtime Database (instant push!)
  static Future<String> sendTurnOffCommand() async {
    return _sendCommandViaRestAPI('turn_off', {});
  }

  // Command cleanup is now handled by ESP32 (no status field needed)
  // ESP32 deletes commands after execution completes

  /// Gets all pending commands from the command queue
  static Future<List<Map<String, dynamic>>> getPendingCommands() async {
    try {
      final snapshot = await _firestore
          .collection(_esp32CommandsCollection)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp')
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      print('❌ Error getting pending commands: $e');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to get pending commands: $e',
      );
    }
  }

  /// Updates the status of a command
  ///
  /// [commandId] - Document ID of the command
  /// [status] - New status: 'pending', 'processing', 'completed', 'failed'
  /// [errorMessage] - Optional error message if status is 'failed'
  static Future<void> updateCommandStatus(
    String commandId,
    String status, {
    String? errorMessage,
  }) async {
    try {
      await _firestore
          .collection(_esp32CommandsCollection)
          .doc(commandId)
          .update({
            'status': status,
            'processedAt': FieldValue.serverTimestamp(),
            if (errorMessage != null) 'errorMessage': errorMessage,
          });

      print('✅ Command status updated: $commandId -> $status');
    } catch (e) {
      print('❌ Error updating command status: $e');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to update command status: $e',
      );
    }
  }

  /// Deletes old completed/failed commands from the queue
  ///
  /// [olderThanHours] - Delete commands older than this many hours (default: 24)
  static Future<int> cleanupOldCommands({int olderThanHours = 24}) async {
    try {
      final cutoffTime = DateTime.now().subtract(
        Duration(hours: olderThanHours),
      );

      final snapshot = await _firestore
          .collection(_esp32CommandsCollection)
          .where('status', whereIn: ['completed', 'failed'])
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ Cleaned up ${snapshot.docs.length} old commands');
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error cleaning up old commands: $e');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to cleanup old commands: $e',
      );
    }
  }

  /// Cleans up old commands from Realtime Database (completed or older than 1 minute)
  /// Uses REST API for web compatibility
  static Future<void> cleanupRealtimeCommands() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ Cannot cleanup: User not authenticated');
        return;
      }

      final dbUrl = FirebaseDatabase.instance.app.options.databaseURL;
      if (dbUrl == null) {
        throw Exception('Database URL not configured');
      }

      // Get auth token
      final idToken = await currentUser.getIdToken();

      // Get all commands
      final url = Uri.parse('$dbUrl/esp32_commands.json?auth=$idToken');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data == null || data is! Map) {
        print('ℹ️ No commands to clean up');
        return;
      }

      int deletedCount = 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final entry in data.entries) {
        final key = entry.key as String;

        // Skip non-command fields
        if (!key.startsWith('-')) continue;

        final commandData = entry.value as Map<String, dynamic>?;
        if (commandData == null) continue;

        final status = commandData['status'] as String?;
        final timestamp = commandData['timestamp'] as int?;

        // Delete if completed or older than 1 minute
        final shouldDelete =
            status == 'completed' ||
            status == 'processing' ||
            (timestamp != null && (now - timestamp) > 60000);

        if (shouldDelete) {
          final deleteUrl = Uri.parse('$dbUrl/esp32_commands/$key.json?auth=$idToken');
          await http.delete(deleteUrl);
          deletedCount++;
          print('🧹 Deleted old command: $key (status: $status)');
        }
      }

      print('✅ Cleanup complete: $deletedCount commands deleted');
    } catch (e) {
      print('❌ Error cleaning up commands: $e');
    }
  }
}
