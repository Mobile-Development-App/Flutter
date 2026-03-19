import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/extensions.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────
// AlertType — maps backend strings
// Backend: EXPIRING_SOON, LOW_STOCK, OUT_OF_STOCK, etc.
// ─────────────────────────────────────────────
enum AlertType {
  lowStock('Stock Bajo'),
  outOfStock('Agotado'),
  expiringSoon('Por Vencer'),
  expired('Vencido'),
  priceChange('Cambio de Precio'),
  newProduct('Nuevo Producto'),
  restock('Reabastecimiento');

  const AlertType(this.label);
  final String label;

  IconData get icon {
    switch (this) {
      case lowStock:     return Icons.warning_rounded;
      case outOfStock:   return Icons.cancel_rounded;
      case expiringSoon: return Icons.access_time_filled_rounded;
      case expired:      return Icons.event_busy_rounded;
      case priceChange:  return Icons.monetization_on_rounded;
      case newProduct:   return Icons.add_circle_rounded;
      case restock:      return Icons.refresh_rounded;
    }
  }

  Color get color {
    switch (this) {
      case lowStock:
      case expiringSoon: return AppColors.warning;
      case outOfStock:
      case expired:      return AppColors.error;
      case priceChange:  return AppColors.info;
      case newProduct:
      case restock:      return AppColors.success;
    }
  }

  String get value => name;

  // Maps backend type strings like LOW_STOCK, EXPIRING_SOON
  static AlertType fromBackend(String? val) {
    switch ((val ?? '').toUpperCase()) {
      case 'LOW_STOCK':     return AlertType.lowStock;
      case 'OUT_OF_STOCK':  return AlertType.outOfStock;
      case 'EXPIRING_SOON': return AlertType.expiringSoon;
      case 'EXPIRED':       return AlertType.expired;
      case 'PRICE_CHANGE':  return AlertType.priceChange;
      case 'NEW_PRODUCT':   return AlertType.newProduct;
      case 'RESTOCK':       return AlertType.restock;
      default:              return AlertType.lowStock;
    }
  }

  static AlertType fromValue(String value) => AlertType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AlertType.lowStock,
      );
}


enum AlertPriority {
  high('Alta'),
  medium('Media'),
  low('Baja');

  const AlertPriority(this.label);
  final String label;

  Color get color {
    switch (this) {
      case high:   return AppColors.error;
      case medium: return AppColors.warning;
      case low:    return AppColors.info;
    }
  }

  String get value => name;

  // Backend sends INFO, WARNING, CRITICAL
  static AlertPriority fromBackend(String? val) {
    switch ((val ?? '').toUpperCase()) {
      case 'CRITICAL': return AlertPriority.high;
      case 'WARNING':  return AlertPriority.medium;
      case 'INFO':
      default:         return AlertPriority.low;
    }
  }

  static AlertPriority fromValue(String value) =>
      AlertPriority.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AlertPriority.low,
      );
}

// ─────────────────────────────────────────────
// InventoryAlert
// Backend schema: { id, title, message, type, priority,
//   isRead, readAt, productId, productName, storeId, createdAt }
// ─────────────────────────────────────────────
class InventoryAlert {
  final String id;
  final String title;
  final String message;
  final AlertType type;
  final AlertPriority priority;
  final String? productId;
  final String? productName;
  final bool isRead;
  final DateTime createdAt;

  const InventoryAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    this.productId,
    this.productName,
    required this.isRead,
    required this.createdAt,
  });

  String get relativeTime => createdAt.relativeFormatted;

  // ── From backend ──
  factory InventoryAlert.fromBackendJson(Map<String, dynamic> json) =>
      InventoryAlert(
        id:          json['id'] as String? ?? '',
        title:       json['title'] as String? ?? '',
        message:     json['message'] as String? ?? '',
        type:        AlertType.fromBackend(json['type'] as String?),
        priority:    AlertPriority.fromBackend(json['priority'] as String?),
        productId:   json['productId'] as String?,
        productName: json['productName'] as String?,
        isRead:      json['isRead'] as bool? ?? false,
        createdAt:   ApiService.parseDate(json['createdAt']) ?? DateTime.now(),
      );

  // ── Local JSON ──
  factory InventoryAlert.fromJson(Map<String, dynamic> json) => InventoryAlert(
        id:          json['id'] as String,
        title:       json['title'] as String,
        message:     json['message'] as String,
        type:        AlertType.fromValue(json['type'] as String),
        priority:    AlertPriority.fromValue(json['priority'] as String),
        productId:   json['productId'] as String?,
        productName: json['productName'] as String?,
        isRead:      json['isRead'] as bool? ?? false,
        createdAt:   DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id':        id,
        'title':     title,
        'message':   message,
        'type':      type.value,
        'priority':  priority.value,
        if (productId   != null) 'productId':   productId,
        if (productName != null) 'productName': productName,
        'isRead':    isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  InventoryAlert copyWith({bool? isRead}) => InventoryAlert(
        id:          id,
        title:       title,
        message:     message,
        type:        type,
        priority:    priority,
        productId:   productId,
        productName: productName,
        isRead:      isRead ?? this.isRead,
        createdAt:   createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryAlert &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
