import 'google_id_token_io.dart'
    if (dart.library.html) 'google_id_token_web.dart' as impl;

/// Token JWT de Google (GIS en web; OAuth nativo en móvil) para Firebase.
Future<String?> requestGoogleIdToken() => impl.requestGoogleIdToken();
