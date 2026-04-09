import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────
// PipelineStage — the six recognised layers
// Maps directly to the analytics pipeline rubric:
//   Source → Ingestion → Storage → Processing → Computation → Presentation
// ─────────────────────────────────────────────
enum PipelineStage {
  /// Raw data origin: Firestore /stores/{storeId}/ collections
  dataSource('DATA_SOURCE'),

  /// REST ingest: Cloud Functions HTTP endpoints + ApiService
  ingestion('INGESTION'),

  /// Persistence: Firestore (remote) + SharedPreferences (local audit log)
  storage('STORAGE'),

  /// Aggregation / transformation: Cloud Functions Node.js (server-side)
  /// and Dart client-side grouping (_buildStockLevelData, _buildCategoryDistribution)
  processing('PROCESSING'),

  /// Reactive derived state: Riverpod AsyncNotifier computed properties
  /// HealthScore, salesTrend %, profitMargin, stockStatus
  computation('COMPUTATION'),

  /// Output channels: Flutter screens, alert badges, PDF/CSV exports
  presentation('PRESENTATION');

  const PipelineStage(this.tag);
  final String tag;
}

// ─────────────────────────────────────────────
// PipelineRecord — one log entry per stage event
// ─────────────────────────────────────────────
class PipelineRecord {
  final PipelineStage stage;
  final String operation;
  final int recordCount;
  final Duration latency;
  final bool success;
  final String? fallbackReason;
  final DateTime timestamp;

  const PipelineRecord({
    required this.stage,
    required this.operation,
    required this.recordCount,
    required this.latency,
    required this.success,
    this.fallbackReason,
    required this.timestamp,
  });

  @override
  String toString() {
    final status = success ? '✅' : '⚠️ FALLBACK';
    final fallback = fallbackReason != null ? ' reason=$fallbackReason' : '';
    return '[PIPELINE][${stage.tag}] $status $operation '
        '| records=$recordCount | latency=${latency.inMilliseconds}ms$fallback';
  }
}

// ─────────────────────────────────────────────
// PipelineLogger — Singleton
//
// Every ApiService call and every Notifier computation
// passes through this logger so the full pipeline is
// observable and auditable without touching Firebase.
//
// CAP Theorem note (Storage Layer):
//   Firestore is classified as CP + eventual AP:
//   - Writes use multi-region quorum → Consistency + Partition Tolerance
//   - Reads served from local cache when offline → Availability (eventual)
//   This dual behaviour is what makes the offline-first strategy possible.
// ─────────────────────────────────────────────
class PipelineLogger {
  PipelineLogger._();
  static final PipelineLogger shared = PipelineLogger._();

  // Keeps the last 200 records in memory (no Firebase, no SharedPreferences)
  final List<PipelineRecord> _records = [];
  static const _maxRecords = 200;

  // ── Public surface ────────────────────────

  /// Log a successful pipeline stage event.
  void log({
    required PipelineStage stage,
    required String operation,
    required int recordCount,
    required Duration latency,
  }) {
    _append(PipelineRecord(
      stage:       stage,
      operation:   operation,
      recordCount: recordCount,
      latency:     latency,
      success:     true,
      timestamp:   DateTime.now(),
    ));
  }

  /// Log a fallback event (API failed → MockData or local cache used).
  void logFallback({
    required PipelineStage stage,
    required String operation,
    required String reason,
    int recordCount = 0,
  }) {
    _append(PipelineRecord(
      stage:          stage,
      operation:      operation,
      recordCount:    recordCount,
      latency:        Duration.zero,
      success:        false,
      fallbackReason: reason,
      timestamp:      DateTime.now(),
    ));
  }

  /// Convenience: wraps an async call, measures latency, logs result.
  Future<T> measure<T>({
    required PipelineStage stage,
    required String operation,
    required Future<T> Function() call,
    required int Function(T) countRecords,
    required T Function(Object) onFallback,
    String? fallbackReason,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final result = await call();
      sw.stop();
      log(
        stage:       stage,
        operation:   operation,
        recordCount: countRecords(result),
        latency:     sw.elapsed,
      );
      return result;
    } catch (e) {
      sw.stop();
      logFallback(
        stage:     stage,
        operation: operation,
        reason:    fallbackReason ?? e.toString(),
      );
      return onFallback(e);
    }
  }

  // ── Queries ───────────────────────────────

  List<PipelineRecord> get all => List.unmodifiable(_records);

  List<PipelineRecord> forStage(PipelineStage stage) =>
      _records.where((r) => r.stage == stage).toList();

  /// Summary map: stage → {calls, fallbacks, avgLatencyMs, totalRecords}
  Map<PipelineStage, PipelineStageSummary> get summary {
    final map = <PipelineStage, _Acc>{};
    for (final r in _records) {
      final acc = map.putIfAbsent(r.stage, _Acc.new);
      acc.calls++;
      if (!r.success) acc.fallbacks++;
      acc.totalLatencyMs += r.latency.inMilliseconds;
      acc.totalRecords   += r.recordCount;
    }
    return map.map((stage, acc) => MapEntry(
          stage,
          PipelineStageSummary(
            stage:         stage,
            totalCalls:    acc.calls,
            fallbacks:     acc.fallbacks,
            avgLatencyMs:  acc.calls > 0 ? acc.totalLatencyMs ~/ acc.calls : 0,
            totalRecords:  acc.totalRecords,
          ),
        ));
  }

  // ── Private ───────────────────────────────

  void _append(PipelineRecord record) {
    if (_records.length >= _maxRecords) _records.removeAt(0);
    _records.add(record);
    if (kDebugMode) debugPrint(record.toString());
  }
}

// ─────────────────────────────────────────────
// PipelineStageSummary — read-only view per stage
// ─────────────────────────────────────────────
class PipelineStageSummary {
  final PipelineStage stage;
  final int totalCalls;
  final int fallbacks;
  final int avgLatencyMs;
  final int totalRecords;

  const PipelineStageSummary({
    required this.stage,
    required this.totalCalls,
    required this.fallbacks,
    required this.avgLatencyMs,
    required this.totalRecords,
  });

  int get successCalls => totalCalls - fallbacks;
  double get reliabilityPct =>
      totalCalls == 0 ? 100.0 : (successCalls / totalCalls) * 100;
}

// ── Internal accumulator ──────────────────────
class _Acc {
  int calls = 0, fallbacks = 0, totalLatencyMs = 0, totalRecords = 0;
}
