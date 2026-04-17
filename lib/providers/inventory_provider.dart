import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/api_constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/persistence_service.dart';
import '../core/utils/extensions.dart';

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
      );
}

// ─────────────────────────────────────────────
// InventoryNotifier
// ─────────────────────────────────────────────
class InventoryNotifier extends AsyncNotifier<InventoryState> {
  final _api         = ApiService.shared;
  final _persistence = PersistenceService.shared;
  static const _uuid = Uuid();

  @override
  Future<InventoryState> build() async {
    return _loadAll();
  }

  Future<InventoryState> _loadAll() async {
    debugPrint('[Inventory] Loading all data from backend...');

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
        '${alerts.length} alerts, '
        'dashboard: ${dashboard != null ? "real" : "computed from products"}');

    return InventoryState(
      products:       products,
      alerts:         alerts,
      dashboardStats: stats,
    );
  }

  // ── API Fetchers ──────────────────────────

  Future<List<Product>> _fetchProducts() async {
    try {
      debugPrint('[Inventory] GET $kProducts');
      final data = await _api.get(kProducts) as dynamic;
      debugPrint('[Inventory] products raw type: ${data.runtimeType}');
      if (data is Map) debugPrint('[Inventory] products keys: ${data.keys.toList()}');
      final list = _extractList(data);
      final products = list
          .map((e) => Product.fromBackendJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[Inventory] ✅ Products: ${products.length} items from backend');
      return products;
    } catch (e) {
      debugPrint('[Inventory] ⚠️  FALLBACK — fetchProducts failed: $e');
      debugPrint('[Inventory] ⚠️  Using MockData.products (${MockData.products.length} items)');
      return MockData.products;
    }
  }

  Future<List<InventoryAlert>> _fetchAlerts() async {
    try {
      debugPrint('[Inventory] GET $kAlerts');
      final data = await _api.get(kAlerts) as dynamic;
      debugPrint('[Inventory] alerts raw type: ${data.runtimeType}');
      if (data is Map) debugPrint('[Inventory] alerts keys: ${data.keys.toList()}');
      final list = _extractList(data);
      final alerts = list
          .map((e) => InventoryAlert.fromBackendJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[Inventory] ✅ Alerts: ${alerts.length} items from backend');
      return alerts;
    } catch (e) {
      debugPrint('[Inventory] ⚠️  FALLBACK — fetchAlerts failed: $e');
      debugPrint('[Inventory] ⚠️  Using MockData.alerts (${MockData.alerts.length} items)');
      return MockData.alerts;
    }
  }

  Future<DashboardStats?> _fetchDashboard() async {
    try {
      debugPrint('[Inventory] GET $kAnalyticsDashboard');
      final data = await _api.get(kAnalyticsDashboard) as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('[Inventory] ⚠️  FALLBACK — dashboard returned null, will compute from products');
        return null;
      }
      final stats = DashboardStats(
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
      debugPrint('[Inventory] ✅ Dashboard stats from backend');
      return stats;
    } catch (e) {
      debugPrint('[Inventory] ⚠️  FALLBACK — fetchDashboard failed: $e');
      debugPrint('[Inventory] ⚠️  Dashboard will be computed locally from products');
      return null;
    }
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

  // ── Search & filter ───────────────────────

  void setSearchText(String v) => _update((s) => s.copyWith(searchText: v));
  void setFilter(StockFilter f) => _update((s) => s.copyWith(selectedFilter: f));
  void setCategory(ProductCategory? c) => _update((s) =>
      c == null ? s.copyWith(clearCategory: true) : s.copyWith(selectedCategory: c));

  // ── CRUD ──────────────────────────────────

  Future<void> addProduct(Product product) async {
    try {
      // Some UI flows create a new Product without `storeId`.
      // Backend usually expects it to associate the record to the current store.
      final productToSend = product.storeId == null
          ? product.copyWith(storeId: _api.storeId)
          : product;

      final body =
          await _api.post(kProducts, productToSend.toBackendJson())
          as Map<String, dynamic>;
      final created = Product.fromBackendJson(
          body['product'] as Map<String, dynamic>? ?? body);
      final s = state.value!;
      final updated   = [...s.products, created];
      final newAlerts = _generateAlerts(created, s.alerts);
      _update((_) => s.copyWith(
            products: updated, alerts: newAlerts,
            dashboardStats: _buildStats(updated, s.orders, newAlerts)));
      await HapticManager.success();
    } catch (e) {
      debugPrint('[Inventory] ⚠️  addProduct API failed, applying locally: $e');
      final s = state.value!;
      final updated = [...s.products, product];
      _update((_) => s.copyWith(
          products: updated,
          dashboardStats: _buildStats(updated, s.orders, s.alerts)));
    }
    _logAudit('Producto Agregado', 'Product', product.id, product.name,
        'SKU: ${product.sku}');
  }

  Future<void> updateProduct(Product product) async {
    try {
      final productToSend = product.storeId == null
          ? product.copyWith(storeId: _api.storeId)
          : product;
      await _api.patch('$kProducts/${product.id}', productToSend.toBackendJson());
      debugPrint('[Inventory] ✅ updateProduct synced to backend');
    } catch (e) {
      debugPrint('[Inventory] ⚠️  updateProduct API failed, updating locally: $e');
    }
    final s = state.value!;
    final idx = s.products.indexWhere((p) => p.id == product.id);
    if (idx == -1) return;
    final updated   = [...s.products]..[idx] = product;
    final newAlerts = _generateAlerts(product, s.alerts);
    _update((_) => s.copyWith(
        products: updated, alerts: newAlerts,
        dashboardStats: _buildStats(updated, s.orders, newAlerts)));
    _logAudit('Producto Actualizado', 'Product', product.id, product.name, '');
  }

  Future<void> deleteProduct(Product product) async {
    // Guard: a product with an empty id cannot be deleted on the backend.
    if (product.id.isEmpty) {
      debugPrint('[Inventory] ❌ deleteProduct — product.id is empty, aborting');
      throw Exception('El producto no tiene un ID válido y no puede eliminarse del servidor.');
    }

    debugPrint('[Inventory] DELETE $kProducts/${product.id}');

    // Call the backend FIRST. If it fails, the exception propagates to the
    // caller so the UI can show an error and the local list stays intact.
    await _api.delete('$kProducts/${product.id}');

    debugPrint('[Inventory] ✅ deleteProduct synced to backend — removing from local state');

    // Only reach here when the backend confirmed the deletion.
    final s = state.value!;
    final updated = s.products.where((p) => p.id != product.id).toList();
    _update((_) => s.copyWith(
        products: updated,
        dashboardStats: _buildStats(updated, s.orders, s.alerts)));
    await HapticManager.success();
    _logAudit('Producto Eliminado', 'Product', product.id, product.name, '');
  }

  Future<void> recordSale(String productId, int quantity) async {
    try {
      await _api.post(kInventoryMovements, {
        'productId': productId, 'type': 'SALE', 'quantity': quantity,
      });
      debugPrint('[Inventory] ✅ recordSale synced to backend');
    } catch (e) {
      debugPrint('[Inventory] ⚠️  recordSale API failed, updating locally: $e');
    }
    final s   = state.value!;
    final idx = s.products.indexWhere((p) => p.id == productId);
    if (idx == -1) return;
    final product = s.products[idx].copyWith(
      quantity:    (s.products[idx].quantity - quantity).clamp(0, 999999),
      lastUpdated: DateTime.now(),
    );
    final updated   = [...s.products]..[idx] = product;
    final newAlerts = _generateAlerts(product, s.alerts);
    _update((_) => s.copyWith(
        products: updated, alerts: newAlerts,
        dashboardStats: _buildStats(updated, s.orders, newAlerts)));
  }

  Future<void> restockProduct(String productId, int quantity) async {
    try {
      await _api.post(kInventoryMovements, {
        'productId': productId, 'type': 'RESTOCK', 'quantity': quantity,
      });
      debugPrint('[Inventory] ✅ restockProduct synced to backend');
    } catch (e) {
      debugPrint('[Inventory] ⚠️  restockProduct API failed, updating locally: $e');
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
    await HapticManager.success();
    _logAudit('Reabastecimiento', 'Product', productId, product.name,
        'Cantidad: +$quantity');
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
    debugPrint('[Inventory] Manual refresh triggered');
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
      addIfMissing(AlertType.lowStock, 'Stock Bajo',
          '${product.name} tiene solo ${product.quantity} uds (mín: ${product.minStock})',
          AlertPriority.high);
    }
    if (product.stockStatus == StockStatus.outOfStock) {
      addIfMissing(AlertType.outOfStock, 'Producto Agotado',
          '${product.name} se ha agotado completamente', AlertPriority.high);
    }
    if (product.isExpiringSoon) {
      final daysLeft = product.expirationDate!.difference(DateTime.now()).inDays;
      addIfMissing(AlertType.expiringSoon, 'Por Vencer',
          '${product.name} vence en $daysLeft días', AlertPriority.medium);
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
