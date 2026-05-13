import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../providers/inventory_provider.dart';
import '../services/inventory_health_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InventoryHealthNotifier
//
// CONCURRENCY PATTERN: Future.wait() + compute() — 4 simultaneous Isolates
// ─────────────────────────────────────────────────────────────────────────────
// On every call to refresh():
//   1. Reads the current product list from InventoryNotifier.
//   2. Serialises products to wire-format maps on the UI thread (fast).
//   3. Calls InventoryHealthService.analyse() which fires 4 compute() calls
//      simultaneously via Future.wait() — each in its own Dart Isolate.
//   4. Awaits the merged InventoryHealthReport and updates state.
//
// The provider is kept separate from the inventory provider so the heavy
// Isolate work never runs unless the user navigates to the Health screen.
// ─────────────────────────────────────────────────────────────────────────────

class InventoryHealthNotifier
    extends AsyncNotifier<InventoryHealthReport?> {
  @override
  Future<InventoryHealthReport?> build() async {
    ref.watch(inventoryProvider);
    return _loadReport();
  }

  /// Serialises products and launches 4 concurrent Isolates.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final report = await _loadReport();
      state = AsyncData(report);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<InventoryHealthReport> _loadReport() async {
    // Read products from the shared inventory provider.
    final inventoryState = ref.read(inventoryProvider).value;
    final products = inventoryState?.products ?? <Product>[];

    // Serialise to wire format on the UI thread (O(n) string ops — fast).
    final wireProducts = products.map(InventoryHealthService.toWireFormat).toList();

    // Run 4 analyses in parallel Isolates.
    return InventoryHealthService.shared.analyse(wireProducts);
  }

  /// Generates a plain-text report in a 5th Isolate and returns the string.
  Future<String?> generateTextReport() async {
    final report = state.value;
    if (report == null) return null;
    return InventoryHealthService.shared.generateTextReport(report);
  }
}

final inventoryHealthProvider =
    AsyncNotifierProvider<InventoryHealthNotifier, InventoryHealthReport?>(
  InventoryHealthNotifier.new,
);
