import 'package:flutter/material.dart';
import '../core/utils/extensions.dart';

// ─────────────────────────────────────────────
// OrderStatus
// ─────────────────────────────────────────────
enum OrderStatus {
  pending('Pendiente'),
  confirmed('Confirmado'),
  shipped('Enviado'),
  delivered('Entregado'),
  cancelled('Cancelado');

  const OrderStatus(this.label);
  final String label;

  IconData get icon {
    switch (this) {
      case pending:
        return Icons.access_time_rounded;
      case confirmed:
        return Icons.check_circle_rounded;
      case shipped:
        return Icons.local_shipping_rounded;
      case delivered:
        return Icons.verified_rounded;
      case cancelled:
        return Icons.cancel_rounded;
    }
  }

  Color get color {
    switch (this) {
      case pending:
        return const Color(0xFFF39C12); // warning
      case confirmed:
        return const Color(0xFF00A8E8); // freshSky / info
      case shipped:
        return const Color(0xFF9B59B6); // purple
      case delivered:
        return const Color(0xFF2ECC71); // success
      case cancelled:
        return const Color(0xFFE74C3C); // error
    }
  }

  String get value => name;

  static OrderStatus fromValue(String value) => OrderStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => OrderStatus.pending,
      );
}

// ─────────────────────────────────────────────
// Order  (mirrors Order struct in Swift)
// ─────────────────────────────────────────────
class Order {
  final String id;
  final String orderNumber;
  final String supplier;
  final OrderStatus status;
  final double totalAmount;
  final int itemCount;
  final DateTime createdAt;
  final DateTime? expectedDelivery;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.supplier,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
    required this.createdAt,
    this.expectedDelivery,
  });

  /// "$450.000"
  String get formattedTotal => totalAmount.currencyFormatted;

  Order copyWith({
    String? id,
    String? orderNumber,
    String? supplier,
    OrderStatus? status,
    double? totalAmount,
    int? itemCount,
    DateTime? createdAt,
    DateTime? expectedDelivery,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      supplier: supplier ?? this.supplier,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      itemCount: itemCount ?? this.itemCount,
      createdAt: createdAt ?? this.createdAt,
      expectedDelivery: expectedDelivery ?? this.expectedDelivery,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String,
        supplier: json['supplier'] as String,
        status: OrderStatus.fromValue(json['status'] as String),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        itemCount: json['itemCount'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        expectedDelivery: json['expectedDelivery'] != null
            ? DateTime.parse(json['expectedDelivery'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'supplier': supplier,
        'status': status.value,
        'totalAmount': totalAmount,
        'itemCount': itemCount,
        'createdAt': createdAt.toIso8601String(),
        if (expectedDelivery != null)
          'expectedDelivery': expectedDelivery!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
