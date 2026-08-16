// File generated for TMK 53 — fill after creating a NEW Firebase project
// (do not reuse tmk-fmb app IDs; package/bundle ids differ).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for TMK 53.
///
/// 1. Create a **new** Firebase project under the same Google account that owns
///    FMB project `tmkfmb-95dd7` (Console → Add project).
/// 2. Add Android app `com.tmkkuwait.tmk_kuwait` and iOS app `com.tmkkuwait.tmkKuwait`.
/// 3. Download `google-services.json` / `GoogleService-Info.plist`, then either:
///    - run `flutterfire configure`, or
///    - paste the values below and set [isConfigured] to true.
class DefaultFirebaseOptions {
  /// Flip to true once android/ios options below are filled from your new project.
  static const bool isConfigured = false;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('TMK 53 push is not configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // REPLACE after creating Firebase project + Android app.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ANDROID_API_KEY',
    appId: 'REPLACE_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_SENDER_ID',
    projectId: 'REPLACE_PROJECT_ID',
    storageBucket: 'REPLACE_PROJECT_ID.appspot.com',
  );

  // REPLACE after creating Firebase project + iOS app.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_IOS_API_KEY',
    appId: 'REPLACE_IOS_APP_ID',
    messagingSenderId: 'REPLACE_SENDER_ID',
    projectId: 'REPLACE_PROJECT_ID',
    storageBucket: 'REPLACE_PROJECT_ID.appspot.com',
    iosBundleId: 'com.tmkkuwait.tmkKuwait',
  );
}
