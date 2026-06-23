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
    apiKey: 'AIzaSyCgEf0B5RGNPhpMAN9NWktzy-buxrK0HVw',
    appId: '1:39592049411:web:2390f033c3af3f9db40736',
    messagingSenderId: '39592049411',
    projectId: 'dgnl-lachithanh-dh52201455',
    authDomain: 'dgnl-lachithanh-dh52201455.firebaseapp.com',
    storageBucket: 'dgnl-lachithanh-dh52201455.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA5B2aHFdfIganFyyUk0CjBCp2X_U6_wq8',
    appId: '1:39592049411:android:9a13d64c3962f854b40736',
    messagingSenderId: '39592049411',
    projectId: 'dgnl-lachithanh-dh52201455',
    storageBucket: 'dgnl-lachithanh-dh52201455.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDPN4-tlFYm5P1A7Hbf7FylwRIyZxc54Kc',
    appId: '1:39592049411:ios:df79dee633a5ff5ab40736',
    messagingSenderId: '39592049411',
    projectId: 'dgnl-lachithanh-dh52201455',
    storageBucket: 'dgnl-lachithanh-dh52201455.firebasestorage.app',
    iosBundleId: 'vn.edu.stu.dgnlLachithanhDh52201455',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDPN4-tlFYm5P1A7Hbf7FylwRIyZxc54Kc',
    appId: '1:39592049411:ios:df79dee633a5ff5ab40736',
    messagingSenderId: '39592049411',
    projectId: 'dgnl-lachithanh-dh52201455',
    storageBucket: 'dgnl-lachithanh-dh52201455.firebasestorage.app',
    iosBundleId: 'vn.edu.stu.dgnlLachithanhDh52201455',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCgEf0B5RGNPhpMAN9NWktzy-buxrK0HVw',
    appId: '1:39592049411:web:2e6e82ac5b60966cb40736',
    messagingSenderId: '39592049411',
    projectId: 'dgnl-lachithanh-dh52201455',
    authDomain: 'dgnl-lachithanh-dh52201455.firebaseapp.com',
    storageBucket: 'dgnl-lachithanh-dh52201455.firebasestorage.app',
  );
}
