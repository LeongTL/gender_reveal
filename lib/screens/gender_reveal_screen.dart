import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'dart:math' as math;
import '../widgets/firework_animation.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

/// Main screen displaying real-time gender reveal voting results
/// 
/// This screen shows animated balloons in the background, real-time vote
/// counts for boy vs girl predictions, and handles the gender reveal moment.
class GenderRevealScreen extends StatefulWidget {
  const GenderRevealScreen({super.key});

  @override
  State<GenderRevealScreen> createState() => _GenderRevealScreenState();
}

class _GenderRevealScreenState extends State<GenderRevealScreen> {
  /// Current number of votes for boy prediction
  int boyVotes = 0;
  
  /// Current number of votes for girl prediction
  int girlVotes = 0;
  
  /// Whether the gender has been revealed
  bool isRevealed = false;
  
  /// Stream subscription for Firestore updates
  late Stream<Map<String, dynamic>> _firestoreStream;

  /// Last vote timestamp to prevent spam while allowing rapid voting
  DateTime? _lastVoteTime;
  static const Duration _voteCooldown = Duration(
    milliseconds: 300,
  ); // 300ms cooldown

  /// Global key to access the firework overlay
  final GlobalKey<FireworkOverlayState> _fireworkKey =
      GlobalKey<FireworkOverlayState>();
  
  /// Video controller for background video
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _setupFirestoreListener();
    _ensureUserExists();
    _initializeVideoPlayer();
  }
  
  /// Sets up real-time listener for Firestore vote updates
  /// 
  /// This method creates a stream that listens to changes in the
  /// gender reveal document and updates the UI accordingly.
  void _setupFirestoreListener() {
    _firestoreStream = FirestoreService.getGenderRevealStream();
  }

  /// Ensures current user exists in Firestore users collection
  ///
  /// This method is called on initialization to make sure the user
  /// is properly stored in the database for vote tracking.
  Future<void> _ensureUserExists() async {
    try {
      await FirestoreService.ensureCurrentUserExists();
    } catch (e) {
      // Silently handle error - voting will still work with fallback username
      debugPrint('Warning: Could not ensure user exists: $e');
    }
  }

  /// Initialize the video player for background video
  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset('assets/video/video1.mp4')
      ..initialize()
          .then((_) {
            // Ensure the first frame is shown and set to loop
            _videoController.setLooping(true);
            _videoController.play();
            if (mounted) {
              setState(() {});
            }
          })
          .catchError((error) {
            debugPrint('Video initialization error: $error');
          });
  }
  
  /// Triggers the gender reveal by updating Firestore
  /// 
  /// This method calls the FirestoreService to set the reveal flag,
  /// which will notify all connected devices to show the result.
  Future<void> _triggerReveal() async {
    try {
      await FirestoreService.triggerReveal();
    } catch (e) {
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger reveal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Resets the voting event (useful for testing or new events)
  Future<void> _resetEvent() async {
    try {
      await FirestoreService.resetGenderRevealEvent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event has been reset'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Casts a vote for boy prediction
  Future<void> _voteForBoy() async {
    print('_voteForBoy called'); // Debug

    try {
      print('Calling FirestoreService.voteForBoy()'); // Debug
      await FirestoreService.voteForBoy();
      print('Vote for boy successful'); // Debug
      // Success feedback is now handled by firework animation instead of SnackBar
    } catch (e) {
      // Silent error handling - firework animation provides feedback regardless
      print('Vote error (silent): $e');
    }
  }

  /// Casts a vote for girl prediction
  Future<void> _voteForGirl() async {
    print('_voteForGirl called'); // Debug

    try {
      print('Calling FirestoreService.voteForGirl()'); // Debug
      await FirestoreService.voteForGirl();
      print('Vote for girl successful'); // Debug
      // Success feedback is now handled by firework animation instead of SnackBar
    } catch (e) {
      // Silent error handling - firework animation provides feedback regardless
      print('Vote error (silent): $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return FireworkOverlay(
      key: _fireworkKey,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            // Video background - full screen with proper aspect ratio
            if (_videoController.value.isInitialized)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),

            // Commented out balloon background
            // const Positioned.fill(
            //   child: BalloonBackground(enableAnimation: true),
            // ),

            // Semi-transparent overlay for better text readability
            _buildOverlay(),

            // Main content with voting results
            _buildMainContent(),

            // Reset button in top-right corner (for testing)
            _buildResetButton(),

            // QR code in bottom right corner
            _buildQRCode(),
          ],
        ),
      ),
    );
  }
  
  /// Builds the app bar with user information and sign-out option
  PreferredSizeWidget _buildAppBar() {
    final User? user = AuthService.currentUser;
    final String displayName = AuthService.getUserDisplayName(user);
    
    return AppBar(
      title: const Text(
        '宝宝性别揭晓派对',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.pink.withValues(alpha: 0.8),
              Colors.blue.withValues(alpha: 0.8),
            ],
          ),
        ),
      ),
      actions: [
        // User profile display with better visibility
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User name display (visible on wider screens)
              if (MediaQuery.of(context).size.width > 500) ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            blurRadius: 2.0,
                            color: Colors.black26,
                            offset: Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user?.email != null && !AuthService.isAnonymous)
                      Text(
                        user!.email!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          shadows: [
                            Shadow(
                              blurRadius: 2.0,
                              color: Colors.black26,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (AuthService.isAnonymous)
                      const Text(
                        'Guest',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          shadows: [
                            Shadow(
                              blurRadius: 2.0,
                              color: Colors.black26,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              
              // Enhanced profile menu button
              PopupMenuButton<String>(
                icon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).primaryColor,
                      size: 22,
                    ),
                  ),
                ),
                tooltip: 'User profile',
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'signout') {
                    _signOut();
                  } else if (value == 'profile') {
                    _showUserProfile();
                  }
                },
                itemBuilder: (context) => [
                  // Enhanced user info header
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.person,
                              color: Theme.of(context).primaryColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                if (user?.email != null && !AuthService.isAnonymous)
                                  Text(
                                    user!.email!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (AuthService.isAnonymous)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.visibility_off,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Anonymous Guest',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AuthService.isAnonymous 
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AuthService.isAnonymous 
                                          ? Colors.orange.withValues(alpha: 0.3)
                                          : Colors.green.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    AuthService.isAnonymous ? 'Guest Session' : 'Authenticated',
                                    style: TextStyle(
                                      color: AuthService.isAnonymous 
                                          ? Colors.orange[700]
                                          : Colors.green[700],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  
                  // View Profile option
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.account_circle_outlined),
                        SizedBox(width: 12),
                        Text('View Profile'),
                      ],
                    ),
                  ),
                  
                  // Sign out option
                  const PopupMenuItem<String>(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
  
  /// Handle user sign-out
  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      // The AuthWrapper will automatically redirect to login screen
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Builds the semi-transparent overlay for better text visibility
  Widget _buildOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
      ),
    );
  }
  
  /// Builds the main content area with voting results and controls
  Widget _buildMainContent() {
    return Center(
      child: StreamBuilder<Map<String, dynamic>>(
        stream: _firestoreStream,
        builder: (context, snapshot) {
          // Debug logging
          print('StreamBuilder state: ${snapshot.connectionState}');
          if (snapshot.hasError) {
            print('StreamBuilder error: ${snapshot.error}');
          }
          if (snapshot.hasData) {
            print('StreamBuilder data: ${snapshot.data}');
          }
          
          // Update local state from Firestore data
          if (snapshot.hasData) {
            final data = snapshot.data!;
            boyVotes = data['boyVotes'] ?? 0;
            girlVotes = data['girlVotes'] ?? 0;
            isRevealed = data['isRevealed'] ?? false;
          }
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildWelcomeMessage(),
              const SizedBox(height: 20),
              _buildTitle(),
              const SizedBox(height: 10),
              _buildVotingChart(),
              const SizedBox(height: 30),
              _buildLegend(),
              const SizedBox(height: 40),
              if (!isRevealed) _buildRevealButton(),
              if (isRevealed) _buildRevealResult(),
              if (snapshot.hasError) _buildErrorMessage(snapshot.error.toString()),
            ],
          );
        },
      ),
    );
  }
  
  /// Builds welcome message with user name
  Widget _buildWelcomeMessage() {
    final User? user = AuthService.currentUser;
    final String displayName = AuthService.getUserDisplayName(user);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.person,
              color: Theme.of(context).primaryColor,
              size: 18,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Welcome text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '欢迎, ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (AuthService.isAnonymous)
                    Icon(
                      Icons.visibility_off,
                      size: 14,
                      color: Colors.orange[600],
                    )
                  else
                    Icon(
                      Icons.verified,
                      size: 14,
                      color: Colors.green[600],
                    ),
                ],
              ),
              Text(
                AuthService.isAnonymous 
                    ? 'Welcome! • Guest Session'
                    : 'Welcome! • Ready to vote',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Builds the main title
  Widget _buildTitle() {
    return const Text(
      '实时投票结果',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [
          Shadow(
            blurRadius: 10.0,
            color: Colors.black,
            offset: Offset(2.0, 2.0),
          ),
        ],
      ),
    );
  }
  
  /// Builds the clean voting chart with only essential elements
  Widget _buildVotingChart() {
    final total = boyVotes + girlVotes;
    final maxVotes = math.max(boyVotes, girlVotes);
    final baseHeight = 60.0;
    final maxBarHeight = 180.0;
    
    // Calculate bar heights with minimum height for visibility
    final boyBarHeight = total > 0
        ? baseHeight + (boyVotes / (maxVotes > 0 ? maxVotes : 1)) * maxBarHeight
        : baseHeight;
    final girlBarHeight = total > 0
        ? baseHeight +
              (girlVotes / (maxVotes > 0 ? maxVotes : 1)) * maxBarHeight
        : baseHeight;

    return Container(
      width: 350,
      height: 320, // Fixed height to prevent overlap
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Total votes display at the top
          _buildEnhancedWoodenSignBoard(total),

          const SizedBox(height: 30),

          // Vote bars at the bottom
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Boy votes - Blue elephant bar
                _buildEnhancedAnimalBar(
                  height: boyBarHeight,
                  color: const Color(0xFF6BB6FF), // Bright sky blue
                  animal: _buildEmojiAnimal('🐘', const Color(0xFF6BB6FF)),
                  votes: boyVotes,
                  isLeft: true,
                  maxHeight: maxBarHeight + baseHeight,
                ),
                
                const SizedBox(width: 100),
                // Girl votes - Pink bunny bar
                _buildEnhancedAnimalBar(
                  height: girlBarHeight,
                  color: const Color(0xFFFF8FA3), // Soft coral pink
                  animal: _buildEmojiAnimal('🐰', const Color(0xFFFF8FA3)),
                  votes: girlVotes,
                  isLeft: false,
                  maxHeight: maxBarHeight + baseHeight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the adorable baby animal-themed vote picker
  Widget _buildLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          // Boy vote button
          Expanded(child: _buildBoyVoteButton()),
          
          const SizedBox(width: 16), // Simple spacing instead of fence
          
          // Girl vote button
          Expanded(child: _buildGirlVoteButton()),
        ],
      ),
    );
  }

  /// Builds the boy vote button with elephant emoji
  Widget _buildBoyVoteButton() {
    return GestureDetector(
      onTap: isRevealed
          ? null
          : () {
              _handleVote(context, const Color(0xFF89CFF0), _voteForBoy);
            },
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween(begin: 1.0, end: 1.0),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF89CFF0).withValues(alpha: 0.2),
                    const Color(0xFF87CEEB).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF89CFF0).withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF89CFF0).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Elephant emoji
                  const Text(
                    '🐘',
                    style: TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 8),
                  // BOY text
                  Text(
                    'BOY',
                    style: TextStyle(
                      color: const Color(0xFF4682B4),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds the girl vote button with bunny emoji
  Widget _buildGirlVoteButton() {
    return GestureDetector(
      onTap: isRevealed
          ? null
          : () {
              _handleVote(context, const Color(0xFFF4C2C2), _voteForGirl);
            },
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween(begin: 1.0, end: 1.0),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF4C2C2).withValues(alpha: 0.2),
                    const Color(0xFFFFB6C1).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF4C2C2).withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF4C2C2).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bunny emoji
                  const Text(
                    '🐰',
                    style: TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 8),
                  // GIRL text
                  Text(
                    'GIRL',
                    style: TextStyle(
                      color: const Color(0xFFD87093),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Handles voting with immediate response and async fireworks
  void _handleVote(BuildContext context, Color color, VoidCallback onVote) {
    final now = DateTime.now();

    // Check cooldown to prevent spam while allowing rapid voting
    if (_lastVoteTime != null &&
        now.difference(_lastVoteTime!) < _voteCooldown) {
      // Still show firework even during cooldown for visual feedback
      _triggerFireworkAsync(this.context, color); // Use main widget context
      return;
    }

    _lastVoteTime = now;

    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();

    // Call the vote function IMMEDIATELY (non-blocking)
    onVote();

    // Trigger firework animation asynchronously (don't block voting)
    _triggerFireworkAsync(this.context, color); // Use main widget context

    // ALSO try a simple test firework at a fixed position
    _triggerTestFirework(this.context, color); // Use main widget context
  }
  
  /// Builds the reveal button (shown before gender is revealed)
  Widget _buildRevealButton() {
    return ElevatedButton(
      onPressed: _triggerReveal,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: const Text(
        '揭晓答案!',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
  
  /// Builds the reveal result (shown after gender is revealed)
  Widget _buildRevealResult() {
    final isboy = boyVotes > girlVotes;
    final resultText = isboy ? '是男宝宝! 👶' : '是女宝宝! 👧';
    final resultColor = isboy ? Colors.blue : Colors.pink;
    
    return Text(
      resultText,
      style: TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.bold,
        color: resultColor,
        shadows: const [
          Shadow(
            blurRadius: 10.0,
            color: Colors.white,
            offset: Offset(2.0, 2.0),
          ),
        ],
      ),
    );
  }
  
  /// Builds error message widget
  Widget _buildErrorMessage(String error) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Error: $error',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
  
  /// Builds the reset button for testing purposes
  Widget _buildResetButton() {
    return Positioned(
      top: 50,
      right: 20,
      child: FloatingActionButton(
        mini: true,
        onPressed: _resetEvent,
        backgroundColor: Colors.grey.withValues(alpha: 0.7),
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  /// Builds QR code widget positioned in bottom right corner
  Widget _buildQRCode() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        width: 200,
        height: 200,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/qr-code.png',
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if image fails to load
              return Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: const Icon(Icons.qr_code, size: 40, color: Colors.grey),
              );
            },
          ),
        ),
      ),
    );
  }
  
  /// Show detailed user profile dialog
  void _showUserProfile() {
    final User? user = AuthService.currentUser;
    final String displayName = AuthService.getUserDisplayName(user);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile header
              Row(
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 28,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'User Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Profile picture
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    width: 100,
                    height: 100,
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).primaryColor,
                      size: 50,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // User name
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // User email or status
              if (user?.email != null && !AuthService.isAnonymous)
                Text(
                  user!.email!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              
              const SizedBox(height: 16),
              
              // Authentication status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AuthService.isAnonymous 
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AuthService.isAnonymous 
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AuthService.isAnonymous 
                          ? Icons.visibility_off 
                          : Icons.verified_user,
                      size: 16,
                      color: AuthService.isAnonymous 
                          ? Colors.orange[700]
                          : Colors.green[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AuthService.isAnonymous ? 'Anonymous Guest' : 'Authenticated User',
                      style: TextStyle(
                        color: AuthService.isAnonymous 
                            ? Colors.orange[700]
                            : Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // User details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildProfileDetailRow(
                      icon: Icons.fingerprint,
                      label: 'User ID',
                      value: user?.uid ?? 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileDetailRow(
                      icon: Icons.access_time,
                      label: 'Account Created',
                      value: user?.metadata.creationTime != null 
                          ? '${user!.metadata.creationTime!.day}/${user.metadata.creationTime!.month}/${user.metadata.creationTime!.year}'
                          : 'Unknown',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileDetailRow(
                      icon: Icons.login,
                      label: 'Last Sign In',
                      value: user?.metadata.lastSignInTime != null 
                          ? '${user!.metadata.lastSignInTime!.day}/${user.metadata.lastSignInTime!.month}/${user.metadata.lastSignInTime!.year}'
                          : 'Unknown',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _signOut();
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Helper method to build profile detail rows
  Widget _buildProfileDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  /// Builds a cute emoji animal with enhanced styling and sparkle effects
  Widget _buildEmojiAnimal(String emoji, Color backgroundColor) {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: backgroundColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main emoji
          Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 36, height: 1.0),
            ),
          ),
          // Sparkle effects around the emoji
          Positioned(
            top: 8,
            right: 12,
            child: Text(
              '✨',
              style: TextStyle(
                fontSize: 12,
                color: Colors.yellow.withValues(alpha: 0.8),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Text(
              '💫',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.withValues(alpha: 0.6),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 8,
            child: Text(
              '⭐',
              style: TextStyle(
                fontSize: 8,
                color: Colors.orange.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds enhanced wooden sign board with better typography and design
  Widget _buildEnhancedWoodenSignBoard(int total) {
    return Container(
      width: 500, // Match the width of individual vote bars
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFDEB887), // Burlywood
            const Color(0xFFCD853F), // Peru
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(15),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(14),
        ),
        border: Border.all(
          color: const Color(0xFF8B4513), // Saddle brown
          width: 3.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(3, 3),
          ),
          BoxShadow(
            color: const Color(0xFFFFF8DC).withValues(alpha: 0.4),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Enhanced wood grain pattern
          Positioned(
            top: 18,
            left: 25,
            right: 25,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            top: 38,
            left: 30,
            right: 20,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 22,
            right: 28,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),

          // Main text content with enhanced styling
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '总票数',
                  style: TextStyle(
                    color: const Color(0xFF5D4E37), // Dark brown
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFFFF8DC).withValues(alpha: 0.6),
                        blurRadius: 1,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8DC).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$total',
                    style: TextStyle(
                      color: const Color(0xFF5D4E37), // Dark brown
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFFF8DC).withValues(alpha: 0.8),
                          blurRadius: 2,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Enhanced nail details with shadows - corners only
          ...List.generate(4, (index) {
            late double top, bottom, left, right;
            switch (index) {
              case 0:
                top = 10;
                left = 18;
                bottom = double.nan;
                right = double.nan;
                break;
              case 1:
                top = 10;
                right = 18;
                bottom = double.nan;
                left = double.nan;
                break;
              case 2:
                bottom = 10;
                left = 18;
                top = double.nan;
                right = double.nan;
                break;
              case 3:
                bottom = 10;
                right = 18;
                top = double.nan;
                left = double.nan;
                break;
            }

            return Positioned(
              top: top.isNaN ? null : top,
              bottom: bottom.isNaN ? null : bottom,
              left: left.isNaN ? null : left,
              right: right.isNaN ? null : right,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [const Color(0xFF696969), const Color(0xFF2F2F2F)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 2,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Builds an enhanced animated animal bar with gentle wobble animation
  Widget _buildEnhancedAnimalBar({
    required double height,
    required Color color,
    required Widget animal,
    required int votes,
    required bool isLeft,
    required double maxHeight,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 50.0, end: height),
      curve: Curves.elasticOut,
      builder: (context, animatedHeight, child) {
        return Container(
          width: 80,
          height: maxHeight,
          child: Stack(
            children: [
              // Enhanced bar with hand-drawn irregular shape and gentle wobble
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1500),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, wobbleValue, child) {
                    return Transform.translate(
                      offset: Offset(
                        math.sin(wobbleValue * math.pi * 2) * 1,
                        0,
                      ),
                      child: Container(
                        height: animatedHeight - 45,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withValues(alpha: 0.9),
                              color.withValues(alpha: 0.7),
                              color,
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isLeft ? 25 : 18),
                            topRight: Radius.circular(isLeft ? 18 : 25),
                            bottomLeft: Radius.circular(isLeft ? 12 : 8),
                            bottomRight: Radius.circular(isLeft ? 8 : 12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(3, 3),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 3,
                              offset: const Offset(-1, -1),
                            ),
                          ],
                          border: Border.all(
                            color: color.withValues(alpha: 0.8),
                            width: 2.5,
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.2),
                                Colors.transparent,
                                color.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Enhanced animal character on top with subtle bounce
              Positioned(
                top: maxHeight - animatedHeight,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween(begin: 0.95, end: 1.0),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: animal);
                  },
                ),
              ),

              // Enhanced vote count with rounded friendly typography
              Positioned(
                bottom: 15,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$votes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.white,
                          blurRadius: 1,
                          offset: const Offset(0.5, 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Triggers firework animation asynchronously at the voting chart area
  void _triggerFireworkAsync(BuildContext context, Color color) {
    print('_triggerFireworkAsync called with color: $color'); // Debug

    // Run firework animation in the next frame to avoid blocking the tap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('PostFrameCallback executed'); // Debug

      final overlay = _fireworkKey.currentState;
      print('FireworkOverlay found: ${overlay != null}'); // Debug

      if (overlay != null && mounted) {
        // Get screen dimensions
        final size = MediaQuery.of(context).size;
        print('Screen size: ${size.width} x ${size.height}'); // Debug

        // Calculate voting chart area (center of screen, above legend)
        final chartCenterX = size.width / 2;
        final chartCenterY = size.height * 0.4; // Approximate chart position

        print('Chart center: ($chartCenterX, $chartCenterY)'); // Debug

        // Add some randomness for multiple fireworks
        final randomOffsetX = -50 + (math.Random().nextDouble() * 100);
        final randomOffsetY = -30 + (math.Random().nextDouble() * 60);

        final fireworkPosition = Offset(
          chartCenterX + randomOffsetX,
          chartCenterY + randomOffsetY,
        );
        print('Firework position: $fireworkPosition'); // Debug

        // Trigger main firework at chart area
        overlay.showFirework(fireworkPosition, color);
        print('Main firework triggered'); // Debug

        // Trigger additional smaller fireworks for more spectacular effect
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            overlay.showFirework(
              Offset(
                chartCenterX + randomOffsetX + 60,
                chartCenterY + randomOffsetY - 30,
              ),
              color.withOpacity(0.7),
            );
            print('Second firework triggered'); // Debug
          }
        });

        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            overlay.showFirework(
              Offset(
                chartCenterX + randomOffsetX - 60,
                chartCenterY + randomOffsetY + 30,
              ),
              color.withOpacity(0.7),
            );
            print('Third firework triggered'); // Debug
          }
        });
      } else {
        print('Overlay is null or widget not mounted'); // Debug
      }
    });
  }

  /// Test firework at a simple fixed position to verify fireworks are working
  void _triggerTestFirework(BuildContext context, Color color) {
    print('_triggerTestFirework called'); // Debug

    // Use GlobalKey to access the overlay
    final overlay = _fireworkKey.currentState;
    if (overlay != null) {
      overlay.showFirework(const Offset(400, 300), color);
      print('Test firework triggered via GlobalKey at center'); // Debug
    } else {
      print('FireworkOverlay not found for test firework'); // Debug
    }
  }
  
  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }
}