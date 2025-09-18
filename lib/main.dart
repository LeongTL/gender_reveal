import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/auth_wrapper.dart';

/// Main entry point for the Gender Reveal Party application
/// 
/// This Flutter app creates a real-time voting system for baby gender
/// predictions with animated balloon backgrounds and Firebase integration.
void main() async {
  // Ensure Flutter binding is initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  
  try {
    // Initialize Firebase for web, mobile, and desktop platforms
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
  } catch (e) {
    // Handle Firebase initialization errors gracefully
    debugPrint('Firebase initialization failed: $e');
    firebaseInitialized = false;
  }
  
  // Run the main app with appropriate screen
  runApp(GenderRevealApp(useFirebase: firebaseInitialized));
}

/// Root widget of the Gender Reveal Party application
/// 
/// This widget configures the app-wide theme, title, and navigation.
/// It uses Material Design with custom color schemes for the party theme.
class GenderRevealApp extends StatelessWidget {
  /// Whether to use Firebase (true) or demo mode (false)
  final bool useFirebase;
  
  const GenderRevealApp({super.key, this.useFirebase = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App configuration
      title: '宝宝性别揭晓派对', // Baby Gender Reveal Party in Chinese
      debugShowCheckedModeBanner: false, // Hide debug banner in release
      
      // Theme configuration with modern Material 3 design
      theme: ThemeData(
        useMaterial3: true, // Enable Material 3 design system
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink, // Primary color for the party theme
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        
        // Custom button theme for the reveal button
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.3),
          ),
        ),
        
        // Text theme with better contrast for overlay text
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
      ),
      
      // Dark theme configuration (optional)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: Brightness.dark,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      
      // Set the appropriate home screen based on Firebase availability
      home: useFirebase 
          ? const AuthWrapper()
          : const AuthWrapper(), // Use same wrapper even without Firebase (will show demo mode)
    );
  }
}
