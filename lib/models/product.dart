import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum StockStatus {
  inStock('En Stock'),
  lowStock('Stock Bajo'),
  outOfStock('Agotado');

  const StockStatus(this.label);
  final String label;

  Color get color {
    switch (this) {
      case StockStatus.inStock:
        return const Color(0xFF2ECC71);
      case StockStatus.lowStock:
        return const Color(0xFFF39C12);
      case StockStatus.outOfStock:
        return const Color(0xFFE74C3C);
    }
  }

  String get value => name;

  static StockStatus fromValue(String value) => StockStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => StockStatus.inStock,
      );
}

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
      case ProductCategory.beverages:
        return Icons.local_cafe_rounded;
      case ProductCategory.dairy:
        return Icons.water_drop_rounded;
      case ProductCategory.snacks:
        return Icons.cookie_rounded;
      case ProductCategory.cleaning:
        return Icons.cleaning_services_rounded;
      case ProductCategory.personalCare:
        return Icons.favorite_rounded;
      case ProductCategory.grains:
        return Icons.grass_rounded;
      case ProductCategory.fruits:
        return Icons.eco_rounded;
      case ProductCategory.meat:
        return Icons.restaurant_rounded;
      case ProductCategory.bakery:
        return Icons.bakery_dining_rounded;
      case ProductCategory.frozen:
        return Icons.ac_unit_rounded;
      case ProductCategory.condiments:
        return Icons.whatshot_rounded;
      case ProductCategory.other:
        return Icons.inventory_2_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ProductCategory.beverages:    return const Color(0xFF3B82F6);
      case ProductCategory.dairy:        return const Color(0xFF60A5FA);
      case ProductCategory.snacks:       return const Color(0xFFF59E0B);
      case ProductCategory.cleaning:     return const Color(0xFF10B981);
      case ProductCategory.personalCare: return const Color(0xFFEC4899);
      case ProductCategory.grains:       return const Color(0xFFD97706);
      case ProductCategory.fruits:       return const Color(0xFF22C55E);
      case ProductCategory.meat:         return const Color(0xFFEF4444);
      case ProductCategory.bakery:       return const Color(0xFFF97316);
      case ProductCategory.frozen:       return const Color(0xFF6366F1);
      case ProductCategory.condiments:   return const Color(0xFFEAB308);
      case ProductCategory.other:        return const Color(0xFF6B7280);
    }
  }

  String get value => name;

  static ProductCategory fromValue(String value) =>
      ProductCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ProductCategory.other,
      );

  static ProductCategory fromCategoryId(String? id) {
    if (id == null || id.isEmpty) return ProductCategory.other;

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
    if (lower.contains('fruta') ||
        lower.contains('verdura') ||
        lower.contains('vegetable')) {
      return ProductCategory.fruits;
    }
    if (lower.contains('carne') || lower.contains('meat')) {
      return ProductCategory.meat;
    }
    if (lower.contains('panadería') ||
        lower.contains('panaderia') ||
        lower.contains('bakery')) {
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

enum MarginHealth {
  loss('Pérdida'),
  low('Margen bajo'),
  medium('Margen medio'),
  high('Margen alto');

  const MarginHealth(this.label);
  final String label;

  Color get color {
    switch (this) {
      case MarginHealth.loss:
        return const Color(0xFFE74C3C);
      case MarginHealth.low:
        return const Color(0xFFF39C12);
      case MarginHealth.medium:
        return const Color(0xFF0A84FF);
      case MarginHealth.high:
        return const Color(0xFF2ECC71);
    }
  }

  IconData get icon {
    switch (this) {
      case MarginHealth.loss:
        return Icons.trending_down_rounded;
      case MarginHealth.low:
        return Icons.report_problem_rounded;
      case MarginHealth.medium:
        return Icons.insights_rounded;
      case MarginHealth.high:
        return Icons.trending_up_rounded;
    }
  }
}

enum StockTrend {
  down('Baja'),
  stable('Estable'),
  up('Alta');

  const StockTrend(this.label);
  final String label;

  Color get color {
    switch (this) {
      case StockTrend.down:
        return const Color(0xFFE74C3C);
      case StockTrend.stable:
        return const Color(0xFF0A84FF);
      case StockTrend.up:
        return const Color(0xFF2ECC71);
    }
  }

  IconData get icon {
    switch (this) {
      case StockTrend.down:
        return Icons.south_rounded;
      case StockTrend.stable:
        return Icons.remove_rounded;
      case StockTrend.up:
        return Icons.north_rounded;
    }
  }
}

class SmartProductAnalysis {
  final MarginHealth marginHealth;
  final StockTrend stockTrend;
  final String headline;
  final String message;

  const SmartProductAnalysis({
    required this.marginHealth,
    required this.stockTrend,
    required this.headline,
    required this.message,
  });
}

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

  double get profitMargin =>
      costPrice > 0 ? ((salePrice - costPrice) / costPrice) * 100 : 0;

  double get markupPercentage =>
      salePrice > 0 ? ((salePrice - costPrice) / salePrice) * 100 : 0;

  double get profitPerUnit => salePrice - costPrice;

  double get stockValue => salePrice * quantity;
  double get costValue => costPrice * quantity;
  double get profitValue => profitPerUnit * quantity;

  double get stockCoverageRatio {
    if (minStock <= 0) return quantity.toDouble();
    return quantity / minStock;
  }

  StockStatus get stockStatus {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= minStock) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  MarginHealth get marginHealth {
    if (profitPerUnit < 0) return MarginHealth.loss;
    if (profitMargin < 10) return MarginHealth.low;
    if (profitMargin < 25) return MarginHealth.medium;
    return MarginHealth.high;
  }

  StockTrend get stockTrend {
    if (quantity <= 0 || quantity <= minStock) return StockTrend.down;
    if (stockCoverageRatio >= 2.5) return StockTrend.up;
    return StockTrend.stable;
  }

  SmartProductAnalysis get smartAnalysis {
    if (marginHealth == MarginHealth.loss) {
      return const SmartProductAnalysis(
        marginHealth: MarginHealth.loss,
        stockTrend: StockTrend.down,
        headline: 'Venta con pérdida',
        message:
            'El precio de venta está por debajo del costo. Ajusta el precio antes de reponer.',
      );
    }

    if (stockTrend == StockTrend.down && marginHealth == MarginHealth.high) {
      return SmartProductAnalysis(
        marginHealth: marginHealth,
        stockTrend: stockTrend,
        headline: 'Alta demanda detectada',
        message:
            'Buen margen, pero el stock está cerca del mínimo. Conviene reabastecer pronto.',
      );
    }

    if (stockTrend == StockTrend.down) {
      return SmartProductAnalysis(
        marginHealth: marginHealth,
        stockTrend: stockTrend,
        headline: 'Riesgo de quiebre',
        message:
            'El inventario va a la baja. Revisa compras o sube el stock mínimo para evitar faltantes.',
      );
    }

    if (marginHealth == MarginHealth.low) {
      return SmartProductAnalysis(
        marginHealth: marginHealth,
        stockTrend: stockTrend,
        headline: 'Margen ajustado',
        message:
            'Se vende con utilidad baja. Evalúa precio, costo o promociones para mejorar rentabilidad.',
      );
    }

    if (stockTrend == StockTrend.up && marginHealth == MarginHealth.high) {
      return SmartProductAnalysis(
        marginHealth: marginHealth,
        stockTrend: stockTrend,
        headline: 'Producto saludable',
        message:
            'Tiene buen margen y stock suficiente. Es un producto estable para priorizar.',
      );
    }

    return SmartProductAnalysis(
      marginHealth: marginHealth,
      stockTrend: stockTrend,
      headline: 'Desempeño estable',
      message:
          'El producto mantiene un equilibrio razonable entre margen y disponibilidad.',
    );
  }

  bool get isExpiringSoon {
    if (expirationDate == null) return false;
    final remaining = expirationDate!.difference(DateTime.now());
    return remaining.inSeconds > 0 && remaining.inDays <= 30;
  }

  bool get isExpired {
    if (expirationDate == null) return false;
    return expirationDate!.isBefore(DateTime.now());
  }

  factory Product.fromBackendJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        barcode: json['barcode'] as String? ?? '',
        category: ProductCategory.fromCategoryId(json['categoryId'] as String?),
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

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        barcode: json['barcode'] as String? ?? '',
        category: ProductCategory.fromValue(
          json['category'] as String? ?? ProductCategory.other.value,
        ),
        supplier: json['supplier'] as String? ?? '',
        costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
        salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        minStock: (json['minStock'] as num?)?.toInt() ?? 0,
        location: json['location'] as String? ?? '',
        expirationDate: json['expirationDate'] != null
            ? DateTime.tryParse(json['expirationDate'].toString())
            : null,
        imageURL: json['imageURL'] as String?,
        description: json['description'] as String? ?? '',
        lastUpdated: DateTime.tryParse(
              json['lastUpdated']?.toString() ?? '',
            ) ??
            DateTime.now(),
        isActive: json['isActive'] as bool? ?? true,
        storeId: json['storeId'] as String?,
        categoryId: json['categoryId'] as String?,
        supplierId: json['supplierId'] as String?,
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
        'expirationDate': expirationDate?.toIso8601String(),
        'imageURL': imageURL,
        'description': description,
        'lastUpdated': lastUpdated.toIso8601String(),
        'isActive': isActive,
        'storeId': storeId,
        'categoryId': categoryId,
        'supplierId': supplierId,
      };

  Map<String, dynamic> toBackendJson() => {
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'categoryId': categoryId,
        'supplierId': supplierId,
        'costPrice': costPrice,
        'sellingPrice': salePrice,
        'currentStock': quantity,
        'minStock': minStock,
        'location': location,
        'unit': description,
        'imageUrl': imageURL,
        'storeId': storeId,
      };

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
    bool clearExpirationDate = false,
    String? imageURL,
    bool clearImageURL = false,
    String? description,
    DateTime? lastUpdated,
    bool? isActive,
    String? storeId,
    String? categoryId,
    String? supplierId,
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
      expirationDate: clearExpirationDate
          ? null
          : (expirationDate ?? this.expirationDate),
      imageURL: clearImageURL ? null : (imageURL ?? this.imageURL),
      description: description ?? this.description,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
      storeId: storeId ?? this.storeId,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
    );
  }
}