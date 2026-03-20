import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
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

  const AnalyticsState({
    this.selectedTimeRange    = TimeRange.week,
    this.salesData            = const [],
    this.stockLevelData       = const [],
    this.categoryDistribution = const [],
    this.isExporting          = false,
    this.exportSuccess        = false,
    this.isLoading            = false,
  });

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
  }) =>
      AnalyticsState(
        selectedTimeRange:    selectedTimeRange    ?? this.selectedTimeRange,
        salesData:            salesData            ?? this.salesData,
        stockLevelData:       stockLevelData       ?? this.stockLevelData,
        categoryDistribution: categoryDistribution ?? this.categoryDistribution,
        isExporting:          isExporting          ?? this.isExporting,
        exportSuccess:        exportSuccess        ?? this.exportSuccess,
        isLoading:            isLoading            ?? this.isLoading,
      );
}

// ─────────────────────────────────────────────
// AnalyticsNotifier
// - Sales trend: real API, fallback MockData
// - Stock levels: computed from real products (API endpoint unreliable)
// - Category dist: computed from real products (endpoint returns 404)
// ─────────────────────────────────────────────
class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  final _api = ApiService.shared;

  @override
  Future<AnalyticsState> build() async {
    // Watch inventory so charts auto-update when products change
    final invState = ref.watch(inventoryProvider).value;
    final products = invState?.products ?? [];

    return AnalyticsState(
      salesData:            await _fetchSalesTrend(TimeRange.week),
      stockLevelData:       _buildStockLevelData(products),
      categoryDistribution: _buildCategoryDistribution(products),
    );
  }

  // ── Real API: Sales trend ─────────────────

  Future<List<SalesDataPoint>> _fetchSalesTrend(TimeRange range) async {
    try {
      debugPrint('[Analytics] GET $kAnalyticsSalesTrend?period=${range.value}');
      final data = await _api.get(
        kAnalyticsSalesTrend,
        query: {'period': range.value},
      ) as dynamic;

      debugPrint('[Analytics] salesTrend raw type: ${data.runtimeType}');
      if (data is Map) debugPrint('[Analytics] salesTrend keys: ${data.keys.toList()}');

      final list = _extractList(data);
      if (list.isEmpty) {
        debugPrint('[Analytics] ⚠️  FALLBACK — salesTrend empty, using MockData');
        return MockData.generateSalesData(days: range.days);
      }

      final result = list.map((e) {
        final map = e as Map<String, dynamic>;
        return SalesDataPoint(
          id:     map['id']     as String? ?? map['date'] as String? ?? '',
          date:   ApiService.parseDate(map['date']) ?? DateTime.now(),
          sales:  (map['total']  as num?)?.toDouble() ??
                  (map['sales']  as num?)?.toDouble() ?? 0.0,
          orders: (map['orders'] as num?)?.toInt() ??
                  (map['count']  as num?)?.toInt() ?? 0,
        );
      }).toList();
      debugPrint('[Analytics] ✅ salesTrend: ${result.length} points from backend');
      return result;
    } catch (e) {
      debugPrint('[Analytics] ⚠️  FALLBACK — fetchSalesTrend failed: $e');
      return MockData.generateSalesData(days: range.days);
    }
  }

  // ── Computed locally from real products ───

  /// Groups products by category and counts inStock / lowStock / outOfStock
  List<StockLevelData> _buildStockLevelData(List<Product> products) {
    if (products.isEmpty) {
      debugPrint('[Analytics] ⚠️  stockLevels — no products yet, using MockData');
      return MockData.stockLevelData;
    }

    final Map<String, _StockBucket> buckets = {};

    for (final p in products) {
      final key = p.category.label;
      buckets.putIfAbsent(key, () => _StockBucket(key));
      switch (p.stockStatus) {
        case StockStatus.inStock:
          buckets[key]!.inStock++;
        case StockStatus.lowStock:
          buckets[key]!.lowStock++;
        case StockStatus.outOfStock:
          buckets[key]!.outOfStock++;
      }
    }

    final result = buckets.entries.map((e) => StockLevelData(
          id:         e.key,
          category:   e.key,
          inStock:    e.value.inStock,
          lowStock:   e.value.lowStock,
          outOfStock: e.value.outOfStock,
        )).toList();

    debugPrint('[Analytics] ✅ stockLevels computed from ${products.length} products → ${result.length} categories');
    return result;
  }

  /// Builds category distribution from real product list
  List<CategoryDistribution> _buildCategoryDistribution(List<Product> products) {
    if (products.isEmpty) {
      debugPrint('[Analytics] ⚠️  categoryDist — no products yet, using MockData');
      return MockData.categoryDistribution;
    }

    final Map<String, int> counts = {};
    for (final p in products) {
      final key = p.category.label;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final total = products.length;
    final result = counts.entries
        .where((e) => e.value > 0)
        .map((e) => CategoryDistribution(
              id:         e.key,
              category:   e.key,
              count:      e.value,
              percentage: (e.value / total) * 100,
              value:      0,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    debugPrint('[Analytics] ✅ categoryDist computed from ${products.length} products → ${result.length} categories');
    return result;
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
    final sales    = await _fetchSalesTrend(range);
    _update((s) => s.copyWith(
      isLoading:            false,
      selectedTimeRange:    range,
      salesData:            sales,
      stockLevelData:       _buildStockLevelData(products),
      categoryDistribution: _buildCategoryDistribution(products),
    ));
  }

  Future<void> refreshAll() async {
    debugPrint('[Analytics] Manual refresh triggered');
    state = const AsyncLoading();
    final invState = ref.read(inventoryProvider).value;
    final products = invState?.products ?? [];
    state = await AsyncValue.guard(() async => AnalyticsState(
      salesData:            await _fetchSalesTrend(state.value?.selectedTimeRange ?? TimeRange.week),
      stockLevelData:       _buildStockLevelData(products),
      categoryDistribution: _buildCategoryDistribution(products),
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
      debugPrint('[Analytics] ✅ Export sent');
    } catch (e) {
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

class _StockBucket {
  final String category;
  int inStock = 0, lowStock = 0, outOfStock = 0;
  _StockBucket(this.category);
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(
        AnalyticsNotifier.new);
