import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../services/barrage_service.dart';

/// Display widget for showing barrage messages on the big screen during gender reveal
/// 
/// Features:
/// - Full-screen overlay with multiple horizontal tracks
/// - Messages fly from right to left at varying speeds
/// - Traditional Chinese calligraphy styling
/// - Firework effects and floating decorations
/// - Host controls for play/pause and clearing
/// - Smooth animations with fade-in/fade-out effects
class BarrageDisplayWidget extends StatefulWidget {
  /// Whether the barrage system is active
  final bool isActive;
  
  /// List of message documents from Firestore
  final List<DocumentSnapshot> messages;
  
  const BarrageDisplayWidget({
    super.key,
    required this.isActive,
    this.messages = const [],
  });

  @override
  State<BarrageDisplayWidget> createState() => _BarrageDisplayWidgetState();
}

class _BarrageDisplayWidgetState extends State<BarrageDisplayWidget>
    with TickerProviderStateMixin {
  
  /// Animation controller for the barrage system
  late AnimationController _barrageController;
  
  /// List of active message animations
  final List<BarrageMessage> _activeMessages = [];
  
  /// Animation controller for decorative elements
  late AnimationController _decorationController;
  
  /// Random number generator for animations
  final math.Random _random = math.Random();

  /// Set to track processed message IDs to detect new ones
  final Set<String> _processedMessageIds = {};

  /// Flag to track if random cycling has started
  bool _randomCyclingStarted = false;
  
  /// Track heights for message positioning (5 tracks)
  final List<double> _trackHeights = [0.15, 0.25, 0.35, 0.45, 0.55];
  
  /// Available speeds for messages
  final List<Duration> _messageSpeeds = [
    const Duration(seconds: 8),  // Slow
    const Duration(seconds: 6),  // Medium
    const Duration(seconds: 4),  // Fast
  ];
  
  /// Available gradient color combinations - DARKER COLORS for web visibility
  final List<List<Color>> _messageGradients = [
    // Darker Pink variations (more visible on web)
    [const Color(0xFFFF1493), const Color(0xFFFF69B4)], // Deep pink to hot pink
    [const Color(0xFFDC143C), const Color(0xFF8B0000)], // Crimson to dark red
    [const Color(0xFFFF6347), const Color(0xFFFF4500)], // Tomato to orange red
    
    // Darker Blue variations (more visible on web)
    [const Color(0xFF0000FF), const Color(0xFF4169E1)], // Blue to royal blue
    [const Color(0xFF1E90FF), const Color(0xFF0000CD)], // Dodger blue to medium blue
    [const Color(0xFF00CED1), const Color(0xFF008B8B)], // Dark turquoise to dark cyan
    
    // High contrast mixed variations
    [const Color(0xFFFF1493), const Color(0xFF0000FF)], // Deep pink to blue
    [const Color(0xFF0000FF), const Color(0xFFFF1493)], // Blue to deep pink
    [const Color(0xFFFFD700), const Color(0xFFFF8C00)], // Gold to dark orange
    [const Color(0xFF32CD32), const Color(0xFF006400)], // Lime green to dark green
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _processNewMessages();
  }

  void _initializeAnimations() {
    _barrageController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    
    _decorationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(BarrageDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always process messages when widget updates
    _processNewMessages();
  }

  /// Process messages - prioritize new messages, then start random cycling
  void _processNewMessages() {
    if (!widget.isActive || widget.messages.isEmpty) return;

    // Check for new messages and show them immediately
    for (final doc in widget.messages) {
      if (!_processedMessageIds.contains(doc.id)) {
        // This is a new message - show it immediately
        _addMessageToBarrage(doc);
        _processedMessageIds.add(doc.id);
      }
    }

    // Start random cycling if not already started and we have messages
    if (!_randomCyclingStarted && widget.messages.isNotEmpty) {
      _randomCyclingStarted = true;
      _startRandomCycling();
    }
  }

  /// Start cycling through random messages continuously
  void _startRandomCycling() {
    if (!mounted || !widget.isActive || widget.messages.isEmpty) return;
    
    // Show a random message
    final randomDoc = widget.messages[_random.nextInt(widget.messages.length)];
    _addMessageToBarrage(randomDoc);
    
    // Schedule next random message
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && widget.isActive) {
        _startRandomCycling();
      }
    });
  }

  /// Add a new message to the barrage animation
  void _addMessageToBarrage(DocumentSnapshot doc) {
    // Create unique ID with timestamp to allow same message to appear multiple times
    final uniqueId = '${doc.id}_${DateTime.now().millisecondsSinceEpoch}';
    
    final message = BarrageMessage(
      id: uniqueId,
      text: doc['barrage_message'] ?? '',
      sender: doc['createdBy'] ?? 'Unknown',
      gradientColors: _messageGradients[_random.nextInt(_messageGradients.length)],
      track: _trackHeights[_random.nextInt(_trackHeights.length)],
      speed: _messageSpeeds[_random.nextInt(_messageSpeeds.length)],
      startTime: DateTime.now(),
      vsync: this,
    );

    setState(() {
      _activeMessages.add(message);
    });

    // Remove message after animation completes
    Future.delayed(message.speed, () {
      if (mounted) {
        setState(() {
          _activeMessages.removeWhere((msg) => msg.id == message.id);
        });
        message.dispose();
      }
    });
  }

  /// Clear all active messages
  void _clearAllMessages() {
    setState(() {
      for (final message in _activeMessages) {
        message.dispose();
      }
      _activeMessages.clear();
    });
  }

  @override
  void dispose() {
    _barrageController.dispose();
    _decorationController.dispose();
    for (final message in _activeMessages) {
      message.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return Positioned.fill(
      child: Stack(
        children: [
          // Barrage messages
          ..._activeMessages.map(_buildBarrageMessage),
          
          // Host controls
          // _buildHostControls(),
        ],
      ),
    );
  }

  /// Build floating lantern decorations in corners


  /// Build individual barrage message animation
  Widget _buildBarrageMessage(BarrageMessage message) {
    return AnimatedBuilder(
      animation: message.controller,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        // Calculate horizontal position (right to left)
        final progress = message.controller.value;
        final x = screenWidth * (1 - progress) - 100; // Start off-screen right
        final y = screenHeight * message.track;
        
        // Fade in/out effect - WEB OPTIMIZED (less aggressive fading)
        double opacity = 1.0;
        if (progress < 0.05) {
          opacity = progress / 0.05; // Faster fade in
        } else if (progress > 0.95) {
          opacity = (1.0 - progress) / 0.05; // Faster fade out
        }
        
        // Ensure minimum opacity for web visibility
        opacity = opacity.clamp(0.7, 1.0);

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity,
            child: IntrinsicWidth(
              child: Container(
                constraints: const BoxConstraints(
                  minWidth:
                      200, // Minimum width to ensure sender name is visible
                  maxWidth:
                      600, // Maximum width to prevent overly long messages
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: message.gradientColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.transparent,
                    width: 0,
                  ), // Explicitly no border
                  boxShadow: [
                    // Enhanced shadow for web visibility
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 3,
                      offset: const Offset(2, 2),
                    ),
                    BoxShadow(
                      color: message.gradientColors.first.withValues(
                        alpha: 0.4,
                      ),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main message text
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _getContrastTextColor(message.gradientColors),
                          decoration: TextDecoration.none,
                        ),
                        softWrap: true,
                        maxLines: 2, // Allow up to 2 lines for longer messages
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Sender name aligned to the right
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '— ${message.sender}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: _getContrastTextColor(
                            message.gradientColors,
                          ).withValues(alpha: 0.8),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build host control buttons
  Widget _buildHostControls() {
    return Positioned(
      top: 50,
      right: 20,
      child: Column(
        children: [
          // Play/Pause button
          FloatingActionButton.small(
            onPressed: () {
              // Toggle barrage system
              // This could be connected to a state management system
            },
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            child: Icon(
              widget.isActive ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Clear all button
          FloatingActionButton.small(
            onPressed: _clearAllMessages,
            backgroundColor: Colors.red.withValues(alpha: 0.7),
            child: const Icon(
              Icons.clear_all,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Settings button
          FloatingActionButton.small(
            onPressed: () {
              // Show barrage settings
              _showBarrageSettings();
            },
            backgroundColor: Colors.blue.withValues(alpha: 0.7),
            child: const Icon(
              Icons.settings,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Show barrage settings dialog
  void _showBarrageSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('弹幕设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('清空所有消息'),
              trailing: const Icon(Icons.delete_forever),
              onTap: () {
                Navigator.pop(context);
                BarrageService.clearAllMessages();
                _clearAllMessages();
              },
            ),
            ListTile(
              title: const Text('清理旧消息'),
              trailing: const Icon(Icons.cleaning_services),
              onTap: () {
                Navigator.pop(context);
                BarrageService.cleanupOldMessages();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// Determine text color for good contrast with gradient background - WEB OPTIMIZED
  Color _getContrastTextColor(List<Color> gradientColors) {
    // For web deployment, use high contrast colors that work reliably
    // Calculate average brightness of the gradient colors
    double totalBrightness = 0.0;
    for (final color in gradientColors) {
      // Calculate relative luminance
      final r = color.red / 255.0;
      final g = color.green / 255.0;
      final b = color.blue / 255.0;
      final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
      totalBrightness += brightness;
    }
    final averageBrightness = totalBrightness / gradientColors.length;
    
    // Use more aggressive contrast for web visibility
    // Use pure white/black instead of semi-transparent variants
    return averageBrightness > 0.4 ? Colors.black : Colors.white;
  }
}

/// Individual barrage message with its own animation controller
class BarrageMessage {
  final String id;
  final String text;
  final String sender;
  final List<Color> gradientColors;
  final double track;
  final Duration speed;
  final DateTime startTime;
  final AnimationController controller;

  BarrageMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.gradientColors,
    required this.track,
    required this.speed,
    required this.startTime,
    required TickerProvider vsync,
  }) : controller = AnimationController(
          duration: speed,
          vsync: vsync,
        ) {
    // Start the animation
    controller.forward();
  }

  void dispose() {
    controller.dispose();
  }
}
