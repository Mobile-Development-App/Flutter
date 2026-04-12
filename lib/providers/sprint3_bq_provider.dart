import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pipeline_logger.dart';
import '../services/usage_tracking_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sprint 3 — Business Question Providers
//
// BQ1  (Type 1)  Average processing latency ingestion→storage
// BQ5  (Type 2)  Screens the user engages with most during peak hours
// BQ7  (Type 3)  Barcode scan vs manual entry accuracy (last 30 days)
// BQ8  (Type 3)  Which analytical features accessed most per week
// ─────────────────────────────────────────────────────────────────────────────

// ── BQ1 — Average processing latency ─────────────────────────────────────────

class BQ1State {
  final double avgIngestionMs;
  final double avgStorageMs;
  final double avgProcessingMs;
  final double avgComputationMs;
  final int totalRecords;
  final bool isLoading;

  const BQ1State({
    this.avgIngestionMs = 0,
    this.avgStorageMs = 0,
    this.avgProcessingMs = 0,
    this.avgComputationMs = 0,
    this.totalRecords = 0,
    this.isLoading = true,
  });

  BQ1State copyWith({
    double? avgIngestionMs,
    double? avgStorageMs,
    double? avgProcessingMs,
    double? avgComputationMs,
    int? totalRecords,
    bool? isLoading,
  }) =>
      BQ1State(
        avgIngestionMs: avgIngestionMs ?? this.avgIngestionMs,
        avgStorageMs: avgStorageMs ?? this.avgStorageMs,
        avgProcessingMs: avgProcessingMs ?? this.avgProcessingMs,
        avgComputationMs: avgComputationMs ?? this.avgComputationMs,
        totalRecords: totalRecords ?? this.totalRecords,
        isLoading: isLoading ?? this.isLoading,
      );
}

class BQ1Notifier extends AsyncNotifier<BQ1State> {
  @override
  Future<BQ1State> build() async {
    await UsageTrackingService.shared.init();
    return _computeLatencies();
  }

  Future<BQ1State> _computeLatencies() async {
    // Read in-memory records from PipelineLogger (real-time session data)
    final records = PipelineLogger.shared.all;

    if (records.isEmpty) {
      return const BQ1State(isLoading: false);
    }

    Duration _avg(PipelineStage stage) {
      final matching =
          records.where((r) => r.stage == stage && r.latency != Duration.zero);
      if (matching.isEmpty) return Duration.zero;
      final total = matching.fold<int>(
          0, (sum, r) => sum + r.latency.inMicroseconds);
      return Duration(microseconds: total ~/ matching.length);
    }

    final ingestion = _avg(PipelineStage.ingestion);
    final storage = _avg(PipelineStage.storage);
    final processing = _avg(PipelineStage.processing);
    final computation = _avg(PipelineStage.computation);

    // Persist to SQLite for cross-session aggregation (BQ1 + local storage)
    final svc = UsageTrackingService.shared;
    if (ingestion != Duration.zero) {
      await svc.persistLatencyRecord(
          stage: 'ingestion',
          latencyMs: ingestion.inMilliseconds,
          success: true);
    }
    if (storage != Duration.zero) {
      await svc.persistLatencyRecord(
          stage: 'storage',
          latencyMs: storage.inMilliseconds,
          success: true);
    }

    // Cross-session averages from SQLite
    final crossSessionIngestion =
        await svc.getAverageLatencyMs(stage: 'ingestion');
    final crossSessionStorage =
        await svc.getAverageLatencyMs(stage: 'storage');

    return BQ1State(
      avgIngestionMs: crossSessionIngestion > 0
          ? crossSessionIngestion
          : ingestion.inMilliseconds.toDouble(),
      avgStorageMs: crossSessionStorage > 0
          ? crossSessionStorage
          : storage.inMilliseconds.toDouble(),
      avgProcessingMs: processing.inMilliseconds.toDouble(),
      avgComputationMs: computation.inMilliseconds.toDouble(),
      totalRecords: records.length,
      isLoading: false,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_computeLatencies);
  }
}

final bq1Provider =
    AsyncNotifierProvider<BQ1Notifier, BQ1State>(BQ1Notifier.new);

// ── BQ5 — Peak business hour screen engagement ────────────────────────────────

class BQ5Notifier extends AsyncNotifier<List<PeakHourInsight>> {
  @override
  Future<List<PeakHourInsight>> build() async {
    await UsageTrackingService.shared.init();
    return UsageTrackingService.shared.getPeakHourInsights(limitDays: 30);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => UsageTrackingService.shared.getPeakHourInsights(limitDays: 30),
    );
  }
}

final bq5Provider =
    AsyncNotifierProvider<BQ5Notifier, List<PeakHourInsight>>(
        BQ5Notifier.new);

// ── BQ7 — Barcode scan vs manual entry accuracy ───────────────────────────────

class BQ7Notifier extends AsyncNotifier<List<ScanAccuracyInsight>> {
  @override
  Future<List<ScanAccuracyInsight>> build() async {
    await UsageTrackingService.shared.init();
    return UsageTrackingService.shared.getScanAccuracyInsights(limitDays: 30);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () =>
          UsageTrackingService.shared.getScanAccuracyInsights(limitDays: 30),
    );
  }
}

final bq7Provider =
    AsyncNotifierProvider<BQ7Notifier, List<ScanAccuracyInsight>>(
        BQ7Notifier.new);

// ── BQ8 — Analytical features accessed most per week ─────────────────────────

class BQ8Notifier extends AsyncNotifier<List<FeatureUsageInsight>> {
  @override
  Future<List<FeatureUsageInsight>> build() async {
    await UsageTrackingService.shared.init();
    return UsageTrackingService.shared.getFeatureUsageInsights(limitWeeks: 4);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () =>
          UsageTrackingService.shared.getFeatureUsageInsights(limitWeeks: 4),
    );
  }
}

final bq8Provider =
    AsyncNotifierProvider<BQ8Notifier, List<FeatureUsageInsight>>(
        BQ8Notifier.new);
