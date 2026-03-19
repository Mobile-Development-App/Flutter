import 'dart:math';
import 'package:uuid/uuid.dart';

import 'alert.dart';
import 'analytics_data.dart';
import 'employee.dart';
import 'order.dart';
import 'product.dart';
import 'store.dart';
import 'supplier.dart';
import 'user.dart';

// ─────────────────────────────────────────────
// MockData  (mirrors MockData.swift)
// Used only during development / preview.
// Replace with real repository calls in prod.
// ─────────────────────────────────────────────
abstract final class MockData {
  static const _uuid = Uuid();

  // ── helper ──
  static DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      DateTime.now().subtract(
          Duration(days: days, hours: hours, minutes: minutes));


  static DateTime _in({int days = 0, int hours = 0, int months = 0}) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month + months,
      now.day + days,
      now.hour + hours,
    );
  }

  // ── Suppliers ──────────────────────────────
  static final List<Supplier> suppliers = [
    Supplier(
      id: _uuid.v4(),
      name: 'Distribuidora Natural',
      contactName: 'María García',
      email: 'maria@distnatural.com',
      phone: '+57 301 234 5678',
      address: 'Cra 15 #45-67, Bogotá',
      category: 'Bebidas',
      isActive: true,
    ),
    Supplier(
      id: _uuid.v4(),
      name: 'Café del Valle',
      contactName: 'Carlos Pérez',
      email: 'carlos@cafevalle.com',
      phone: '+57 302 345 6789',
      address: 'Cll 10 #23-45, Armenia',
      category: 'Bebidas',
      isActive: true,
    ),
    Supplier(
      id: _uuid.v4(),
      name: 'Lácteos Alpina',
      contactName: 'Ana Rodríguez',
      email: 'ana@alpina.com',
      phone: '+57 303 456 7890',
      address: 'Km 5 Vía Sopó, Cundinamarca',
      category: 'Lácteos',
      isActive: true,
    ),
    Supplier(
      id: _uuid.v4(),
      name: 'Frito Lay Colombia',
      contactName: 'Juan Martínez',
      email: 'juan@fritolay.com',
      phone: '+57 304 567 8901',
      address: 'Zona Industrial, Funza',
      category: 'Snacks',
      isActive: true,
    ),
    Supplier(
      id: _uuid.v4(),
      name: 'P&G Colombia',
      contactName: 'Laura López',
      email: 'laura@pg.com',
      phone: '+57 305 678 9012',
      address: 'Cra 7 #32-16, Medellín',
      category: 'Limpieza',
      isActive: true,
    ),
  ];

  // ── Stores ──────────────────────────────────
  static final List<Store> stores = [
    Store(
      id: _uuid.v4(),
      name: 'Tienda Principal',
      address: 'Cra 15 #85-20, Bogotá',
      phone: '+57 301 123 4567',
      email: 'principal@inventaria.com',
      manager: 'Sarah Johnson',
      employeeCount: 5,
      productCount: 156,
      monthlySales: 12500000,
      isActive: true,
      createdAt: _ago(days: 180),
    ),
    Store(
      id: _uuid.v4(),
      name: 'Sucursal Norte',
      address: 'Cll 170 #45-10, Bogotá',
      phone: '+57 302 234 5678',
      email: 'norte@inventaria.com',
      manager: 'Carlos Rivera',
      employeeCount: 3,
      productCount: 98,
      monthlySales: 8200000,
      isActive: true,
      createdAt: _ago(days: 60),
    ),
  ];

  // ── Products ────────────────────────────────
  static final List<Product> products = [
    Product(
      id: _uuid.v4(),
      name: 'Té Verde Orgánico',
      sku: 'BEV-001',
      barcode: '7701234567890',
      category: ProductCategory.beverages,
      supplier: 'Distribuidora Natural',
      costPrice: 8500,
      salePrice: 12000,
      quantity: 45,
      minStock: 10,
      location: 'Pasillo 3, Estante A',
      expirationDate: _in(days: 60),
      description: 'Té verde orgánico premium, presentación 100g',
      lastUpdated: DateTime.now(),
      isActive: true,
    ),
    Product(
      id: _uuid.v4(),
      name: 'Granos de Café Premium',
      sku: 'BEV-002',
      barcode: '7701234567891',
      category: ProductCategory.beverages,
      supplier: 'Café del Valle',
      costPrice: 25000,
      salePrice: 38000,
      quantity: 8,
      minStock: 15,
      location: 'Pasillo 3, Estante B',
      expirationDate: _in(days: 90),
      description: 'Café en grano de origen colombiano, tostado medio',
      lastUpdated: _ago(hours: 3),
      isActive: true,
    ),
    Product(
      id: _uuid.v4(),
      name: 'Leche Entera',
      sku: 'DAI-001',
      barcode: '7701234567892',
      category: ProductCategory.dairy,
      supplier: 'Lácteos Alpina',
      costPrice: 3200,
      salePrice: 4800,
      quantity: 120,
      minStock: 30,
      location: 'Refrigerador 1',
      expirationDate: _in(days: 15),
      description: 'Leche entera pasteurizada, 1 litro',
      lastUpdated: DateTime.now(),
      isActive: true,
    ),
    Product(
      id: _uuid.v4(),
      name: 'Papas Fritas Clásicas',
      sku: 'SNK-001',
      barcode: '7701234567893',
      category: ProductCategory.snacks,
      supplier: 'Frito Lay Colombia',
      costPrice: 2800,
      salePrice: 4500,
      quantity: 0,
      minStock: 20,
      location: 'Pasillo 1, Estante C',
      expirationDate: _in(days: 120),
      description: 'Papas fritas sabor natural, 150g',
      lastUpdated: _ago(days: 1),
      isActive: true,
    ),
    Product(
      id: _uuid.v4(),
      name: 'Detergente Líquido',
      sku: 'CLN-001',
      barcode: '7701234567894',
      category: ProductCategory.cleaning,
      supplier: 'P&G Colombia',
      costPrice: 15000,
      salePrice: 22000,
      quantity: 35,
      minStock: 10,
      location: 'Pasillo 5, Estante A',
      description: 'Detergente líquido multiusos, 2 litros',
      lastUpdated: _ago(hours: 12),
      isActive: true,
    ),
    Product(
      id: _uuid.v4(),
      name: 'Arroz Blanco Diana',
      sku: 'GRN-001',
      barcode: '7701234567895',
      category: ProductCategory.grains,
      supplier: 'Diana Corporación',
      costPrice: 4200,
      salePrice: 6500,
      quantity: 5,
      minStock: 25,
      location: 'Pasillo 2, Estante B',
      expirationDate: _in(months: 6),
      description: 'Arroz blanco premium, 1kg',
      lastUpdated: _ago(days: 2),
      isActive: true,
    ),
    Product(
      id: _uuid.v4(),
      name: 'Yogurt Natural',
      sku: 'DAI-002',
      barcode: '7701234567896',
      category: ProductCategory.dairy,
      supplier: 'Lácteos Alpina',
      costPrice: 4500,
      salePrice: 7200,
      quantity: 18,
      minStock: 20,
      location: 'Refrigerador 2',
      expirationDate: _in(days: 10),
      description: 'Yogurt natural sin azúcar, 500ml',
      lastUpdated: DateTime.now(),
      isActive: true,
    ),
    Product(
      id: _uuid.v4(),
      name: 'Jabón en Barra',
      sku: 'PER-001',
      barcode: '7701234567897',
      category: ProductCategory.personalCare,
      supplier: 'Unilever Colombia',
      costPrice: 3500,
      salePrice: 5500,
      quantity: 60,
      minStock: 15,
      location: 'Pasillo 4, Estante C',
      description: 'Jabón en barra hidratante, 120g',
      lastUpdated: _ago(days: 5),
      isActive: true,
    ),
  ];

  // ── Employees ───────────────────────────────
  static final List<Employee> employees = [
    Employee(
      id: _uuid.v4(),
      fullName: 'María García',
      email: 'maria@inventaria.com',
      phone: '+57 300 111 2222',
      role: UserRole.manager,
      storeId: stores[0].id,
      storeName: 'Tienda Principal',
      joinDate: _ago(days: 150),
      isActive: true,
    ),
    Employee(
      id: _uuid.v4(),
      fullName: 'Carlos Pérez',
      email: 'carlos@inventaria.com',
      phone: '+57 300 333 4444',
      role: UserRole.employee,
      storeId: stores[0].id,
      storeName: 'Tienda Principal',
      joinDate: _ago(days: 90),
      isActive: true,
    ),
    Employee(
      id: _uuid.v4(),
      fullName: 'Ana Rodríguez',
      email: 'ana@inventaria.com',
      phone: '+57 300 555 6666',
      role: UserRole.employee,
      storeId: stores[1].id,
      storeName: 'Sucursal Norte',
      joinDate: _ago(days: 30),
      isActive: true,
    ),
  ];

  // ── Alerts ──────────────────────────────────
  static final List<InventoryAlert> alerts = [
    InventoryAlert(
      id: _uuid.v4(),
      title: 'Stock Bajo',
      message:
          'Granos de Café Premium tiene solo 8 unidades (mínimo: 15)',
      type: AlertType.lowStock,
      priority: AlertPriority.high,
      productId: products[1].id,
      productName: 'Granos de Café Premium',
      isRead: false,
      createdAt: _ago(minutes: 30),
    ),
    InventoryAlert(
      id: _uuid.v4(),
      title: 'Producto Agotado',
      message: 'Papas Fritas Clásicas se ha agotado completamente',
      type: AlertType.outOfStock,
      priority: AlertPriority.high,
      productId: products[3].id,
      productName: 'Papas Fritas Clásicas',
      isRead: false,
      createdAt: _ago(hours: 2),
    ),
    InventoryAlert(
      id: _uuid.v4(),
      title: 'Por Vencer',
      message: 'Yogurt Natural vence en 10 días',
      type: AlertType.expiringSoon,
      priority: AlertPriority.medium,
      productId: products[6].id,
      productName: 'Yogurt Natural',
      isRead: false,
      createdAt: _ago(hours: 5),
    ),
    InventoryAlert(
      id: _uuid.v4(),
      title: 'Stock Bajo',
      message:
          'Arroz Blanco Diana tiene solo 5 unidades (mínimo: 25)',
      type: AlertType.lowStock,
      priority: AlertPriority.high,
      productId: products[5].id,
      productName: 'Arroz Blanco Diana',
      isRead: true,
      createdAt: _ago(days: 1),
    ),
    InventoryAlert(
      id: _uuid.v4(),
      title: 'Reabastecimiento',
      message:
          'Pedido #ORD-001 de Lácteos Alpina ha sido confirmado',
      type: AlertType.restock,
      priority: AlertPriority.low,
      isRead: true,
      createdAt: _ago(days: 2),
    ),
  ];

  // ── Orders ──────────────────────────────────
  static final List<Order> orders = [
    Order(
      id: _uuid.v4(),
      orderNumber: 'ORD-001',
      supplier: 'Lácteos Alpina',
      status: OrderStatus.confirmed,
      totalAmount: 450000,
      itemCount: 50,
      createdAt: _ago(days: 1),
      expectedDelivery: _in(days: 2),
    ),
    Order(
      id: _uuid.v4(),
      orderNumber: 'ORD-002',
      supplier: 'Frito Lay Colombia',
      status: OrderStatus.pending,
      totalAmount: 280000,
      itemCount: 100,
      createdAt: DateTime.now(),
      expectedDelivery: _in(days: 5),
    ),
    Order(
      id: _uuid.v4(),
      orderNumber: 'ORD-003',
      supplier: 'Distribuidora Natural',
      status: OrderStatus.delivered,
      totalAmount: 170000,
      itemCount: 20,
      createdAt: _ago(days: 5),
      expectedDelivery: _ago(days: 3),
    ),
    Order(
      id: _uuid.v4(),
      orderNumber: 'ORD-004',
      supplier: 'Diana Corporación',
      status: OrderStatus.shipped,
      totalAmount: 520000,
      itemCount: 80,
      createdAt: _ago(days: 2),
      expectedDelivery: _in(days: 1),
    ),
  ];

  // ── Current User ────────────────────────────
  static final User currentUser = User(
    id: _uuid.v4(),
    fullName: 'Sarah Johnson',
    email: 'sarah@inventaria.com',
    phone: '+57 301 123 4567',
    role: UserRole.owner,
    storeName: 'Tienda Principal',
    storeId: stores[0].id,
    joinDate: _ago(days: 180),
    isActive: true,
  );

  // ── Dashboard Stats ──────────────────────────
  static const DashboardStats dashboardStats = DashboardStats(
    totalProducts: 156,
    lowStockCount: 12,
    outOfStockCount: 3,
    totalStockValue: 8450000,
    totalSalesToday: 1250000,
    totalOrders: 4,
    expiringCount: 5,
    activeAlerts: 3,
  );

  // ── Sales Chart Data ─────────────────────────
  static List<SalesDataPoint> generateSalesData({int days = 7}) {
    final rng = Random();
    return List.generate(days, (i) {
      final date = DateTime.now().subtract(Duration(days: days - 1 - i));
      return SalesDataPoint(
        id: _uuid.v4(),
        date: date,
        sales: 800000 + rng.nextDouble() * 1200000,
        orders: 15 + rng.nextInt(31),
      );
    });
  }

  // ── Stock Level Chart Data ────────────────────
  static final List<StockLevelData> stockLevelData = [
    StockLevelData(
        id: _uuid.v4(),
        category: 'Bebidas',
        inStock: 25,
        lowStock: 3,
        outOfStock: 1),
    StockLevelData(
        id: _uuid.v4(),
        category: 'Lácteos',
        inStock: 18,
        lowStock: 4,
        outOfStock: 0),
    StockLevelData(
        id: _uuid.v4(),
        category: 'Snacks',
        inStock: 30,
        lowStock: 2,
        outOfStock: 2),
    StockLevelData(
        id: _uuid.v4(),
        category: 'Limpieza',
        inStock: 15,
        lowStock: 1,
        outOfStock: 0),
    StockLevelData(
        id: _uuid.v4(),
        category: 'Granos',
        inStock: 12,
        lowStock: 5,
        outOfStock: 1),
  ];

  // ── Category Distribution ─────────────────────
  static final List<CategoryDistribution> categoryDistribution = [
    CategoryDistribution(
        id: _uuid.v4(),
        category: 'Bebidas',
        count: 29,
        percentage: 18.6,
        value: 1200000),
    CategoryDistribution(
        id: _uuid.v4(),
        category: 'Lácteos',
        count: 22,
        percentage: 14.1,
        value: 980000),
    CategoryDistribution(
        id: _uuid.v4(),
        category: 'Snacks',
        count: 34,
        percentage: 21.8,
        value: 1500000),
    CategoryDistribution(
        id: _uuid.v4(),
        category: 'Limpieza',
        count: 16,
        percentage: 10.3,
        value: 750000),
    CategoryDistribution(
        id: _uuid.v4(),
        category: 'Granos',
        count: 18,
        percentage: 11.5,
        value: 820000),
    CategoryDistribution(
        id: _uuid.v4(),
        category: 'Cuidado Personal',
        count: 20,
        percentage: 12.8,
        value: 900000),
    CategoryDistribution(
        id: _uuid.v4(),
        category: 'Otros',
        count: 17,
        percentage: 10.9,
        value: 650000),
  ];
}
