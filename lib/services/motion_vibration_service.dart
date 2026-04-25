import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// MotionVibrationService — usa sensor de movimiento (acelerómetro) para
/// reforzar vibración cuando se dispara una alerta/notificación (foreground).
///
/// Nota: en background (app cerrada) el control lo tiene el SO + canal de
/// notificaciones (ya configurado en NotificationService).
class MotionVibrationService {
  MotionVibrationService._();
  static final MotionVibrationService shared = MotionVibrationService._();

  StreamSubscription<AccelerometerEvent>? _sub;
  double _lastMagnitude = 0;
  DateTime _lastSampleAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isActive => _sub != null;

  Future<void> start() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_sub != null) return;

    _sub = accelerometerEventStream().listen((e) {
      final m = (e.x * e.x + e.y * e.y + e.z * e.z);
      _lastMagnitude = m;
      _lastSampleAt = DateTime.now();
    });

    debugPrint('[MotionVibration] started');
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    debugPrint('[MotionVibration] stopped');
  }

  /// Llamar cuando se crea una alerta NUEVA.
  /// - Si hay movimiento reciente, vibra “fuerte”.
  /// - Si no, vibra normal.
  Future<void> vibrateOnAlert() async {
    await start(); // lazy

    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final ageMs = DateTime.now().difference(_lastSampleAt).inMilliseconds;
    final hasRecentMotionSample = ageMs >= 0 && ageMs <= 1500;

    // Aprox: 9.8^2 ≈ 96 cuando está quieto; arriba de ~140 suele indicar movimiento notable.
    final isMoving = hasRecentMotionSample && _lastMagnitude > 140.0;

    try {
      if (isMoving) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.vibrate();
      }
    } catch (_) {
      // ignore
    }
  }
}

