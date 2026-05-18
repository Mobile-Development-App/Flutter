import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardSnapshotStore — NUEVO requerimiento (resumen del home)
//
// Estrategia: Hive — snapshot durable del último [DashboardStats] válido.
// Complementa CacheService (TTL corto API); este persiste 24 h como fallback
// cuando falla el endpoint y no hay stale en api_cache.
// ─────────────────────────────────────────────────────────────────────────────

class DashboardSnapshotStore {
  DashboardSnapshotStore._();
  static final DashboardSnapshotStore shared = DashboardSnapshotStore._();

  static const _boxName = 'dashboard_snapshot_v1';
  static const _ttl = Duration(hours: 24);

  late Box<String> _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox<String>(_boxName);
    _ready = true;
  }

  Future<void> save(String storeId, DashboardStats stats) async {
    _assertReady();
    await _box.put(storeId, jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'stats': _statsToMap(stats),
    }));
  }

  DashboardStats? load(String storeId) {
    _assertReady();
    final raw = _box.get(storeId);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.parse(map['savedAt'] as String);
      if (DateTime.now().difference(savedAt) > _ttl) {
        _box.delete(storeId);
        return null;
      }
      return _statsFromMap(map['stats'] as Map<String, dynamic>);
    } catch (_) {
      _box.delete(storeId);
      return null;
    }
  }

  void _assertReady() {
    assert(_ready, 'DashboardSnapshotStore no inicializado');
  }
}

Map<String, dynamic> _statsToMap(DashboardStats s) => {
      'totalProducts': s.totalProducts,
      'lowStockCount': s.lowStockCount,
      'outOfStockCount': s.outOfStockCount,
      'totalStockValue': s.totalStockValue,
      'totalSalesToday': s.totalSalesToday,
      'totalOrders': s.totalOrders,
      'expiringCount': s.expiringCount,
      'activeAlerts': s.activeAlerts,
    };

DashboardStats _statsFromMap(Map<String, dynamic> m) => DashboardStats(
      totalProducts: (m['totalProducts'] as num?)?.toInt() ?? 0,
      lowStockCount: (m['lowStockCount'] as num?)?.toInt() ?? 0,
      outOfStockCount: (m['outOfStockCount'] as num?)?.toInt() ?? 0,
      totalStockValue: (m['totalStockValue'] as num?)?.toDouble() ?? 0,
      totalSalesToday: (m['totalSalesToday'] as num?)?.toDouble() ?? 0,
      totalOrders: (m['totalOrders'] as num?)?.toInt() ?? 0,
      expiringCount: (m['expiringCount'] as num?)?.toInt() ?? 0,
      activeAlerts: (m['activeAlerts'] as num?)?.toInt() ?? 0,
    );
