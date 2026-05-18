import 'package:flutter/foundation.dart';

import 'cache/dashboard_snapshot_store.dart';
import 'cache/inventory_movements_cache.dart';
import 'cache/open_food_facts_cache.dart';
import 'cache/restock_suggestions_cache.dart';
import 'persistence/alerts_read_preferences_store.dart';
import 'persistence/scan_session_file_store.dart';

/// Inicializa todos los módulos de `lib/storage/` (nuevos requerimientos).
/// Llamar desde [main] después de Hive.initFlutter (UsageTrackingService).
class StorageInitializer {
  StorageInitializer._();

  static Future<void> init() async {
    await Future.wait([
      InventoryMovementsCache.shared.init(),
      OpenFoodFactsCache.shared.init(),
      RestockSuggestionsCache.shared.init(),
      DashboardSnapshotStore.shared.init(),
      AlertsReadPreferencesStore.shared.init(),
      if (!kIsWeb) ScanSessionFileStore.shared.init(),
    ]);
    debugPrint('[Storage] Módulos lib/storage/ inicializados');
  }
}
