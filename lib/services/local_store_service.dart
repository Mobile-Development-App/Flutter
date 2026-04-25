import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LocalStoreService — capa unificada de storage con versionado.
///
/// - Guarda JSON con `schemaVersion` y `data`.
/// - Usa Hive si está disponible; si falla, cae a SharedPreferences.
/// - No reemplaza los servicios existentes (es una opción nueva y aislada).
class LocalStoreService {
  LocalStoreService._();
  static final LocalStoreService shared = LocalStoreService._();

  static const int currentSchemaVersion = 1;
  static const String _boxName = 'local_store_v1';
  static const String _spPrefix = 'inventaria_local_store_v1_';

  Box<String>? _box;
  bool _initAttempted = false;

  Future<void> init() async {
    if (_initAttempted) return;
    _initAttempted = true;
    try {
      _box = await Hive.openBox<String>(_boxName);
      debugPrint('[LocalStore] init: Hive box opened ($_boxName)');
    } catch (e) {
      _box = null;
      debugPrint('[LocalStore] init: Hive unavailable, fallback to SharedPreferences ($e)');
    }
  }

  Future<void> setJson(
    String key,
    Map<String, dynamic> data, {
    int schemaVersion = currentSchemaVersion,
  }) async {
    await init();
    final payload = jsonEncode({
      'schemaVersion': schemaVersion,
      'data': data,
      'writtenAt': DateTime.now().toIso8601String(),
    });

    final box = _box;
    if (box != null) {
      await box.put(key, payload);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_spPrefix$key', payload);
  }

  /// Lee JSON; si `schemaVersion` no coincide, intenta migrar.
  Future<Map<String, dynamic>?> getJson(String key) async {
    await init();
    String? raw;

    final box = _box;
    if (box != null) {
      raw = box.get(key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString('$_spPrefix$key');
    }

    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final v = (decoded['schemaVersion'] as int?) ?? 0;
      final data = decoded['data'];

      if (data is! Map) return null;

      final mapData = data.cast<String, dynamic>();
      if (v == currentSchemaVersion) return mapData;

      final migrated = _migrate(mapData, from: v, to: currentSchemaVersion);
      if (migrated == null) return null;

      // Persistir migración.
      await setJson(key, migrated, schemaVersion: currentSchemaVersion);
      return migrated;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    await init();
    final box = _box;
    if (box != null) {
      await box.delete(key);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_spPrefix$key');
  }

  /// Migraciones por versión (mantener pequeñas y seguras).
  Map<String, dynamic>? _migrate(
    Map<String, dynamic> data, {
    required int from,
    required int to,
  }) {
    if (from <= 0) return data;
    if (from == to) return data;

    // No hay migraciones definidas aún. En el futuro:
    // if (from == 1 && to == 2) { ... }
    return null;
  }
}

