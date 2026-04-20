/// **ID de cliente OAuth 2.0 (tipo Web)** — termina en `.apps.googleusercontent.com`.
///
/// En **web** lo usa [Google Identity Services](https://developers.google.com/identity/gsi/web)
/// (`google.accounts.id`). En **móvil** el mismo ID como `serverClientId` ayuda a obtener
/// el `idToken` para Firebase.
///
/// Consíguelo en [Firebase Console](https://console.firebase.google.com) → tu proyecto →
/// Configuración del proyecto → Tus apps → **ID de cliente web**,
/// o en Google Cloud Console → Credenciales → Cliente OAuth web.
///
/// Ejemplo:
/// `flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=tu_id.apps.googleusercontent.com`
const String kGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);
