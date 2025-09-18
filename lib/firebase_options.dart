import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDF2ggee7uPfDt-swIFxteHHGEqG-cc0nE',
    appId: '1:63687376257:web:bff68791ddcde647d4fc80',
    messagingSenderId: '63687376257',
    projectId: 'gender-reveal-f0a3e',
    authDomain: 'gender-reveal-f0a3e.firebaseapp.com',
    storageBucket: 'gender-reveal-f0a3e.firebasestorage.app',
    measurementId: 'G-221C5L35QC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgYzU7P6Bww1Xnid-NjAujLUinZweA-Ds',
    appId: '1:63687376257:android:4e1142463c086f50d4fc80',
    messagingSenderId: '63687376257',
    projectId: 'gender-reveal-f0a3e',
    storageBucket: 'gender-reveal-f0a3e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDYsiuVCrbJPpmHuvm0GhFGRgNNgqqpG-A',
    appId: '1:63687376257:ios:df2a05939eb57c28d4fc80',
    messagingSenderId: '63687376257',
    projectId: 'gender-reveal-f0a3e',
    storageBucket: 'gender-reveal-f0a3e.firebasestorage.app',
    iosBundleId: 'com.example.genderReveal',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'your-macos-api-key',
    appId: '1:your-app-id:ios:your-macos-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.appspot.com',
    iosBundleId: 'com.example.genderReveal',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'your-windows-api-key',
    appId: '1:your-app-id:web:your-windows-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
    authDomain: 'your-project-id.firebaseapp.com',
    storageBucket: 'your-project-id.appspot.com',
    measurementId: 'your-measurement-id',
  );
}