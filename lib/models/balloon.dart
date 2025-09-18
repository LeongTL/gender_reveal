import 'package:flutter/material.dart';
import 'dart:math';

/// Model class representing a balloon with animation properties
/// 
/// This class encapsulates all the properties needed to render and animate
/// a balloon in the gender reveal party application.
class Balloon {
  /// X coordinate position of the balloon
  double x;
  
  /// Y coordinate position of the balloon
  double y;
  
  /// Speed at which the balloon moves upward (pixels per frame)
  double speed;
  
  /// Color of the balloon (randomly assigned from Material colors)
  Color color;
  
  /// Size of the balloon (width, height is calculated as size * 1.2)
  double size;
  
  /// Offset value for horizontal swinging motion
  double swingOffset;
  
  /// Speed of the horizontal swinging animation
  double swingSpeed;
  
  /// Constructor for creating a balloon with all required properties
  /// 
  /// Parameters:
  /// - [x]: Initial horizontal position
  /// - [y]: Initial vertical position  
  /// - [speed]: Upward movement speed
  /// - [color]: Balloon color
  /// - [size]: Balloon size
  /// - [swingOffset]: Initial swing offset
  /// - [swingSpeed]: Speed of swinging motion
  Balloon({
    required this.x,
    required this.y,
    required this.speed,
    required this.color,
    required this.size,
    required this.swingOffset,
    required this.swingSpeed,
  });
  
  /// Updates the balloon's position based on its animation properties
  /// 
  /// Parameters:
  /// - [time]: Current time in seconds for calculating swing motion
  /// - [screenHeight]: Screen height for resetting balloon position
  /// - [screenWidth]: Screen width for random repositioning
  void updatePosition(double time, double screenHeight, double screenWidth) {
    // Move balloon upward
    y -= speed;
    
    // Add horizontal swinging motion using sine wave
    x += sin(time * swingSpeed) * 0.5;
    
    // Reset balloon to bottom when it goes off screen
    if (y < -100) {
      y = screenHeight + 100;
      x = (screenWidth * 0.8) * (x.abs() % 1); // Keep within 80% of screen width
    }
  }
}
