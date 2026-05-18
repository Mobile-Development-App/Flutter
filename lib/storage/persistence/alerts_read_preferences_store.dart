import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertsReadPreferencesStore — NUEVO requerimiento (Preferences)
//
// Cola local de IDs de alertas marcadas como leídas cuando la API falla.
// Se fusiona al cargar alertas desde caché/API.
// ─────────────────────────────────────────────────────────────────────────────

class AlertsReadPreferencesStore {
  AlertsReadPreferencesStore._();
  static final AlertsReadPreferencesStore shared =
      AlertsReadPreferencesStore._();

  static const _kPendingReadIds = 'inventaria_pending_alert_reads_v1';

  Future<void> init() async {}

  Future<Set<String>> pendingReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingReadIds);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> markRead(String alertId) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await pendingReadIds()..add(alertId);
    await prefs.setString(_kPendingReadIds, jsonEncode(set.toList()));
  }

  Future<void> markAllRead(Iterable<String> alertIds) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await pendingReadIds()..addAll(alertIds);
    await prefs.setString(_kPendingReadIds, jsonEncode(set.toList()));
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingReadIds);
  }
}
