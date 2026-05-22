import 'package:flutter/foundation.dart';

import '../../models/inventory_movement.dart';
import '../../models/product.dart';
import '../../services/local_store_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InventorySqliteMirror — NUEVO requerimiento (BD relacional sqflite)
//
// Espeja en SQLite lo que ya vive en memoria/API, sin reemplazar CacheService.
// Permite consultas JOIN offline (stock por tienda, movimientos por producto).
// Solo en plataformas con sqflite (!kIsWeb).
// ─────────────────────────────────────────────────────────────────────────────

class InventorySqliteMirror {
  InventorySqliteMirror._();
  static final InventorySqliteMirror shared = InventorySqliteMirror._();

  bool get _enabled => !kIsWeb;

  Future<void> mirrorProducts(Iterable<Product> products) async {
    if (!_enabled || products.isEmpty) return;
    try {
      await LocalDatabaseService.shared.init();
      await LocalDatabaseService.shared.upsertProducts(products.toList());
      debugPrint('[SqliteMirror] ${products.length} productos');
    } catch (e) {
      debugPrint('[SqliteMirror] mirrorProducts: $e');
    }
  }

  Future<void> mirrorMovements(
    String productId,
    List<InventoryMovement> movements,
  ) async {
    if (!_enabled || movements.isEmpty) return;
    try {
      await LocalDatabaseService.shared.init();
      await LocalDatabaseService.shared.insertMovements(movements);
      debugPrint('[SqliteMirror] ${movements.length} movimientos → $productId');
    } catch (e) {
      debugPrint('[SqliteMirror] mirrorMovements: $e');
    }
  }

  Future<void> recordRestockMovement({
    required String productId,
    required int quantity,
    String? movementId,
  }) async {
    if (!_enabled) return;
    try {
      await LocalDatabaseService.shared.init();
      final movement = InventoryMovement(
        id: movementId ?? 'local_${DateTime.now().millisecondsSinceEpoch}',
        productId: productId,
        type: InventoryMovementType.restock,
        quantity: quantity,
        createdAt: DateTime.now(),
      );
      await LocalDatabaseService.shared.insertMovement(movement);
    } catch (e) {
      debugPrint('[SqliteMirror] recordRestockMovement: $e');
    }
  }

  Future<List<Product>> readProductsOffline() async {
    if (!_enabled) return [];
    try {
      await LocalDatabaseService.shared.init();
      return LocalDatabaseService.shared.getProducts();
    } catch (e) {
      debugPrint('[SqliteMirror] readProductsOffline: $e');
      return [];
    }
  }
}
