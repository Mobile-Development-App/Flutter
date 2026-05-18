import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/lru_cache.dart';
import '../../models/inventory_movement.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InventoryMovementsCache — NUEVO requerimiento (movimientos de inventario)
//
// Problema: restock, BQ3 y AI reabastecimiento llamaban GET /movements sin caché.
// Estrategia: L1 LRU (30 productos) + L2 Hive box "movements_cache_v1"
// TTL: 15 minutos (movimientos cambian con ventas/reposición).
// ─────────────────────────────────────────────────────────────────────────────

class InventoryMovementsCache {
  InventoryMovementsCache._();
  static final InventoryMovementsCache shared = InventoryMovementsCache._();

  static const _boxName = 'movements_cache_v1';
  static const _ttl = Duration(minutes: 15);
  static const _l1Capacity = 30;

  final LRUCache<String, _Entry> _l1 = LRUCache(_l1Capacity);
  late Box<String> _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox<String>(_boxName);
    _ready = true;
    debugPrint('[MovementsCache] init — ${_box.length} claves en L2');
  }

  String _key(String productId) => 'movements_$productId';

  /// Cache-aside: devuelve caché válido o ejecuta [fetchFromApi] y persiste.
  Future<List<InventoryMovement>> getOrFetch(
    String productId,
    Future<List<InventoryMovement>> Function() fetchFromApi,
  ) async {
    _assertReady();

    final key = _key(productId);
    final hit = _read(key);
    if (hit != null) {
      debugPrint('[MovementsCache] HIT $productId (${hit.length})');
      return hit;
    }

    final fresh = await fetchFromApi();
    await put(productId, fresh);
    return fresh;
  }

  Future<void> put(String productId, List<InventoryMovement> movements) async {
    _assertReady();
    final key = _key(productId);
    final entry = _Entry(
      movements: movements,
      cachedAt: DateTime.now(),
    );
    _l1.put(key, entry);
    await _box.put(key, entry.toJsonString());
  }

  /// Invalida tras un restock local/API para forzar refresco.
  Future<void> invalidate(String productId) async {
    _assertReady();
    final key = _key(productId);
    _l1.remove(key);
    await _box.delete(key);
  }

  List<InventoryMovement>? _read(String key) {
    final l1 = _l1.get(key);
    if (l1 != null) {
      if (!l1.isExpired(_ttl)) return l1.movements;
      _l1.remove(key);
      _box.delete(key);
      return null;
    }

    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final entry = _Entry.fromJsonString(raw);
      if (entry.isExpired(_ttl)) {
        _box.delete(key);
        return null;
      }
      _l1.put(key, entry);
      return entry.movements;
    } catch (_) {
      _box.delete(key);
      return null;
    }
  }

  void _assertReady() {
    assert(_ready, 'InventoryMovementsCache no inicializado');
  }
}

class _Entry {
  final List<InventoryMovement> movements;
  final DateTime cachedAt;

  _Entry({required this.movements, required this.cachedAt});

  bool isExpired(Duration ttl) =>
      DateTime.now().isAfter(cachedAt.add(ttl));

  String toJsonString() => jsonEncode({
        'cachedAt': cachedAt.toIso8601String(),
        'items': movements.map(_movementToMap).toList(),
      });

  static _Entry fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final items = (map['items'] as List)
        .map((e) => InventoryMovement.fromBackendJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
    return _Entry(
      movements: items,
      cachedAt: DateTime.parse(map['cachedAt'] as String),
    );
  }
}

Map<String, dynamic> _movementToMap(InventoryMovement m) => {
      'id': m.id,
      'productId': m.productId,
      'type': m.type.name.toUpperCase(),
      'quantity': m.quantity,
      'createdAt': m.createdAt.toIso8601String(),
    };
