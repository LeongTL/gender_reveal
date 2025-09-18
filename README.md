# 🎉 Gender Reveal Party App

A beautiful Flutter application for hosting real-time gender reveal parties with animated balloons and live voting functionality powered by Firebase.

## 📱 Features

- **Google Authentication**: Secure sign-in with Google accounts or anonymous guest access
- **Real-time Voting**: Live vote counting for boy vs girl predictions using Firebase Firestore
- **Animated Balloons**: Beautiful floating balloon animations with realistic physics
- **Cross-Platform**: Runs on Web, iOS, Android, macOS, Windows, and Linux
- **Responsive Design**: Adapts to different screen sizes and orientations
- **Material Design 3**: Modern UI with custom themes and animations
- **User Management**: Profile display and secure sign-out functionality

## 🏗️ Project Structure

```
lib/
├── main.dart                          # App entry point with Firebase initialization
├── models/
│   └── balloon.dart                   # Balloon data model with animation properties
├── widgets/
│   ├── auth_wrapper.dart              # Authentication state management
│   ├── balloon_background.dart        # Animated balloon background widget
│   └── balloon_painter.dart           # Custom painter for balloon rendering
├── screens/
│   ├── auth_screen.dart               # Google sign-in and guest access
│   ├── gender_reveal_screen.dart      # Main screen with voting results
│   └── demo_gender_reveal_screen.dart # Offline demo mode
└── services/
    ├── auth_service.dart              # Firebase Authentication operations
    ├── firestore_service.dart         # Firebase Firestore operations
    └── mock_firestore_service.dart    # Mock service for demo mode
```

## 🔧 Dependencies

### Core Dependencies
- `flutter`: Flutter SDK
- `firebase_core`: Firebase initialization
- `firebase_auth`: User authentication and Google Sign-In
- `cloud_firestore`: Real-time database for voting
- `cupertino_icons`: iOS-style icons

### Dev Dependencies
- `flutter_test`: Testing framework
- `flutter_lints`: Dart linting rules

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Firebase project with Firestore enabled
- Web browser for testing (Chrome recommended)

### Installation

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Set up Firebase**:
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Firestore Database
   - Enable Authentication with Google provider
   - Add your web app and download configuration
   - Follow Flutter Firebase setup instructions
   - See `GOOGLE_AUTH_SETUP.md` for detailed authentication configuration

3. **Run the application**:
   ```bash
   # For web
   flutter run -d chrome
   
   # For mobile (with device/emulator connected)
   flutter run
   ```

For detailed documentation, see the comprehensive README in the project files.
