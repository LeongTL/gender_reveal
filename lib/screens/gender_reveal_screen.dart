import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'dart:async';
import '../widgets/firework_animation.dart';
import '../widgets/barrage_display_widget.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/barrage_service.dart';
import '../services/esp32_light_service.dart';
import '../services/encryption_service.dart';

/// Gender reveal results screen that displays only the voting chart and results
/// This screen shows the final voting results without any voting functionality
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

  /// Previous vote counts to detect changes for firework triggers
  int _previousBoyVotes = 0;
  int _previousGirlVotes = 0;

  /// Whether the gender has been revealed
  bool isRevealed = false;

  /// Stream subscription for Firestore updates
  late Stream<Map<String, dynamic>> _firestoreStream;

  /// Auth state subscription to handle sign out
  late Stream<User?> _authStream;

  /// Global key to access the firework overlay
  final GlobalKey<FireworkOverlayState> _fireworkKey =
      GlobalKey<FireworkOverlayState>();

  /// Video controller for background video
  late VideoPlayerController _videoController;

  /// ESP32 RGB light service for controlling physical lights
  final ESP32LightService _esp32Service = ESP32LightService();

  @override
  void initState() {
    super.initState();
    _checkAuthAndRedirect();
    _setupFirestoreListener();
    _setupAuthListener();
    _ensureUserExists();
    _initializeVideoPlayer();
  }

  /// Check if user is authenticated, redirect to auth screen if not
  void _checkAuthAndRedirect() {
    if (!AuthService.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/');
        }
      });
      return;
    }
  }

  /// Sets up real-time listener for Firestore vote updates
  void _setupFirestoreListener() {
    _firestoreStream = FirestoreService.getGenderRevealStream();
  }

  /// Sets up auth state listener to handle sign out
  void _setupAuthListener() {
    _authStream = AuthService.authStateChanges;
    _authStream.listen((User? user) {
      if (user == null && mounted) {
        // User signed out, redirect to auth screen
        context.go('/');
      }
    });
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
    _videoController = VideoPlayerController.asset('assets/video/video1.mp4')
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

  /// Triggers the gender reveal by updating Firestore
  Future<void> _triggerReveal() async {
    // Show password confirmation dialog with PIN-style input
    final List<TextEditingController> pinControllers = List.generate(
      4,
      (index) => TextEditingController(),
    );
    final List<FocusNode> focusNodes = List.generate(4, (index) => FocusNode());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认揭晓'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入密码以揭晓答案:'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  width: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: pinControllers[index],
                    focusNode: focusNodes[index],
                    textAlign: TextAlign.center,
                    obscureText: true,
                    obscuringCharacter: '•',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    maxLength: 1,
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 3) {
                        // Move to next field
                        focusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        // Move to previous field on backspace
                        focusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final pin = pinControllers.map((c) => c.text).join();
              Navigator.of(context).pop(pin == '0405');
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );

    // Clean up controllers and focus nodes
    for (var controller in pinControllers) {
      controller.dispose();
    }
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }

    if (confirmed != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('密码错误或已取消'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Password is correct! Trigger reveal IMMEDIATELY so vote screen updates
    try {
      // 1. Trigger reveal in Firestore FIRST (vote screen will update immediately!)
      await FirestoreService.triggerReveal();
      debugPrint('✅ Reveal triggered - vote screen should update now!');
    } catch (e) {
      debugPrint('❌ Error triggering reveal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger reveal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 2. Start ESP32 animation (flashing lights)
    if (mounted) {
      _sendRevealAnswerTheme(); // Fire and forget (no await)

      try {
        // 3. Fetch baby gender from database
        final babyGenderData = await FirestoreService.getBabyGender();
        final gender =
            babyGenderData?['baby_gender']?.toString().toLowerCase() ??
            'unknown';

        // 4. Show countdown with gender information
        // Vote screen is ALREADY showing the result by now!
        await _showCountdownAnimation(gender);
      } catch (e) {
        debugPrint('Error fetching gender for countdown: $e');
        // Show countdown with unknown gender as fallback
        await _showCountdownAnimation('unknown');
      }
    }
  }

  /// Shows a 10-second countdown animation in the center of the screen
  Future<void> _showCountdownAnimation(String gender) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _CountdownDialog(gender: gender);
      },
    );
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

  /// Clear all barrage messages (admin only)
  Future<void> _clearBarrageMessages() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear All Barrage Messages?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all barrage messages from the database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BarrageService.clearAllMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All barrage messages have been cleared'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear barrage messages: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Handle user sign-out
  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      // Explicitly redirect to auth screen after sign out
      if (mounted) {
        context.go('/');
      }
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

  /// Triggers firework animation when vote count increases (same config as vote screen)
  void _triggerFireworkForVoteIncrease(Color color) async {
    // Add a small delay then trigger multiple fireworks (same as vote screen)
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted && _fireworkKey.currentState != null) {
      final screenSize = MediaQuery.of(context).size;
      final random = math.Random();

      // Trigger multiple fireworks at random positions (same config as vote screen)
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

  /// Show ESP32 discovery dialog to manually input IP address
  Future<void> _showESP32DiscoveryDialog() async {
    final TextEditingController ipController = TextEditingController(
      text: _esp32Service.deviceIP ?? '192.168.31.37',
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Configure ESP32 RGB Light'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your ESP32 device IP address:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: '192.168.x.x',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: Make sure your ESP32 is on the same network and CORS is enabled.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final ip = ipController.text.trim();
                if (ip.isNotEmpty) {
                  _esp32Service.setDeviceIP(ip);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ESP32 configured: $ip'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Test ESP32 RGB light with current gender result color
  Future<void> _testESP32Light() async {
    if (!_esp32Service.isConnected) {
      // ESP32 not initialized - show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ ESP32 not configured. Please contact admin.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Show loading indicator
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Sending color to ESP32...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    // Determine color based on current vote leader
    bool success;
    String colorName;
    if (boyVotes > girlVotes) {
      success = await _esp32Service.sendBoyColor();
      colorName = 'Blue (Boy)';
    } else if (girlVotes > boyVotes) {
      success = await _esp32Service.sendGirlColor();
      colorName = 'Pink (Girl)';
    } else {
      // Tie - alternate or show both
      success = await _esp32Service.sendBoyColor();
      colorName = 'Blue (Tie - Boy color)';
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ESP32 light updated: $colorName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✗ Failed to update ESP32 light. Check connection.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Configure',
            textColor: Colors.white,
            onPressed: _showESP32DiscoveryDialog,
          ),
        ),
      );
    }
  }

  // NOTE: rgb_light calls _sendRevealAnswerCommands() but that method doesn't exist in rgb_light!
  // So we don't implement it either. The ESP32 theme animation does the work automatically.

  /// Send "Reveal Answer" theme animation to ESP32 (alternating pink/blue flashing)
  /// Synchronized with countdown timer: 10s blink → 5s blackout → 2s solid → gradient
  Future<void> _sendRevealAnswerTheme() async {
    debugPrint('🎨 Starting ESP32 reveal sequence');

    try {
      // Get baby gender from database first
      final babyGenderData = await FirestoreService.getBabyGender();
      final babyGender =
          babyGenderData?['baby_gender']?.toString().toLowerCase() ?? 'girl';

      debugPrint('👶 Baby gender: $babyGender');

      // PHASE 1: 10-second blinking countdown with blue/pink alternating
      debugPrint('🔵💗 Phase 1: 10-second blinking started');
      await FirestoreService.sendBlinkingCommand(
        10000, // 10 seconds duration
        255, // brightness
      );

      debugPrint('✅ Blinking command sent to Realtime Database!');

      // Wait 10 seconds (countdown: 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)
      await Future.delayed(const Duration(seconds: 9));
      if (!mounted) return;

      // PHASE 2: Blackout for 5 seconds ("Hold on..." phase)
      debugPrint('🖤 Phase 2: 5-second blackout started');
      await FirestoreService.sendTurnOffCommand();

      // Wait 5 seconds (showing "Hold on...")
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;

      // PHASE 3: Show solid gender color (PERMANENT)
      debugPrint('💙💗 Phase 3: Showing solid gender color [PERMANENT]');
      await FirestoreService.sendThemeCommand(babyGender, 255, permanent: true);
    } catch (e) {
      debugPrint('❌ Error in reveal sequence: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error sending reveal commands: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Animation state for reveal flashing
  bool _isRevealAnimating = false;
  int _revealFlashCount = 0;
  Timer? _revealFlashTimer;
  Timer? _colorCommandTimer;
  Color? _pendingColor;

  /// Debounced color command to prevent overwhelming ESP32 (EXACT match to rgb_light)
  void _sendColorCommandDebounced(Color color) {
    _pendingColor = color;

    // Cancel existing timer
    _colorCommandTimer?.cancel();

    // Set new timer (150ms delay - EXACT match to rgb_light)
    _colorCommandTimer = Timer(const Duration(milliseconds: 150), () {
      if (_pendingColor != null) {
        _esp32Service.setRGB(
          _pendingColor!.red,
          _pendingColor!.green,
          _pendingColor!.blue,
        );
        _pendingColor = null;
      }
    });
  }

  /// Start the reveal flash animation sequence
  /// EXACTLY matches rgb_light lines 601-647: immediate color commands, NO debouncing
  void _startRevealFlashAnimation() {
    // Stop any existing animation
    _stopRevealFlashAnimation();

    setState(() {
      _isRevealAnimating = true;
      _revealFlashCount = 0;
    });

    // Animation parameters (EXACT match to rgb_light)
    const flashDuration = 10000; // 10 seconds for flashing
    const flashInterval = 300; // 300ms per flash
    const totalFlashes = flashDuration ~/ flashInterval; // 33 flashes

    void performFlash() {
      if (!_isRevealAnimating || !mounted) return;

      if (_revealFlashCount < totalFlashes) {
        // Alternate between DodgerBlue and DeepPink (EXACT colors from rgb_light)
        final targetColor = (_revealFlashCount % 2 == 0)
            ? const Color(0xFF1E90FF) // DodgerBlue #1E90FF (30, 144, 255)
            : const Color(0xFFFF1493); // DeepPink #FF1493 (255, 20, 147)

        // CRITICAL: Use debouncing (EXACT match to rgb_light line 623)
        // This means only ~1 request gets sent (the last one), but ESP32 theme animation does the work!
        _sendColorCommandDebounced(targetColor);

        _revealFlashCount++;
        _revealFlashTimer = Timer(
          const Duration(milliseconds: flashInterval),
          performFlash,
        );
      } else {
        // Flashing complete - turn off lights for 5 seconds
        debugPrint('🎨 Flashing complete - turning off lights (5 seconds)');
        _esp32Service.setRGB(0, 0, 0); // Turn off

        // After 5 seconds, show solid color for 2 seconds based on database gender
        _revealFlashTimer = Timer(const Duration(seconds: 5), () {
          if (_isRevealAnimating && mounted) {
            _showSolidRevealColor();
          }
        });
      }
    }

    // Start the flashing sequence
    debugPrint('🎨 Starting reveal flash animation (10 seconds)');
    performFlash();
  }

  /// Show solid color for 2 seconds based on database gender, then start gradient animation
  Future<void> _showSolidRevealColor() async {
    try {
      // Get baby gender from database
      final babyGenderData = await FirestoreService.getBabyGender();
      final babyGender = babyGenderData?['baby_gender']
          ?.toString()
          .toLowerCase();

      // Determine colors based on database value
      Color solidColor;
      String genderName;

      if (babyGender == 'boy') {
        solidColor = const Color(0xFF1E90FF); // DodgerBlue
        genderName = 'boy (blue)';
      } else if (babyGender == 'girl') {
        solidColor = const Color(0xFFFF1493); // DeepPink
        genderName = 'girl (pink)';
      } else {
        // Default to pink if no database value or invalid value
        solidColor = const Color(0xFFFF1493); // DeepPink
        genderName = 'default (pink)';
        debugPrint('⚠️ No baby gender found in database, defaulting to pink');
      }

      debugPrint('🎨 Showing solid $genderName for 2 seconds');
      _esp32Service.setRGB(solidColor.red, solidColor.green, solidColor.blue);

      // After 2 seconds, start gradient animation
      _revealFlashTimer = Timer(const Duration(seconds: 2), () {
        if (_isRevealAnimating && mounted) {
          _startGradientAnimation(babyGender);
        }
      });
    } catch (e) {
      debugPrint('❌ Error getting baby gender: $e');
      // Fallback to pink if database error
      debugPrint('🎨 Fallback: Showing solid pink for 2 seconds');
      const fallbackPink = Color(0xFFFF1493);
      _esp32Service.setRGB(
        fallbackPink.red,
        fallbackPink.green,
        fallbackPink.blue,
      );

      // After 2 seconds, start pink gradient animation
      _revealFlashTimer = Timer(const Duration(seconds: 2), () {
        if (_isRevealAnimating && mounted) {
          _startGradientAnimation('girl'); // Default to girl
        }
      });
    }
  }

  /// Start gradient animation based on baby gender from database
  void _startGradientAnimation(String? babyGender) {
    List<Color> gradientColors;
    String colorSchemeName;

    if (babyGender == 'boy') {
      // BLUE gradient (rich, saturated blues)
      gradientColors = [
        const Color(0xFF000080), // Navy Blue - RGB(0, 0, 128)
        const Color(0xFF0000CD), // Medium Blue - RGB(0, 0, 205)
        const Color(0xFF1E90FF), // DodgerBlue - RGB(30, 144, 255)
        const Color(0xFF4169E1), // Royal Blue - RGB(65, 105, 225)
        const Color(0xFF6495ED), // Cornflower Blue - RGB(100, 149, 237)
        const Color(0xFF87CEEB), // Sky Blue - RGB(135, 206, 235)
      ];
      colorSchemeName = 'blue gradient';
    } else {
      // PINK gradient (rich, saturated pinks - default for girl or unknown)
      gradientColors = [
        const Color(0xFF8B0046), // Very Dark Pink - RGB(139, 0, 70)
        const Color(0xFFC71585), // Medium Violet Red - RGB(199, 21, 133)
        const Color(0xFFDB1B78), // Rich Pink - RGB(219, 27, 120)
        const Color(0xFFFF1493), // Deep Pink - RGB(255, 20, 147)
        const Color(0xFFE6388B), // Hot Magenta Pink - RGB(230, 56, 139)
        const Color(0xFFFF2D9D), // Bright Deep Pink - RGB(255, 45, 157)
      ];
      colorSchemeName = 'pink gradient';
    }

    debugPrint('🎨 Starting $colorSchemeName animation');

    // Send complete theme pattern to ESP32 ONCE - ESP32 handles the loop!
    final themeData = {
      'colors': gradientColors
          .map((color) => {'r': color.red, 'g': color.green, 'b': color.blue})
          .toList(),
      'duration': 1200, // Duration per color in milliseconds
      'transitionTime': 800, // Wait time between colors
      'loop': true, // Loop the animation
    };

    debugPrint('🎨 Sending $colorSchemeName theme pattern to ESP32 (ONCE)');
    _esp32Service.sendTheme(themeData);

    debugPrint('✅ Theme pattern sent - ESP32 will handle the animation loop');
  }

  /// Stop the reveal flash animation
  void _stopRevealFlashAnimation() {
    _revealFlashTimer?.cancel();
    if (mounted) {
      setState(() {
        _isRevealAnimating = false;
        _revealFlashCount = 0;
      });
    }
    debugPrint('🛑 Reveal flash animation stopped');
  }

  /// Debug method to show encrypted gender examples (remove in production)
  void _showEncryptedExamples() {
    // Show what encrypted values look like in the console
    print('\n=== 🔐 ENCRYPTED GENDER EXAMPLES ===');
    print(
      'Original "boy" → Encrypted: "${EncryptionService.encryptGender('boy')}"',
    );
    print(
      'Original "girl" → Encrypted: "${EncryptionService.encryptGender('girl')}"',
    );
    print('=====================================\n');

    // Show in UI as well
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Encrypted examples printed to console. Check debug output for encrypted values.',
        ),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FireworkOverlay(
      key: _fireworkKey,
      child: Stack(
        children: [
          // Main scaffold content
          Scaffold(
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

                // Main content with voting results
                _buildMainContent(),

                // QR code in bottom right corner
                _buildQRCode(),
              ],
            ),
          ),

          // Barrage display system - positioned on top but below app bar
          Positioned(
            top:
                AppBar().preferredSize.height +
                MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            bottom: 0,
            child: StreamBuilder<QuerySnapshot>(
              stream: BarrageService.getAllMessageStream(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return IgnorePointer(
                    child: BarrageDisplayWidget(
                      isActive: true,
                      messages: snapshot.data!.docs,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController.dispose();
    _stopRevealFlashAnimation();
    _colorCommandTimer?.cancel();
    super.dispose();
  }

  /// Builds the app bar with user information and navigation
  PreferredSizeWidget _buildAppBar() {
    final User? user = AuthService.currentUser;
    final String displayName = AuthService.getUserDisplayName(user);

    return AppBar(
      title: const Text(
        '宝宝性别揭晓派对',
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
        // Navigation back to vote page button
        IconButton(
          onPressed: () => context.go('/vote'),
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
                Icons.how_to_vote,
                color: Theme.of(context).primaryColor,
                size: 22,
              ),
            ),
          ),
          tooltip: 'Back to voting',
        ),

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
                  } else if (value == 'profile') {
                    _showUserProfile();
                  } else if (value == 'add_gender') {
                    _showAddGenderDialog();
                  } else if (value == 'reset_event') {
                    _resetEvent();
                  } else if (value == 'esp32_test') {
                    _testESP32Light();
                  } else if (value == 'reveal_theme') {
                    _sendRevealAnswerTheme();
                  } else if (value == 'esp32_discovery') {
                    _showESP32DiscoveryDialog();
                  } else if (value == 'clear_barrage') {
                    _clearBarrageMessages();
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
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
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
                                if (user?.email != null &&
                                    !AuthService.isAnonymous)
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
                                    AuthService.isAnonymous
                                        ? 'Guest Session'
                                        : 'Authenticated',
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

                  // Add Gender option (only for specific user)
                  if (AuthService.currentUser?.uid ==
                      'ZtVkO42SpvcIm8yqOkzSbYIBH6s1')
                    const PopupMenuItem<String>(
                      value: 'add_gender',
                      child: Row(
                        children: [
                          Icon(
                            Icons.baby_changing_station,
                            color: Colors.purple,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Add Gender',
                            style: TextStyle(color: Colors.purple),
                          ),
                        ],
                      ),
                    ),

                  // Reset Event option (only for specific user)
                  if (AuthService.currentUser?.uid ==
                      'ZtVkO42SpvcIm8yqOkzSbYIBH6s1')
                    const PopupMenuItem<String>(
                      value: 'reset_event',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.orange),
                          SizedBox(width: 12),
                          Text(
                            'Reset Event',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ],
                      ),
                    ),

                  // ESP32 Controls (only for admin)
                  if (AuthService.currentUser?.uid ==
                      'ZtVkO42SpvcIm8yqOkzSbYIBH6s1')
                    const PopupMenuDivider(),

                  // TEST button
                  if (AuthService.currentUser?.uid ==
                      'ZtVkO42SpvcIm8yqOkzSbYIBH6s1')
                    const PopupMenuItem<String>(
                      value: 'esp32_test',
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.purple),
                          SizedBox(width: 12),
                          Text('TEST'),
                        ],
                      ),
                    ),

                  // Reveal Theme button
                  if (AuthService.currentUser?.uid ==
                      'ZtVkO42SpvcIm8yqOkzSbYIBH6s1')
                    const PopupMenuItem<String>(
                      value: 'reveal_theme',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.teal),
                          SizedBox(width: 12),
                          Text('Reveal Theme'),
                        ],
                      ),
                    ),

                  // Discovery button
                  if (AuthService.currentUser?.uid ==
                      'ZtVkO42SpvcIm8yqOkzSbYIBH6s1')
                    PopupMenuItem<String>(
                      value: 'esp32_discovery',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.settings_input_antenna,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _esp32Service.isConnected ? 'Config' : 'Discovery',
                          ),
                        ],
                      ),
                    ),

                  // Clear Barrage Messages button (admin only)
                  if (AuthService.currentUser?.uid ==
                      'ZtVkO42SpvcIm8yqOkzSbYIBH6s1')
                    const PopupMenuItem<String>(
                      value: 'clear_barrage',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep, color: Colors.orange),
                          SizedBox(width: 12),
                          Text(
                            'Clear Barrage',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ],
                      ),
                    ),

                  if (AuthService.currentUser?.uid ==
                      'ZtVkO42SpvcIm8yqOkzSbYIBH6s1')
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
            ],
          ),
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

  /// Builds the main content area with voting results
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

          // Update local state from Firestore data and trigger fireworks for new votes
          if (snapshot.hasData) {
            final data = snapshot.data!;
            final newBoyVotes = data['boyVotes'] ?? 0;
            final newGirlVotes = data['girlVotes'] ?? 0;
            final newIsRevealed = data['isRevealed'] ?? false;

            // Detect vote increases and trigger fireworks
            if (newBoyVotes > _previousBoyVotes) {
              _triggerFireworkForVoteIncrease(
                const Color(0xFF6BB6FF),
              ); // Blue for boy
            }
            if (newGirlVotes > _previousGirlVotes) {
              _triggerFireworkForVoteIncrease(
                const Color(0xFFFF8FA3),
              ); // Pink for girl
            }

            // Update previous votes for next comparison
            _previousBoyVotes = boyVotes;
            _previousGirlVotes = girlVotes;

            // Update current votes and state
            boyVotes = newBoyVotes;
            girlVotes = newGirlVotes;
            isRevealed = newIsRevealed;
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTitle(),
              const SizedBox(height: 10),
              // Hide voting chart after reveal
              if (!isRevealed) _buildVotingChartWithPools(),
              const SizedBox(height: 40),
              if (!isRevealed &&
                  AuthService.currentUser?.uid ==
                      'ZtVkO42SpvcIm8yqOkzSbYIBH6s1')
                _buildRevealButton(),
              if (isRevealed) _buildRevealResult(),
              const SizedBox(height: 20),
              if (snapshot.hasError)
                _buildErrorMessage(snapshot.error.toString()),
            ],
          );
        },
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
      height: 320,
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
                  color: const Color(0xFF6BB6FF),
                  animal: _buildEmojiAnimal('🐘', const Color(0xFF6BB6FF)),
                  votes: boyVotes,
                  isLeft: true,
                  maxHeight: maxBarHeight + baseHeight,
                ),

                const SizedBox(width: 100),
                // Girl votes - Pink bunny bar
                _buildEnhancedAnimalBar(
                  height: girlBarHeight,
                  color: const Color(0xFFFF8FA3),
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

  /// Builds the voting chart with integrated voter pools beside each vote count
  Widget _buildVotingChartWithPools() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FirestoreService.getVoterPoolsStream(),
      builder: (context, poolSnapshot) {
        final boyVoters = poolSnapshot.hasData
            ? List<Map<String, dynamic>>.from(
                poolSnapshot.data!['boyVoters'] ?? [],
              )
            : <Map<String, dynamic>>[];
        final girlVoters = poolSnapshot.hasData
            ? List<Map<String, dynamic>>.from(
                poolSnapshot.data!['girlVoters'] ?? [],
              )
            : <Map<String, dynamic>>[];

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Boy voters pool
            _buildSeparateVoterPool(
              title: '男宝宝 👶',
              voters: boyVoters,
              color: const Color(0xFF6BB6FF),
              votes: boyVoters.length, // Use pool length instead of boyVotes
            ),

            const SizedBox(width: 20),

            // Center - Voting chart
            _buildVotingChart(),

            const SizedBox(width: 20),

            // Right side - Girl voters pool
            _buildSeparateVoterPool(
              title: '女宝宝 👧',
              voters: girlVoters,
              color: const Color(0xFFFF8FA3),
              votes: girlVoters.length, // Use pool length instead of girlVotes
            ),
          ],
        );
      },
    );
  }

  /// Builds a separate voter pool with white background
  Widget _buildSeparateVoterPool({
    required String title,
    required List<Map<String, dynamic>> voters,
    required Color color,
    required int votes,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 200,
        maxHeight: 400,
        minWidth: 200,
        maxWidth: 350,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and count side by side
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              // Vote count beside the title
              Text(
                '$votes 票',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Voters list - 3 names per row
          if (voters.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                '暂无投票',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: _buildVoterGrid(voters, color),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a grid layout with dynamic names per row (4 or 5 based on total count)
  Widget _buildVoterGrid(List<Map<String, dynamic>> voters, Color color) {
    // Determine names per row based on total voter count
    // If more than 9 rows (36+ names with 4 per row), use 5 per row
    int namesPerRow = 4;
    int estimatedRows = (voters.length / 4).ceil();
    if (estimatedRows > 9) {
      namesPerRow = 5;
    }

    // Group voters into rows
    List<List<Map<String, dynamic>>> rows = [];
    for (int i = 0; i < voters.length; i += namesPerRow) {
      int end = (i + namesPerRow < voters.length)
          ? i + namesPerRow
          : voters.length;
      rows.add(voters.sublist(i, end));
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((voter) {
              final userName = voter['userName'] as String? ?? 'Anonymous';
              return Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 40, // Minimum width for very short names
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    userName,
                    style: TextStyle(
                      fontSize: namesPerRow == 5 ? 10 : 11,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    // Remove maxLines restriction to allow full names
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  /// Builds the reveal button (shown before gender is revealed)
  Widget _buildRevealButton() {
    return ElevatedButton(
      onPressed: _triggerReveal,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: const Text('揭晓答案!', style: TextStyle(fontSize: 20)),
    );
  }

  /// Builds the reveal result (shown after gender is revealed)
  Widget _buildRevealResult() {
    // Fetch baby gender and voter pools
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        FirestoreService.getBabyGender(),
        FirestoreService.getVoterPoolsStream().first,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text(
            '加载失败: ${snapshot.error}',
            style: const TextStyle(fontSize: 20, color: Colors.red),
          );
        }

        final genderData = snapshot.data?[0] as Map<String, dynamic>?;
        final voterData = snapshot.data?[1] as Map<String, dynamic>?;

        final gender = genderData?['baby_gender'] as String? ?? 'unknown';
        final isBoy = gender.toLowerCase() == 'boy';
        final resultText = isBoy ? '男宝宝 👶' : '女宝宝 👧';
        final resultColor = isBoy ? Colors.blue : Colors.pink;

        // Theme colors based on actual gender (opposite of result for "wrong" voters)
        final themeColor = isBoy
            ? const Color(
                0xFFFFB6C1,
              ) // Light pink (for those who chose girl when it's boy)
            : const Color(
                0xFF89CFF0,
              ); // Light blue (for those who chose boy when it's girl)

        // Get the wrong voters (those who guessed incorrectly)
        final wrongVoters = isBoy
            ? List<Map<String, dynamic>>.from(voterData?['girlVoters'] ?? [])
            : List<Map<String, dynamic>>.from(voterData?['boyVoters'] ?? []);

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Move result up a bit
            const SizedBox(height: 40),

            // Result text
            Text(
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
            ),

            const SizedBox(height: 40),

            // Wrong voters section - ALWAYS SHOW
            Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Warning icon and message with orange beer icon
                  const Icon(Icons.sports_bar, size: 50, color: Colors.orange),
                  const SizedBox(height: 12),
                  Text(
                    '哎呀，你们猜错了！',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请拿起你们的啤酒，一罐下！🍺',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Wrong voters list or empty message
                  if (wrongVoters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '恭喜！大家都猜对了！🎉',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: wrongVoters.map((voter) {
                        final userName =
                            voter['userName'] as String? ?? 'Anonymous';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: themeColor, width: 2),
                          ),
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeColor.withValues(alpha: 0.9),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds ESP32 RGB light control buttons
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
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
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                      AuthService.isAnonymous
                          ? 'Anonymous Guest'
                          : 'Authenticated User',
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
        Icon(icon, size: 16, color: Colors.grey[600]),
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
      width: 500,
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
                        height: math.max(0, animatedHeight - 45),
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
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.2),
                                Colors.transparent,
                                color.withValues(alpha: 0.1),
                              ],
                            ),
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

  /// Show Add Gender dialog for selecting baby gender
  void _showAddGenderDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.baby_changing_station,
                    size: 28,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Baby Gender',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

              // Instructions
              const Text(
                'Select the baby\'s gender:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Gender selection buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showConfirmGenderDialog('boy');
                      },
                      icon: const Icon(Icons.boy, color: Colors.blue),
                      label: const Text(
                        'Boy',
                        style: TextStyle(color: Colors.blue),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showConfirmGenderDialog('girl');
                      },
                      icon: const Icon(Icons.girl, color: Colors.pink),
                      label: const Text(
                        'Girl',
                        style: TextStyle(color: Colors.pink),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.withOpacity(0.1),
                        foregroundColor: Colors.pink,
                        side: const BorderSide(color: Colors.pink),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Reset button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // _showResetGenderDialog();  // Temporarily commented out
                    print('Reset functionality temporarily disabled');
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Reset Previous Record',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show confirmation dialog for gender selection
  void _showConfirmGenderDialog(String selectedGender) {
    final Color genderColor = selectedGender == 'boy'
        ? Colors.blue
        : Colors.pink;
    final IconData genderIcon = selectedGender == 'boy'
        ? Icons.boy
        : Icons.girl;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: genderColor, size: 28),
            const SizedBox(width: 12),
            const Text('Confirm Selection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(genderIcon, size: 64, color: genderColor),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                children: [
                  const TextSpan(text: 'Are you sure the baby is a '),
                  TextSpan(
                    text: selectedGender.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: genderColor,
                    ),
                  ),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will save the gender information to the database.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _saveBabyGender(selectedGender);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: genderColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  /// Show reset confirmation dialog
  void _showResetGenderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Reset Gender Record'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_forever, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Are you sure you want to delete the previously added gender record?',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resetBabyGender();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Save baby gender to Firestore
  Future<void> _saveBabyGender(String gender) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await FirestoreService.saveBabyGender(gender);

      // Hide loading indicator
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                gender == 'boy' ? Icons.boy : Icons.girl,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text('Baby gender saved as ${gender.toUpperCase()}!'),
            ],
          ),
          backgroundColor: gender == 'boy' ? Colors.blue : Colors.pink,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Hide loading indicator
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Failed to save gender: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Reset/Delete baby gender from Firestore
  Future<void> _resetBabyGender() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await FirestoreService.deleteBabyGender();

      // Hide loading indicator
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.white),
              SizedBox(width: 8),
              Text('Baby gender record deleted successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Hide loading indicator
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Failed to delete gender record: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

/// Countdown dialog widget that displays a 10-second countdown animation
class _CountdownDialog extends StatefulWidget {
  final String gender;

  const _CountdownDialog({required this.gender});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog>
    with SingleTickerProviderStateMixin {
  int _currentCount = 10;
  Timer? _countdownTimer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showResult = false;
  bool _showHoldOn = false; // New state for "Hold on..." message
  int _holdOnCount = 5; // 5 seconds hold on message

  @override
  void initState() {
    super.initState();

    // Setup scale animation for the number
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // Start countdown
    _startCountdown();
  }

  void _startCountdown() {
    _animationController.forward(from: 0);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_showHoldOn && !_showResult) {
        // Phase 1: 10-second countdown (matches light blinking)
        setState(() {
          _currentCount--;
        });

        if (_currentCount > 0) {
          // Reset and replay animation for next number
          _animationController.forward(from: 0);
        }

        if (_currentCount <= 0) {
          // Switch to "Hold on..." phase (matches light off period)
          setState(() {
            _showHoldOn = true;
          });
          _animationController.forward(from: 0);
        }
      } else if (_showHoldOn && !_showResult) {
        // Phase 2: 5-second "Hold on..." (matches light off period)
        setState(() {
          _holdOnCount--;
        });

        if (_holdOnCount <= 0) {
          // Phase 3: Show result (matches solid color start)
          timer.cancel();
          setState(() {
            _showResult = true;
          });
          _animationController.forward(from: 0);
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine text based on gender
    final bool isBoy = widget.gender.toLowerCase() == 'boy';
    final String resultText = isBoy ? '是男宝宝! 👶' : '是女宝宝! 👧';
    final String emoji = isBoy ? '👶' : '👧';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Stack(
          children: [
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF89CFF0), // Light blue (baby blue)
                    Color(0xFFFFB6C1), // Light pink
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Show countdown, hold on message, or result based on state
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: _showResult
                            ? Column(
                                children: [
                                  Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 100),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    resultText,
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 10.0,
                                          color: Colors.black26,
                                          offset: Offset(2.0, 2.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : _showHoldOn
                            ? Column(
                                children: [
                                  // const Text(
                                  //   '⏳',
                                  //   style: TextStyle(fontSize: 80),
                                  // ),
                                  // const SizedBox(height: 20),
                                  const Text(
                                    'hmm...',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 10.0,
                                          color: Colors.black26,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Text(
                                  //   '$_holdOnCount',
                                  //   style: const TextStyle(
                                  //     fontSize: 48,
                                  //     fontWeight: FontWeight.w600,
                                  //     color: Colors.white70,
                                  //     shadows: [
                                  //       Shadow(
                                  //         blurRadius: 10.0,
                                  //         color: Colors.black26,
                                  //         offset: Offset(0, 2),
                                  //       ),
                                  //     ],
                                  //   ),
                                  // ),
                                ],
                              )
                            : Text(
                                '$_currentCount',
                                style: const TextStyle(
                                  fontSize: 120,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 20.0,
                                      color: Colors.black26,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                              ),
                      );
                    },
                  ),
                  if (!_showResult && !_showHoldOn) ...[
                    const SizedBox(height: 20),
                    const Text(
                      '准备揭晓...',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black26,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Close button (X) on top right
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    color: Colors.black87,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
