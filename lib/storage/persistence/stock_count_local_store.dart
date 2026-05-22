import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/stock_count.dart';

class StockCountLocalStore {
  StockCountLocalStore._();
  static final StockCountLocalStore shared = StockCountLocalStore._();

  static const _sessionsBox = 'stock_count_sessions_v1';
  static const _pendingBox = 'stock_count_pending_sync_v1';
  static const _activeKey = '__active_session__';

  late Box<String> _sessions;
  late Box<String> _pending;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _sessions = await Hive.openBox<String>(_sessionsBox);
    _pending = await Hive.openBox<String>(_pendingBox);
    _ready = true;
  }

  Future<StockCountSession> startSession(String storeId) async {
    _assertReady();
    final session = StockCountSession(
      id: const Uuid().v4(),
      storeId: storeId,
      startedAt: DateTime.now(),
    );
    await _sessions.put(session.id, jsonEncode(session.toJson()));
    await _sessions.put(_activeKey, session.id);
    return session;
  }

  StockCountSession? activeSession() {
    _assertReady();
    final id = _sessions.get(_activeKey);
    if (id == null) return null;
    return loadSession(id);
  }

  StockCountSession? loadSession(String id) {
    _assertReady();
    final raw = _sessions.get(id);
    if (raw == null) return null;
    try {
      return StockCountSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(StockCountSession session) async {
    _assertReady();
    await _sessions.put(session.id, jsonEncode(session.toJson()));
    if (session.isActive) {
      await _sessions.put(_activeKey, session.id);
    } else {
      final activeId = _sessions.get(_activeKey);
      if (activeId == session.id) {
        await _sessions.delete(_activeKey);
      }
    }
  }

  Future<void> clearActive() async {
    _assertReady();
    await _sessions.delete(_activeKey);
  }

  Future<void> discardDraftSession(String sessionId) async {
    _assertReady();
    await _sessions.delete(sessionId);
    final activeId = _sessions.get(_activeKey);
    if (activeId == sessionId) {
      await _sessions.delete(_activeKey);
    }
  }

  List<StockCountSession> completedSessions(String storeId, {int limit = 10}) {
    _assertReady();
    final list = <StockCountSession>[];
    for (final key in _sessions.keys) {
      if (key == _activeKey) continue;
      final s = loadSession(key as String);
      if (s != null &&
          s.storeId == storeId &&
          s.completedAt != null &&
          !s.isActive) {
        list.add(s);
      }
    }
    list.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return list.take(limit).toList();
  }

  Future<void> enqueuePendingSync(String sessionId) async {
    _assertReady();
    await _pending.put(sessionId, DateTime.now().toIso8601String());
  }

  List<String> pendingSyncIds() {
    _assertReady();
    return _pending.keys.cast<String>().toList();
  }

  Future<void> markSynced(String sessionId) async {
    _assertReady();
    await _pending.delete(sessionId);
    final s = loadSession(sessionId);
    if (s != null) {
      await saveSession(s.copyWith(syncPending: false));
    }
  }

  void _assertReady() {
    assert(_ready, 'StockCountLocalStore no inicializado');
  }
}
