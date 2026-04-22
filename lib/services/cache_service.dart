import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CacheService — Sprint 4 (Caching Strategy)
//
// PATRÓN: Cache-Aside (lazy population)
//   1. El caller intenta get(key).
//   2. Si hay HIT y no está expirado → retorna datos cacheados.
//   3. Si MISS o expirado → el caller obtiene datos frescos del API y
//      luego llama put(key, data) para cachear.
//   4. Ante error de red → get(key, allowStale: true) puede retornar
//      datos expirados como último recurso de degradación.
//
// ALMACENAMIENTO: Hive box "api_cache".
//   Cada entrada es un mapa con:
//     data      — JSON-encoded payload
//     cachedAt  — ISO-8601 timestamp de escritura
//     ttlMs     — tiempo de vida en milisegundos
//
// TTLs por defecto (configurables en put()):
//   products  → 5 minutos
//   alerts    → 10 minutos
//   dashboard → 10 minutos
//
// HILO SEGURO: Hive es single-threaded; las operaciones son await-able y
// no requieren locks adicionales en Dart (single-threaded event loop).
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

  late Box<Map> _box;
  bool _initialized = false;

  /// Inicializa el box de Hive.  Llamar en main() tras Hive.initFlutter().
  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<Map>(_boxName);
    _initialized = true;
    debugPrint('[Cache] init — ${_box.length} entradas en caché');
  }

  // ── Escritura ──────────────────────────────────────────────────────────────

  /// Almacena [data] bajo [key] con el [ttl] especificado.
  ///
  /// Si no se pasa [ttl], se infiere según los valores predeterminados por
  /// [CacheKeys]:  products=5 min, alerts/dashboard=10 min, default=5 min.
  Future<void> put(String key, dynamic data, {Duration? ttl}) async {
    _assertInit();
    final effectiveTtl = ttl ?? _defaultTtl(key);
    final entry = _CacheEntry(
      data: data,
      cachedAt: DateTime.now(),
      ttl: effectiveTtl,
    );
    await _box.put(key, entry.toJson());
    debugPrint('[Cache] put  key=$key  ttl=${effectiveTtl.inMinutes}min');
  }

  // ── Lectura ────────────────────────────────────────────────────────────────

  /// Retorna los datos cacheados para [key], o `null` si:
  ///   - no existe la entrada, o
  ///   - está expirada (y [allowStale] == false).
  ///
  /// Con [allowStale] = true retorna datos expirados sin evictarlos
  /// (útil como fallback de último recurso cuando la red no está disponible).
  dynamic get(String key, {bool allowStale = false}) {
    _assertInit();
    final raw = _box.get(key);
    if (raw == null) {
      debugPrint('[Cache] MISS  key=$key');
      return null;
    }

    final entry = _CacheEntry.fromJson(raw);

    if (entry.isExpired) {
      if (!allowStale) {
        // Evictar entrada expirada de forma asíncrona (fire-and-forget).
        _box.delete(key);
        debugPrint('[Cache] EXPIRED+EVICTED  key=$key');
        return null;
      }
      debugPrint('[Cache] STALE-HIT  key=$key  (allowStale=true)');
      return entry.data;
    }

    final age = DateTime.now().difference(entry.cachedAt);
    debugPrint('[Cache] HIT  key=$key  age=${age.inSeconds}s');
    return entry.data;
  }

  /// Elimina la entrada de [key] (útil tras operaciones de escritura exitosas).
  Future<void> invalidate(String key) async {
    _assertInit();
    await _box.delete(key);
    debugPrint('[Cache] invalidate  key=$key');
  }

  /// Invalida múltiples claves a la vez.
  Future<void> invalidateAll(List<String> keys) async {
    _assertInit();
    await _box.deleteAll(keys);
    debugPrint('[Cache] invalidateAll  keys=$keys');
  }

  /// Elimina todas las entradas (útil al cerrar sesión o cambiar de tienda).
  Future<void> clearAll() async {
    _assertInit();
    await _box.clear();
    debugPrint('[Cache] clearAll');
  }

  /// Devuelve true si existe una entrada válida (no expirada) para [key].
  bool hasValid(String key) => get(key) != null;

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
