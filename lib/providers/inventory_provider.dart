import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/api_constants.dart';
import '../core/utils/extensions.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/persistence_service.dart';
import '../services/usage_tracking_service.dart';
import 'settings_provider.dart';

enum StockFilter {
  all('Todos'),
  inStock('En Stock'),
  lowStock('Stock Bajo'),
  outOfStock('Agotado');

  const StockFilter(this.label);
  final String label;
}

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
      totalProducts: 0,
      lowStockCount: 0,
      outOfStockCount: 0,
      totalStockValue: 0,
      totalSalesToday: 0,
      totalOrders: 0,
      expiringCount: 0,
      activeAlerts: 0,
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
      result = result.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.barcode.contains(q) ||
            p.category.label.toLowerCase().contains(q);
      }).toList();
    }

    switch (selectedFilter) {
      case StockFilter.inStock:
        result =
            result.where((p) => p.stockStatus == StockStatus.inStock).toList();
        break;
      case StockFilter.lowStock:
        result =
            result.where((p) => p.stockStatus == StockStatus.lowStock).toList();
        break;
      case StockFilter.outOfStock:
        result = result
            .where((p) => p.stockStatus == StockStatus.outOfStock)
            .toList();
        break;
      case StockFilter.all:
        break;
    }

    if (selectedCategory != null) {
      result = result.where((p) => p.category == selectedCategory).toList();
    }

    return result;
  }

  Map<StockFilter, int> get filterCounts => {
        StockFilter.all: products.length,
        StockFilter.inStock:
            products.where((p) => p.stockStatus == StockStatus.inStock).length,
        StockFilter.lowStock:
            products.where((p) => p.stockStatus == StockStatus.lowStock).length,
        StockFilter.outOfStock: products
            .where((p) => p.stockStatus == StockStatus.outOfStock)
            .length,
      };

  int get unreadAlertCount => alerts.where((a) => !a.isRead).length;

  double get totalStockValue =>
      products.fold<double>(0.0, (sum, p) => sum + p.stockValue);

  List<Product> get restockNeeded => products
    ..where((p) => p.quantity <= p.minStock && p.isActive).toList()
    ..sort((a, b) => a.quantity.compareTo(b.quantity));

  List<Product> get expiringProducts => products
    ..where((p) => p.isExpiringSoon).toList()
    ..sort((a, b) => (a.expirationDate ?? DateTime(9999))
        .compareTo(b.expirationDate ?? DateTime(9999)));

  InventoryState copyWith({
    List<Product>? products,
    List<InventoryAlert>? alerts,
    List<Order>? orders,
    List<Supplier>? suppliers,
    DashboardStats? dashboardStats,
    String? searchText,
    StockFilter? selectedFilter,
    ProductCategory? selectedCategory,
    bool clearCategory = false,
    Product? editingProduct,
    bool clearEditingProduct = false,
    bool? showingAddProduct,
    bool? productSaved,
    ScannedProductResult? scannedProduct,
    bool clearScannedProduct = false,
    bool? isScanning,
  }) {
    return InventoryState(
      products: products ?? this.products,
      alerts: alerts ?? this.alerts,
      orders: orders ?? this.orders,
      suppliers: suppliers ?? this.suppliers,
      dashboardStats: dashboardStats ?? this.dashboardStats,
      searchText: searchText ?? this.searchText,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      editingProduct:
          clearEditingProduct ? null : (editingProduct ?? this.editingProduct),
      showingAddProduct: showingAddProduct ?? this.showingAddProduct,
      productSaved: productSaved ?? this.productSaved,
      scannedProduct: clearScannedProduct
          ? null
          : (scannedProduct ?? this.scannedProduct),
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class InventoryNotifier extends AsyncNotifier<InventoryState> {
  final _api = ApiService.shared;
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

    final products = results[0] as List<Product>;
    final alerts = results[1] as List<InventoryAlert>;
    final dashboard = results[2] as DashboardStats?;
    final stats = dashboard ?? _buildStats(products, [], alerts);

    debugPrint(
      '[Inventory] Loaded — ${products.length} products, ${alerts.length} alerts, dashboard: ${dashboard != null ? "real" : "computed from products"}',
    );

    return InventoryState(
      products: products,
      alerts: alerts,
      dashboardStats: stats,
    );
  }

  Future<List<Product>> _fetchProducts() async {
    try {
      debugPrint('[Inventory] GET $kProducts');
      final data = await _api.get(kProducts) as dynamic;
      debugPrint('[Inventory] products raw type: ${data.runtimeType}');
      if (data is Map) {
        debugPrint('[Inventory] products keys: ${data.keys.toList()}');
      }
      final list = _extractList(data);
      final products = list
          .map((e) => Product.fromBackendJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[Inventory] Products from backend: ${products.length}');
      return products;
    } catch (e) {
      debugPrint('[Inventory] Fallback fetchProducts failed: $e');
      debugPrint(
        '[Inventory] Using MockData.products (${MockData.products.length} items)',
      );
      return MockData.products;
    }
  }

  Future<List<InventoryAlert>> _fetchAlerts() async {
    try {
      debugPrint('[Inventory] GET $kAlerts');
      final data = await _api.get(kAlerts) as dynamic;
      debugPrint('[Inventory] alerts raw type: ${data.runtimeType}');
      if (data is Map) {
        debugPrint('[Inventory] alerts keys: ${data.keys.toList()}');
      }
      final list = _extractList(data);
      final alerts = list
          .map((e) => InventoryAlert.fromBackendJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[Inventory] Alerts from backend: ${alerts.length}');
      return alerts;
    } catch (e) {
      debugPrint('[Inventory] Fallback fetchAlerts failed: $e');
      debugPrint(
        '[Inventory] Using MockData.alerts (${MockData.alerts.length} items)',
      );
      return MockData.alerts;
    }
  }

  Future<DashboardStats?> _fetchDashboard() async {
    try {
      debugPrint('[Inventory] GET $kAnalyticsDashboard');
      final data = await _api.get(kAnalyticsDashboard) as Map<String, dynamic>?;
      if (data == null) {
        debugPrint(
          '[Inventory] Dashboard returned null, will compute from products',
        );
        return null;
      }

      final stats = DashboardStats(
        totalProducts: (data['totalProducts'] as num?)?.toInt() ?? 0,
        lowStockCount: (data['lowStockCount'] as num?)?.toInt() ?? 0,
        outOfStockCount: (data['outOfStockCount'] as num?)?.toInt() ?? 0,
        totalStockValue: (data['totalStockValue'] as num?)?.toDouble() ?? 0,
        totalSalesToday: (data['totalSalesToday'] as num?)?.toDouble() ??
            (data['salesToday'] as num?)?.toDouble() ??
            0,
        totalOrders: (data['totalOrders'] as num?)?.toInt() ?? 0,
        expiringCount: (data['expiringCount'] as num?)?.toInt() ?? 0,
        activeAlerts: (data['activeAlerts'] as num?)?.toInt() ?? 0,
      );

      debugPrint('[Inventory] Dashboard stats from backend');
      return stats;
    } catch (e) {
      debugPrint('[Inventory] Fallback fetchDashboard failed: $e');
      debugPrint(
        '[Inventory] Dashboard will be computed locally from products',
      );
      return null;
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in [
        'data',
        'products',
        'alerts',
        'items',
        'results',
        'records',
      ]) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    return [];
  }

  void setSearchText(String value) {
    _update((s) => s.copyWith(searchText: value));
  }

  void setFilter(StockFilter filter) {
    _update((s) => s.copyWith(selectedFilter: filter));
  }

  void setCategory(ProductCategory? category) {
    _update((s) {
      return category == null
          ? s.copyWith(clearCategory: true)
          : s.copyWith(selectedCategory: category);
    });
  }

  Future<void> addProduct(Product product) async {
    try {
      final productToSend = product.storeId == null
          ? product.copyWith(storeId: _api.storeId)
          : product;

      final body = await _api.post(kProducts, productToSend.toBackendJson())
          as Map<String, dynamic>;

      final created = Product.fromBackendJson(
        body['product'] as Map<String, dynamic>? ?? body,
      );

      final s = state.value!;
      final updated = [...s.products, created];
      final newAlerts = _generateAlerts(created, s.alerts);

      _update((_) {
        return s.copyWith(
          products: updated,
          alerts: newAlerts,
          dashboardStats: _buildStats(updated, s.orders, newAlerts),
        );
      });

      await HapticManager.success();
    } catch (e) {
      debugPrint('[Inventory] addProduct API failed, applying locally: $e');
      final s = state.value!;
      final updated = [...s.products, product];

      _update((_) {
        return s.copyWith(
          products: updated,
          dashboardStats: _buildStats(updated, s.orders, s.alerts),
        );
      });
    }

    _logAudit(
      'Producto Agregado',
      'Product',
      product.id,
      product.name,
      'SKU: ${product.sku}',
    );

    if (_notificationsEnabled) {
      await _notif.showProductAdded(product.name);
    }
  }

  Future<void> updateProduct(Product product) async {
    final previous =
        state.value?.products.where((p) => p.id == product.id).firstOrNull;

    try {
      final productToSend = product.storeId == null
          ? product.copyWith(storeId: _api.storeId)
          : product;

      await _api.patch('$kProducts/${product.id}', productToSend.toBackendJson());
      debugPrint('[Inventory] updateProduct synced to backend');
    } catch (e) {
      debugPrint('[Inventory] updateProduct API failed, updating locally: $e');
    }

    final s = state.value!;
    final idx = s.products.indexWhere((p) => p.id == product.id);
    if (idx == -1) return;

    final updated = [...s.products]..[idx] = product;
    final newAlerts = _generateAlerts(product, s.alerts);

    _update((_) {
      return s.copyWith(
        products: updated,
        alerts: newAlerts,
        dashboardStats: _buildStats(updated, s.orders, newAlerts),
      );
    });

    _logAudit('Producto Actualizado', 'Product', product.id, product.name, '');

    if (previous != null && previous.quantity != product.quantity) {
      await UsageTrackingService.shared.init();
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

  String _describeChanges(Product before, Product after) {
    final parts = <String>[];

    if (before.quantity != after.quantity) {
      parts.add('Cantidad: ${before.quantity} -> ${after.quantity}');
    }
    if (before.salePrice != after.salePrice) {
      parts.add(
        'Precio: ${before.salePrice.toStringAsFixed(2)} -> ${after.salePrice.toStringAsFixed(2)}',
      );
    }
    if (before.costPrice != after.costPrice) {
      parts.add(
        'Costo: ${before.costPrice.toStringAsFixed(2)} -> ${after.costPrice.toStringAsFixed(2)}',
      );
    }
    if (before.minStock != after.minStock) {
      parts.add('Stock min: ${before.minStock} -> ${after.minStock}');
    }
    if (before.name != after.name) {
      parts.add('Nombre: "${before.name}" -> "${after.name}"');
    }

    return parts.join(' · ');
  }

  Future<void> deleteProduct(Product product) async {
    if (product.id.isEmpty) {
      debugPrint('[Inventory] deleteProduct aborted: product.id is empty');
      throw Exception(
        'El producto no tiene un ID valido y no puede eliminarse del servidor.',
      );
    }

    debugPrint('[Inventory] DELETE $kProducts/${product.id}');
    await _api.delete('$kProducts/${product.id}');
    debugPrint('[Inventory] deleteProduct synced to backend');

    final s = state.value!;
    final updated = s.products.where((p) => p.id != product.id).toList();

    _update((_) {
      return s.copyWith(
        products: updated,
        dashboardStats: _buildStats(updated, s.orders, s.alerts),
      );
    });

    await HapticManager.success();
    _logAudit('Producto Eliminado', 'Product', product.id, product.name, '');

    if (_notificationsEnabled) {
      await _notif.showProductDeleted(product.name);
    }
  }

  Future<void> recordSale(
    String productId,
    int quantity,
    double unitPrice,
  ) async {
    final s = state.value!;
    final idx = s.products.indexWhere((p) => p.id == productId);
    if (idx == -1) return;

    await _api.post(kSales, {
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
    });

    debugPrint('[Inventory] recordSale synced to backend via POST $kSales');

    final previousProduct = s.products[idx];
    final product = previousProduct.copyWith(
      quantity: (previousProduct.quantity - quantity).clamp(0, 999999),
      lastUpdated: DateTime.now(),
    );

    final updated = [...s.products]..[idx] = product;
    final newAlerts = _generateAlerts(product, s.alerts);

    _update((_) {
      return s.copyWith(
        products: updated,
        alerts: newAlerts,
        dashboardStats: _buildStats(updated, s.orders, newAlerts),
      );
    });

    await UsageTrackingService.shared.init();
    await UsageTrackingService.shared.trackAutoInventoryUpdate(
      productId: product.id,
      productName: product.name,
      source: 'sale',
      previousQuantity: previousProduct.quantity,
      newQuantity: product.quantity,
    );
  }

  Future<void> restockProduct(String productId, int quantity) async {
    try {
      await _api.post(kInventoryMovements, {
        'productId': productId,
        'type': 'RESTOCK',
        'quantity': quantity,
      });
      debugPrint('[Inventory] restockProduct synced to backend');
    } catch (e) {
      debugPrint('[Inventory] restockProduct API failed, updating locally: $e');
    }

    final s = state.value!;
    final idx = s.products.indexWhere((p) => p.id == productId);
    if (idx == -1) return;

    final previousProduct = s.products[idx];
    final product = previousProduct.copyWith(
      quantity: previousProduct.quantity + quantity,
      lastUpdated: DateTime.now(),
    );

    final updated = [...s.products]..[idx] = product;

    _update((_) {
      return s.copyWith(
        products: updated,
        dashboardStats: _buildStats(updated, s.orders, s.alerts),
      );
    });

    await UsageTrackingService.shared.init();
    await UsageTrackingService.shared.trackAutoInventoryUpdate(
      productId: product.id,
      productName: product.name,
      source: 'restock',
      previousQuantity: previousProduct.quantity,
      newQuantity: product.quantity,
    );

    await HapticManager.success();
    _logAudit(
      'Reabastecimiento',
      'Product',
      productId,
      product.name,
      'Cantidad: +$quantity',
    );

    if (_notificationsEnabled) {
      await _notif.showRestock(product.name, quantity);
    }
  }

  Future<void> markAlertAsRead(InventoryAlert alert) async {
    try {
      await _api.patch('$kAlerts/${alert.id}/read', {});
    } catch (_) {}

    final s = state.value!;
    final updated = s.alerts
        .map((a) => a.id == alert.id ? a.copyWith(isRead: true) : a)
        .toList();

    _update((_) => s.copyWith(alerts: updated));
  }

  Future<void> markAllAlertsAsRead() async {
    try {
      await _api.post('$kAlerts/mark-all-read', {});
    } catch (_) {}

    final s = state.value!;
    final updated = s.alerts.map((a) => a.copyWith(isRead: true)).toList();

    _update((_) => s.copyWith(alerts: updated));
  }

  Future<void> refreshData() async {
    debugPrint('[Inventory] Manual refresh triggered');
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadAll);
  }

  Product? findProductByBarcode(String barcode) {
    return state.value?.products.where((p) => p.barcode == barcode).firstOrNull;
  }

  List<Product> findDuplicates(String name, String barcode) {
    return state.value?.products.where((p) {
          return p.barcode == barcode ||
              p.name.toLowerCase().contains(name.toLowerCase());
        }).toList() ??
        [];
  }

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
    if (current != null) {
      state = AsyncData(fn(current));
    }
  }

  DashboardStats _buildStats(
    List<Product> products,
    List<Order> orders,
    List<InventoryAlert> alerts,
  ) {
    return DashboardStats(
      totalProducts: products.length,
      lowStockCount:
          products.where((p) => p.stockStatus == StockStatus.lowStock).length,
      outOfStockCount:
          products.where((p) => p.stockStatus == StockStatus.outOfStock).length,
      totalStockValue: products.fold<double>(0.0, (sum, p) => sum + p.stockValue),
      totalSalesToday: state.value?.dashboardStats.totalSalesToday ?? 0.0,
      totalOrders: orders.length,
      expiringCount: products.where((p) => p.isExpiringSoon).length,
      activeAlerts: alerts.where((a) => !a.isRead).length,
    );
  }

  List<InventoryAlert> _generateAlerts(
    Product product,
    List<InventoryAlert> current,
  ) {
    final alerts = List<InventoryAlert>.from(current);

    void addIfMissing(
      AlertType type,
      String title,
      String message,
      AlertPriority priority,
    ) {
      final exists = alerts.any(
        (a) => a.productId == product.id && a.type == type && !a.isRead,
      );

      if (!exists) {
        alerts.insert(
          0,
          InventoryAlert(
            id: _uuid.v4(),
            title: title,
            message: message,
            type: type,
            priority: priority,
            productId: product.id,
            productName: product.name,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    if (product.stockStatus == StockStatus.lowStock) {
      final isNew = !alerts.any(
        (a) =>
            a.productId == product.id &&
            a.type == AlertType.lowStock &&
            !a.isRead,
      );

      addIfMissing(
        AlertType.lowStock,
        'Stock Bajo',
        '${product.name} tiene solo ${product.quantity} uds (min: ${product.minStock})',
        AlertPriority.high,
      );

      if (isNew && _notificationsEnabled) {
        _notif.showInventoryAlert(
          title: 'Stock Bajo',
          body:
              '${product.name} tiene solo ${product.quantity} uds (min: ${product.minStock})',
          productId: product.id,
          kind: AlertKind.lowStock,
        );
      }
    }

    if (product.stockStatus == StockStatus.outOfStock) {
      final isNew = !alerts.any(
        (a) =>
            a.productId == product.id &&
            a.type == AlertType.outOfStock &&
            !a.isRead,
      );

      addIfMissing(
        AlertType.outOfStock,
        'Producto Agotado',
        '${product.name} se ha agotado completamente',
        AlertPriority.high,
      );

      if (isNew && _notificationsEnabled) {
        _notif.showInventoryAlert(
          title: 'Producto Agotado',
          body: '${product.name} se ha agotado completamente',
          productId: product.id,
          kind: AlertKind.outOfStock,
        );
      }
    }

    if (product.isExpiringSoon && product.expirationDate != null) {
      final daysLeft = product.expirationDate!.difference(DateTime.now()).inDays;

      final isNew = !alerts.any(
        (a) =>
            a.productId == product.id &&
            a.type == AlertType.expiringSoon &&
            !a.isRead,
      );

      addIfMissing(
        AlertType.expiringSoon,
        'Por Vencer',
        '${product.name} vence en $daysLeft dias',
        AlertPriority.medium,
      );

      if (isNew && _notificationsEnabled) {
        _notif.showInventoryAlert(
          title: 'Producto Por Vencer',
          body: '${product.name} vence en $daysLeft dias',
          productId: product.id,
          kind: AlertKind.expiringSoon,
        );
      }
    }

    return alerts;
  }

  void _logAudit(
    String action,
    String entityType,
    String entityId,
    String entityName,
    String details,
  ) {
    _persistence.logAuditEvent(
      AuditEvent.create(
        userId: 'current_user',
        userName: 'Usuario',
        action: action,
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        details: details,
      ),
    );
  }
}

final inventoryProvider =
    AsyncNotifierProvider<InventoryNotifier, InventoryState>(
  InventoryNotifier.new,
);