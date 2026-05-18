import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OpenFoodFactsCache — NUEVO requerimiento (escaneo / lookup externo)
//
// Estrategia: Hive llave/valor — clave = código de barras.
// TTL: 30 días (datos de catálogo Open Food Facts cambian poco).
// ─────────────────────────────────────────────────────────────────────────────

class OpenFoodFactsCache {
  OpenFoodFactsCache._();
  static final OpenFoodFactsCache shared = OpenFoodFactsCache._();

  static const _boxName = 'open_food_facts_v1';
  static const _ttl = Duration(days: 30);

  late Box<String> _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox<String>(_boxName);
    _ready = true;
  }

  Future<Map<String, dynamic>?> get(String barcode) async {
    _assertReady();
    final raw = _box.get(barcode);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expires = DateTime.parse(map['_expiresAt'] as String);
      if (DateTime.now().isAfter(expires)) {
        await _box.delete(barcode);
        return null;
      }
      final data = Map<String, dynamic>.from(map['data'] as Map);
      debugPrint('[OFFCache] HIT $barcode');
      return data;
    } catch (_) {
      await _box.delete(barcode);
      return null;
    }
  }

  Future<void> put(String barcode, Map<String, dynamic> data) async {
    _assertReady();
    final payload = jsonEncode({
      '_expiresAt': DateTime.now().add(_ttl).toIso8601String(),
      'data': data,
    });
    await _box.put(barcode, payload);
    debugPrint('[OFFCache] PUT $barcode');
  }

  void _assertReady() {
    assert(_ready, 'OpenFoodFactsCache no inicializado');
  }
}
