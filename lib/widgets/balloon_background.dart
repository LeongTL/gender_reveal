import 'package:flutter/material.dart';
import 'dart:math';
import '../models/balloon.dart';
import 'balloon_painter.dart';

/// Animated background widget displaying floating balloons
/// 
/// This widget creates and animates multiple balloons that float upward
/// and sway side to side, providing a festive background for the gender
/// reveal party application.
class BalloonBackground extends StatefulWidget {
  /// Number of balloons to display (default: 15)
  final int balloonCount;
  
  /// Whether to enable animations (useful for testing)
  final bool enableAnimation;
  
  /// Constructor with optional balloon count and animation parameters
  const BalloonBackground({
    super.key, 
    this.balloonCount = 15,
    this.enableAnimation = true,
  });

  @override
  State<BalloonBackground> createState() => _BalloonBackgroundState();
}

class _BalloonBackgroundState extends State<BalloonBackground>
    with SingleTickerProviderStateMixin {
  /// Animation controller for managing balloon movement
  late AnimationController _controller;
  
  /// List of balloon objects to be animated
  List<Balloon> balloons = [];
  
  /// Random number generator for balloon properties
  final Random random = Random();
  
  @override
  void initState() {
    super.initState();
    _initializeBalloons();
    _setupAnimationController();
  }
  
  /// Creates initial balloon objects with random properties
  void _initializeBalloons() {
    for (int i = 0; i < widget.balloonCount; i++) {
      balloons.add(Balloon(
        x: random.nextDouble() * 300, // Random horizontal position
        y: random.nextDouble() * 600 + 600, // Start below screen
        speed: 0.5 + random.nextDouble() * 1.5, // Random speed (0.5-2.0)
        color: Colors.primaries[random.nextInt(Colors.primaries.length)], // Random Material color
        size: 30 + random.nextDouble() * 30, // Random size (30-60)
        swingOffset: random.nextDouble() * 2, // Random swing pattern
        swingSpeed: 0.5 + random.nextDouble() * 1.0, // Random swing speed
      ));
    }
  }
  
  /// Sets up the animation controller for continuous balloon movement
  void _setupAnimationController() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // 20-second animation cycle
    );
    
    // Only start animation if enabled (for testing purposes)
    if (widget.enableAnimation) {
      _controller.repeat(); // Repeat indefinitely
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // If animation is disabled, just return static balloons
    if (!widget.enableAnimation) {
      return CustomPaint(
        painter: BalloonPainter(balloons: balloons),
        child: Container(), // Empty container to provide painting surface
      );
    }
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        _updateBalloonPositions();
        return CustomPaint(
          painter: BalloonPainter(balloons: balloons),
          child: Container(), // Empty container to provide painting surface
        );
      },
    );
  }
  
  /// Updates all balloon positions based on current time
  void _updateBalloonPositions() {
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0; // Current time in seconds
    final screenSize = MediaQuery.of(context).size;
    
    for (var balloon in balloons) {
      balloon.updatePosition(time, screenSize.height, screenSize.width);
    }
  }
}
