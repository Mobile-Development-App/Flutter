import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/google_sign_in_config.dart';

/// Android / iOS / escritorio: OAuth con el SDK de inicio de sesión de Google
/// (equivalente nativo a la credencial que GIS entrega en web).
Future<String?> requestGoogleIdToken() async {
  final google = kGoogleWebClientId.isNotEmpty
      ? GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: kGoogleWebClientId,
        )
      : GoogleSignIn(scopes: const ['email', 'profile']);
  final account = await google.signIn();
  if (account == null) return null;
  final auth = await account.authentication;
  return auth.idToken;
}
