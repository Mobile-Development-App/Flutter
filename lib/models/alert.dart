import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/extensions.dart';

// ─────────────────────────────────────────────
// AlertType  (mirrors AlertType enum in Swift)
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

  /// Material icon that mirrors the SF Symbol used in Swift
  IconData get icon {
    switch (this) {
      case lowStock:
        return Icons.warning_rounded;
      case outOfStock:
        return Icons.cancel_rounded;
      case expiringSoon:
        return Icons.access_time_filled_rounded;
      case expired:
        return Icons.event_busy_rounded;
      case priceChange:
        return Icons.monetization_on_rounded;
      case newProduct:
        return Icons.add_circle_rounded;
      case restock:
        return Icons.refresh_rounded;
    }
  }

  Color get color {
    switch (this) {
      case lowStock:
      case expiringSoon:
        return AppColors.warning;
      case outOfStock:
      case expired:
        return AppColors.error;
      case priceChange:
        return AppColors.info;
      case newProduct:
      case restock:
        return AppColors.success;
    }
  }

  /// JSON serialization key
  String get value => name;

  static AlertType fromValue(String value) =>
      AlertType.values.firstWhere((e) => e.name == value,
          orElse: () => AlertType.lowStock);
}

// ─────────────────────────────────────────────
// AlertPriority
// ─────────────────────────────────────────────
enum AlertPriority {
  high('Alta'),
  medium('Media'),
  low('Baja');

  const AlertPriority(this.label);
  final String label;

  Color get color {
    switch (this) {
      case high:
        return AppColors.error;
      case medium:
        return AppColors.warning;
      case low:
        return AppColors.info;
    }
  }

  String get value => name;

  static AlertPriority fromValue(String value) =>
      AlertPriority.values.firstWhere((e) => e.name == value,
          orElse: () => AlertPriority.low);
}

// ─────────────────────────────────────────────
// InventoryAlert  (mirrors InventoryAlert struct)
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

  /// "hace 3 min", "hace 2 días" – uses DateFormatting extension
  String get relativeTime => createdAt.relativeFormatted;

  // ── Immutable copy ──
  InventoryAlert copyWith({
    String? id,
    String? title,
    String? message,
    AlertType? type,
    AlertPriority? priority,
    String? productId,
    String? productName,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return InventoryAlert(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ── JSON ──
  factory InventoryAlert.fromJson(Map<String, dynamic> json) {
    return InventoryAlert(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: AlertType.fromValue(json['type'] as String),
      priority: AlertPriority.fromValue(json['priority'] as String),
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.value,
        'priority': priority.value,
        if (productId != null) 'productId': productId,
        if (productName != null) 'productName': productName,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryAlert &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
