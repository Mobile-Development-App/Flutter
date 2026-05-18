import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../storage/inventory_movements_fetcher.dart';
import 'inventory_provider.dart';

@immutable
class RestockLatencyInfo {
  final int? lastCycleDays;
  final int? averageDays;
  final int? recommendedDays;

  const RestockLatencyInfo({this.lastCycleDays, this.averageDays, this.recommendedDays});

  bool get hasData => lastCycleDays != null || averageDays != null;
}

final inventoryMovementsProvider =
    FutureProvider.family<List<InventoryMovement>, String>((ref, productId) {
  return InventoryMovementsFetcher.fetchForProduct(productId);
});

final restockLatencyProvider =
    Provider.family<RestockLatencyInfo, String>((ref, productId) {
  final inv = ref.watch(inventoryProvider).value;
  if (inv == null) return const RestockLatencyInfo();

  final product = inv.products.where((p) => p.id == productId).firstOrNull;

  final alerts = inv.alerts
      .where((a) =>
          a.productId == productId &&
          (a.type == AlertType.lowStock || a.type == AlertType.outOfStock))
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final movementsAsync = ref.watch(inventoryMovementsProvider(productId));
  final movements = movementsAsync.valueOrNull;
  if (movements == null || movements.isEmpty) {
    // We can still compute a quantity-based recommendation without movement history.
    final rec = _recommendFromQuantity(product);
    final referenceDate = product?.lastUpdated ?? DateTime.now();
    final adjustedRec = rec == null ? null : _adjustDaysByElapsedHalfDays(rec, referenceDate);
    return RestockLatencyInfo(recommendedDays: adjustedRec);
  }

  final restocks =
      movements.where((m) => m.type == InventoryMovementType.restock).toList();

  int? lastCycleDays;
  int? avgDays;
  if (alerts.isNotEmpty && restocks.isNotEmpty) {
    InventoryMovement sentinelMovement() => InventoryMovement(
          id: '',
          productId: '',
          type: InventoryMovementType.unknown,
          quantity: 0,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );

    final lastAlert = alerts.last;
    final nextRestockAfterLast = restocks.firstWhere(
      (m) => !m.createdAt.isBefore(lastAlert.createdAt),
      orElse: sentinelMovement,
    );
    if (nextRestockAfterLast.id.isNotEmpty) {
      final d =
          nextRestockAfterLast.createdAt.difference(lastAlert.createdAt).inDays;
      if (d >= 0) lastCycleDays = d;
    }

    final deltas = <int>[];
    for (final a in alerts) {
      final r = restocks.firstWhere(
        (m) => !m.createdAt.isBefore(a.createdAt),
        orElse: sentinelMovement,
      );
      if (r.id.isEmpty) continue;
      final d = r.createdAt.difference(a.createdAt).inDays;
      if (d >= 0) deltas.add(d);
    }

    if (deltas.isNotEmpty) {
      avgDays = (deltas.reduce((a, b) => a + b) / deltas.length).round();
    }
  }

  final sales = movements.where((m) => m.type == InventoryMovementType.sale).toList();
  final rec = _recommendFromQuantity(product, sales: sales);

  final referenceDate = product?.lastUpdated ?? DateTime.now();

  final adjustedLastCycleDays = lastCycleDays == null
      ? null
      : _adjustDaysByElapsedHalfDays(lastCycleDays, referenceDate);
  final adjustedAvgDays = avgDays == null
      ? null
      : _adjustDaysByElapsedHalfDays(avgDays, referenceDate);

  int? adjustedRec = rec;
  if (adjustedRec != null) {
    adjustedRec = _adjustDaysByElapsedHalfDays(adjustedRec, referenceDate);
  }

  return RestockLatencyInfo(
    lastCycleDays: adjustedLastCycleDays,
    averageDays: adjustedAvgDays,
    recommendedDays: adjustedRec,
  );
});

int _adjustDaysByElapsedHalfDays(int days, DateTime since) {
  final elapsedHours = DateTime.now().difference(since).inHours;
  if (elapsedHours < 12) return days;

  final reduction = elapsedHours ~/ 12;
  final result = days - reduction;
  return result < 0 ? 0 : result;
}

int? _recommendFromQuantity(Product? p, {List<InventoryMovement> sales = const []}) {
  if (p == null) return null;
  if (!p.isActive) return null;

  if (p.quantity <= 0) return 0;
  if (p.minStock <= 0) return null;

  // Only recommend when we're at/below minimum (same trigger as low stock).
  if (p.quantity > p.minStock) return null;

  // Quantity factor: closer to 0 => fewer days.
  final deficitRatio = ((p.minStock - p.quantity) / p.minStock).clamp(0.0, 1.0);
  // Maps ratio [0..1] to days [7..1]
  final ratioDays = (7 - (deficitRatio * 6)).round().clamp(1, 7);

  // Velocity factor (if we have SALE movements): estimate days until stockout.
  int? velocityDays;
  if (sales.isNotEmpty) {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 14));
    final recent = sales.where((m) => m.createdAt.isAfter(windowStart)).toList();
    if (recent.isNotEmpty) {
      final totalSold = recent.fold<int>(0, (s, m) => s + m.quantity.abs());
      final daily = totalSold / 14.0;
      if (daily > 0) {
        velocityDays = (p.quantity / daily).floor().clamp(0, 30);
      }
    }
  }

  if (velocityDays == null) return ratioDays;
  // Take the more urgent (smaller) number of days.
  return velocityDays < ratioDays ? velocityDays : ratioDays;
}

