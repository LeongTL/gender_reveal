import 'package:flutter/material.dart';
import '../models/balloon.dart';

/// Custom painter class for rendering animated balloons
/// 
/// This painter draws balloons with shadows, highlights, and strings
/// to create a realistic balloon effect for the gender reveal party.
class BalloonPainter extends CustomPainter {
  /// List of balloons to be painted
  final List<Balloon> balloons;
  
  /// Constructor requiring a list of balloons to paint
  BalloonPainter({required this.balloons});
  
  /// Main painting method called by Flutter's rendering system
  /// 
  /// Parameters:
  /// - [canvas]: The canvas to draw on
  /// - [size]: The size of the widget being painted
  @override
  void paint(Canvas canvas, Size size) {
    // Create paint object for balloon shadows
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    // Draw each balloon with shadow, main body, highlight, and string
    for (var balloon in balloons) {
      _drawBalloonShadow(canvas, balloon, shadowPaint);
      _drawBalloonBody(canvas, balloon);
      _drawBalloonHighlight(canvas, balloon);
      _drawBalloonString(canvas, balloon);
    }
  }
  
  /// Draws the shadow of a balloon slightly offset from the main balloon
  /// 
  /// Parameters:
  /// - [canvas]: Canvas to draw on
  /// - [balloon]: Balloon object containing position and size
  /// - [shadowPaint]: Pre-configured paint for shadow rendering
  void _drawBalloonShadow(Canvas canvas, Balloon balloon, Paint shadowPaint) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(balloon.x + 2, balloon.y + 2), // Slight offset for shadow
        width: balloon.size,
        height: balloon.size * 1.2, // Balloons are taller than they are wide
      ),
      shadowPaint,
    );
  }
  
  /// Draws the main body of the balloon
  /// 
  /// Parameters:
  /// - [canvas]: Canvas to draw on
  /// - [balloon]: Balloon object containing position, size, and color
  void _drawBalloonBody(Canvas canvas, Balloon balloon) {
    final balloonPaint = Paint()..color = balloon.color;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(balloon.x, balloon.y),
        width: balloon.size,
        height: balloon.size * 1.2,
      ),
      balloonPaint,
    );
  }
  
  /// Draws a highlight on the balloon to give it a 3D appearance
  /// 
  /// Parameters:
  /// - [canvas]: Canvas to draw on
  /// - [balloon]: Balloon object containing position and size
  void _drawBalloonHighlight(Canvas canvas, Balloon balloon) {
    final highlightPaint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          balloon.x - balloon.size * 0.2, // Offset to upper-left for realistic lighting
          balloon.y - balloon.size * 0.2,
        ),
        width: balloon.size * 0.4,
        height: balloon.size * 0.5,
      ),
      highlightPaint,
    );
  }
  
  /// Draws the string attached to the balloon
  /// 
  /// Parameters:
  /// - [canvas]: Canvas to draw on
  /// - [balloon]: Balloon object containing position and size
  void _drawBalloonString(Canvas canvas, Balloon balloon) {
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(balloon.x, balloon.y + balloon.size * 0.6), // Start from bottom of balloon
      Offset(balloon.x, balloon.y + balloon.size * 1.5), // End below balloon
      linePaint,
    );
  }
  
  /// Determines whether the painter should repaint
  /// 
  /// Returns true to enable continuous animation
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint for smooth animation
  }
}
