import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/lru_cache.dart';
import '../../models/location_walk.dart';

class LocationWalkSnapshotCache {
  LocationWalkSnapshotCache._();
  static final LocationWalkSnapshotCache shared =
      LocationWalkSnapshotCache._();

  static const _boxName = 'location_walk_snapshot_cache_v1';
  static const _ttl = Duration(hours: 8);
  static const _l1Capacity = 4;

  final LRUCache<String, _Entry> _l1 = LRUCache(_l1Capacity);
  late Box<String> _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox<String>(_boxName);
    _ready = true;
  }

  Future<LocationWalkSummary?> read(String storeKey) async {
    if (!_ready) return null;

    final mem = _l1.get(storeKey);
    if (mem != null && !mem.isExpired) return mem.summary;
    if (mem != null) _l1.remove(storeKey);

    final raw = _box.get(storeKey);
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.parse(map['savedAt'] as String);
      if (DateTime.now().difference(savedAt) > _ttl) {
        await _box.delete(storeKey);
        return null;
      }
      final summary = LocationWalkSummary.fromJson(
          Map<String, dynamic>.from(map['summary'] as Map));
      _l1.put(storeKey, _Entry(summary: summary, savedAt: savedAt));
      return summary;
    } catch (_) {
      await _box.delete(storeKey);
      return null;
    }
  }

  Future<void> save(String storeKey, LocationWalkSummary summary) async {
    if (!_ready) return;
    final savedAt = DateTime.now();
    _l1.put(storeKey, _Entry(summary: summary, savedAt: savedAt));
    await _box.put(
      storeKey,
      jsonEncode({
        'savedAt': savedAt.toIso8601String(),
        'summary': summary.toJson(),
      }),
    );
  }
}

class _Entry {
  final LocationWalkSummary summary;
  final DateTime savedAt;

  _Entry({required this.summary, required this.savedAt});

  bool get isExpired =>
      DateTime.now().difference(savedAt) > LocationWalkSnapshotCache._ttl;
}
