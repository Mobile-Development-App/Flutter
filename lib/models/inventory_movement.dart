import '../services/api_service.dart';

enum InventoryMovementType {
  sale,
  restock,
  adjust,
  unknown;

  static InventoryMovementType fromBackend(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'SALE':
        return InventoryMovementType.sale;
      case 'RESTOCK':
        return InventoryMovementType.restock;
      case 'ADJUST':
      case 'ADJUSTMENT':
        return InventoryMovementType.adjust;
      default:
        return InventoryMovementType.unknown;
    }
  }
}

class InventoryMovement {
  final String id;
  final String productId;
  final InventoryMovementType type;
  final int quantity;
  final DateTime createdAt;

  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.createdAt,
  });

  factory InventoryMovement.fromBackendJson(Map<String, dynamic> json) {
    final created = ApiService.parseDate(json['createdAt']) ??
        ApiService.parseDate(json['timestamp']) ??
        ApiService.parseDate(json['date']) ??
        DateTime.now();

    return InventoryMovement(
      id: (json['id'] as String?) ??
          (json['movementId'] as String?) ??
          '',
      productId: json['productId'] as String? ?? '',
      type: InventoryMovementType.fromBackend(json['type'] as String?),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      createdAt: created,
    );
  }
}

