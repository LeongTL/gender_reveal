import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../widgets/firework_animation.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

/// Voting screen where users can cast their votes for baby gender prediction
/// This is now the main screen after authentication
class VoteScreen extends StatefulWidget {
  const VoteScreen({super.key});

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
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
  static const Duration _voteCooldown = Duration(milliseconds: 300);

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
  void _setupFirestoreListener() {
    _firestoreStream = FirestoreService.getGenderRevealStream();
  }

  /// Ensures current user exists in Firestore users collection
  Future<void> _ensureUserExists() async {
    try {
      await FirestoreService.ensureCurrentUserExists();
    } catch (e) {
      debugPrint('Warning: Could not ensure user exists: $e');
    }
  }

  /// Initialize the video player for background video
  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset('assets/video/video2.mp4')
      ..initialize()
          .then((_) {
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

  /// Casts a vote for boy prediction
  Future<void> _voteForBoy() async {
    try {
      await FirestoreService.voteForBoy();
    } catch (e) {
      debugPrint('Vote error: $e');
    }
  }

  /// Casts a vote for girl prediction
  Future<void> _voteForGirl() async {
    try {
      await FirestoreService.voteForGirl();
    } catch (e) {
      debugPrint('Vote error: $e');
    }
  }

  /// Handles voting with immediate response and async fireworks
  void _handleVote(BuildContext context, Color color, VoidCallback onVote) {
    final now = DateTime.now();

    // Check cooldown to prevent spam while allowing rapid voting
    if (_lastVoteTime != null &&
        now.difference(_lastVoteTime!) < _voteCooldown) {
      _triggerFireworkAsync(context, color);
      return;
    }

    _lastVoteTime = now;

    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();

    // Call the vote function IMMEDIATELY (non-blocking)
    onVote();

    // Trigger firework animation asynchronously (don't block voting)
    _triggerFireworkAsync(context, color);
  }

  /// Triggers firework animation asynchronously
  void _triggerFireworkAsync(BuildContext context, Color color) async {
    // Add a small delay then trigger multiple fireworks
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted && _fireworkKey.currentState != null) {
      final screenSize = MediaQuery.of(context).size;
      final random = math.Random();

      // Trigger multiple fireworks at random positions
      for (int i = 0; i < 3; i++) {
        await Future.delayed(Duration(milliseconds: i * 200));
        if (mounted) {
          final x = random.nextDouble() * screenSize.width;
          final y = random.nextDouble() * screenSize.height * 0.7;
          _fireworkKey.currentState?.showFirework(Offset(x, y), color);
        }
      }
    }
  }

  /// Sign out the current user
  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
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

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
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

            // Semi-transparent overlay for better text readability
            _buildOverlay(),

            // Main content with voting interface
            _buildMainContent(),

            // QR code in bottom right corner
          ],
        ),
      ),
    );
  }

  /// Builds the app bar with user information and navigation
  PreferredSizeWidget _buildAppBar() {
    final User? user = AuthService.currentUser;
    final String displayName = AuthService.getUserDisplayName(user);

    return AppBar(
      title: const Text(
        '投票环节',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
        // Navigation to results page button
        IconButton(
          onPressed: () => context.go('/gender-reveal'),
          icon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
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
                Icons.bar_chart,
                color: Theme.of(context).primaryColor,
                size: 22,
              ),
            ),
          ),
          tooltip: 'View Results',
        ),

        // Profile menu button
        PopupMenuButton<String>(
          icon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
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
            }
          },
          itemBuilder: (context) => [
            // User info header
            PopupMenuItem<String>(
              enabled: false,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),

            // Sign out option
            const PopupMenuItem<String>(
              value: 'signout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Sign Out', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Builds the semi-transparent overlay for better text visibility
  Widget _buildOverlay() {
    return Positioned.fill(
      child: Container(color: Colors.black.withValues(alpha: 0.4)),
    );
  }

  /// Builds the main content area with voting interface
  Widget _buildMainContent() {
    return Center(
      child: StreamBuilder<Map<String, dynamic>>(
        stream: _firestoreStream,
        builder: (context, snapshot) {
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
              const SizedBox(height: 40),
              _buildTitle(),
              const SizedBox(height: 40),
              _buildVotingInterface(),
              const SizedBox(height: 40),
              _buildVoteCount(),
              if (snapshot.hasError)
                _buildErrorMessage(snapshot.error.toString()),
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
                ],
              ),
              Text(
                '请为宝宝性别投票',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the main title with encouraging context
  Widget _buildTitle() {
    return Column(
      children: [
        const Text(
          '你觉得是男宝宝还是女宝宝？',
          style: TextStyle(
            fontSize: 28,
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
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Text(
            '💝 每一票都很重要！尽情投票表达你的想法吧！',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 5.0,
                  color: Colors.black,
                  offset: Offset(1.0, 1.0),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '🎉 点击越多，烟花越精彩！',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.yellow,
            shadows: [
              Shadow(
                blurRadius: 3.0,
                color: Colors.black,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds the voting interface with boy and girl options
  Widget _buildVotingInterface() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Boy vote button
          Expanded(child: _buildBoyVoteButton()),

          const SizedBox(width: 20),

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
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF89CFF0).withValues(alpha: 0.8),
              const Color(0xFF87CEEB).withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF89CFF0), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF89CFF0).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🐘', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              'BOY',
              style: TextStyle(
                color: const Color(0xFF4682B4),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
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
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF4C2C2).withValues(alpha: 0.8),
              const Color(0xFFFFB6C1).withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF4C2C2), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF4C2C2).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🐰', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              'GIRL',
              style: TextStyle(
                color: const Color(0xFFD87093),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds current vote count display
  Widget _buildVoteCount() {
    final total = boyVotes + girlVotes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '当前投票结果',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text('🐘', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    '$boyVotes',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4682B4),
                    ),
                  ),
                  const Text(
                    'BOY',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4682B4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(width: 2, height: 50, color: Colors.grey[300]),
              Column(
                children: [
                  const Text('🐰', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    '$girlVotes',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD87093),
                    ),
                  ),
                  const Text(
                    'GIRL',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD87093),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '总投票数: $total',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
      child: Text('Error: $error', style: const TextStyle(color: Colors.white)),
    );
  }

  /// Builds QR code widget positioned in bottom right corner
}
