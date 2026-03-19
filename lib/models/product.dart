import 'package:flutter/material.dart';

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
        return const Color(0xFF2ECC71); // AppColors.success
      case lowStock:
        return const Color(0xFFF39C12); // AppColors.warning
      case outOfStock:
        return const Color(0xFFE74C3C); // AppColors.error
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

  /// Material icons as equivalents for SF Symbols
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
}

// ─────────────────────────────────────────────
// Product  (mirrors Product struct in Swift)
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
  });

  // ── Computed properties ──

  /// ((salePrice - costPrice) / costPrice) * 100
  double get profitMargin =>
      costPrice > 0 ? ((salePrice - costPrice) / costPrice) * 100 : 0;

  double get stockValue => salePrice * quantity;
  double get costValue => costPrice * quantity;

  StockStatus get stockStatus {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= minStock) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  /// Expires within 30 days but not yet expired
  bool get isExpiringSoon {
    if (expirationDate == null) return false;
    final remaining = expirationDate!.difference(DateTime.now());
    return remaining.inSeconds > 0 && remaining.inDays <= 30;
  }

  bool get isExpired {
    if (expirationDate == null) return false;
    return expirationDate!.isBefore(DateTime.now());
  }

  Product copyWith({
    String? id,
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
  }) {
    return Product(
      id: id ?? this.id,
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
    );
  }

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
      );

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
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
