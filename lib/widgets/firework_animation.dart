import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A single firework particle with position and animation properties
class FireworkParticle {
  late double x;
  late double y;
  late double vx;
  late double vy;
  late Color color;
  late double life;
  late double decay;
  late double size;

  FireworkParticle(double startX, double startY, Color particleColor) {
    x = startX;
    y = startY;
    
    // Random velocity for explosion effect with more variation
    final angle = math.Random().nextDouble() * 2 * math.pi;
    final speed = 80 + math.Random().nextDouble() * 120; // Increased speed range
    vx = math.cos(angle) * speed;
    vy = math.sin(angle) * speed;
    
    color = particleColor;
    life = 1.0;
    decay = 0.02 + math.Random().nextDouble() * 0.03; // Slightly faster decay for quicker animations
    size = 1.5 + math.Random().nextDouble() * 5; // Larger size range
  }

  void update() {
    x += vx * 0.016; // Assuming 60fps
    y += vy * 0.016;
    vy += 250 * 0.016; // Increased gravity for more realistic fall
    life -= decay;
    
    // Slow down particles over time with air resistance
    vx *= 0.985; // Slightly more air resistance
    vy *= 0.985;
  }

  bool get isDead => life <= 0;
}

/// Custom painter for rendering firework particles
class FireworkPainter extends CustomPainter {
  final List<FireworkParticle> particles;

  FireworkPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final particle in particles) {
      if (!particle.isDead) {
        final opacity = particle.life;
        final particleSize = particle.size * particle.life;
        
        // Draw glow effect
        paint.color = particle.color.withOpacity(opacity * 0.3);
        canvas.drawCircle(
          Offset(particle.x, particle.y),
          particleSize * 2,
          paint,
        );
        
        // Draw main particle
        paint.color = particle.color.withOpacity(opacity);
        canvas.drawCircle(
          Offset(particle.x, particle.y),
          particleSize,
          paint,
        );
        
        // Draw bright center
        paint.color = Colors.white.withOpacity(opacity * 0.8);
        canvas.drawCircle(
          Offset(particle.x, particle.y),
          particleSize * 0.3,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Firework animation widget that creates an explosion effect
class FireworkAnimation extends StatefulWidget {
  final Offset position;
  final Color color;
  final VoidCallback? onComplete;

  const FireworkAnimation({
    super.key,
    required this.position,
    required this.color,
    this.onComplete,
  });

  @override
  State<FireworkAnimation> createState() => _FireworkAnimationState();
}

class _FireworkAnimationState extends State<FireworkAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<FireworkParticle> particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500), // Increased from 1500ms for more dramatic effect
      vsync: this,
    );

    // Create particles for the firework explosion
    _createParticles();

    // Start animation and call onComplete when done
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });

    // Listen to animation updates to update particles
    _controller.addListener(() {
      setState(() {
        for (final particle in particles) {
          particle.update();
        }
        // Remove dead particles to optimize performance
        particles.removeWhere((particle) => particle.isDead);
      });
    });
  }

  void _createParticles() {
    final random = math.Random();
    const particleCount = 80; // Increased particle count for more spectacular effect

    for (int i = 0; i < particleCount; i++) {
      // Create particles with more vibrant color variations
      Color colorVariation;
      if (random.nextBool()) {
        // Main color with brightness variation
        colorVariation = Color.lerp(
          widget.color,
          Colors.white,
          random.nextDouble() * 0.4,
        )!;
      } else {
        // Complementary colors for more variety
        final hsl = HSLColor.fromColor(widget.color);
        colorVariation = hsl.withLightness(
          (hsl.lightness + random.nextDouble() * 0.3).clamp(0.3, 1.0)
        ).withSaturation(
          (hsl.saturation + random.nextDouble() * 0.2).clamp(0.5, 1.0)
        ).toColor();
      }
      
      particles.add(
        FireworkParticle(
          widget.position.dx,
          widget.position.dy,
          colorVariation,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FireworkPainter(particles),
      child: Container(),
    );
  }
}

/// Overlay widget that manages multiple firework animations
class FireworkOverlay extends StatefulWidget {
  final Widget child;

  const FireworkOverlay({
    super.key,
    required this.child,
  });

  @override
  State<FireworkOverlay> createState() => FireworkOverlayState();

  /// Static method to show firework at a specific position
  static FireworkOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<FireworkOverlayState>();
  }
}

class FireworkOverlayState extends State<FireworkOverlay> {
  List<Widget> fireworks = [];

  /// Trigger a firework animation at the specified position
  void showFirework(Offset position, Color color) {
    print('FireworkOverlay.showFirework called at position: $position, color: $color'); // Debug
    
    final key = UniqueKey();
    
    final firework = Positioned(
      key: key,
      left: position.dx - 50,
      top: position.dy - 50,
      child: IgnorePointer(  // Prevent fireworks from blocking touch events
        child: SizedBox(
          width: 100,
          height: 100,
          child: FireworkAnimation(
            position: const Offset(50, 50),
            color: color, 
            onComplete: () {
              // Remove this firework when animation completes
              setState(() {
                fireworks.removeWhere((fw) => fw.key == key);
              });
            },
          ),
        ),
      ),
    );

    setState(() {
      fireworks.add(firework);
      print('Firework added to overlay, total fireworks: ${fireworks.length}'); // Debug
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ...fireworks,
      ],
    );
  }
}
