import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UsageTrackingService — Sprint 3
//
// ESTRATEGIA DE ALMACENAMIENTO LOCAL: Hive (NoSQL embebido)
// ──────────────────────────────────────────────────────────
// Sprint 2 usó SharedPreferences (clave-valor simple, sin queries).
// Sprint 3 introduce Hive como segunda estrategia distinta:
//   • Boxes tipados → esquema estructurado por entidad
//   • Lectura O(1) por clave, sin deserializar toda la colección
//   • Funciona en web (IndexedDB), móvil y desktop (sin cambiar código)
//   • API sincrónica para lecturas, asincrónica para escrituras
//
// ESTRATEGIA DE CONCURRENCIA: compute() — Dart Isolates
// ───────────────────────────────────────────────────────
// Las tres agregaciones pesadas (BQ5, BQ7, BQ8) se ejecutan en un
// Isolate separado vía compute(), liberando el hilo UI de trabajo pesado.
//
// BQs implementados:
//   BQ1 (Tipo 1) — Latencia promedio ingesta→storage
//   BQ5 (Tipo 2) — Pantallas más usadas en hora pico
//   BQ7 (Tipo 3) — Precisión escaneo vs entrada manual
//   BQ8 (Tipo 3) — Frecuencia de funciones analíticas por semana
// ─────────────────────────────────────────────────────────────────────────────

// ── DTOs ─────────────────────────────────────────────────────────────────────

class ScreenSession {
  final String screenName;
  final DateTime startedAt;
  final int durationSeconds;
  final int hourOfDay;

  const ScreenSession({
    required this.screenName,
    required this.startedAt,
    required this.durationSeconds,
    required this.hourOfDay,
  });
}

class PeakHourInsight {
  final int hour;
  final String screenName;
  final double totalSeconds;
  final int visits;

  const PeakHourInsight({
    required this.hour,
    required this.screenName,
    required this.totalSeconds,
    required this.visits,
  });
}

class ScanAccuracyInsight {
  final String method;
  final int total;
  final int accurate;
  double get accuracyRate => total == 0 ? 0 : accurate / total;

  ScanAccuracyInsight({
    required this.method,
    required this.total,
    required this.accurate,
  });
}

class FeatureUsageInsight {
  final String featureName;
  final int usageCount;
  final int weekCount;

  const FeatureUsageInsight({
    required this.featureName,
    required this.usageCount,
    required this.weekCount,
  });
}

// ── Funciones top-level para compute() ───────────────────────────────────────
// DEBEN ser top-level (no métodos de clase) para que Dart pueda
// transferirlas al Isolate sin serializar el heap completo.

List<PeakHourInsight> _aggregatePeakHours(List<Map<String, dynamic>> rows) {
  final Map<String, Map<String, dynamic>> buckets = {};
  for (final row in rows) {
    final hour   = row['hour_of_day'] as int;
    final screen = row['screen_name'] as String;
    final dur    = row['duration_seconds'] as int;
    final key    = '$hour|$screen';
    buckets.putIfAbsent(key, () => {
          'hour': hour,
          'screen': screen,
          'totalSeconds': 0.0,
          'visits': 0,
        });
    buckets[key]!['totalSeconds'] =
        (buckets[key]!['totalSeconds'] as double) + dur;
    buckets[key]!['visits'] = (buckets[key]!['visits'] as int) + 1;
  }
  return buckets.values
      .map((b) => PeakHourInsight(
            hour: b['hour'] as int,
            screenName: b['screen'] as String,
            totalSeconds: b['totalSeconds'] as double,
            visits: b['visits'] as int,
          ))
      .toList()
    ..sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
}

List<ScanAccuracyInsight> _aggregateScanAccuracy(
    List<Map<String, dynamic>> rows) {
  final Map<String, Map<String, dynamic>> buckets = {
    'barcode': {'total': 0, 'accurate': 0},
    'manual':  {'total': 0, 'accurate': 0},
  };
  for (final row in rows) {
    final method   = row['entry_method'] as String;
    final accurate = row['is_accurate'] as bool;
    if (!buckets.containsKey(method)) continue;
    buckets[method]!['total'] = (buckets[method]!['total'] as int) + 1;
    if (accurate) {
      buckets[method]!['accurate'] =
          (buckets[method]!['accurate'] as int) + 1;
    }
  }
  return buckets.entries
      .map((e) => ScanAccuracyInsight(
            method:   e.key,
            total:    e.value['total'] as int,
            accurate: e.value['accurate'] as int,
          ))
      .toList();
}

List<FeatureUsageInsight> _aggregateFeatureUsage(
    List<Map<String, dynamic>> rows) {
  final Map<String, Map<String, dynamic>> buckets = {};
  for (final row in rows) {
    final feature = row['feature_name'] as String;
    final week    = row['week_number'] as int;
    buckets.putIfAbsent(
        feature, () => {'count': 0, 'weeks': <int>{}});
    buckets[feature]!['count'] = (buckets[feature]!['count'] as int) + 1;
    (buckets[feature]!['weeks'] as Set<int>).add(week);
  }
  return buckets.entries
      .map((e) => FeatureUsageInsight(
            featureName: e.key,
            usageCount:  e.value['count'] as int,
            weekCount:   (e.value['weeks'] as Set<int>).length,
          ))
      .toList()
    ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
}

// ── Servicio principal ────────────────────────────────────────────────────────

class UsageTrackingService {
  UsageTrackingService._();
  static final UsageTrackingService shared = UsageTrackingService._();

  // Nombres de los Hive Boxes (equivalen a "tablas")
  static const _boxSessions = 'screen_sessions'; // BQ5
  static const _boxFeatures = 'feature_events';  // BQ8
  static const _boxEntries  = 'entry_methods';   // BQ7
  static const _boxLatency  = 'latency_records'; // BQ1

  bool      _initialized      = false;
  DateTime? _currentScreenStart;
  String?   _currentScreen;

  // ── Inicialización ────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    // Abre los 4 boxes en paralelo para mayor velocidad
    await Future.wait([
      Hive.openBox<Map>(_boxSessions),
      Hive.openBox<Map>(_boxFeatures),
      Hive.openBox<Map>(_boxEntries),
      Hive.openBox<Map>(_boxLatency),
    ]);
    _initialized = true;
    debugPrint('[UsageTrackingService] Hive inicializado — 4 boxes abiertos');
  }

  Box<Map> get _sessions => Hive.box<Map>(_boxSessions);
  Box<Map> get _features => Hive.box<Map>(_boxFeatures);
  Box<Map> get _entries  => Hive.box<Map>(_boxEntries);
  Box<Map> get _latency  => Hive.box<Map>(_boxLatency);

  // ── BQ5: Tracking de sesiones de pantalla ────────────────────────────────

  void trackScreenEnter(String screenName) {
    _currentScreen      = screenName;
    _currentScreenStart = DateTime.now();
  }

  Future<void> trackScreenExit(String screenName) async {
    if (_currentScreen != screenName || _currentScreenStart == null) return;
    final duration =
        DateTime.now().difference(_currentScreenStart!).inSeconds;
    if (duration < 1) return;

    await _sessions.add({
      'screen_name':      screenName,
      'started_at':       _currentScreenStart!.millisecondsSinceEpoch,
      'duration_seconds': duration,
      'hour_of_day':      _currentScreenStart!.hour,
    });
    _currentScreen      = null;
    _currentScreenStart = null;
  }

  // ── BQ8: Tracking de uso de funciones analíticas ─────────────────────────

  Future<void> trackFeatureUsed(String featureName) async {
    final now  = DateTime.now();
    final week = _isoWeek(now);
    await _features.add({
      'feature_name': featureName,
      'used_at':      now.millisecondsSinceEpoch,
      'week_number':  week,
    });
  }

  // ── BQ7: Tracking de método de ingreso de producto ────────────────────────

  Future<void> trackProductEntry({
    required String productId,
    required bool   viaBarcode,
    bool isAccurate = true,
  }) async {
    await _entries.add({
      'product_id':   productId,
      'entry_method': viaBarcode ? 'barcode' : 'manual',
      'is_accurate':  isAccurate,
      'recorded_at':  DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> markEntryInaccurate(String productId) async {
    for (final key in _entries.keys.toList().reversed) {
      final entry = _entries.get(key);
      if (entry != null && entry['product_id'] == productId) {
        await _entries.put(key, {...Map<String, dynamic>.from(entry), 'is_accurate': false});
        break;
      }
    }
  }

  // ── BQ1: Registro de latencias ────────────────────────────────────────────

  Future<void> persistLatencyRecord({
    required String stage,
    required int    latencyMs,
    required bool   success,
  }) async {
    await _latency.add({
      'stage':       stage,
      'latency_ms':  latencyMs,
      'success':     success,
      'recorded_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<double> getAverageLatencyMs({String? stage}) async {
    final records = _latency.values
        .where((m) => stage == null || m['stage'] == stage)
        .map((m) => (m['latency_ms'] as int).toDouble())
        .toList();
    if (records.isEmpty) return 0.0;
    return records.reduce((a, b) => a + b) / records.length;
  }

  // ── Agregaciones con compute() ────────────────────────────────────────────

  /// BQ5 — pantallas en hora pico (últimos N días)
  /// MULTI-THREADING: corre en Isolate separado vía compute()
  Future<List<PeakHourInsight>> getPeakHourInsights({
    int limitDays = 30,
  }) async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: limitDays))
        .millisecondsSinceEpoch;
    final rows = _sessions.values
        .where((m) => (m['started_at'] as int) >= cutoff)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    // ── ISOLATE ───────────────────────────────────────────────────────────
    return compute(_aggregatePeakHours, rows);
  }

  /// BQ7 — precisión escaneo vs manual (últimos N días)
  /// MULTI-THREADING: corre en Isolate separado vía compute()
  Future<List<ScanAccuracyInsight>> getScanAccuracyInsights({
    int limitDays = 30,
  }) async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: limitDays))
        .millisecondsSinceEpoch;
    final rows = _entries.values
        .where((m) => (m['recorded_at'] as int) >= cutoff)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    // ── ISOLATE ───────────────────────────────────────────────────────────
    return compute(_aggregateScanAccuracy, rows);
  }

  /// BQ8 — funciones analíticas más usadas por semana
  /// MULTI-THREADING: corre en Isolate separado vía compute()
  Future<List<FeatureUsageInsight>> getFeatureUsageInsights({
    int limitWeeks = 4,
  }) async {
    final cutoffWeek = _isoWeek(DateTime.now()) - limitWeeks;
    final rows = _features.values
        .where((m) => (m['week_number'] as int) >= cutoffWeek)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    // ── ISOLATE ───────────────────────────────────────────────────────────
    return compute(_aggregateFeatureUsage, rows);
  }

  // ── Utilidad ──────────────────────────────────────────────────────────────

  static int _isoWeek(DateTime d) {
    final doy = d.difference(DateTime(d.year, 1, 1)).inDays;
    return ((doy - d.weekday + 10) / 7).floor();
  }

  Future<void> closeAll() async {
    await Hive.close();
    _initialized = false;
  }
}
