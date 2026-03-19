// ─────────────────────────────────────────────
// Analytics Models  (mirrors AnalyticsData.swift)
// ─────────────────────────────────────────────

/// Single point on a sales timeline chart
class SalesDataPoint {
  final String id;
  final DateTime date;
  final double sales;
  final int orders;

  const SalesDataPoint({
    required this.id,
    required this.date,
    required this.sales,
    required this.orders,
  });

  factory SalesDataPoint.fromJson(Map<String, dynamic> json) => SalesDataPoint(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        sales: (json['sales'] as num).toDouble(),
        orders: json['orders'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'sales': sales,
        'orders': orders,
      };
}

/// Stock level breakdown per category (for stacked bar charts)
class StockLevelData {
  final String id;
  final String category;
  final int inStock;
  final int lowStock;
  final int outOfStock;

  const StockLevelData({
    required this.id,
    required this.category,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
  });

  int get total => inStock + lowStock + outOfStock;

  factory StockLevelData.fromJson(Map<String, dynamic> json) => StockLevelData(
        id: json['id'] as String,
        category: json['category'] as String,
        inStock: json['inStock'] as int,
        lowStock: json['lowStock'] as int,
        outOfStock: json['outOfStock'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'inStock': inStock,
        'lowStock': lowStock,
        'outOfStock': outOfStock,
      };
}

/// Pie/donut chart slice for category distribution
class CategoryDistribution {
  final String id;
  final String category;
  final int count;
  final double percentage;
  final double value;

  const CategoryDistribution({
    required this.id,
    required this.category,
    required this.count,
    required this.percentage,
    required this.value,
  });

  factory CategoryDistribution.fromJson(Map<String, dynamic> json) =>
      CategoryDistribution(
        id: json['id'] as String,
        category: json['category'] as String,
        count: json['count'] as int,
        percentage: (json['percentage'] as num).toDouble(),
        value: (json['value'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'count': count,
        'percentage': percentage,
        'value': value,
      };
}

/// KPI snapshot shown in the Home dashboard
class DashboardStats {
  final int totalProducts;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalStockValue;
  final double totalSalesToday;
  final int totalOrders;
  final int expiringCount;
  final int activeAlerts;

  const DashboardStats({
    required this.totalProducts,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalStockValue,
    required this.totalSalesToday,
    required this.totalOrders,
    required this.expiringCount,
    required this.activeAlerts,
  });

  /// Empty state / loading placeholder
  factory DashboardStats.empty() => const DashboardStats(
        totalProducts: 0,
        lowStockCount: 0,
        outOfStockCount: 0,
        totalStockValue: 0,
        totalSalesToday: 0,
        totalOrders: 0,
        expiringCount: 0,
        activeAlerts: 0,
      );

  DashboardStats copyWith({
    int? totalProducts,
    int? lowStockCount,
    int? outOfStockCount,
    double? totalStockValue,
    double? totalSalesToday,
    int? totalOrders,
    int? expiringCount,
    int? activeAlerts,
  }) {
    return DashboardStats(
      totalProducts: totalProducts ?? this.totalProducts,
      lowStockCount: lowStockCount ?? this.lowStockCount,
      outOfStockCount: outOfStockCount ?? this.outOfStockCount,
      totalStockValue: totalStockValue ?? this.totalStockValue,
      totalSalesToday: totalSalesToday ?? this.totalSalesToday,
      totalOrders: totalOrders ?? this.totalOrders,
      expiringCount: expiringCount ?? this.expiringCount,
      activeAlerts: activeAlerts ?? this.activeAlerts,
    );
  }

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        totalProducts: json['totalProducts'] as int,
        lowStockCount: json['lowStockCount'] as int,
        outOfStockCount: json['outOfStockCount'] as int,
        totalStockValue: (json['totalStockValue'] as num).toDouble(),
        totalSalesToday: (json['totalSalesToday'] as num).toDouble(),
        totalOrders: json['totalOrders'] as int,
        expiringCount: json['expiringCount'] as int,
        activeAlerts: json['activeAlerts'] as int,
      );

  Map<String, dynamic> toJson() => {
        'totalProducts': totalProducts,
        'lowStockCount': lowStockCount,
        'outOfStockCount': outOfStockCount,
        'totalStockValue': totalStockValue,
        'totalSalesToday': totalSalesToday,
        'totalOrders': totalOrders,
        'expiringCount': expiringCount,
        'activeAlerts': activeAlerts,
      };
}
