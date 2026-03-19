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

  // ── Computed ──────────────────────────────

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
        StockFilter.all:      products.length,
        StockFilter.inStock:  products.where((p) => p.stockStatus == StockStatus.inStock).length,
        StockFilter.lowStock: products.where((p) => p.stockStatus == StockStatus.lowStock).length,
        StockFilter.outOfStock: products.where((p) => p.stockStatus == StockStatus.outOfStock).length,
      };

  int get unreadAlertCount => alerts.where((a) => !a.isRead).length;

  double get totalStockValue =>
      products.fold<double>(0.0, (s, p) => s + p.stockValue);

  List<Product> get restockNeeded => products
      .where((p) => p.quantity <= p.minStock && p.isActive)
      .toList()
    ..sort((a, b) => a.quantity.compareTo(b.quantity));

  List<Product> get expiringProducts => products
      .where((p) => p.isExpiringSoon)
      .toList()
    ..sort((a, b) => (a.expirationDate ?? DateTime(9999))
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
// InventoryNotifier — connects to /products, /alerts
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
    try {
      // Load products and alerts in parallel
      final results = await Future.wait([
        _fetchProducts(),
        _fetchAlerts(),
      ]);

      final products = results[0] as List<Product>;
      final alerts   = results[1] as List<InventoryAlert>;
      final stats    = _buildStats(products, [], alerts);

      return InventoryState(
        products:       products,
        alerts:         alerts,
        dashboardStats: stats,
      );
    } catch (e) {
      // Fallback to MockData if API fails
      return InventoryState(
        products: MockData.products,
        alerts:   MockData.alerts,
        dashboardStats: MockData.dashboardStats,
      );
    }
  }

  // ── API Fetchers ──────────────────────────

  Future<List<Product>> _fetchProducts() async {
    try {
      final data = await _api.get(kProducts) as dynamic;
      final list = _extractList(data);
      return list.map((e) => Product.fromBackendJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return MockData.products;
    }
  }

  Future<List<InventoryAlert>> _fetchAlerts() async {
    try {
      final data = await _api.get(kAlerts) as dynamic;
      final list = _extractList(data);
      return list.map((e) => InventoryAlert.fromBackendJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return MockData.alerts;
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      return data['data'] as List<dynamic>? ??
             data['products'] as List<dynamic>? ??
             data['alerts'] as List<dynamic>? ??
             data['items'] as List<dynamic>? ?? [];
    }
    return [];
  }

  // ── Search & filter ───────────────────────

  void setSearchText(String v) =>
      _update((s) => s.copyWith(searchText: v));
  void setFilter(StockFilter f) =>
      _update((s) => s.copyWith(selectedFilter: f));
  void setCategory(ProductCategory? c) => _update((s) =>
      c == null ? s.copyWith(clearCategory: true) : s.copyWith(selectedCategory: c));

  // ── CRUD ──────────────────────────────────

  Future<void> addProduct(Product product) async {
    try {
      final body = await _api.post(kProducts, product.toBackendJson())
          as Map<String, dynamic>;
      final created = Product.fromBackendJson(body['product'] as Map<String, dynamic>? ?? body);
      final s = state.value!;
      final updated = [...s.products, created];
      final newAlerts = _generateAlerts(created, s.alerts);
      _update((_) => s.copyWith(
            products: updated,
            alerts: newAlerts,
            dashboardStats: _buildStats(updated, s.orders, newAlerts),
          ));
      await HapticManager.success();
    } catch (_) {
      // Optimistic local update if API fails
      final s = state.value!;
      final updated = [...s.products, product];
      _update((_) => s.copyWith(products: updated,
          dashboardStats: _buildStats(updated, s.orders, s.alerts)));
    }
    _logAudit('Producto Agregado', 'Product', product.id, product.name,
        'SKU: ${product.sku}');
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _api.patch('$kProducts/${product.id}', product.toBackendJson());
    } catch (_) {}
    final s = state.value!;
    final idx = s.products.indexWhere((p) => p.id == product.id);
    if (idx == -1) return;
    final updated = [...s.products]..[idx] = product;
    final newAlerts = _generateAlerts(product, s.alerts);
    _update((_) => s.copyWith(products: updated, alerts: newAlerts,
        dashboardStats: _buildStats(updated, s.orders, newAlerts)));
    _logAudit('Producto Actualizado', 'Product', product.id, product.name, '');
  }

  Future<void> deleteProduct(Product product) async {
    try { await _api.delete('$kProducts/${product.id}'); } catch (_) {}
    final s = state.value!;
    final updated = s.products.where((p) => p.id != product.id).toList();
    _update((_) => s.copyWith(products: updated,
        dashboardStats: _buildStats(updated, s.orders, s.alerts)));
    await HapticManager.success();
    _logAudit('Producto Eliminado', 'Product', product.id, product.name, '');
  }

  Future<void> recordSale(String productId, int quantity) async {
    try {
      await _api.post(kInventoryMovements, {
        'productId': productId,
        'type':      'SALE',
        'quantity':  quantity,
      });
    } catch (_) {}
    final s = state.value!;
    final idx = s.products.indexWhere((p) => p.id == productId);
    if (idx == -1) return;
    final product = s.products[idx].copyWith(
      quantity: (s.products[idx].quantity - quantity).clamp(0, 999999),
      lastUpdated: DateTime.now(),
    );
    final updated = [...s.products]..[idx] = product;
    final newAlerts = _generateAlerts(product, s.alerts);
    _update((_) => s.copyWith(products: updated, alerts: newAlerts,
        dashboardStats: _buildStats(updated, s.orders, newAlerts)));
  }

  Future<void> restockProduct(String productId, int quantity) async {
    try {
      await _api.post(kInventoryMovements, {
        'productId': productId,
        'type':      'RESTOCK',
        'quantity':  quantity,
      });
    } catch (_) {}
    final s = state.value!;
    final idx = s.products.indexWhere((p) => p.id == productId);
    if (idx == -1) return;
    final product = s.products[idx].copyWith(
      quantity: s.products[idx].quantity + quantity,
      lastUpdated: DateTime.now(),
    );
    final updated = [...s.products]..[idx] = product;
    _update((_) => s.copyWith(products: updated,
        dashboardStats: _buildStats(updated, s.orders, s.alerts)));
    await HapticManager.success();
    _logAudit('Reabastecimiento', 'Product', productId,
        product.name, 'Cantidad: +$quantity');
  }

  // ── Alerts ────────────────────────────────

  Future<void> markAlertAsRead(InventoryAlert alert) async {
    try { await _api.patch('$kAlerts/${alert.id}/read', {}); } catch (_) {}
    final s = state.value!;
    final updated = s.alerts.map((a) =>
        a.id == alert.id ? a.copyWith(isRead: true) : a).toList();
    _update((_) => s.copyWith(alerts: updated));
  }

  Future<void> markAllAlertsAsRead() async {
    try { await _api.post('$kAlerts/mark-all-read', {}); } catch (_) {}
    final s = state.value!;
    final updated = s.alerts.map((a) => a.copyWith(isRead: true)).toList();
    _update((_) => s.copyWith(alerts: updated));
  }

  Future<void> refreshData() async {
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

  DashboardStats _buildStats(List<Product> products, List<Order> orders,
      List<InventoryAlert> alerts) {
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
