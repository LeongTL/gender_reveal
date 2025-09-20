import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'firebase_options.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/vote_screen.dart';
import 'screens/gender_reveal_screen.dart';

/// Main entry point for the Gender Reveal Party application
/// 
/// This Flutter app creates a real-time voting system for baby gender
/// predictions with animated balloon backgrounds and Firebase integration.
void main() async {
  // Ensure Flutter binding is initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure URL strategy for web routing
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
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
  
  GenderRevealApp({super.key, this.useFirebase = true});

  /// Router configuration for URL-based navigation
  late final GoRouter _router = GoRouter(
    routes: [
      // Main voting screen route (after auth)
      GoRoute(
        path: '/',
        builder: (context, state) {
          debugPrint('Navigating to root path: / (Vote Screen)');
          return useFirebase ? const AuthWrapper() : const VoteScreen();
        },
      ),
      // Gender reveal results page (chart only)
      GoRoute(
        path: '/gender-reveal',
        builder: (context, state) {
          debugPrint('Navigating to gender-reveal path: /gender-reveal');
          return const GenderRevealScreen();
        },
      ),
      // Direct voting page (alternative route)
      GoRoute(
        path: '/vote',
        builder: (context, state) {
          debugPrint('Navigating to vote path: /vote');
          return const VoteScreen();
        },
      ),
    ],
    // Set the initial location
    initialLocation: '/',
    // Enable debug logging
    debugLogDiagnostics: kDebugMode,
    // Handle unknown routes
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Page Not Found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('The page "${state.uri}" does not exist.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // Router configuration
      routerConfig: _router,
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
    );
  }
}
