import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/pipeline_logger.dart';
import '../services/data_processing_service.dart';
import '../core/utils/extensions.dart';
import 'inventory_provider.dart';

// ─────────────────────────────────────────────
// TimeRange
// ─────────────────────────────────────────────
enum TimeRange {
  week('7d', '7 días', 7),
  month('30d', '30 días', 30),
  quarter('90d', '90 días', 90),
  year('1a', '1 año', 365);

  const TimeRange(this.value, this.label, this.days);
  final String value;
  final String label;
  final int days;
}

// ─────────────────────────────────────────────
// AnalyticsState
// ─────────────────────────────────────────────
class AnalyticsState {
  final TimeRange selectedTimeRange;
  final List<SalesDataPoint> salesData;
  final List<StockLevelData> stockLevelData;
  final List<CategoryDistribution> categoryDistribution;
  final bool isExporting;
  final bool exportSuccess;
  final bool isLoading;
  // Pipeline observability — surfaced to AnalyticsScreen
  final Map<PipelineStage, PipelineStageSummary> pipelineMetrics;

  const AnalyticsState({
    this.selectedTimeRange    = TimeRange.week,
    this.salesData            = const [],
    this.stockLevelData       = const [],
    this.categoryDistribution = const [],
    this.isExporting          = false,
    this.exportSuccess        = false,
    this.isLoading            = false,
    this.pipelineMetrics      = const {},
  });

  // ── Computation Layer: derived properties ──

  double get totalSales =>
      salesData.fold<double>(0.0, (s, p) => s + p.sales);

  double get averageDailySales =>
      salesData.isEmpty ? 0.0 : totalSales / salesData.length;

  int get totalOrders =>
      salesData.fold(0, (s, p) => s + p.orders);

  double get salesTrend {
    if (salesData.length < 2) return 0;
    final mid        = salesData.length ~/ 2;
    final firstHalf  = salesData.sublist(0, mid).fold<double>(0.0, (s, p) => s + p.sales);
    final secondHalf = salesData.sublist(mid).fold<double>(0.0, (s, p) => s + p.sales);
    if (firstHalf == 0) return 0;
    return ((secondHalf - firstHalf) / firstHalf) * 100;
  }

  AnalyticsState copyWith({
    TimeRange? selectedTimeRange,
    List<SalesDataPoint>? salesData,
    List<StockLevelData>? stockLevelData,
    List<CategoryDistribution>? categoryDistribution,
    bool? isExporting,
    bool? exportSuccess,
    bool? isLoading,
    Map<PipelineStage, PipelineStageSummary>? pipelineMetrics,
  }) =>
      AnalyticsState(
        selectedTimeRange:    selectedTimeRange    ?? this.selectedTimeRange,
        salesData:            salesData            ?? this.salesData,
        stockLevelData:       stockLevelData       ?? this.stockLevelData,
        categoryDistribution: categoryDistribution ?? this.categoryDistribution,
        isExporting:          isExporting          ?? this.isExporting,
        exportSuccess:        exportSuccess        ?? this.exportSuccess,
        isLoading:            isLoading            ?? this.isLoading,
        pipelineMetrics:      pipelineMetrics      ?? this.pipelineMetrics,
      );
}

// ─────────────────────────────────────────────
// AnalyticsNotifier
//
// Pipeline responsibilities per layer:
//   INGESTION  — ApiService.get() → Cloud Functions REST
//   PROCESSING — DataProcessingService (real-time client) /
//                Cloud Functions cron (batch server-side)
//   COMPUTATION— AnalyticsState derived props (salesTrend, totalSales…)
//   PRESENTATION — AsyncData emitted to AnalyticsScreen ConsumerWidget
// ─────────────────────────────────────────────
class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  final _api        = ApiService.shared;
  final _processing = DataProcessingService.shared;
  final _pipeline   = PipelineLogger.shared;

  @override
  Future<AnalyticsState> build() async {
    final invState = ref.watch(inventoryProvider).value;
    final products = invState?.products ?? [];

    final sales       = await _fetchSalesTrend(TimeRange.week);
    final stockResult = _processing.aggregateStockByCategory(products);
    final catResult   = _processing.aggregateCategoryDistribution(products);

    _pipeline.log(
      stage:       PipelineStage.computation,
      operation:   'AnalyticsState.build — derived props ready',
      recordCount: products.length,
      latency:     Duration.zero,
    );

    return AnalyticsState(
      salesData:            sales,
      stockLevelData:       stockResult.data,
      categoryDistribution: catResult.data,
      pipelineMetrics:      _pipeline.summary,
    );
  }

  // ── INGESTION: sales trend via REST ───────

  Future<List<SalesDataPoint>> _fetchSalesTrend(TimeRange range) async {
    return _pipeline.measure<List<SalesDataPoint>>(
      stage:     PipelineStage.ingestion,
      operation: 'GET $kAnalyticsSalesTrend?period=${range.value}',
      call: () async {
        final data = await _api.get(
          kAnalyticsSalesTrend,
          query: {'period': range.value},
        ) as dynamic;
        final list = _extractList(data);
        if (list.isEmpty) throw Exception('empty response');
        return list.map((e) {
          final map = e as Map<String, dynamic>;
          return SalesDataPoint(
            id:     map['id']    as String? ?? map['date'] as String? ?? '',
            date:   ApiService.parseDate(map['date']) ?? DateTime.now(),
            sales:  (map['total']  as num?)?.toDouble() ??
                    (map['sales']  as num?)?.toDouble() ?? 0.0,
            orders: (map['orders'] as num?)?.toInt() ??
                    (map['count']  as num?)?.toInt() ?? 0,
          );
        }).toList();
      },
      countRecords:   (list) => list.length,
      onFallback:     (_)    => <SalesDataPoint>[],
      fallbackReason: 'API unavailable — sin datos de ventas',
    );
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['data', 'items', 'results', 'sales', 'trends', 'records']) {
        final val = data[key];
        if (val is List && val.isNotEmpty) return val;
      }
    }
    return [];
  }

  // ── Actions ───────────────────────────────

  Future<void> loadData(TimeRange range) async {
    _update((s) => s.copyWith(isLoading: true, selectedTimeRange: range));
    final invState = ref.read(inventoryProvider).value;
    final products = invState?.products ?? [];

    final sales       = await _fetchSalesTrend(range);
    final stockResult = _processing.aggregateStockByCategory(products);
    final catResult   = _processing.aggregateCategoryDistribution(products);

    _pipeline.log(
      stage:       PipelineStage.presentation,
      operation:   'loadData → AnalyticsScreen render',
      recordCount: sales.length + stockResult.data.length + catResult.data.length,
      latency:     Duration.zero,
    );

    _update((s) => s.copyWith(
      isLoading:            false,
      selectedTimeRange:    range,
      salesData:            sales,
      stockLevelData:       stockResult.data,
      categoryDistribution: catResult.data,
      pipelineMetrics:      _pipeline.summary,
    ));
  }

  Future<void> refreshAll() async {
    debugPrint('[Analytics] Manual refresh');
    state = const AsyncLoading();
    final invState = ref.read(inventoryProvider).value;
    final products = invState?.products ?? [];
    final sales       = await _fetchSalesTrend(state.value?.selectedTimeRange ?? TimeRange.week);
    final stockResult = _processing.aggregateStockByCategory(products);
    final catResult   = _processing.aggregateCategoryDistribution(products);
    state = AsyncData(AnalyticsState(
      salesData:            sales,
      stockLevelData:       stockResult.data,
      categoryDistribution: catResult.data,
      pipelineMetrics:      _pipeline.summary,
    ));
  }

  Future<void> exportReport() async {
    _update((s) => s.copyWith(isExporting: true));
    try {
      await _api.post('/exports', {
        'format': 'PDF',
        'dateRange': {
          'from': DateTime.now()
              .subtract(Duration(days: state.value?.selectedTimeRange.days ?? 7))
              .toIso8601String(),
          'to': DateTime.now().toIso8601String(),
        },
      });
      _pipeline.log(
        stage: PipelineStage.presentation, operation: 'exportReport → PDF',
        recordCount: 1, latency: Duration.zero,
      );
      debugPrint('[Analytics] ✅ Export sent');
    } catch (e) {
      _pipeline.logFallback(
        stage: PipelineStage.presentation, operation: 'exportReport', reason: e.toString(),
      );
      debugPrint('[Analytics] ⚠️  exportReport failed: $e');
    }
    await HapticManager.success();
    _update((s) => s.copyWith(isExporting: false, exportSuccess: true));
    await Future<void>.delayed(const Duration(seconds: 2));
    _update((s) => s.copyWith(exportSuccess: false));
  }

  void _update(AnalyticsState Function(AnalyticsState) fn) {
    final current = state.value;
    if (current != null) state = AsyncData(fn(current));
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(
        AnalyticsNotifier.new);
