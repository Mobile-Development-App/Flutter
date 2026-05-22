import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/api_constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../services/persistence_service.dart';
import '../core/utils/extensions.dart';
import '../services/motion_vibration_service.dart';
import '../services/notification_service.dart';
import '../services/usage_tracking_service.dart'; // BQ6 — tracking de correcciones e inventario automático
import 'settings_provider.dart';

// ─────────────────────────────────────────────
// StockFilter
// ─────────────────────────────────────────────
enum StockFilter {
  all('Todos'),
  inStock('En Stock'),
  lowStock('Stock Bajo'),
  outOfStock('Agotado');

  const StockFilter(this.label);
  final String label;
}

// ─────────────────────────────────────────────
// ScannedProductResult
// ─────────────────────────────────────────────
class ScannedProductResult {
  final String name;
  final String brand;
  final ProductCategory category;
  final String barcode;
  final double suggestedPrice;
  final double confidence;
  final bool isDuplicate;
  final List<Product> similarProducts;

  const ScannedProductResult({
    required this.name,
    required this.brand,
    required this.category,
    required this.barcode,
    required this.suggestedPrice,
    required this.confidence,
    required this.isDuplicate,
    required this.similarProducts,
  });
}

// ─────────────────────────────────────────────
// InventoryState
// ─────────────────────────────────────────────
class InventoryState {
  final List<Product> products;
  final List<InventoryAlert> alerts;
  final List<Order> orders;
  final List<Supplier> suppliers;
  final DashboardStats dashboardStats;
  final String searchText;
  final StockFilter selectedFilter;
  final ProductCategory? selectedCategory;
  final Product? editingProduct;
  final bool showingAddProduct;
  final bool productSaved;
  final ScannedProductResult? scannedProduct;
  final bool isScanning;

  /// Número de operaciones pendientes en la cola offline.
  final int pendingOpsCount;

  /// Si el dispositivo está actualmente online.
  final bool isOnline;

  const InventoryState({
    this.products = const [],
    this.alerts = const [],
    this.orders = const [],
    this.suppliers = const [],
    this.dashboardStats = const DashboardStats(
      totalProducts: 0, lowStockCount: 0, outOfStockCount: 0,
      totalStockValue: 0, totalSalesToday: 0, totalOrders: 0,
      expiringCount: 0, activeAlerts: 0,
    ),
    this.searchText = '',
    this.selectedFilter = StockFilter.all,
    this.selectedCategory,
    this.editingProduct,
    this.showingAddProduct = false,
    this.productSaved = false,
    this.scannedProduct,
    this.isScanning = false,
    this.pendingOpsCount = 0,
    this.isOnline = true,
  });

  List<Product> get filteredProducts {
    var result = products;
    if (searchText.isNotEmpty) {
      final q = searchText.toLowerCase();
      result = result.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.barcode.contains(q) ||
          p.category.label.toLowerCase().contains(q)).toList();
    }
    switch (selectedFilter) {
      case StockFilter.inStock:
        result = result.where((p) => p.stockStatus == StockStatus.inStock).toList();
      case StockFilter.lowStock:
        result = result.where((p) => p.stockStatus == StockStatus.lowStock).toList();
      case StockFilter.outOfStock:
        result = result.where((p) => p.stockStatus == StockStatus.outOfStock).toList();
      case StockFilter.all:
        break;
    }
    if (selectedCategory != null) {
      result = result.where((p) => p.category == selectedCategory).toList();
    }
    return result;
  }

  Map<StockFilter, int> get filterCounts => {
        StockFilter.all:        products.length,
        StockFilter.inStock:    products.where((p) => p.stockStatus == StockStatus.inStock).length,
        StockFilter.lowStock:   products.where((p) => p.stockStatus == StockStatus.lowStock).length,
        StockFilter.outOfStock: products.where((p) => p.stockStatus == StockStatus.outOfStock).length,
      };

  int get unreadAlertCount => alerts.where((a) => !a.isRead).length;
  double get totalStockValue => products.fold<double>(0.0, (s, p) => s + p.stockValue);

  List<Product> get restockNeeded => products
      .where((p) => p.quantity <= p.minStock && p.isActive)
      .toList()
    ..sort((a, b) => a.quantity.compareTo(b.quantity));

  List<Product> get expiringProducts => products
      .where((p) => p.isExpiringSoon)
      .toList()
    ..sort((a, b) =>
        (a.expirationDate ?? DateTime(9999))
            .compareTo(b.expirationDate ?? DateTime(9999)));

  InventoryState copyWith({
    List<Product>? products, List<InventoryAlert>? alerts,
    List<Order>? orders, List<Supplier>? suppliers,
    DashboardStats? dashboardStats, String? searchText,
    StockFilter? selectedFilter, ProductCategory? selectedCategory,
    bool clearCategory = false, Product? editingProduct,
    bool clearEditingProduct = false, bool? showingAddProduct,
    bool? productSaved, ScannedProductResult? scannedProduct,
    bool clearScannedProduct = false, bool? isScanning,
    int? pendingOpsCount, bool? isOnline,
  }) =>
      InventoryState(
        products:       products       ?? this.products,
        alerts:         alerts         ?? this.alerts,
        orders:         orders         ?? this.orders,
        suppliers:      suppliers      ?? this.suppliers,
        dashboardStats: dashboardStats ?? this.dashboardStats,
        searchText:     searchText     ?? this.searchText,
        selectedFilter: selectedFilter ?? this.selectedFilter,
        selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
        editingProduct:   clearEditingProduct ? null : (editingProduct ?? this.editingProduct),
        showingAddProduct: showingAddProduct ?? this.showingAddProduct,
        productSaved:    productSaved ?? this.productSaved,
        scannedProduct:  clearScannedProduct ? null : (scannedProduct ?? this.scannedProduct),
        isScanning:      isScanning ?? this.isScanning,
        pendingOpsCount: pendingOpsCount ?? this.pendingOpsCount,
        isOnline:        isOnline ?? this.isOnline,
      );
}

// ─────────────────────────────────────────────
// InventoryNotifier
// ─────────────────────────────────────────────
class InventoryNotifier extends AsyncNotifier<InventoryState> {
  final _api          = ApiService.shared;
  final _persistence  = PersistenceService.shared;
  final _cache        = CacheService.shared;
  final _queue        = OfflineQueueService.shared;
  final _connectivity = ConnectivityService.shared;

  static const _uuid = Uuid();

  StreamSubscription<bool>? _connectivitySub;

  @override
  Future<InventoryState> build() async {
    // ── Suscribirse a cambios de conectividad ─────────────────────────────
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (isOnline) async {
        debugPrint('[Inventory] conectividad → isOnline=$isOnline');
        _update((s) => s.copyWith(isOnline: isOnline));
        if (isOnline) {
          await _drainOfflineQueue();
        }
      },
    );
    ref.onDispose(() => _connectivitySub?.cancel());

    return _loadAll();
  }

  Future<InventoryState> _loadAll() async {
    debugPrint('[Inventory] Loading all data...');

    final results = await Future.wait([
      _fetchProducts(),
      _fetchAlerts(),
      _fetchDashboard(),
    ]);

    final products  = results[0] as List<Product>;
    final alerts    = results[1] as List<InventoryAlert>;
    final dashboard = results[2] as DashboardStats?;
    final stats     = dashboard ?? _buildStats(products, [], alerts);

    debugPrint('[Inventory] Loaded — '
        '${products.length} products, '
        '${alerts.length} alerts');

    return InventoryState(
      products:        products,
      alerts:          alerts,
      dashboardStats:  stats,
      isOnline:        _connectivity.isOnline,
      pendingOpsCount: _queue.pendingCount,
    );
  }

  // ── API Fetchers con Cache-Aside ──────────────────────────────────────────

  Future<List<Product>> _fetchProducts() async {
    List<Product>? parseFromCache(dynamic raw) {
      if (raw is! List) return null;
      try {
        return raw
            .map((e) => Product.fromBackendJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return null;
      }
    }

    if (_connectivity.isOnline) {
      try {
        debugPrint('[Inventory] GET $kProducts');
        final data = await _api.get(kProducts) as dynamic;
        final list = _extractList(data);
        final products = list
            .map((e) => Product.fromBackendJson(e as Map<String, dynamic>))
            .toList();
        await _cache.put(CacheKeys.products, list);
        debugPrint('[Inventory] products from API (${products.length}) → cached');
        return products;
      } catch (e) {
        debugPrint('[Inventory] fetchProducts API failed: $e');
      }
    }

    final cached = parseFromCache(_cache.get(CacheKeys.products));
    if (cached != null) {
      debugPrint('[Inventory] products from cache (${cached.length})');
      return cached;
    }

    final stale = parseFromCache(_cache.get(CacheKeys.products, allowStale: true));
    if (stale != null) {
      debugPrint('[Inventory] products from STALE cache (${stale.length})');
      return stale;
    }

    debugPrint('[Inventory] fallback MockData.products');
    return MockData.products;
  }

  Future<List<InventoryAlert>> _fetchAlerts() async {
    List<InventoryAlert>? parseFromCache(dynamic raw) {
      if (raw is! List) return null;
      try {
        return raw
            .map((e) => InventoryAlert.fromBackendJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return null;
      }
    }

    if (_connectivity.isOnline) {
      try {
        debugPrint('[Inventory] GET $kAlerts');
        final data = await _api.get(kAlerts) as dynamic;
        final list = _extractList(data);
        final alerts = list
            .map((e) => InventoryAlert.fromBackendJson(e as Map<String, dynamic>))
            .toList();
        await _cache.put(CacheKeys.alerts, list);
        debugPrint('[Inventory] alerts from API (${alerts.length}) → cached');
        return alerts;
      } catch (e) {
        debugPrint('[Inventory] fetchAlerts API failed: $e');
      }
    }

    final cached = parseFromCache(_cache.get(CacheKeys.alerts));
    if (cached != null) {
      debugPrint('[Inventory] alerts from cache (${cached.length})');
      return cached;
    }

    final stale = parseFromCache(_cache.get(CacheKeys.alerts, allowStale: true));
    if (stale != null) {
      debugPrint('[Inventory] alerts from STALE cache (${stale.length})');
      return stale;
    }

    return MockData.alerts;
  }

  Future<DashboardStats?> _fetchDashboard() async {
    DashboardStats? parseFromCache(dynamic raw) {
      if (raw is! Map<String, dynamic>) return null;
      try {
        return _parseDashboardStats(raw);
      } catch (_) {
        return null;
      }
    }

    if (_connectivity.isOnline) {
      try {
        debugPrint('[Inventory] GET $kAnalyticsDashboard');
        final data = await _api.get(kAnalyticsDashboard) as Map<String, dynamic>?;
        if (data == null) return null;
        await _cache.put(CacheKeys.dashboard, data);
        debugPrint('[Inventory] dashboard from API → cached');
        return _parseDashboardStats(data);
      } catch (e) {
        debugPrint('[Inventory] fetchDashboard API failed: $e');
      }
    }

    final cached = parseFromCache(_cache.get(CacheKeys.dashboard));
    if (cached != null) {
      debugPrint('[Inventory] dashboard from cache');
      return cached;
    }

    final stale = parseFromCache(_cache.get(CacheKeys.dashboard, allowStale: true));
    if (stale != null) {
      debugPrint('[Inventory] dashboard from STALE cache');
      return stale;
    }

    return null;
  }

  DashboardStats _parseDashboardStats(Map<String, dynamic> data) {
    return DashboardStats(
      totalProducts:   (data['totalProducts']   as num?)?.toInt()    ?? 0,
      lowStockCount:   (data['lowStockCount']   as num?)?.toInt()    ?? 0,
      outOfStockCount: (data['outOfStockCount'] as num?)?.toInt()    ?? 0,
      totalStockValue: (data['totalStockValue'] as num?)?.toDouble() ?? 0,
      totalSalesToday: (data['totalSalesToday'] as num?)?.toDouble() ??
                       (data['salesToday']      as num?)?.toDouble() ?? 0,
      totalOrders:     (data['totalOrders']     as num?)?.toInt()    ?? 0,
      expiringCount:   (data['expiringCount']   as num?)?.toInt()    ?? 0,
      activeAlerts:    (data['activeAlerts']    as num?)?.toInt()    ?? 0,
    );
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['data', 'products', 'alerts', 'items', 'results', 'records']) {
        final val = data[key];
        if (val is List) return val;
      }
    }
    return [];
  }

  // ── Offline Queue ─────────────────────────────────────────────────────────

  Future<void> _enqueueOp(OfflineOpType type, Map<String, dynamic> payload) async {
    final op = OfflineQueueService.createOp(type: type, payload: payload);
    await _queue.enqueue(op);
    _update((s) => s.copyWith(pendingOpsCount: _queue.pendingCount));
  }

  Future<void> _drainOfflineQueue() async {
    if (_queue.pendingCount == 0) return;
    debugPrint('[Inventory] Reconectado — drenando cola (${_queue.pendingCount} ops)');

    final count = await _queue.drainQueue(_executeQueuedOp);

    if (count > 0) {
      await _cache.invalidateAll([
        CacheKeys.products, CacheKeys.alerts, CacheKeys.dashboard,
      ]);
      debugPrint('[Inventory] cola drenada — refrescando estado...');
      state = const AsyncLoading();
      state = await AsyncValue.guard(_loadAll);
    }

    _update((s) => s.copyWith(pendingOpsCount: _queue.pendingCount));
  }

  Future<void> _executeQueuedOp(OfflineOperation op) async {
    switch (op.type) {
      case OfflineOpType.addProduct:
        await _api.post(kProducts, op.payload);
      case OfflineOpType.updateProduct:
        final id = op.payload['id'] as String;
        await _api.patch('$kProducts/$id', op.payload);
      case OfflineOpType.deleteProduct:
        final id = op.payload['id'] as String;
        await _api.delete('$kProducts/$id');
      case OfflineOpType.recordSale:
        await _api.post(kSales, op.payload);
    }
  }

  // ── Search & filter ───────────────────────

  void setSearchText(String v) => _update((s) => s.copyWith(searchText: v));
  void setFilter(StockFilter f) => _update((s) => s.copyWith(selectedFilter: f));
  void setCategory(ProductCategory? c) => _update((s) =>
      c == null ? s.copyWith(clearCategory: true) : s.copyWith(selectedCategory: c));

  // ── CRUD con offline-first + optimistic updates ───────────────────────────

  Future<void> addProduct(Product product) async {
    final productToSend = product.storeId == null
        ? product.copyWith(storeId: _api.storeId)
        : product;

    if (!_connectivity.isOnline) {
      debugPrint('[Inventory] addProduct — OFFLINE, optimistic + encolando');
      await _enqueueOp(OfflineOpType.addProduct, productToSend.toBackendJson());
      final s         = state.value!;
      final updated   = [...s.products, product];
      final newAlerts = _generateAlerts(product, s.alerts);
      _update((_) => s.copyWith(
            products: updated, alerts: newAlerts,
            dashboardStats: _buildStats(updated, s.orders, newAlerts),
            pendingOpsCount: _queue.pendingCount));
    } else {
      try {
        final body = await _api.post(kProducts, productToSend.toBackendJson())
            as Map<String, dynamic>;
        final created = Product.fromBackendJson(
            body['product'] as Map<String, dynamic>? ?? body);
        final s         = state.value!;
        final updated   = [...s.products, created];
        final newAlerts = _generateAlerts(created, s.alerts);
        await _cache.invalidate(CacheKeys.products);
        _update((_) => s.copyWith(
              products: updated, alerts: newAlerts,
              dashboardStats: _buildStats(updated, s.orders, newAlerts)));
        await HapticManager.success();
      } catch (e) {
        debugPrint('[Inventory] addProduct API failed, encolando: $e');
        await _enqueueOp(OfflineOpType.addProduct, productToSend.toBackendJson());
        final s       = state.value!;
        final updated = [...s.products, product];
        _update((_) => s.copyWith(
            products: updated,
            dashboardStats: _buildStats(updated, s.orders, s.alerts),
            pendingOpsCount: _queue.pendingCount));
      }
    }

    _logAudit('Producto Agregado', 'Product', product.id, product.name,
        'SKU: ${product.sku}');
    if (_notificationsEnabled) {
      await _notif.showProductAdded(product.name);
    }
  }

  Future<void> updateProduct(Product product) async {
    final previous = state.value?.products
        .where((p) => p.id == product.id)
        .firstOrNull;

    final productToSend = product.storeId == null
        ? product.copyWith(storeId: _api.storeId)
        : product;

    // Optimistic update inmediato en estado local
    final s   = state.value!;
    final idx = s.products.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      final updated   = [...s.products]..[idx] = product;
      final newAlerts = _generateAlerts(product, s.alerts);
      _update((_) => s.copyWith(
          products: updated, alerts: newAlerts,
          dashboardStats: _buildStats(updated, s.orders, newAlerts)));
    }

    if (!_connectivity.isOnline) {
      debugPrint('[Inventory] updateProduct — OFFLINE, encolando');
      await _enqueueOp(OfflineOpType.updateProduct, productToSend.toBackendJson());
      _update((st) => st.copyWith(pendingOpsCount: _queue.pendingCount));
    } else {
      try {
        await _api.patch('$kProducts/${product.id}', productToSend.toBackendJson());
        await _cache.invalidate(CacheKeys.products);
        debugPrint('[Inventory] updateProduct synced');
      } catch (e) {
        debugPrint('[Inventory] updateProduct API failed, encolando: $e');
        await _enqueueOp(OfflineOpType.updateProduct, productToSend.toBackendJson());
        _update((st) => st.copyWith(pendingOpsCount: _queue.pendingCount));
      }
    }

    _logAudit('Producto Actualizado', 'Product', product.id, product.name, '');

    // BQ6 — registrar corrección manual si cambió el stock
    if (previous != null && previous.quantity != product.quantity) {
      await UsageTrackingService.shared.trackManualInventoryCorrection(
        productId: product.id,
        productName: product.name,
        previousQuantity: previous.quantity,
        newQuantity: product.quantity,
      );
    }

    if (_notificationsEnabled && previous != null) {
      final changes = _describeChanges(previous, product);
      if (changes.isNotEmpty) {
        await _notif.showProductUpdated(product.name, changes: changes);
      }
    }
  }

  Future<void> deleteProduct(Product product) async {
    if (product.id.isEmpty) {
      throw Exception('El producto no tiene un ID válido y no puede eliminarse del servidor.');
    }

    debugPrint('[Inventory] DELETE $kProducts/${product.id}');

    if (!_connectivity.isOnline) {
      debugPrint('[Inventory] deleteProduct — OFFLINE, optimistic delete + encolando');
      await _enqueueOp(OfflineOpType.deleteProduct, {'id': product.id});
      final s       = state.value!;
      final updated = s.products.where((p) => p.id != product.id).toList();
      _update((_) => s.copyWith(
          products: updated,
          dashboardStats: _buildStats(updated, s.orders, s.alerts),
          pendingOpsCount: _queue.pendingCount));
      await HapticManager.success();
    } else {
      try {
        await _api.delete('$kProducts/${product.id}');
        await _cache.invalidate(CacheKeys.products);
        debugPrint('[Inventory] deleteProduct synced');
        final s       = state.value!;
        final updated = s.products.where((p) => p.id != product.id).toList();
        _update((_) => s.copyWith(
            products: updated,
            dashboardStats: _buildStats(updated, s.orders, s.alerts)));
        await HapticManager.success();
      } catch (e) {
        debugPrint('[Inventory] deleteProduct API failed, encolando: $e');
        await _enqueueOp(OfflineOpType.deleteProduct, {'id': product.id});
        final s       = state.value!;
        final updated = s.products.where((p) => p.id != product.id).toList();
        _update((_) => s.copyWith(
            products: updated,
            dashboardStats: _buildStats(updated, s.orders, s.alerts),
            pendingOpsCount: _queue.pendingCount));
        await HapticManager.success();
      }
    }

    _logAudit('Producto Eliminado', 'Product', product.id, product.name, '');
    if (_notificationsEnabled) {
      await _notif.showProductDeleted(product.name);
    }
  }

  Future<void> recordSale(String productId, int quantity, double unitPrice) async {
    final s   = state.value!;
    final idx = s.products.indexWhere((p) => p.id == productId);
    if (idx == -1) return;

    // Optimistic: ajustar stock localmente de inmediato
    final product = s.products[idx].copyWith(
      quantity:    (s.products[idx].quantity - quantity).clamp(0, 999999),
      lastUpdated: DateTime.now(),
    );
    final updated   = [...s.products]..[idx] = product;
    final newAlerts = _generateAlerts(product, s.alerts);
    _update((_) => s.copyWith(
        products: updated, alerts: newAlerts,
        dashboardStats: _buildStats(updated, s.orders, newAlerts)));

    final payload = {
      'productId': productId,
      'quantity':  quantity,
      'unitPrice': unitPrice,
    };

    if (!_connectivity.isOnline) {
      debugPrint('[Inventory] recordSale — OFFLINE, encolando');
      await _enqueueOp(OfflineOpType.recordSale, payload);
      _update((st) => st.copyWith(pendingOpsCount: _queue.pendingCount));
    } else {
      try {
        await _api.post(kSales, payload);
        debugPrint('[Inventory] recordSale synced via POST $kSales');
      } catch (e) {
        debugPrint('[Inventory] recordSale API failed, encolando: $e');
        await _enqueueOp(OfflineOpType.recordSale, payload);
        _update((st) => st.copyWith(pendingOpsCount: _queue.pendingCount));
      }
    }

    // BQ6 — registrar actualización automática por venta
    await UsageTrackingService.shared.trackAutoInventoryUpdate(
      productId: product.id,
      productName: product.name,
      source: 'sale',
      previousQuantity: s.products[idx].quantity,
      newQuantity: product.quantity,
    );
  }

  Future<void> restockProduct(String productId, int quantity) async {
    try {
      await _api.post(kInventoryMovements, {
        'productId': productId, 'type': 'RESTOCK', 'quantity': quantity,
      });
      debugPrint('[Inventory] restockProduct synced');
    } catch (e) {
      debugPrint('[Inventory] restockProduct API failed, updating locally: $e');
    }
    final s   = state.value!;
    final idx = s.products.indexWhere((p) => p.id == productId);
    if (idx == -1) return;
    final product = s.products[idx].copyWith(
      quantity:    s.products[idx].quantity + quantity,
      lastUpdated: DateTime.now(),
    );
    final updated = [...s.products]..[idx] = product;
    _update((_) => s.copyWith(
        products: updated,
        dashboardStats: _buildStats(updated, s.orders, s.alerts)));

    // BQ6 — registrar actualización automática por reabastecimiento
    await UsageTrackingService.shared.trackAutoInventoryUpdate(
      productId: product.id,
      productName: product.name,
      source: 'restock',
      previousQuantity: s.products[idx].quantity,
      newQuantity: product.quantity,
    );

    await HapticManager.success();
    _logAudit('Reabastecimiento', 'Product', productId, product.name,
        'Cantidad: +$quantity');
    if (_notificationsEnabled) {
      await _notif.showRestock(product.name, quantity);
    }
  }

  // ── Alerts ────────────────────────────────

  Future<void> markAlertAsRead(InventoryAlert alert) async {
    try { await _api.patch('$kAlerts/${alert.id}/read', {}); } catch (_) {}
    final s       = state.value!;
    final updated = s.alerts
        .map((a) => a.id == alert.id ? a.copyWith(isRead: true) : a)
        .toList();
    _update((_) => s.copyWith(alerts: updated));
  }

  Future<void> markAllAlertsAsRead() async {
    try { await _api.post('$kAlerts/mark-all-read', {}); } catch (_) {}
    final s       = state.value!;
    final updated = s.alerts.map((a) => a.copyWith(isRead: true)).toList();
    _update((_) => s.copyWith(alerts: updated));
  }

  Future<void> refreshData() async {
    debugPrint('[Inventory] Manual refresh — invalidando caché...');
    await _cache.invalidateAll([
      CacheKeys.products, CacheKeys.alerts, CacheKeys.dashboard,
    ]);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadAll);
  }

  Product? findProductByBarcode(String barcode) =>
      state.value?.products.where((p) => p.barcode == barcode).firstOrNull;

  List<Product> findDuplicates(String name, String barcode) =>
      state.value?.products
          .where((p) =>
              p.barcode == barcode ||
              p.name.toLowerCase().contains(name.toLowerCase()))
          .toList() ?? [];

  // ── Private ───────────────────────────────

  bool get _notificationsEnabled {
    try {
      return ref.read(settingsProvider).value?.notificationsEnabled ?? true;
    } catch (_) {
      return false;
    }
  }

  NotificationService get _notif => NotificationService.shared;

  void _update(InventoryState Function(InventoryState) fn) {
    final current = state.value;
    if (current != null) state = AsyncData(fn(current));
  }

  DashboardStats _buildStats(
      List<Product> products, List<Order> orders, List<InventoryAlert> alerts) {
    return DashboardStats(
      totalProducts:   products.length,
      lowStockCount:   products.where((p) => p.stockStatus == StockStatus.lowStock).length,
      outOfStockCount: products.where((p) => p.stockStatus == StockStatus.outOfStock).length,
      totalStockValue: products.fold<double>(0.0, (s, p) => s + p.stockValue),
      totalSalesToday: state.value?.dashboardStats.totalSalesToday ?? 0.0,
      totalOrders:     orders.length,
      expiringCount:   products.where((p) => p.isExpiringSoon).length,
      activeAlerts:    alerts.where((a) => !a.isRead).length,
    );
  }

  String _describeChanges(Product before, Product after) {
    final parts = <String>[];
    if (before.quantity  != after.quantity)  parts.add('Cantidad: ${before.quantity} → ${after.quantity}');
    if (before.salePrice != after.salePrice) parts.add('Precio: ${before.salePrice.toStringAsFixed(2)} → ${after.salePrice.toStringAsFixed(2)}');
    if (before.costPrice != after.costPrice) parts.add('Costo: ${before.costPrice.toStringAsFixed(2)} → ${after.costPrice.toStringAsFixed(2)}');
    if (before.minStock  != after.minStock)  parts.add('Stock mín: ${before.minStock} → ${after.minStock}');
    if (before.name      != after.name)      parts.add('Nombre: "${before.name}" → "${after.name}"');
    return parts.join(' · ');
  }

  List<InventoryAlert> _generateAlerts(
      Product product, List<InventoryAlert> current) {
    final alerts = List<InventoryAlert>.from(current);

    void addIfMissing(AlertType type, String title, String message,
        AlertPriority priority) {
      final exists = alerts.any(
          (a) => a.productId == product.id && a.type == type && !a.isRead);
      if (!exists) {
        alerts.insert(0, InventoryAlert(
          id: _uuid.v4(), title: title, message: message,
          type: type, priority: priority,
          productId: product.id, productName: product.name,
          isRead: false, createdAt: DateTime.now(),
        ));
      }
    }

    if (product.stockStatus == StockStatus.lowStock) {
      final isNew = !alerts.any(
          (a) => a.productId == product.id && a.type == AlertType.lowStock && !a.isRead);
      addIfMissing(AlertType.lowStock, 'Stock Bajo',
          '${product.name} tiene solo ${product.quantity} uds (mín: ${product.minStock})',
          AlertPriority.high);
      if (isNew && _notificationsEnabled) {
        _notif.showInventoryAlert(
          title: '⚠️ Stock Bajo',
          body: '${product.name} tiene solo ${product.quantity} uds (mín: ${product.minStock})',
          productId: product.id, kind: AlertKind.lowStock,
        );
        MotionVibrationService.shared.vibrateOnAlert();
      }
    }

    if (product.stockStatus == StockStatus.outOfStock) {
      final isNew = !alerts.any(
          (a) => a.productId == product.id && a.type == AlertType.outOfStock && !a.isRead);
      addIfMissing(AlertType.outOfStock, 'Producto Agotado',
          '${product.name} se ha agotado completamente', AlertPriority.high);
      if (isNew && _notificationsEnabled) {
        _notif.showInventoryAlert(
          title: '🚫 Producto Agotado',
          body: '${product.name} se ha agotado completamente',
          productId: product.id, kind: AlertKind.outOfStock,
        );
        MotionVibrationService.shared.vibrateOnAlert();
      }
    }

    if (product.isExpiringSoon) {
      final daysLeft = product.expirationDate!.difference(DateTime.now()).inDays;
      final isNew = !alerts.any(
          (a) => a.productId == product.id && a.type == AlertType.expiringSoon && !a.isRead);
      addIfMissing(AlertType.expiringSoon, 'Por Vencer',
          '${product.name} vence en $daysLeft días', AlertPriority.medium);
      if (isNew && _notificationsEnabled) {
        _notif.showInventoryAlert(
          title: '⏰ Producto Por Vencer',
          body: '${product.name} vence en $daysLeft días',
          productId: product.id, kind: AlertKind.expiringSoon,
        );
        MotionVibrationService.shared.vibrateOnAlert();
      }
    }

    return alerts;
  }

  void _logAudit(String action, String entityType, String entityId,
      String entityName, String details) {
    _persistence.logAuditEvent(AuditEvent.create(
      userId: 'current_user', userName: 'Usuario',
      action: action, entityType: entityType,
      entityId: entityId, entityName: entityName, details: details,
    ));
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final inventoryProvider =
    AsyncNotifierProvider<InventoryNotifier, InventoryState>(
        InventoryNotifier.new);
