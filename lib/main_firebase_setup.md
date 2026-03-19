# Configuración Firebase Auth en Flutter

## 1. Agregar dependencias en pubspec.yaml

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  # (las demás que ya tienes: flutter_riverpod, http, shared_preferences, etc.)
```

## 2. Inicializar Firebase en main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // generado por flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: InventariaApp()));
}
```

## 3. Generar firebase_options.dart (una sola vez)

```bash
# Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurar con tu proyecto
flutterfire configure --project=inventaria-app-ae5ce
```

Esto genera automáticamente `lib/firebase_options.dart` con todas las claves.

## 4. Si ya tienes google-services.json / GoogleService-Info.plist

Colócalos en:
- Android: `android/app/google-services.json`
- iOS:     `ios/Runner/GoogleService-Info.plist`
- Web:     usar `flutterfire configure` de todas formas

## 5. Después de todo:

```bash
flutter clean
flutter pub get
flutter run
```
