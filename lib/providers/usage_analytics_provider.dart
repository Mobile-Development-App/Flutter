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
// BQ9  (Type 2)  Workflow points where restock decisions consume most time
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

    Duration calcAvg(PipelineStage stage) {
      final matching =
          records.where((r) => r.stage == stage && r.latency != Duration.zero);
      if (matching.isEmpty) return Duration.zero;
      final total = matching.fold<int>(
          0, (sum, r) => sum + r.latency.inMicroseconds);
      return Duration(microseconds: total ~/ matching.length);
    }

    final ingestion = calcAvg(PipelineStage.ingestion);
    final storage = calcAvg(PipelineStage.storage);
    final processing = calcAvg(PipelineStage.processing);
    final computation = calcAvg(PipelineStage.computation);

    final svc = UsageTrackingService.shared;
    final stageLatencies = <String, Duration>{
      'ingestion': ingestion,
      'storage': storage,
      'processing': processing,
      'computation': computation,
    };

    for (final entry in stageLatencies.entries) {
      if (entry.value != Duration.zero) {
        await svc.persistLatencyRecord(
          stage: entry.key,
          latencyMs: entry.value.inMilliseconds,
          success: true,
        );
      }
    }

    final crossSessionIngestion =
        await svc.getAverageLatencyMs(stage: 'ingestion');
    final crossSessionStorage =
        await svc.getAverageLatencyMs(stage: 'storage');
    final crossSessionProcessing =
        await svc.getAverageLatencyMs(stage: 'processing');
    final crossSessionComputation =
        await svc.getAverageLatencyMs(stage: 'computation');

    return BQ1State(
      avgIngestionMs: crossSessionIngestion > 0
          ? crossSessionIngestion
          : ingestion.inMilliseconds.toDouble(),
      avgStorageMs: crossSessionStorage > 0
          ? crossSessionStorage
          : storage.inMilliseconds.toDouble(),
      avgProcessingMs: crossSessionProcessing > 0
          ? crossSessionProcessing
          : processing.inMilliseconds.toDouble(),
      avgComputationMs: crossSessionComputation > 0
          ? crossSessionComputation
          : computation.inMilliseconds.toDouble(),
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

// ── BQ9 — Restock decision workflow hotspots ─────────────────────────────────

class BQ9Dashboard {
  final List<RestockWorkflowInsight> points;
  final double totalDecisionSeconds;
  final double averageDecisionSeconds;
  final int totalSessions;

  const BQ9Dashboard({
    required this.points,
    required this.totalDecisionSeconds,
    required this.averageDecisionSeconds,
    required this.totalSessions,
  });
}

class BQ9Notifier extends AsyncNotifier<BQ9Dashboard> {
  @override
  Future<BQ9Dashboard> build() async {
    await UsageTrackingService.shared.init();
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<BQ9Dashboard> _load() async {
    final points = await UsageTrackingService.shared.getRestockWorkflowInsights(limitDays: 30);
    final totalDecisionSeconds = points.fold<double>(0, (sum, point) => sum + point.totalSeconds);
    final totalSessions = points.fold<int>(0, (sum, point) => sum + point.visits);
    final averageDecisionSeconds =
      totalSessions == 0 ? 0.0 : totalDecisionSeconds / totalSessions;

    return BQ9Dashboard(
      points: points,
      totalDecisionSeconds: totalDecisionSeconds,
      averageDecisionSeconds: averageDecisionSeconds,
      totalSessions: totalSessions,
    );
  }
}

final bq9Provider =
    AsyncNotifierProvider<BQ9Notifier, BQ9Dashboard>(BQ9Notifier.new);
