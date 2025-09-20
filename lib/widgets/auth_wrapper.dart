import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../screens/auth_screen.dart';
import '../screens/vote_screen.dart';

/// Authentication wrapper that manages the app's authentication flow
/// 
/// This widget listens to authentication state changes and shows either
/// the login screen or the main app based on the user's authentication status.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Check if user is authenticated
        final User? user = snapshot.data;
        
        if (user != null) {
          // User is signed in, show voting screen
          return const VoteScreen();
        } else {
          // User is not signed in, show auth screen (always with gradient background)
          return AuthScreen(key: UniqueKey());
        }
      },
    );
  }
}
