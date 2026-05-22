import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MotionVibrationService {
  MotionVibrationService._();
  static final MotionVibrationService shared = MotionVibrationService._();

  StreamSubscription<AccelerometerEvent>? _sub;
  double _lastMagnitudeSq = 0;
  DateTime _lastSampleAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isActive => _sub != null;

  Future<void> start() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_sub != null) return;

    _sub = accelerometerEventStream().listen((e) {
      final m = (e.x * e.x + e.y * e.y + e.z * e.z);
      _lastMagnitudeSq = m;
      _lastSampleAt = DateTime.now();
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> vibrateOnAlert() async {
    await start();
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final ageMs = DateTime.now().difference(_lastSampleAt).inMilliseconds;
    final hasRecentMotionSample = ageMs >= 0 && ageMs <= 1500;
    final isMoving = hasRecentMotionSample && _lastMagnitudeSq > 140.0;

    try {
      if (isMoving) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.vibrate();
      }
    } catch (_) {}
  }
}
