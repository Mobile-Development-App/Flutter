import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pipeline_logger.dart';

class BQCacheService {
  BQCacheService._();
  static final BQCacheService shared = BQCacheService._();

  static const _prefix = 'inventaria_bq_cache_';

  Future<void> save(
    String key,
    Map<String, dynamic> payload, {
    Duration ttl = const Duration(hours: 12),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;
    final data = {
      'expiresAt': expiresAt,
      'payload': payload,
    };
    final sw = Stopwatch()..start();
    await prefs.setString('$_prefix$key', jsonEncode(data));
    sw.stop();
    PipelineLogger.shared.log(
      stage: PipelineStage.storage,
      operation: 'SharedPreferences.save($_prefix$key)',
      recordCount: 1,
      latency: sw.elapsed,
    );
  }

  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final sw = Stopwatch()..start();
    final raw = prefs.getString('$_prefix$key');
    sw.stop();
    if (raw == null || raw.isEmpty) return null;

    PipelineLogger.shared.log(
      stage: PipelineStage.storage,
      operation: 'SharedPreferences.read($_prefix$key)',
      recordCount: 1,
      latency: sw.elapsed,
    );

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = map['expiresAt'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) return null;
      return (map['payload'] as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}
