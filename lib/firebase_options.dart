import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return web;
    }
  }

  // ── Web ──────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAPeZ4wLK9DYE-hs8QPPA4gf59Ff-ws_0s',
    authDomain: 'inventaria-app-ae5ce.firebaseapp.com',
    projectId: 'inventaria-app-ae5ce',
    storageBucket: 'inventaria-app-ae5ce.firebasestorage.app',
    messagingSenderId: '340434979291',
    appId: '1:340434979291:web:a0c624446a744a106ebffe',
  );

  // ── Android ──────────────────────────────
  // Por ahora usa las mismas claves Web. Para producción en Android,
  // registra la app Android en Firebase Console y reemplaza estos valores
  // con los del google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAPeZ4wLK9DYE-hs8QPPA4gf59Ff-ws_0s',
    authDomain: 'inventaria-app-ae5ce.firebaseapp.com',
    projectId: 'inventaria-app-ae5ce',
    storageBucket: 'inventaria-app-ae5ce.firebasestorage.app',
    messagingSenderId: '340434979291',
    appId: '1:340434979291:web:a0c624446a744a106ebffe',
  );

  // ── iOS ───────────────────────────────────
  // Por ahora usa las mismas claves Web. Para producción en iOS,
  // registra la app iOS en Firebase Console y reemplaza con
  // los valores del GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAPeZ4wLK9DYE-hs8QPPA4gf59Ff-ws_0s',
    authDomain: 'inventaria-app-ae5ce.firebaseapp.com',
    projectId: 'inventaria-app-ae5ce',
    storageBucket: 'inventaria-app-ae5ce.firebasestorage.app',
    messagingSenderId: '340434979291',
    appId: '1:340434979291:web:a0c624446a744a106ebffe',
    iosBundleId: 'com.inventaria.app',
  );

  // ── macOS ─────────────────────────────────
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAPeZ4wLK9DYE-hs8QPPA4gf59Ff-ws_0s',
    authDomain: 'inventaria-app-ae5ce.firebaseapp.com',
    projectId: 'inventaria-app-ae5ce',
    storageBucket: 'inventaria-app-ae5ce.firebasestorage.app',
    messagingSenderId: '340434979291',
    appId: '1:340434979291:web:a0c624446a744a106ebffe',
    iosBundleId: 'com.inventaria.app',
  );
}