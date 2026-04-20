import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:google_identity_services_web/id.dart';
import 'package:google_identity_services_web/loader.dart' as gis;

import '../core/constants/google_sign_in_config.dart';

Future<String?> requestGoogleIdToken() async {
  debugPrint('GOOGLE_WEB_CLIENT_ID = $kGoogleWebClientId');

  if (kGoogleWebClientId.isEmpty) return null;

  await gis.loadWebSdk();
  final completer = Completer<String?>();

  final host = (html.window.location.hostname ?? '').toLowerCase();
  final isLocalhost = host == 'localhost' || host == '127.0.0.1';

  id.setLogLevel('debug');
  id.initialize(
    IdConfiguration(
      client_id: kGoogleWebClientId,
      use_fedcm_for_prompt: !isLocalhost,
      cancel_on_tap_outside: false,
      callback: (CredentialResponse r) {
        final err = r.error;
        if (err != null && err.isNotEmpty) {
          debugPrint('GIS error: $err');
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final jwt = r.credential;
        debugPrint('GIS credential received: ${jwt != null && jwt.isNotEmpty}');

        if (jwt != null && jwt.isNotEmpty && !completer.isCompleted) {
          completer.complete(jwt);
        }
      },
    ),
  );

  id.prompt();

  return completer.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      debugPrint('GIS timeout: no credential');
      return null;
    },
  );
}