import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

/// Welcome screen that appears after authentication
/// 
/// This screen serves as an intermediary page that:
/// - Pre-loads the video for the vote screen
/// - Provides a welcoming message
/// - Ensures smooth transition to voting
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  
  /// Video controller for pre-loading
  late VideoPlayerController _videoController;
  
  /// Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  /// Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  /// Track video loading state
  bool _videoReady = false;
  bool _showContinueButton = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _preloadVideo();
    _startWelcomeSequence();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _preloadVideo() {
    _videoController = VideoPlayerController.asset('assets/video/video1.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        if (mounted) {
          setState(() {
            _videoReady = true;
          });
          debugPrint('Video pre-loaded successfully for vote screen');
        }
      }).catchError((error) {
        debugPrint('Video pre-load error: $error');
        // Still allow continuation even if video fails
        if (mounted) {
          setState(() {
            _videoReady = true; // Allow continuation
          });
        }
      });
  }

  void _startWelcomeSequence() async {
    // Start fade in animation
    _fadeController.forward();
    
    // Start slide animation after a delay
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _slideController.forward();
    }
    
    // Show continue button after animations and video loading
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted && _videoReady) {
      setState(() {
        _showContinueButton = true;
      });
    }
  }

  void _navigateToVoting() {
    // Pass the pre-loaded video controller to vote screen (if needed)
    context.go('/vote');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB6C1), Color(0xFF87CEEB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top spacing
              const Spacer(flex: 2),
              
              // Welcome content
              Expanded(
                flex: 6,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Welcome emoji
                        const Text(
                          '🎉',
                          style: TextStyle(fontSize: 80),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Welcome title
                        const Text(
                          '欢迎参加',
                          style: TextStyle(
                            fontSize: 32,
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
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Event title
                        const Text(
                          '宝宝性别揭晓派对',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 8.0,
                                color: Colors.black,
                                offset: Offset(1.5, 1.5),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Loading indicator or ready message
                        if (!_videoReady)
                          Column(
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '准备中...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            '🎈 准备就绪！',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Continue button
              Expanded(
                flex: 2,
                child: AnimatedOpacity(
                  opacity: _showContinueButton ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _showContinueButton ? _navigateToVoting : null,
                      icon: const Icon(Icons.arrow_forward, size: 24),
                      label: const Text(
                        '开始投票',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF9A4FFF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Bottom spacing
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
