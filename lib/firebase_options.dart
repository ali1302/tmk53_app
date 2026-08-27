// File generated for Firebase project tmk-53-a6840.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static bool get isConfigured => true;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  // Web app not created in tmk-53-a6840 yet — uses Android key placeholders for compile.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDT2OumTEOt43tsbn6w-tD2kW401pyS0Z8',
    appId: '1:502998534784:android:8d05f82f868188db4f7465',
    messagingSenderId: '502998534784',
    projectId: 'tmk-53-a6840',
    authDomain: 'tmk-53-a6840.firebaseapp.com',
    storageBucket: 'tmk-53-a6840.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDT2OumTEOt43tsbn6w-tD2kW401pyS0Z8',
    appId: '1:502998534784:android:8d05f82f868188db4f7465',
    messagingSenderId: '502998534784',
    projectId: 'tmk-53-a6840',
    storageBucket: 'tmk-53-a6840.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBkcdx9WzWFCH3p-daVtjquubw7NMWWko0',
    appId: '1:502998534784:ios:b8077905321c7fca4f7465',
    messagingSenderId: '502998534784',
    projectId: 'tmk-53-a6840',
    storageBucket: 'tmk-53-a6840.firebasestorage.app',
    iosBundleId: 'com.tmkkuwait.tmk53',
  );
}
