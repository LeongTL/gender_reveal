# Google Authentication Setup Guide

This guide explains how to set up Google Authentication for the Gender Reveal Party app using only `firebase_auth` (no `google_sign_in` package required).

## Overview

The app uses Firebase Authentication's built-in OAuth providers to handle Google Sign-In across all platforms:

- **Web**: Uses popup-based OAuth flow
- **Mobile**: Uses Firebase Auth's built-in OAuth handling  
- **Desktop**: Uses OAuth redirect flow

## Firebase Console Setup

### 1. Enable Google Sign-In Provider

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method**
4. Click on **Google** provider
5. Toggle **Enable** to on
6. Add your **Project support email**
7. Click **Save**

### 2. Configure OAuth Consent Screen (if needed)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Navigate to **APIs & Services** → **OAuth consent screen**
4. Fill in required fields:
   - App name: "Gender Reveal Party"
   - User support email: your email
   - Developer contact information: your email
5. Add scopes if needed (email, profile are default)
6. Save and continue

### 3. Configure Authorized Domains

1. In Firebase Console → Authentication → Settings
2. Under **Authorized domains**, add:
   - `localhost` (for local development)
   - Your production domain (e.g., `yourdomain.com`)

## Platform-Specific Setup

### Web Setup

For web applications, Firebase automatically handles the OAuth flow. No additional setup required beyond Firebase configuration.

**Supported browsers:**
- Chrome
- Firefox  
- Safari
- Edge

### Mobile Setup (iOS/Android)

#### iOS Setup

1. In Firebase Console, download the updated `GoogleService-Info.plist`
2. Replace the file in your `ios/Runner` directory
3. In Xcode, verify the file is added to your target

#### Android Setup

1. In Firebase Console, download the updated `google-services.json`
2. Replace the file in your `android/app` directory
3. Verify your package name matches in Firebase Console

### Desktop Setup

Desktop applications use the web OAuth flow through the system browser.

## Code Implementation

### AuthService

The `AuthService` class in `lib/services/auth_service.dart` provides:

```dart
// Sign in with Google
static Future<User?> signInWithGoogle()

// Sign in anonymously (fallback)
static Future<User?> signInAnonymously()

// Sign out
static Future<void> signOut()

// Get user info
static String getUserDisplayName(User? user)
static String? getUserPhotoURL(User? user)
```

### Authentication Flow

1. **AuthWrapper** (`lib/widgets/auth_wrapper.dart`) listens to auth state
2. **AuthScreen** (`lib/screens/auth_screen.dart`) handles sign-in UI
3. **GenderRevealScreen** shows the main app after authentication

## Troubleshooting

### Common Issues

#### 1. "popup-blocked" Error
- **Solution**: Ask users to allow popups for your domain
- **Alternative**: Use redirect flow instead of popup

#### 2. "operation-not-allowed" Error  
- **Solution**: Ensure Google provider is enabled in Firebase Console
- **Check**: Verify OAuth consent screen is configured

#### 3. "invalid-credential" Error
- **Solution**: Check Firebase configuration files are up to date
- **Verify**: OAuth client IDs match in Firebase Console

#### 4. CORS Issues (Web)
- **Solution**: Add your domain to authorized domains in Firebase
- **Check**: Ensure localhost is included for development

### Debug Information

The app provides detailed error logging:

```dart
debugPrint('Google Sign-In failed: ${e.code} - ${e.message}');
```

Check browser console or Flutter logs for specific error details.

## Testing

### Local Testing
1. Run `flutter run -d chrome` for web testing
2. Use `flutter run` for mobile device testing

### Production Testing
1. Deploy to your hosting provider
2. Test on actual production URLs
3. Verify all authorized domains are configured

## Security Considerations

1. **OAuth Scopes**: Only request necessary permissions (email, profile)
2. **Domain Validation**: Ensure only your domains are authorized
3. **Anonymous Users**: Provide guest access for privacy-conscious users
4. **Session Management**: Implement proper sign-out functionality

## Production Deployment

### Web Deployment
1. Build: `flutter build web`
2. Deploy `build/web` to your hosting provider
3. Configure authorized domains in Firebase
4. Test authentication on production URL

### Mobile Deployment
1. Build release APK/IPA with proper signing
2. Verify Firebase configuration files are included
3. Test on physical devices
4. Submit to app stores with privacy policy

## Support

For additional help:
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [Google Identity Documentation](https://developers.google.com/identity)
