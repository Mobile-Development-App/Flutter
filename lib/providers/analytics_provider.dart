import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../core/utils/extensions.dart';

// ─────────────────────────────────────────────
// TimeRange  (mirrors TimeRange enum in Swift)
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
// State
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

  // ── Computed stats (mirrors Swift computed vars) ──

  double get totalSales =>
      salesData.fold<double>(0.0, (sum, p) => sum + p.sales);

  double get averageDailySales =>
      salesData.isEmpty ? 0 : totalSales / salesData.length;

  int get totalOrders =>
      salesData.fold(0, (sum, p) => sum + p.orders);

  /// % change: (secondHalf - firstHalf) / firstHalf * 100
  double get salesTrend {
    if (salesData.length < 2) return 0;
    final mid = salesData.length ~/ 2;
    final firstHalf =
        salesData.sublist(0, mid).fold<double>(0.0, (s, p) => s + p.sales);
    final secondHalf =
        salesData.sublist(mid).fold<double>(0.0, (s, p) => s + p.sales);
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
  }) {
    return AnalyticsState(
      selectedTimeRange: selectedTimeRange ?? this.selectedTimeRange,
      salesData: salesData ?? this.salesData,
      stockLevelData: stockLevelData ?? this.stockLevelData,
      categoryDistribution: categoryDistribution ?? this.categoryDistribution,
      isExporting: isExporting ?? this.isExporting,
      exportSuccess: exportSuccess ?? this.exportSuccess,
    );
  }
}

// ─────────────────────────────────────────────
// Notifier  (mirrors AnalyticsViewModel)
// ─────────────────────────────────────────────
class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  @override
  Future<AnalyticsState> build() async {
    return AnalyticsState(
      salesData: MockData.generateSalesData(days: TimeRange.week.days),
      stockLevelData: MockData.stockLevelData,
      categoryDistribution: MockData.categoryDistribution,
    );
  }

  /// Reload chart data for the selected time range
  void loadData(TimeRange range) {
    _update((s) => s.copyWith(
          selectedTimeRange: range,
          salesData: MockData.generateSalesData(days: range.days),
        ));
  }

  /// Simulate export (mirrors exportReport())
  Future<void> exportReport() async {
    _update((s) => s.copyWith(isExporting: true));
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    await HapticManager.success();
    _update((s) => s.copyWith(isExporting: false, exportSuccess: true));

    // Auto-reset success flag after 2s
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
