import '../core/constants/api_constants.dart';
import '../models/inventory_movement.dart';
import '../services/api_service.dart';
import 'cache/inventory_movements_cache.dart';
import 'persistence/inventory_sqlite_mirror.dart';

/// Punto único para obtener movimientos con caché (L1 LRU + L2 Hive) y
/// espejo SQLite. Usado por restock, BQ3 y sugerencias AI.
class InventoryMovementsFetcher {
  InventoryMovementsFetcher._();

  static Future<List<InventoryMovement>> fetchForProduct(String productId) {
    return InventoryMovementsCache.shared.getOrFetch(
      productId,
      () => _fetchFromApi(productId),
    );
  }

  static Future<List<InventoryMovement>> _fetchFromApi(String productId) async {
    final data = await ApiService.shared.get(
      kInventoryMovements,
      query: {'productId': productId},
    );

    final list = _extractList(data);
    final movements = list
        .whereType<Map>()
        .map((e) => InventoryMovement.fromBackendJson(
              e.cast<String, dynamic>(),
            ))
        .where((m) => m.productId == productId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    await InventorySqliteMirror.shared.mirrorMovements(productId, movements);
    return movements;
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      return (data['data'] as List?) ??
          (data['items'] as List?) ??
          (data['movements'] as List?) ??
          (data['results'] as List?) ??
          const [];
    }
    return const [];
  }
}
