import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'pipeline_logger.dart';
import '../core/utils/lru_cache.dart'; // ajusta el path según tu estructura

// ─────────────────────────────────────────────────────────────────────────────
// CacheService — Sprint 4 (Caching Strategy)  [LRU actualizado]
//
// ARQUITECTURA EN DOS CAPAS:
//   L1 — LRU in-memory  (LRUCache<String, _CacheEntry>, capacity=50)
//        Acceso O(1), sin I/O. Perdido al reiniciar la app.
//   L2 — Hive box "api_cache"
//        Persistente entre sesiones. Más lento por I/O de disco.
//
// FLUJO DE LECTURA (get):
//   1. Buscar en L1. Si HIT y no expirado → retornar.
//   2. Buscar en L2. Si HIT y no expirado → promover a L1 y retornar.
//   3. MISS → retornar null (o stale si allowStale=true).
//
// FLUJO DE ESCRITURA (put):
//   Escribir simultáneamente en L1 y L2.
//
// EVICCIÓN AUTOMÁTICA:
//   L1: LRU evicta al llegar a capacity.
//   L2: Hive evicta entradas expiradas al hacer get().
// ─────────────────────────────────────────────────────────────────────────────

/// Claves de caché predefinidas para los endpoints principales.
class CacheKeys {
  static const products  = 'products';
  static const alerts    = 'alerts';
  static const dashboard = 'dashboard';
}

/// TTLs por defecto (en milisegundos) alineados con la frecuencia de cambio
/// de cada recurso.
class CacheTtl {
  static const products  = Duration(minutes: 5);
  static const alerts    = Duration(minutes: 10);
  static const dashboard = Duration(minutes: 10);
}

/// Entrada de caché interna.
class _CacheEntry {
  final dynamic data;      // payload ya deserializado (List / Map / etc.)
  final DateTime cachedAt;
  final Duration ttl;

  const _CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.ttl,
  });

  bool get isExpired =>
      DateTime.now().isAfter(cachedAt.add(ttl));

  Map<String, dynamic> toJson() => {
        'data': jsonEncode(data),
        'cachedAt': cachedAt.toIso8601String(),
        'ttlMs': ttl.inMilliseconds,
      };

  factory _CacheEntry.fromJson(Map<dynamic, dynamic> map) {
    return _CacheEntry(
      data: jsonDecode(map['data'] as String),
      cachedAt: DateTime.parse(map['cachedAt'] as String),
      ttl: Duration(milliseconds: (map['ttlMs'] as int?) ?? 300000),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class CacheService {
  CacheService._();
  static final CacheService shared = CacheService._();

  static const _boxName = 'api_cache';

  /// L1: LRU in-memory con capacidad de 50 entradas.
  /// Suficiente para cubrir productos, alertas y dashboard sin consumir
  /// memoria excesiva en dispositivos de gama baja.
  final LRUCache<String, _CacheEntry> _l1 = LRUCache(50);

  late Box<Map> _box;
  bool _initialized = false;

  /// Inicializa el box de Hive.  Llamar en main() tras Hive.initFlutter().
  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<Map>(_boxName);
    _initialized = true;
    debugPrint('[Cache] init — ${_box.length} entradas en caché (L2/Hive)');
  }

  // ── Escritura ──────────────────────────────────────────────────────────────

  /// Almacena [data] bajo [key] en L1 (LRU) y L2 (Hive) simultáneamente.
  Future<void> put(String key, dynamic data, {Duration? ttl}) async {
    _assertInit();
    final effectiveTtl = ttl ?? _defaultTtl(key);
    final entry = _CacheEntry(
      data: data,
      cachedAt: DateTime.now(),
      ttl: effectiveTtl,
    );

    // L1: inmediato, sin I/O.
    _l1.put(key, entry);

    // L2: persistente.
    final sw = Stopwatch()..start();
    await _box.put(key, entry.toJson());
    sw.stop();
    PipelineLogger.shared.log(
      stage: PipelineStage.storage,
      operation: 'Hive.put($key)',
      recordCount: 1,
      latency: sw.elapsed,
    );
    debugPrint('[Cache] put  key=$key  ttl=${effectiveTtl.inMinutes}min  '
        'L1.size=${_l1.length}');
  }

  // ── Lectura ────────────────────────────────────────────────────────────────

  /// Retorna los datos cacheados para [key], o `null` si:
  ///   - no existe la entrada en ninguna capa, o
  ///   - está expirada (y [allowStale] == false).
  ///
  /// Con [allowStale] = true retorna datos expirados como fallback de red.
  dynamic get(String key, {bool allowStale = false}) {
    _assertInit();

    // ── L1: LRU in-memory ──────────────────────────────────────────────────
    final l1Entry = _l1.get(key); // get() ya actualiza el orden LRU
    if (l1Entry != null) {
      if (!l1Entry.isExpired) {
        debugPrint('[Cache] L1-HIT  key=$key');
        return l1Entry.data;
      }
      if (allowStale) {
        debugPrint('[Cache] L1-STALE-HIT  key=$key  (allowStale=true)');
        return l1Entry.data;
      }
      // Expirado en L1: evictar de ambas capas asincrónicamente.
      _l1.remove(key);
      _box.delete(key); // fire-and-forget
      debugPrint('[Cache] L1-EXPIRED+EVICTED  key=$key');
      return null;
    }

    // ── L2: Hive (persistente) ─────────────────────────────────────────────
    final sw = Stopwatch()..start();
    final raw = _box.get(key);
    sw.stop();

    if (raw == null) {
      debugPrint('[Cache] MISS  key=$key');
      return null;
    }

    PipelineLogger.shared.log(
      stage: PipelineStage.storage,
      operation: 'Hive.get($key)',
      recordCount: 1,
      latency: sw.elapsed,
    );

    final entry = _CacheEntry.fromJson(raw);

    if (entry.isExpired) {
      if (!allowStale) {
        _box.delete(key); // fire-and-forget
        debugPrint('[Cache] L2-EXPIRED+EVICTED  key=$key');
        return null;
      }
      debugPrint('[Cache] L2-STALE-HIT  key=$key  (allowStale=true)');
      return entry.data;
    }

    // Promover a L1 para próximas lecturas sin I/O.
    _l1.put(key, entry);
    final age = DateTime.now().difference(entry.cachedAt);
    debugPrint('[Cache] L2-HIT→L1-PROMOTED  key=$key  age=${age.inSeconds}s');
    return entry.data;
  }

  /// Elimina la entrada de [key] en L1 y L2.
  Future<void> invalidate(String key) async {
    _assertInit();
    _l1.remove(key);
    final sw = Stopwatch()..start();
    await _box.delete(key);
    sw.stop();
    PipelineLogger.shared.log(
      stage: PipelineStage.storage,
      operation: 'Hive.delete($key)',
      recordCount: 1,
      latency: sw.elapsed,
    );
    debugPrint('[Cache] invalidate  key=$key');
  }

  /// Invalida múltiples claves a la vez en L1 y L2.
  Future<void> invalidateAll(List<String> keys) async {
    _assertInit();
    _l1.removeAll(keys);
    final sw = Stopwatch()..start();
    await _box.deleteAll(keys);
    sw.stop();
    PipelineLogger.shared.log(
      stage: PipelineStage.storage,
      operation: 'Hive.deleteAll(${keys.length})',
      recordCount: keys.length,
      latency: sw.elapsed,
    );
    debugPrint('[Cache] invalidateAll  keys=$keys');
  }

  /// Elimina todas las entradas en L1 y L2 (útil al cerrar sesión).
  Future<void> clearAll() async {
    _assertInit();
    _l1.clear();
    final sw = Stopwatch()..start();
    await _box.clear();
    sw.stop();
    PipelineLogger.shared.log(
      stage: PipelineStage.storage,
      operation: 'Hive.clear()',
      recordCount: 0,
      latency: sw.elapsed,
    );
    debugPrint('[Cache] clearAll  (L1+L2 vaciados)');
  }

  /// Devuelve true si existe una entrada válida (no expirada) para [key].
  bool hasValid(String key) => get(key) != null;

  // ── Stats ──────────────────────────────────────────────────────────────────

  /// Número de entradas actualmente en la capa L1 (LRU).
  int get l1Size => _l1.length;

  /// Número de entradas actualmente en la capa L2 (Hive).
  int get l2Size => _initialized ? _box.length : 0;

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _assertInit() {
    assert(_initialized, 'CacheService no inicializado — llama init()');
  }

  Duration _defaultTtl(String key) {
    switch (key) {
      case CacheKeys.products:
        return CacheTtl.products;
      case CacheKeys.alerts:
        return CacheTtl.alerts;
      case CacheKeys.dashboard:
        return CacheTtl.dashboard;
      default:
        return CacheTtl.products; // 5 min como default conservador
    }
  }
}
