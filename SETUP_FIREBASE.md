# 🔥 Pasos para conectar Firebase Auth (hacer UNA sola vez)

## Paso 1 — Obtener las claves de Firebase Console

1. Ve a https://console.firebase.google.com/project/inventaria-app-ae5ce
2. Clic en el ⚙️ (Settings) → **Project Settings**
3. Baja hasta **"Your apps"**
4. Si no hay una app Web, crea una (clic en `</>`)
5. Copia los valores de `firebaseConfig`:
   - apiKey
   - messagingSenderId
   - appId

## Paso 2 — Opción A: flutterfire configure (recomendado, automático)

```bash
# Instalar CLI de FlutterFire
dart pub global activate flutterfire_cli

# Configurar (genera lib/firebase_options.dart automáticamente)
flutterfire configure --project=inventaria-app-ae5ce
```

Esto reemplaza el `lib/firebase_options.dart` que viene en el ZIP con los valores reales.

## Paso 2 — Opción B: Manual (si no puedes usar CLI)

Abre `lib/firebase_options.dart` y reemplaza los campos `REPLACE_WITH_...`:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSy....',          // ← pega tu apiKey aquí
  authDomain: 'inventaria-app-ae5ce.firebaseapp.com',
  projectId: 'inventaria-app-ae5ce',
  storageBucket: 'inventaria-app-ae5ce.appspot.com',
  messagingSenderId: '123456789',  // ← de Firebase Console
  appId: '1:123...:web:abc...',    // ← de Firebase Console
);
```

Para Android copia los mismos valores pero con el apiKey de Android.

## Paso 3 — Correr la app

```bash
flutter clean
flutter pub get
flutter run
```

## ✅ Cómo verificar que funciona

En los logs de Flutter deberías ver:
```
[API] POST https://...cloudfunctions.net/api/auth/login
[API] 200 https://...cloudfunctions.net/api/auth/login
```

Si ves `400` con `uid is required` → Firebase Auth no está inicializado correctamente (vuelve al Paso 2).

## 🔐 Email/Auth habilitado en Firebase?

Ve a Firebase Console → **Authentication** → **Sign-in method**
Verifica que **Email/Password** esté habilitado (toggle ON).
