import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/quick_scan_history_service.dart';

final quickScanHistoryProvider =
    FutureProvider<List<QuickScanEntry>>((ref) async {
  await QuickScanHistoryService.shared.init();
  return QuickScanHistoryService.shared.getRecent();
});

class QuickScanHistoryNotifier {
  QuickScanHistoryNotifier(this.ref);
  final Ref ref;

  Future<void> record({
    required String barcode,
    String? productId,
    required String displayName,
    required bool foundInInventory,
  }) async {
    await QuickScanHistoryService.shared.record(
      barcode: barcode,
      productId: productId,
      displayName: displayName,
      foundInInventory: foundInInventory,
    );
    ref.invalidate(quickScanHistoryProvider);
  }

  Future<void> clear() async {
    await QuickScanHistoryService.shared.clear();
    ref.invalidate(quickScanHistoryProvider);
  }
}
