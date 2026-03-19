import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../core/utils/extensions.dart';

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

  const AnalyticsState({
    this.selectedTimeRange = TimeRange.week,
    this.salesData = const [],
    this.stockLevelData = const [],
    this.categoryDistribution = const [],
    this.isExporting = false,
    this.exportSuccess = false,
  });

  double get totalSales =>
      salesData.fold<double>(0.0, (sum, p) => sum + p.sales);

  double get averageDailySales =>
      salesData.isEmpty ? 0.0 : totalSales / salesData.length;

  int get totalOrders =>
      salesData.fold(0, (sum, p) => sum + p.orders);

  double get salesTrend {
    if (salesData.length < 2) return 0;
    final mid = salesData.length ~/ 2;
    final firstHalf = salesData
        .sublist(0, mid).fold<double>(0.0, (s, p) => s + p.sales);
    final secondHalf = salesData
        .sublist(mid).fold<double>(0.0, (s, p) => s + p.sales);
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
  }) =>
      AnalyticsState(
        selectedTimeRange:     selectedTimeRange     ?? this.selectedTimeRange,
        salesData:             salesData             ?? this.salesData,
        stockLevelData:        stockLevelData        ?? this.stockLevelData,
        categoryDistribution:  categoryDistribution  ?? this.categoryDistribution,
        isExporting:           isExporting           ?? this.isExporting,
        exportSuccess:         exportSuccess         ?? this.exportSuccess,
      );
}

// ─────────────────────────────────────────────
// AnalyticsNotifier — connects to /analytics
// ─────────────────────────────────────────────
class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  final _api = ApiService.shared;

  @override
  Future<AnalyticsState> build() async {
    return AnalyticsState(
      salesData:            await _fetchSalesTrend(TimeRange.week),
      stockLevelData:       await _fetchStockByCategory(),
      categoryDistribution: await _fetchCategoryDistribution(),
    );
  }

  // ── API Fetchers ──────────────────────────

  Future<List<SalesDataPoint>> _fetchSalesTrend(TimeRange range) async {
    try {
      final data = await _api.get(
        kAnalyticsSalesTrend,
        query: {'period': range.value},
      ) as dynamic;

      final list = _extractList(data, 'data');
      if (list.isEmpty) return MockData.generateSalesData(days: range.days);

      return list.map((e) {
        final map = e as Map<String, dynamic>;
        return SalesDataPoint(
          id:     map['id'] as String? ?? map['date'] as String? ?? '',
          date:   ApiService.parseDate(map['date']) ?? DateTime.now(),
          sales:  (map['total'] as num?)?.toDouble() ??
                  (map['sales'] as num?)?.toDouble() ?? 0.0,
          orders: (map['orders'] as num?)?.toInt() ??
                  (map['count']  as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (_) {
      return MockData.generateSalesData(days: range.days);
    }
  }

  Future<List<StockLevelData>> _fetchStockByCategory() async {
    try {
      final data = await _api.get(kAnalyticsStockCat) as dynamic;
      final list = _extractList(data, 'data');
      if (list.isEmpty) return MockData.stockLevelData;

      return list.map((e) {
        final map = e as Map<String, dynamic>;
        return StockLevelData(
          id:         map['id'] as String? ?? map['category'] as String? ?? '',
          category:   map['category'] as String? ?? map['categoryId'] as String? ?? '',
          inStock:    (map['inStock']    as num?)?.toInt() ?? 0,
          lowStock:   (map['lowStock']   as num?)?.toInt() ?? 0,
          outOfStock: (map['outOfStock'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (_) {
      return MockData.stockLevelData;
    }
  }

  Future<List<CategoryDistribution>> _fetchCategoryDistribution() async {
    try {
      final data = await _api.get(kAnalyticsCategoryDist) as dynamic;
      final list = _extractList(data, 'data');
      if (list.isEmpty) return MockData.categoryDistribution;

      return list.map((e) {
        final map = e as Map<String, dynamic>;
        return CategoryDistribution(
          id:         map['id'] as String? ?? map['category'] as String? ?? '',
          category:   map['category'] as String? ?? '',
          count:      (map['count'] as num?)?.toInt() ?? 0,
          percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
          value:      (map['value'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } catch (_) {
      return MockData.categoryDistribution;
    }
  }

  List<dynamic> _extractList(dynamic data, String key) {
    if (data is List) return data;
    if (data is Map) {
      return data[key] as List<dynamic>? ?? data['items'] as List<dynamic>? ?? [];
    }
    return [];
  }

  // ── Actions ───────────────────────────────

  Future<void> loadData(TimeRange range) async {
    final sales = await _fetchSalesTrend(range);
    _update((s) => s.copyWith(selectedTimeRange: range, salesData: sales));
  }

  Future<void> exportReport() async {
    _update((s) => s.copyWith(isExporting: true));
    try {
      await _api.post('/exports', {
        'format':    'PDF',
        'dateRange': {
          'from': DateTime.now()
              .subtract(Duration(
                  days: state.value?.selectedTimeRange.days ?? 7))
              .toIso8601String(),
          'to': DateTime.now().toIso8601String(),
        },
      });
    } catch (_) {}
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
