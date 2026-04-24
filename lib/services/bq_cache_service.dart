import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pipeline_logger.dart';
import '../core/utils/lru_cache.dart'; // ajusta el path según tu estructura

// ─────────────────────────────────────────────────────────────────────────────
// BQCacheService — Sprint 4 [LRU actualizado]
//
// Caché en dos capas para respuestas de Business Questions (llamadas costosas
// al API de Claude).
//
// L1 — LRUCache<String, _BQEntry> en memoria, capacidad 20.
//      Evita leer SharedPreferences en cada rebuild del provider.
//      Se pierde al reiniciar la app; L2 lo restaura en el próximo acceso.
//
// L2 — SharedPreferences (persistente entre sesiones).
//      TTL predeterminado: 12 horas (configurable por llamada).
//
// FLUJO read(key):
//   1. Check L1  → HIT si no expirado.
//   2. Check L2  → HIT, deserializa y promueve a L1.
//   3. MISS      → null (el provider llama a la API y luego hace save()).
//
// FLUJO save(key, payload):
//   Escribe en L1 (inmediato) y L2 (async).
// ─────────────────────────────────────────────────────────────────────────────

class _BQEntry {
  final Map<String, dynamic> payload;
  final int expiresAtMs; // epoch millis

  const _BQEntry({required this.payload, required this.expiresAtMs});

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > expiresAtMs;
}

class BQCacheService {
  BQCacheService._();
  static final BQCacheService shared = BQCacheService._();

  static const _prefix = 'inventaria_bq_cache_';

  /// L1: LRU in-memory — capacidad 20 (una por cada combinación BQ×tienda).
  final LRUCache<String, _BQEntry> _l1 = LRUCache(20);

  // ── Escritura ──────────────────────────────────────────────────────────────

  Future<void> save(
    String key,
    Map<String, dynamic> payload, {
    Duration ttl = const Duration(hours: 12),
  }) async {
    final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;

    // L1: inmediato.
    _l1.put(key, _BQEntry(payload: payload, expiresAtMs: expiresAt));

    // L2: persistente.
    final prefs = await SharedPreferences.getInstance();
    final data = {'expiresAt': expiresAt, 'payload': payload};
    final sw = Stopwatch()..start();
    await prefs.setString('$_prefix$key', jsonEncode(data));
    sw.stop();
    PipelineLogger.shared.log(
      stage: PipelineStage.storage,
      operation: 'SharedPreferences.save($_prefix$key)',
      recordCount: 1,
      latency: sw.elapsed,
    );
  }

  // ── Lectura ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> read(String key) async {
    // ── L1: LRU in-memory ────────────────────────────────────────────────────
    final l1 = _l1.get(key); // actualiza orden LRU
    if (l1 != null) {
      if (!l1.isExpired) return l1.payload;
      // Expirado: evictar de L1; L2 también estará expirado.
      _l1.remove(key);
      return null;
    }

    // ── L2: SharedPreferences ────────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final sw = Stopwatch()..start();
    final raw = prefs.getString('$_prefix$key');
    sw.stop();

    if (raw == null || raw.isEmpty) return null;

    PipelineLogger.shared.log(
      stage: PipelineStage.storage,
      operation: 'SharedPreferences.read($_prefix$key)',
      recordCount: 1,
      latency: sw.elapsed,
    );

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = map['expiresAt'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) return null;

      final payload = (map['payload'] as Map).cast<String, dynamic>();

      // Promover a L1 para próximas lecturas sin I/O.
      _l1.put(key, _BQEntry(payload: payload, expiresAtMs: expiresAt));

      return payload;
    } catch (_) {
      return null;
    }
  }

  // ── Limpieza ───────────────────────────────────────────────────────────────

  /// Invalida una clave específica en L1 y L2.
  Future<void> invalidate(String key) async {
    _l1.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  /// Vacía todo el caché BQ (útil al cambiar de tienda o cerrar sesión).
  Future<void> clearAll() async {
    _l1.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Número de entradas actualmente en L1.
  int get l1Size => _l1.length;
}
