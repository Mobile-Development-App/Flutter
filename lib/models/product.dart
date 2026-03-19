import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────
// StockStatus
// ─────────────────────────────────────────────
enum StockStatus {
  inStock('En Stock'),
  lowStock('Stock Bajo'),
  outOfStock('Agotado');

  const StockStatus(this.label);
  final String label;

  Color get color {
    switch (this) {
      case inStock:
        return const Color(0xFF2ECC71);
      case lowStock:
        return const Color(0xFFF39C12);
      case outOfStock:
        return const Color(0xFFE74C3C);
    }
  }

  String get value => name;

  static StockStatus fromValue(String value) => StockStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => StockStatus.inStock,
      );
}

// ─────────────────────────────────────────────
// ProductCategory
// ─────────────────────────────────────────────
enum ProductCategory {
  beverages('Bebidas'),
  dairy('Lácteos'),
  snacks('Snacks'),
  cleaning('Limpieza'),
  personalCare('Cuidado Personal'),
  grains('Granos'),
  fruits('Frutas y Verduras'),
  meat('Carnes'),
  bakery('Panadería'),
  frozen('Congelados'),
  condiments('Condimentos'),
  other('Otros');

  const ProductCategory(this.label);
  final String label;

  IconData get icon {
    switch (this) {
      case beverages:
        return Icons.local_cafe_rounded;
      case dairy:
        return Icons.water_drop_rounded;
      case snacks:
        return Icons.cookie_rounded;
      case cleaning:
        return Icons.cleaning_services_rounded;
      case personalCare:
        return Icons.favorite_rounded;
      case grains:
        return Icons.grass_rounded;
      case fruits:
        return Icons.eco_rounded;
      case meat:
        return Icons.restaurant_rounded;
      case bakery:
        return Icons.bakery_dining_rounded;
      case frozen:
        return Icons.ac_unit_rounded;
      case condiments:
        return Icons.whatshot_rounded;
      case other:
        return Icons.inventory_2_rounded;
    }
  }

  String get value => name;

  static ProductCategory fromValue(String value) =>
      ProductCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ProductCategory.other,
      );

  // Map backend categoryId string to enum
  static ProductCategory fromCategoryId(String? id) {
    if (id == null) {
      return ProductCategory.other;
    }
    final lower = id.toLowerCase();
    if (lower.contains('bebida') || lower.contains('beverage')) {
      return ProductCategory.beverages;
    }
    if (lower.contains('lácteo') ||
        lower.contains('lacteo') ||
        lower.contains('dairy')) {
      return ProductCategory.dairy;
    }
    if (lower.contains('snack')) {
      return ProductCategory.snacks;
    }
    if (lower.contains('limpieza') || lower.contains('clean')) {
      return ProductCategory.cleaning;
    }
    if (lower.contains('personal') || lower.contains('cuidado')) {
      return ProductCategory.personalCare;
    }
    if (lower.contains('grano') || lower.contains('grain')) {
      return ProductCategory.grains;
    }
    if (lower.contains('fruta') || lower.contains('verdura')) {
      return ProductCategory.fruits;
    }
    if (lower.contains('carne') || lower.contains('meat')) {
      return ProductCategory.meat;
    }
    if (lower.contains('panadería') || lower.contains('bakery')) {
      return ProductCategory.bakery;
    }
    if (lower.contains('congelado') || lower.contains('frozen')) {
      return ProductCategory.frozen;
    }
    if (lower.contains('condimento') || lower.contains('condiment')) {
      return ProductCategory.condiments;
    }
    return ProductCategory.other;
  }
}

// ─────────────────────────────────────────────
// Product
// Backend field mapping:
//   currentStock  → quantity
//   sellingPrice  → salePrice
//   categoryId    → category (enum)
//   isDeleted     → isActive (inverted)
//   updatedAt     → lastUpdated
// ─────────────────────────────────────────────
class Product {
  final String id;
  final String name;
  final String sku;
  final String barcode;
  final ProductCategory category;
  final String supplier;
  final double costPrice;
  final double salePrice;
  final int quantity;
  final int minStock;
  final String location;
  final DateTime? expirationDate;
  final String? imageURL;
  final String description;
  final DateTime lastUpdated;
  final bool isActive;
  // Extra backend fields
  final String? storeId;
  final String? categoryId;
  final String? supplierId;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.category,
    required this.supplier,
    required this.costPrice,
    required this.salePrice,
    required this.quantity,
    required this.minStock,
    required this.location,
    this.expirationDate,
    this.imageURL,
    required this.description,
    required this.lastUpdated,
    required this.isActive,
    this.storeId,
    this.categoryId,
    this.supplierId,
  });

  // ── Computed ──

  double get profitMargin =>
      costPrice > 0 ? ((salePrice - costPrice) / costPrice) * 100 : 0;

  double get stockValue => salePrice * quantity;
  double get costValue => costPrice * quantity;

  StockStatus get stockStatus {
    if (quantity <= 0) {
      return StockStatus.outOfStock;
    }
    if (quantity <= minStock) {
      return StockStatus.lowStock;
    }
    return StockStatus.inStock;
  }

  bool get isExpiringSoon {
    if (expirationDate == null) {
      return false;
    }
    final remaining = expirationDate!.difference(DateTime.now());
    return remaining.inSeconds > 0 && remaining.inDays <= 30;
  }

  bool get isExpired {
    if (expirationDate == null) {
      return false;
    }
    return expirationDate!.isBefore(DateTime.now());
  }

  // ── From backend JSON ──
  factory Product.fromBackendJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        barcode: json['barcode'] as String? ?? '',
        category:
            ProductCategory.fromCategoryId(json['categoryId'] as String?),
        categoryId: json['categoryId'] as String?,
        supplierId: json['supplierId'] as String?,
        supplier: json['supplierId'] as String? ?? '',
        costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
        salePrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
        quantity: (json['currentStock'] as num?)?.toInt() ?? 0,
        minStock: (json['minStock'] as num?)?.toInt() ?? 0,
        location: json['location'] as String? ?? '',
        description: json['unit'] as String? ?? '',
        imageURL: json['imageUrl'] as String?,
        storeId: json['storeId'] as String?,
        lastUpdated: ApiService.parseDate(json['updatedAt']) ??
            ApiService.parseDate(json['createdAt']) ??
            DateTime.now(),
        isActive: !(json['isDeleted'] as bool? ?? false),
      );

  // ── Local JSON ──
  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        sku: json['sku'] as String,
        barcode: json['barcode'] as String,
        category: ProductCategory.fromValue(json['category'] as String),
        supplier: json['supplier'] as String,
        costPrice: (json['costPrice'] as num).toDouble(),
        salePrice: (json['salePrice'] as num).toDouble(),
        quantity: json['quantity'] as int,
        minStock: json['minStock'] as int,
        location: json['location'] as String,
        expirationDate: json['expirationDate'] != null
            ? DateTime.parse(json['expirationDate'] as String)
            : null,
        imageURL: json['imageURL'] as String?,
        description: json['description'] as String,
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
        isActive: json['isActive'] as bool? ?? true,
        storeId: json['storeId'] as String?,
      );

  // What to send TO backend when creating/updating
  Map<String, dynamic> toBackendJson() => {
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'categoryId': categoryId ?? category.value,
        'unit': description,
        'location': location,
        'costPrice': costPrice,
        'sellingPrice': salePrice,
        'currentStock': quantity,
        'minStock': minStock,
        if (supplierId != null) 'supplierId': supplierId,
        if (imageURL != null) 'imageUrl': imageURL,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'category': category.value,
        'supplier': supplier,
        'costPrice': costPrice,
        'salePrice': salePrice,
        'quantity': quantity,
        'minStock': minStock,
        'location': location,
        if (expirationDate != null)
          'expirationDate': expirationDate!.toIso8601String(),
        if (imageURL != null) 'imageURL': imageURL,
        'description': description,
        'lastUpdated': lastUpdated.toIso8601String(),
        'isActive': isActive,
        if (storeId != null) 'storeId': storeId,
      };

  Product copyWith({
    String? name,
    String? sku,
    String? barcode,
    ProductCategory? category,
    String? supplier,
    double? costPrice,
    double? salePrice,
    int? quantity,
    int? minStock,
    String? location,
    DateTime? expirationDate,
    String? imageURL,
    String? description,
    DateTime? lastUpdated,
    bool? isActive,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        category: category ?? this.category,
        supplier: supplier ?? this.supplier,
        costPrice: costPrice ?? this.costPrice,
        salePrice: salePrice ?? this.salePrice,
        quantity: quantity ?? this.quantity,
        minStock: minStock ?? this.minStock,
        location: location ?? this.location,
        expirationDate: expirationDate ?? this.expirationDate,
        imageURL: imageURL ?? this.imageURL,
        description: description ?? this.description,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        isActive: isActive ?? this.isActive,
        storeId: storeId,
        categoryId: categoryId,
        supplierId: supplierId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
