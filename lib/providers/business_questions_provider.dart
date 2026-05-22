import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/bq_cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/usage_tracking_service.dart';
import '../storage/inventory_movements_fetcher.dart';
import 'inventory_provider.dart';

class BQ3ProductInsight {
  final String productId;
  final String productName;
  final int cycles;
  final double averageDays;
  final int minDays;
  final int maxDays;
  final DateTime? lastAlertAt;
  final DateTime? lastRestockAt;
  final bool hasPendingAlert;
  final int currentStock;
  final int minStock;

  const BQ3ProductInsight({
    required this.productId,
    required this.productName,
    required this.cycles,
    required this.averageDays,
    required this.minDays,
    required this.maxDays,
    required this.lastAlertAt,
    required this.lastRestockAt,
    required this.hasPendingAlert,
    required this.currentStock,
    required this.minStock,
  });
}

class BQ3Dashboard {
  final double averageDays;
  final int completedCycles;
  final int pendingAlerts;
  final int longestCycleDays;
  final int shortestCycleDays;
  final List<BQ3ProductInsight> products;

  const BQ3Dashboard({
    required this.averageDays,
    required this.completedCycles,
    required this.pendingAlerts,
    required this.longestCycleDays,
    required this.shortestCycleDays,
    required this.products,
  });
}

class BQ4ProductInsight {
  final String productId;
  final String productName;
  final int currentStock;
  final int daysToExpire;
  final int sellCount;
  final int removeCount;
  final String recommendedAction;
  final DateTime? expirationDate;

  const BQ4ProductInsight({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.daysToExpire,
    required this.sellCount,
    required this.removeCount,
    required this.recommendedAction,
    required this.expirationDate,
  });
}

class BQ4Dashboard {
  final int trackedProducts;
  final int saleActions;
  final int removeActions;
  final String topRecommendedAction;
  final List<BQ4ProductInsight> products;

  const BQ4Dashboard({
    required this.trackedProducts,
    required this.saleActions,
    required this.removeActions,
    required this.topRecommendedAction,
    required this.products,
  });
}

class BQ6Dashboard {
  final int correctedProducts;
  final int totalCorrections;
  final double averageAdjustment;
  final String topSource;
  final List<ManualCorrectionInsight> items;

  const BQ6Dashboard({
    required this.correctedProducts,
    required this.totalCorrections,
    required this.averageAdjustment,
    required this.topSource,
    required this.items,
  });
}

class BQ3Notifier extends AsyncNotifier<BQ3Dashboard> {
  @override
  Future<BQ3Dashboard> build() async => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<BQ3Dashboard> _load() async {
    final online = ConnectivityService.shared.isOnline;
    final cache = BQCacheService.shared;
    if (!online) {
      final cached = await cache.read('bq3_dashboard');
      final parsed = _fromCache(cached);
      if (parsed != null) return parsed;
    }

    final inv = ref.read(inventoryProvider).value;
    if (inv == null) {
      return const BQ3Dashboard(
        averageDays: 0,
        completedCycles: 0,
        pendingAlerts: 0,
        longestCycleDays: 0,
        shortestCycleDays: 0,
        products: [],
      );
    }

    try {
      final alerts = inv.alerts
          .where((a) => a.productId != null &&
              (a.type == AlertType.lowStock || a.type == AlertType.outOfStock))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final productIds = alerts.map((e) => e.productId!).toSet().toList();
      final movementLists = await Future.wait(productIds.map(_loadMovementsForProduct));
      final movementsByProduct = <String, List<InventoryMovement>>{
        for (var i = 0; i < productIds.length; i++) productIds[i]: movementLists[i],
      };

      final productsById = {for (final p in inv.products) p.id: p};
      final perProduct = <String, List<int>>{};
      final pendingByProduct = <String, bool>{};
      final lastAlertByProduct = <String, DateTime?>{};
      final lastRestockByProduct = <String, DateTime?>{};

      for (final alert in alerts) {
        final pid = alert.productId!;
        lastAlertByProduct[pid] = alert.createdAt;
        final restocks = (movementsByProduct[pid] ?? const [])
            .where((m) => m.type == InventoryMovementType.restock && !m.createdAt.isBefore(alert.createdAt))
            .toList();
        if (restocks.isEmpty) {
          pendingByProduct[pid] = true;
          continue;
        }
        final nextRestock = restocks.first;
        final delta = nextRestock.createdAt.difference(alert.createdAt).inDays;
        if (delta < 0) continue;
        perProduct.putIfAbsent(pid, () => []).add(delta);
        lastRestockByProduct[pid] = nextRestock.createdAt;
        pendingByProduct.putIfAbsent(pid, () => false);
      }

      final items = <BQ3ProductInsight>[];
      for (final pid in {...productIds, ...perProduct.keys}) {
        final product = productsById[pid];
        final values = perProduct[pid] ?? const <int>[];
        final avg = values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
        items.add(BQ3ProductInsight(
          productId: pid,
          productName: product?.name ?? alerts.firstWhere((a) => a.productId == pid, orElse: () => InventoryAlert(id: '', title: '', message: '', type: AlertType.lowStock, priority: AlertPriority.low, isRead: false, createdAt: DateTime.now())).productName ?? 'Producto',
          cycles: values.length,
          averageDays: avg.toDouble(),
          minDays: values.isEmpty ? 0 : values.reduce(math.min),
          maxDays: values.isEmpty ? 0 : values.reduce(math.max),
          lastAlertAt: lastAlertByProduct[pid],
          lastRestockAt: lastRestockByProduct[pid],
          hasPendingAlert: pendingByProduct[pid] ?? false,
          currentStock: product?.quantity ?? 0,
          minStock: product?.minStock ?? 0,
        ));
      }
      items.sort((a, b) => b.averageDays.compareTo(a.averageDays));

      final allCycles = perProduct.values.expand((e) => e).toList();
      final dashboard = BQ3Dashboard(
        averageDays: allCycles.isEmpty ? 0 : allCycles.reduce((a, b) => a + b) / allCycles.length,
        completedCycles: allCycles.length,
        pendingAlerts: pendingByProduct.values.where((e) => e).length,
        longestCycleDays: allCycles.isEmpty ? 0 : allCycles.reduce(math.max),
        shortestCycleDays: allCycles.isEmpty ? 0 : allCycles.reduce(math.min),
        products: items,
      );

      await cache.save('bq3_dashboard', _toCacheBQ3(dashboard));
      return dashboard;
    } catch (_) {
      final cached = await cache.read('bq3_dashboard');
      final parsed = _fromCache(cached);
      if (parsed != null) return parsed;
      return const BQ3Dashboard(
        averageDays: 0,
        completedCycles: 0,
        pendingAlerts: 0,
        longestCycleDays: 0,
        shortestCycleDays: 0,
        products: [],
      );
    }
  }

  Future<List<InventoryMovement>> _loadMovementsForProduct(String productId) =>
      InventoryMovementsFetcher.fetchForProduct(productId);

  Map<String, dynamic> _toCacheBQ3(BQ3Dashboard dashboard) => {
        'averageDays': dashboard.averageDays,
        'completedCycles': dashboard.completedCycles,
        'pendingAlerts': dashboard.pendingAlerts,
        'longestCycleDays': dashboard.longestCycleDays,
        'shortestCycleDays': dashboard.shortestCycleDays,
        'products': dashboard.products.map((p) => {
          'productId': p.productId,
          'productName': p.productName,
          'cycles': p.cycles,
          'averageDays': p.averageDays,
          'minDays': p.minDays,
          'maxDays': p.maxDays,
          'lastAlertAt': p.lastAlertAt?.toIso8601String(),
          'lastRestockAt': p.lastRestockAt?.toIso8601String(),
          'hasPendingAlert': p.hasPendingAlert,
          'currentStock': p.currentStock,
          'minStock': p.minStock,
        }).toList(),
      };

  BQ3Dashboard? _fromCache(Map<String, dynamic>? cached) {
    if (cached == null) return null;
    final products = (cached['products'] as List? ?? const []).whereType<Map>().map((e) => BQ3ProductInsight(
      productId: e['productId'] as String? ?? '',
      productName: e['productName'] as String? ?? 'Producto',
      cycles: e['cycles'] as int? ?? 0,
      averageDays: (e['averageDays'] as num?)?.toDouble() ?? 0,
      minDays: e['minDays'] as int? ?? 0,
      maxDays: e['maxDays'] as int? ?? 0,
      lastAlertAt: DateTime.tryParse(e['lastAlertAt'] as String? ?? ''),
      lastRestockAt: DateTime.tryParse(e['lastRestockAt'] as String? ?? ''),
      hasPendingAlert: e['hasPendingAlert'] as bool? ?? false,
      currentStock: e['currentStock'] as int? ?? 0,
      minStock: e['minStock'] as int? ?? 0,
    )).toList();
    return BQ3Dashboard(
      averageDays: (cached['averageDays'] as num?)?.toDouble() ?? 0,
      completedCycles: cached['completedCycles'] as int? ?? 0,
      pendingAlerts: cached['pendingAlerts'] as int? ?? 0,
      longestCycleDays: cached['longestCycleDays'] as int? ?? 0,
      shortestCycleDays: cached['shortestCycleDays'] as int? ?? 0,
      products: products,
    );
  }
}

final bq3Provider = AsyncNotifierProvider<BQ3Notifier, BQ3Dashboard>(BQ3Notifier.new);

class BQ4Notifier extends AsyncNotifier<BQ4Dashboard> {
  @override
  Future<BQ4Dashboard> build() async => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> saveAction({required Product product, required String action}) async {
    await UsageTrackingService.shared.trackExpiryPriorityAction(
      productId: product.id,
      productName: product.name,
      action: action,
    );
    await refresh();
  }

  Future<BQ4Dashboard> _load() async {
    await UsageTrackingService.shared.init();
    final online = ConnectivityService.shared.isOnline;
    final cache = BQCacheService.shared;
    if (!online) {
      final cached = await cache.read('bq4_dashboard');
      final parsed = _fromCache(cached);
      if (parsed != null) return parsed;
    }

    final inv = ref.read(inventoryProvider).value;
    final expiringProducts = inv?.expiringProducts ?? const <Product>[];
    final actions = await UsageTrackingService.shared.getExpiryPriorityInsights(limitDays: 30);
    final grouped = <String, Map<String, int>>{};
    for (final action in actions) {
      grouped.putIfAbsent(action.productId, () => {'sell': 0, 'remove': 0});
      grouped[action.productId]![action.action] = action.count;
    }

    final products = expiringProducts.map((p) {
      final actionCounts = grouped[p.id] ?? const {'sell': 0, 'remove': 0};
      final days = p.expirationDate == null ? 999 : p.expirationDate!.difference(DateTime.now()).inDays;
      final recommended = days <= 2 ? 'remove' : (p.quantity > p.minStock ? 'sell' : 'sell');
      return BQ4ProductInsight(
        productId: p.id,
        productName: p.name,
        currentStock: p.quantity,
        daysToExpire: days,
        sellCount: actionCounts['sell'] ?? 0,
        removeCount: actionCounts['remove'] ?? 0,
        recommendedAction: recommended,
        expirationDate: p.expirationDate,
      );
    }).toList()..sort((a, b) => a.daysToExpire.compareTo(b.daysToExpire));

    final saleActions = products.fold<int>(0, (s, p) => s + p.sellCount);
    final removeActions = products.fold<int>(0, (s, p) => s + p.removeCount);
    final dashboard = BQ4Dashboard(
      trackedProducts: products.length,
      saleActions: saleActions,
      removeActions: removeActions,
      topRecommendedAction: saleActions >= removeActions ? 'Venta prioritaria' : 'Eliminación prioritaria',
      products: products,
    );
    await cache.save('bq4_dashboard', _toCacheBQ4(dashboard));
    return dashboard;
  }

  Map<String, dynamic> _toCacheBQ4(BQ4Dashboard d) => {
        'trackedProducts': d.trackedProducts,
        'saleActions': d.saleActions,
        'removeActions': d.removeActions,
        'topRecommendedAction': d.topRecommendedAction,
        'products': d.products.map((p) => {
          'productId': p.productId,
          'productName': p.productName,
          'currentStock': p.currentStock,
          'daysToExpire': p.daysToExpire,
          'sellCount': p.sellCount,
          'removeCount': p.removeCount,
          'recommendedAction': p.recommendedAction,
          'expirationDate': p.expirationDate?.toIso8601String(),
        }).toList(),
      };

  BQ4Dashboard? _fromCache(Map<String, dynamic>? cached) {
    if (cached == null) return null;
    final products = (cached['products'] as List? ?? const []).whereType<Map>().map((e) => BQ4ProductInsight(
      productId: e['productId'] as String? ?? '',
      productName: e['productName'] as String? ?? 'Producto',
      currentStock: e['currentStock'] as int? ?? 0,
      daysToExpire: e['daysToExpire'] as int? ?? 0,
      sellCount: e['sellCount'] as int? ?? 0,
      removeCount: e['removeCount'] as int? ?? 0,
      recommendedAction: e['recommendedAction'] as String? ?? 'sell',
      expirationDate: DateTime.tryParse(e['expirationDate'] as String? ?? ''),
    )).toList();
    return BQ4Dashboard(
      trackedProducts: cached['trackedProducts'] as int? ?? 0,
      saleActions: cached['saleActions'] as int? ?? 0,
      removeActions: cached['removeActions'] as int? ?? 0,
      topRecommendedAction: cached['topRecommendedAction'] as String? ?? 'Venta prioritaria',
      products: products,
    );
  }
}

final bq4Provider = AsyncNotifierProvider<BQ4Notifier, BQ4Dashboard>(BQ4Notifier.new);

class BQ6Notifier extends AsyncNotifier<BQ6Dashboard> {
  @override
  Future<BQ6Dashboard> build() async => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<BQ6Dashboard> _load() async {
    await UsageTrackingService.shared.init();
    final online = ConnectivityService.shared.isOnline;
    final cache = BQCacheService.shared;
    if (!online) {
      final cached = await cache.read('bq6_dashboard');
      final parsed = _fromCache(cached);
      if (parsed != null) return parsed;
    }

    final items = await UsageTrackingService.shared.getManualCorrectionInsights(limitDays: 30);
    final totalCorrections = items.fold<int>(0, (s, e) => s + e.correctionCount);
    final totalAdjustmentMagnitude = items.fold<double>(0, (s, e) => s + e.averageAdjustment.abs());
    final saleBased = items.where((e) => e.lastAutoSource == 'sale').length;
    final restockBased = items.where((e) => e.lastAutoSource == 'restock').length;
    final dashboard = BQ6Dashboard(
      correctedProducts: items.length,
      totalCorrections: totalCorrections,
      averageAdjustment: items.isEmpty ? 0 : totalAdjustmentMagnitude / items.length,
      topSource: saleBased >= restockBased ? 'sale' : 'restock',
      items: items,
    );
    await cache.save('bq6_dashboard', {
      'correctedProducts': dashboard.correctedProducts,
      'totalCorrections': dashboard.totalCorrections,
      'averageAdjustment': dashboard.averageAdjustment,
      'topSource': dashboard.topSource,
      'items': dashboard.items.map((e) => {
        'productId': e.productId,
        'productName': e.productName,
        'correctionCount': e.correctionCount,
        'totalAdjustment': e.totalAdjustment,
        'averageAdjustment': e.averageAdjustment,
        'lastAutoSource': e.lastAutoSource,
        'lastCorrectionAt': e.lastCorrectionAt.toIso8601String(),
      }).toList(),
    });
    return dashboard;
  }

  BQ6Dashboard? _fromCache(Map<String, dynamic>? cached) {
    if (cached == null) return null;
    final items = (cached['items'] as List? ?? const []).whereType<Map>().map((e) => ManualCorrectionInsight(
      productId: e['productId'] as String? ?? '',
      productName: e['productName'] as String? ?? 'Producto',
      correctionCount: e['correctionCount'] as int? ?? 0,
      totalAdjustment: e['totalAdjustment'] as int? ?? 0,
      averageAdjustment: (e['averageAdjustment'] as num?)?.toDouble() ?? 0,
      lastAutoSource: e['lastAutoSource'] as String? ?? 'manual',
      lastCorrectionAt: DateTime.tryParse(e['lastCorrectionAt'] as String? ?? '') ?? DateTime.now(),
    )).toList();
    return BQ6Dashboard(
      correctedProducts: cached['correctedProducts'] as int? ?? 0,
      totalCorrections: cached['totalCorrections'] as int? ?? 0,
      averageAdjustment: (cached['averageAdjustment'] as num?)?.toDouble() ?? 0,
      topSource: cached['topSource'] as String? ?? 'manual',
      items: items,
    );
  }
}

final bq6Provider = AsyncNotifierProvider<BQ6Notifier, BQ6Dashboard>(BQ6Notifier.new);
