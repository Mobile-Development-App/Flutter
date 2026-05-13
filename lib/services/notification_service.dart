import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─────────────────────────────────────────────
// NotificationService
//
// Singleton que gestiona TODO el ciclo de vida
// de notificaciones locales:
//   • Inicialización (canales Android, permisos iOS/Android 13+)
//   • Envío de notificaciones por categoría
//   • Cancelación individual / masiva
//   • Respeta el flag notificationsEnabled del SettingsProvider
// ─────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService shared = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;

  // ── Channel IDs ───────────────────────────
  static const _chAlerts   = 'inv_alerts';
  static const _chChanges  = 'inv_changes';

  // ── Notification ID ranges ────────────────
  // Rango fijo por tipo para evitar colisiones.
  // Cada producto usa su hashCode % 1000 como sufijo.
  static const _baseAlert    = 1000; // lowStock / outOfStock / expiring
  static const _baseAdded    = 2000; // producto agregado
  static const _baseUpdated  = 3000; // producto actualizado
  static const _baseDeleted  = 4000; // producto eliminado
  static const _baseRestock  = 5000; // reabastecimiento

  // ─────────────────────────────────────────
  // Inicialización (llamar en main.dart)
  // ─────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      _permissionGranted = false;
      debugPrint('[Notifications] Web detected - local notifications disabled');
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // pedimos en el momento oportuno
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Crear canales en Android (requerido desde API 26)
    if (!kIsWeb && Platform.isAndroid) {
      await _createAndroidChannels();
    }

    _initialized = true;

    // BUG FIX: _permissionGranted arrancaba en false en cada cold start.
    // Si el usuario ya concedió permiso en una sesión anterior, las
    // notificaciones fallaban silenciosamente hasta que el settings toggle
    // volvía a llamar a requestPermission(). Lo corregimos comprobando
    // el estado real del permiso justo después de inicializar el plugin.
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        _permissionGranted = await android?.areNotificationsEnabled() ?? false;
      } else if (Platform.isIOS) {
        // En iOS no hay API síncrona; asumimos que si el usuario llegó aquí
        // con el toggle activo ya concedió el permiso. requestPermission()
        // lo confirmará cuando vuelva a abrirse Settings.
        _permissionGranted = false; // se restablece con requestPermission()
      }
    }

    debugPrint('[Notifications] ✅ Initialized (permissionGranted: $_permissionGranted)');
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _chAlerts,
        'Alertas de Inventario',
        description: 'Stock bajo, productos agotados y vencimientos próximos.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _chChanges,
        'Cambios en Productos',
        description: 'Notificaciones de alta, edición y eliminación de productos.',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      ),
    );

    debugPrint('[Notifications] Android channels created');
  }

  // ─────────────────────────────────────────
  // Permisos
  // ─────────────────────────────────────────

  /// Solicita permiso al sistema operativo.
  /// Devuelve true si fue concedido (o si ya lo estaba).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    bool granted = false;

    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } else if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      // Android 13+ (API 33) requiere permiso explícito.
      granted = await android?.requestNotificationsPermission() ?? true;
    }

    _permissionGranted = granted;
    debugPrint('[Notifications] Permission granted: $granted');
    return granted;
  }

  // ─────────────────────────────────────────
  // API pública de envío
  // ─────────────────────────────────────────

  /// Notificación de ALERTA de inventario (stock bajo, agotado, vencimiento).
  Future<void> showInventoryAlert({
    required String title,
    required String body,
    required String productId,
    required AlertKind kind,
  }) async {
    if (!_canSend()) return;
    final id = _id(_baseAlert + kind.index, productId);
    await _show(id, title, body, channel: _chAlerts, highPriority: true);
  }

  /// Notificación de producto AGREGADO.
  Future<void> showProductAdded(String productName) async {
    if (!_canSend()) return;
    final id = _id(_baseAdded, productName);
    await _show(
      id,
      '✅ Producto agregado',
      '$productName fue añadido al inventario.',
      channel: _chChanges,
    );
  }

  /// Notificación de producto ACTUALIZADO.
  /// [changes] describe qué cambió (ej: "Cantidad: 10 → 15").
  Future<void> showProductUpdated(
    String productName, {
    required String changes,
  }) async {
    if (!_canSend()) return;
    final id = _id(_baseUpdated, productName);
    await _show(
      id,
      '✏️ Producto actualizado',
      '$productName — $changes',
      channel: _chChanges,
    );
  }

  /// Notificación de producto ELIMINADO.
  Future<void> showProductDeleted(String productName) async {
    if (!_canSend()) return;
    final id = _id(_baseDeleted, productName);
    await _show(
      id,
      '🗑 Producto eliminado',
      '$productName fue eliminado del inventario.',
      channel: _chChanges,
    );
  }

  /// Notificación de REABASTECIMIENTO.
  Future<void> showRestock(String productName, int qty) async {
    if (!_canSend()) return;
    final id = _id(_baseRestock, productName);
    await _show(
      id,
      '📦 Reabastecimiento registrado',
      '$productName: +$qty unidades añadidas.',
      channel: _chChanges,
    );
  }

  /// Cancela todas las notificaciones pendientes (al desactivar).
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[Notifications] All notifications cancelled');
  }

  // ─────────────────────────────────────────
  // Internos
  // ─────────────────────────────────────────

  bool _canSend() {
    if (!_initialized) {
      debugPrint('[Notifications] ⚠️  Not initialized — call init() first');
      return false;
    }
    if (!_permissionGranted) {
      debugPrint('[Notifications] ⚠️  Permission not granted');
      return false;
    }
    return true;
  }

  /// Genera un ID entero estable a partir de una base y una clave string.
  int _id(int base, String key) => base + key.hashCode.abs() % 1000;

  Future<void> _show(
    int id,
    String title,
    String body, {
    required String channel,
    bool highPriority = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channel,
      channel == _chAlerts ? 'Alertas de Inventario' : 'Cambios en Productos',
      importance: highPriority ? Importance.high : Importance.defaultImportance,
      priority:   highPriority ? Priority.high    : Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(body),
      vibrationPattern: highPriority
          ? Int64List.fromList(<int>[0, 300, 150, 300])
          : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );

    debugPrint('[Notifications] 📨 Sent ($id): $title — $body');
  }
}

// ─────────────────────────────────────────────
// AlertKind — determina el rango de ID de alerta
// ─────────────────────────────────────────────
enum AlertKind {
  lowStock,     // base 1000
  outOfStock,   // base 1001
  expiringSoon, // base 1002
}
