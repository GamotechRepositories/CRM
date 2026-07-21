// Generated-style Firebase options for the Meeting App.
// Android: from google-services.json (meeting-app-e6603).
// iOS: add GoogleService-Info.plist and re-run `flutterfire configure`.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => ios,
      _ => throw UnsupportedError(
        'DefaultFirebaseOptions are not supported for this platform.',
      ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAseyYTt7OE2rBEVl-0o6P0dj9lZSpsiUI',
    appId: '1:584086897293:android:2cbee7cb0cae51631bd8c4',
    messagingSenderId: '584086897293',
    projectId: 'meeting-app-e6603',
    storageBucket: 'meeting-app-e6603.firebasestorage.app',
  );

  /// Placeholder until iOS app is registered in Firebase Console.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAseyYTt7OE2rBEVl-0o6P0dj9lZSpsiUI',
    appId: '1:584086897293:ios:0000000000000000000000',
    messagingSenderId: '584086897293',
    projectId: 'meeting-app-e6603',
    storageBucket: 'meeting-app-e6603.firebasestorage.app',
    iosBundleId: 'com.meetingapp.meetingApp',
  );
}
