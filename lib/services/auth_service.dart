import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Authentication service that handles Google Sign-In using only firebase_auth
/// 
/// This service provides Google authentication for web and mobile platforms
/// using Firebase Auth's built-in OAuth providers without requiring 
/// the google_sign_in package.
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Get the current authenticated user
  static User? get currentUser => _auth.currentUser;
  
  /// Stream of authentication state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  /// Check if user is signed in
  static bool get isSignedIn => currentUser != null;
  
  /// Sign in with Google using Firebase Auth OAuth
  /// 
  /// This method works across all platforms:
  /// - Web: Uses popup-based OAuth flow
  /// - Mobile: Uses Firebase Auth's built-in OAuth handling
  /// - Desktop: Uses OAuth redirect flow
  /// 
  /// Returns the signed-in user or null if sign-in was cancelled/failed
  static Future<User?> signInWithGoogle() async {
    try {
      // Create Google Auth provider
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      // Configure OAuth scopes (optional)
      googleProvider.addScope('profile');
      googleProvider.addScope('email');
      
      // Set custom parameters (optional)
      googleProvider.setCustomParameters({
        'login_hint': 'user@example.com'
      });
      
      UserCredential credential;
      
      if (kIsWeb) {
        // For web: Use popup-based sign-in
        credential = await _auth.signInWithPopup(googleProvider);
      } else {
        // For mobile/desktop: Use redirect-based sign-in
        // Note: signInWithRedirect doesn't return UserCredential directly
        await _auth.signInWithRedirect(googleProvider);
        // We'll need to listen to auth state changes to get the result
        return null; // User will be signed in when redirect completes
      }
      
      debugPrint('Successfully signed in: ${credential.user?.displayName}');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google Sign-In failed: ${e.code} - ${e.message}');
      
      // Handle specific error codes
      switch (e.code) {
        case 'popup-closed-by-user':
          debugPrint('User closed the sign-in popup');
          break;
        case 'cancelled-popup-request':
          debugPrint('Multiple popup requests cancelled');
          break;
        case 'popup-blocked':
          debugPrint('Popup was blocked by browser');
          break;
        case 'operation-not-allowed':
          debugPrint('Google sign-in is not enabled in Firebase');
          break;
        case 'invalid-credential':
          debugPrint('Invalid Google credentials');
          break;
        default:
          debugPrint('Unknown authentication error: ${e.code}');
      }
      
      return null;
    } catch (e) {
      debugPrint('Unexpected error during Google Sign-In: $e');
      return null;
    }
  }
  
  /// Sign in anonymously (fallback option)
  /// 
  /// This allows users to participate without Google account
  /// Useful for testing or privacy-conscious users
  static Future<User?> signInAnonymously() async {
    try {
      final UserCredential credential = await _auth.signInAnonymously();
      debugPrint('Successfully signed in anonymously');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Anonymous Sign-In failed: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Unexpected error during anonymous Sign-In: $e');
      return null;
    }
  }
  
  /// Sign out from Firebase
  /// 
  /// Clears the authentication state and signs out the current user.
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('Successfully signed out');
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
  
  /// Get user display information
  /// 
  /// Returns a map with user information for display purposes.
  static Map<String, String?> getUserInfo() {
    final user = currentUser;
    return {
      'displayName': user?.displayName,
      'email': user?.email,
      'photoURL': user?.photoURL,
      'uid': user?.uid,
    };
  }
  
  /// Get user display name with fallback
  /// 
  /// Returns the user's display name or a default value for anonymous users
  static String getUserDisplayName(User? user) {
    if (user == null) return 'Guest';
    
    if (user.isAnonymous) {
      return 'Anonymous Guest';
    }
    
    return user.displayName ?? user.email ?? 'User';
  }
  
  /// Get user profile photo URL with fallback
  /// 
  /// Returns the user's photo URL or null if not available
  static String? getUserPhotoURL(User? user) {
    if (user == null || user.isAnonymous) return null;
    final photoURL = user.photoURL;
    if (photoURL != null) {
      debugPrint('Original photo URL: $photoURL');
      
      // For Google photos, we'll return null to force fallback to initials
      // This is because Google's CORS policy blocks direct image access from web apps
      // Even though the URL works in browser, it fails in Flutter web due to:
      // 1. CORS restrictions
      // 2. Referrer policy checks  
      // 3. Rate limiting (HTTP 429)
      if (photoURL.contains('googleusercontent.com')) {
        debugPrint('Google photo detected - using fallback to avoid CORS/rate limit issues');
        // Return null to trigger beautiful initials fallback instead of broken images
        return null;
      }
      
      // For non-Google URLs, return as-is
      debugPrint('Using non-Google photo URL: $photoURL');
      return photoURL;
    }
    return photoURL;
  }
  
  /// Generate a reliable avatar URL using Gravatar or similar service
  /// 
  /// This creates a backup profile image that actually works in web apps
  static String? getReliableAvatarURL(User? user) {
    if (user == null || user.isAnonymous) return null;
    
    // Option 1: Use Gravatar if user has email
    if (user.email != null) {
      // Generate Gravatar URL (works reliably in web apps)
      final email = user.email!.toLowerCase().trim();
      // For demo purposes, we could use a service like this:
      // return 'https://www.gravatar.com/avatar/${md5Hash}?s=120&d=identicon';
      debugPrint('Could use Gravatar for: $email');
    }
    
    // Option 2: Use a placeholder service
    final name = user.displayName ?? user.email ?? 'User';
    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    
    // Could use services like:
    // return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(initials)}&background=random&size=120';
    
    debugPrint('Generated initials for avatar: $initials');
    return null; // For now, return null to use our custom initials widget
  }
  
  /// Check if current user is anonymous
  static bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;
  
  /// Check if the current user is an admin
  /// 
  /// In a real app, this would check against a database of admin users.
  /// For this demo, we'll consider the first user or specific emails as admin.
  static bool isAdmin() {
    final user = currentUser;
    if (user == null) return false;
    
    // Add your admin logic here
    // For demo purposes, you could check specific email addresses
    const adminEmails = [
      // Add admin email addresses here
      // 'admin@example.com',
    ];
    
    return adminEmails.contains(user.email);
  }
  
  /// Initialize authentication listener
  /// 
  /// Call this method early in your app to set up authentication state monitoring.
  static void initializeAuthListener() {
    authStateChanges.listen((User? user) {
      if (user != null) {
        debugPrint('User signed in: ${user.displayName} (${user.email})');
      } else {
        debugPrint('User signed out');
      }
    });
  }
}
