// File generated for habits-ea326 Firebase project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for android.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDNJ84-dt7WKgySB3Y2dyCWEL7yTEn1ut8',
    appId: '1:889103210231:web:17af11f7ed5d6b9605a5f2',
    messagingSenderId: '889103210231',
    projectId: 'habits-ea326',
    authDomain: 'habits-ea326.firebaseapp.com',
    storageBucket: 'habits-ea326.firebasestorage.app',
  );
}
