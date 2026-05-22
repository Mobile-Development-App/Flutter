import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/location_walk.dart';

class LocationWalkLocalStore {
  LocationWalkLocalStore._();
  static final LocationWalkLocalStore shared = LocationWalkLocalStore._();

  static const _sessionsBox = 'location_walk_sessions_v1';
  static const _activeKey = '__active__';

  late Box<String> _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox<String>(_sessionsBox);
    _ready = true;
  }

  LocationWalkSession? activeSession() {
    _assertReady();
    final raw = _box.get(_activeKey);
    if (raw == null) return null;
    try {
      return LocationWalkSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActive(LocationWalkSession session) async {
    _assertReady();
    await _box.put(_activeKey, jsonEncode(session.toJson()));
  }

  Future<void> clearActive() async {
    _assertReady();
    await _box.delete(_activeKey);
  }

  Future<void> saveCompleted(LocationWalkSession session) async {
    _assertReady();
    await _box.put(session.id, jsonEncode(session.toJson()));
    await clearActive();
  }

  LocationWalkSession? latestCompleted(String storeId) {
    _assertReady();
    LocationWalkSession? best;
    for (final key in _box.keys) {
      if (key == _activeKey) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        final s = LocationWalkSession.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        if (s.storeId != storeId || s.completedAt == null) continue;
        if (best == null ||
            s.completedAt!.isAfter(best.completedAt!)) {
          best = s;
        }
      } catch (_) {}
    }
    return best;
  }

  Future<void> discardDraft(String sessionId) async {
    _assertReady();
    final active = activeSession();
    if (active?.id == sessionId) {
      await clearActive();
    }
    await _box.delete(sessionId);
  }

  void _assertReady() {
    assert(_ready, 'LocationWalkLocalStore no inicializado');
  }
}
